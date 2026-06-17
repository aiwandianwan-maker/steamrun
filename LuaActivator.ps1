#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ========== 配置区 ==========
$mapUrl = "https://awsteam.icu/keys.json"
$downloadBaseUrl = "https://awsteam.icu/lua/"
# ============================

# 网络基础配置：强制TLS12 + 忽略证书 + 禁用系统代理
try {
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
} catch {
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
}
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# 主窗口
$form = New-Object System.Windows.Forms.Form
$form.Text = "steam游戏入库"
$form.Size = New-Object System.Drawing.Size(520,320)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(23,26,33)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei",9)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# 说明文字
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(30,30)
$label.Size = New-Object System.Drawing.Size(440,60)
$label.Text = "请输入激活码"
$label.ForeColor = [System.Drawing.Color]::FromArgb(200,200,200)
$form.Controls.Add($label)

# 激活码输入框
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(30,110)
$textBox.Size = New-Object System.Drawing.Size(440,35)
$textBox.BackColor = [System.Drawing.Color]::FromArgb(40,44,52)
$textBox.ForeColor = [System.Drawing.Color]::White
$textBox.BorderStyle = "FixedSingle"
$textBox.Font = New-Object System.Drawing.Font("Microsoft YaHei",10)
$form.Controls.Add($textBox)

# 状态提示
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(30,160)
$statusLabel.Size = New-Object System.Drawing.Size(440,25)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,150,150)
$form.Controls.Add($statusLabel)

# 确认按钮
$okBtn = New-Object System.Windows.Forms.Button
$okBtn.Location = New-Object System.Drawing.Point(260,210)
$okBtn.Size = New-Object System.Drawing.Size(100,35)
$okBtn.Text = "确认"
$okBtn.BackColor = [System.Drawing.Color]::FromArgb(0,117,194)
$okBtn.ForeColor = [System.Drawing.Color]::White
$okBtn.FlatStyle = "Flat"

$okBtn.Add_Click({
    $okBtn.Enabled = $false
    $statusLabel.Text = "正在校验激活码..."
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,200,100)

    $inputKey = $textBox.Text.Trim()
    if([string]::IsNullOrWhiteSpace($inputKey)){
        $statusLabel.Text = "错误：请输入激活码"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,100,100)
        $okBtn.Enabled = $true
        return
    }

    # 1. 下载激活码映射文件
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Proxy = $null
    try{
        $mapJson = $wc.DownloadString($mapUrl)
    }catch{
        $statusLabel.Text = "错误：无法连接激活服务，请检查网络"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,100,100)
        $okBtn.Enabled = $true
        return
    }

    # 2. 解析JSON（完全兼容PowerShell 5.1）
    try{
        $keyObj = $mapJson | ConvertFrom-Json
        $keyTable = @{}
        # 把对象属性转成哈希表，替代-AsHashtable
        foreach($prop in $keyObj.PSObject.Properties){
            $keyTable[$prop.Name] = $prop.Value
        }
    }catch{
        $statusLabel.Text = "错误：激活码数据解析失败"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,100,100)
        $okBtn.Enabled = $true
        return
    }

    # 校验激活码是否存在
    if(-not $keyTable.ContainsKey($inputKey)){
        $statusLabel.Text = "错误：激活码无效，请检查输入，区分大小写"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,100,100)
        $okBtn.Enabled = $true
        return
    }

    $luaFile = $keyTable[$inputKey]
    $statusLabel.Text = "正在定位Steam安装目录..."

    # 3. 自动查找Steam目录
    $steamPath = $null
    # 注册表查找
    if(Test-Path "HKCU:\Software\Valve\Steam"){
        $reg = Get-ItemProperty "HKCU:\Software\Valve\Steam"
        if($reg.SteamPath -and (Test-Path "$($reg.SteamPath)\steam.exe")){
            $steamPath = $reg.SteamPath.TrimEnd('\')
        }
    }
    if(-not $steamPath -and (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam")){
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
        if($reg.InstallPath -and (Test-Path "$($reg.InstallPath)\steam.exe")){
            $steamPath = $reg.InstallPath.TrimEnd('\')
        }
    }
    # 盘符扫描兜底
    if(-not $steamPath){
        @("C:","D:","E:","F:") | ForEach-Object {
            foreach($p in @("$_\Program Files (x86)\Steam","$_\Steam")){
                if(Test-Path "$p\steam.exe"){ $steamPath = $p; break }
            }
        }
    }

    if(-not $steamPath){
        $statusLabel.Text = "错误：未找到Steam安装目录"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,100,100)
        $okBtn.Enabled = $true
        return
    }

    # 4. 创建lua目录并下载文件
    $targetDir = Join-Path $steamPath "config\lua"
    $targetPath = Join-Path $targetDir $luaFile
    $downloadUrl = $downloadBaseUrl + $luaFile

    try{
        if(-not (Test-Path $targetDir)){
            New-Item $targetDir -ItemType Directory -Force | Out-Null
        }
        $wc.DownloadFile($downloadUrl, $targetPath)
    }catch{
        $statusLabel.Text = "错误：文件下载失败，请检查网络"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255,100,100)
        $okBtn.Enabled = $true
        return
    }

    # 完成
    $statusLabel.Text = "成功，已激活游戏"
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(100,255,100)
    Start-Sleep -Seconds 1.5
    $form.Close()
})
$form.Controls.Add($okBtn)

# 取消按钮
$cancelBtn = New-Object System.Windows.Forms.Button
$cancelBtn.Location = New-Object System.Drawing.Point(370,210)
$cancelBtn.Size = New-Object System.Drawing.Size(100,35)
$cancelBtn.Text = "取消"
$cancelBtn.BackColor = [System.Drawing.Color]::FromArgb(60,64,72)
$cancelBtn.ForeColor = [System.Drawing.Color]::White
$cancelBtn.FlatStyle = "Flat"
$cancelBtn.Add_Click({ $form.Close() })
$form.Controls.Add($cancelBtn)

# 显示窗口
$form.ShowDialog() | Out-Null