#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ========== 配置区（仅修改这里的接口域名） ==========
$apiUrl = "https://api.awsteam.icu/api.php"
$downloadBaseUrl = "https://awsteam.icu/lua/"
# ==========================================

# TLS网络兼容适配
try {
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
} catch {
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
}
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# 读取本地当前登录Steam 64位账号ID
function Get-LocalSteamID {
    try {
        $reg = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop
        if ($reg.SteamID -and $reg.SteamID -ne 0) {
            return [string]$reg.SteamID
        }
        return $null
    }
    catch {
        return $null
    }
}

# 激活GUI主窗口
$form = New-Object System.Windows.Forms.Form
$form.Text = "Steam Lua激活工具"
$form.Size = New-Object System.Drawing.Size(530,330)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(23,26,33)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei",9)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# 顶部提示文字
$labelTip = New-Object System.Windows.Forms.Label
$labelTip.Location = New-Object System.Drawing.Point(30,28)
$labelTip.Size = New-Object System.Drawing.Size(460,60)
$labelTip.Text = "输入激活码自动下载对应Lua补丁。激活码首次使用绑定当前Steam账号，同账号换电脑可重复使用，其他账号无法激活。"
$labelTip.ForeColor = [System.Drawing.Color]::LightGray
$form.Controls.Add($labelTip)

# 激活码输入框
$textKey = New-Object System.Windows.Forms.TextBox
$textKey.Location = New-Object System.Drawing.Point(30,112)
$textKey.Size = New-Object System.Drawing.Size(460,36)
$textKey.BackColor = [System.Drawing.Color]::FromArgb(40,44,52)
$textKey.ForeColor = [System.Drawing.Color]::White
$textKey.BorderStyle = "FixedSingle"
$textKey.Font = New-Object System.Drawing.Font("Microsoft YaHei",10)
$form.Controls.Add($textKey)

# 状态提示文字
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Location = New-Object System.Drawing.Point(30,162)
$labelStatus.Size = New-Object System.Drawing.Size(460,26)
$labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(255,130,130)
$form.Controls.Add($labelStatus)

# 确认按钮
$btnConfirm = New-Object System.Windows.Forms.Button
$btnConfirm.Location = New-Object System.Drawing.Point(270,210)
$btnConfirm.Size = New-Object System.Drawing.Size(105,38)
$btnConfirm.Text = "确认激活"
$btnConfirm.BackColor = [System.Drawing.Color]::FromArgb(0,120,200)
$btnConfirm.ForeColor = [System.Drawing.Color]::White
$btnConfirm.FlatStyle = "Flat"

$btnConfirm.Add_Click({
    $btnConfirm.Enabled = $false
    $labelStatus.Text = "正在校验激活码与Steam账号..."
    $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(255,210,100)

    $inputCode = $textKey.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($inputCode)) {
        $labelStatus.Text = "错误：请填写激活码"
        $labelStatus.ForeColor = [System.Drawing.Color]::Red
        $btnConfirm.Enabled = $true
        return
    }

    $sid = Get-LocalSteamID
    if (-not $sid) {
        $labelStatus.Text = "错误：未检测到登录的Steam客户端，请先登录Steam"
        $labelStatus.ForeColor = [System.Drawing.Color]::Red
        $btnConfirm.Enabled = $true
        return
    }

    # 提交激活信息到云服务器后端校验
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Encoding = [System.Text.Encoding]::UTF8
        $wc.Proxy = $null
        $wc.Headers.Add("Content-Type", "application/x-www-form-urlencoded")
        $postData = "key=" + [System.Web.HttpUtility]::UrlEncode($inputCode) + "&steamid=" + $sid
        $response = $wc.UploadString($apiUrl, $postData)
        $resData = $response | ConvertFrom-Json
    }
    catch {
        $labelStatus.Text = "网络错误：无法连接激活服务器，请检查网络"
        $labelStatus.ForeColor = [System.Drawing.Color]::Red
        $btnConfirm.Enabled = $true
        return
    }

    # 后端返回校验结果判断
    if ($resData.code -ne 1) {
        $labelStatus.Text = $resData.msg
        $labelStatus.ForeColor = [System.Drawing.Color]::Red
        $btnConfirm.Enabled = $true
        return
    }

    $luaName = $resData.lua
    $labelStatus.Text = "校验通过，正在下载对应Lua补丁..."
    $labelStatus.ForeColor = [System.Drawing.Color]::Green

    # 自动检索Steam安装目录
    $steamRoot = $null
    if (Test-Path "HKCU:\Software\Valve\Steam") {
        $regInfo = Get-ItemProperty "HKCU:\Software\Valve\Steam"
        if ($regInfo.SteamPath -and (Test-Path "$($regInfo.SteamPath)\steam.exe")) {
            $steamRoot = $regInfo.SteamPath.TrimEnd('\')
        }
    }
    if (-not $steamRoot -and (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam")) {
        $regInfo = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
        if ($regInfo.InstallPath -and (Test-Path "$($regInfo.InstallPath)\steam.exe")) {
            $steamRoot = $regInfo.InstallPath.TrimEnd('\')
        }
    }
    if (-not $steamRoot) {
        $disks = @("C:","D:","E:","F:")
        foreach ($d in $disks) {
            $p1 = "$d\Program Files (x86)\Steam"
            if (Test-Path "$p1\steam.exe") { $steamRoot = $p1; break }
            $p2 = "$d\Steam"
            if (Test-Path "$p2\steam.exe") { $steamRoot = $p2; break }
        }
    }
    if (-not $steamRoot) {
        $labelStatus.Text = "错误：未找到Steam安装文件夹"
        $labelStatus.ForeColor = [System.Drawing.Color]::Red
        $btnConfirm.Enabled = $true
        return
    }

    # 下载后端返回的专属Lua文件
    $luaDir = Join-Path $steamRoot "config\lua"
    $luaFullPath = Join-Path $luaDir $luaName
    $dlUrl = $downloadBaseUrl + $luaName
    try {
        if (-not (Test-Path $luaDir)) {
            New-Item $luaDir -ItemType Directory -Force | Out-Null
        }
        $wc.DownloadFile($dlUrl, $luaFullPath)
    }
    catch {
        $labelStatus.Text = "Lua补丁下载失败，请检查网络或文件名"
        $labelStatus.ForeColor = [System.Drawing.Color]::Red
        $btnConfirm.Enabled = $true
        return
    }

    # 激活完成提示，2秒自动关闭窗口
    $labelStatus.Text = $resData.msg
    $labelStatus.ForeColor = [System.Drawing.Color]::LimeGreen
    Start-Sleep -Seconds 2
    $form.Close()
})
$form.Controls.Add($btnConfirm)

# 取消按钮
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(390,210)
$btnCancel.Size = New-Object System.Drawing.Size(105,38)
$btnCancel.Text = "取消"
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60,64,72)
$btnCancel.ForeColor = [System.Drawing.Color]::White
$btnCancel.FlatStyle = "Flat"
$btnCancel.Add_Click({ $form.Close() })
$form.Controls.Add($btnCancel)

$form.ShowDialog() | Out-Null
