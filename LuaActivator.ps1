# 激活码验证独立程序
try {
    $ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    exit
}

# 网络配置
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::Expect100Continue = $false
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$ApiUrl = "https://api.awsteam.icu/api.php"

# 字体容错：优先雅黑，不存在则用系统默认字体
try {
    $defFont = New-Object System.Drawing.Font("Microsoft YaHei", 10)
    $titleFont = New-Object System.Drawing.Font("Microsoft YaHei", 18, [System.Drawing.FontStyle]::Bold)
    $codeFont = New-Object System.Drawing.Font("Consolas", 12)
} catch {
    $defFont = [System.Drawing.SystemFonts]::DefaultFont
    $titleFont = New-Object System.Drawing.Font($defFont.FontFamily, 18, [System.Drawing.FontStyle]::Bold)
    $codeFont = [System.Drawing.SystemFonts]::DefaultFont
}

# 浏览器UA，避免被服务器拦截
$reqHeaders = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
}

# 主窗口
$form = New-Object System.Windows.Forms.Form
$form.Text = "  输入您的激活码"
$form.Size = New-Object System.Drawing.Size(680, 420)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 35, 42)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Font = $defFont
$form.TopMost = $true

# 标题
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "输入您的产品激活码"
$lblTitle.Font = $titleFont
$lblTitle.Location = New-Object System.Drawing.Point(30, 25)
$lblTitle.Size = New-Object System.Drawing.Size(500, 40)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($lblTitle)

# 说明文字
$lblDesc = New-Object System.Windows.Forms.Label
$lblDesc.Text = "输入激活码完成补丁授权绑定，激活后将与当前Steam账号永久绑定。`r`n请确保输入的激活码与您购买的补丁产品一致。"
$lblDesc.Location = New-Object System.Drawing.Point(32, 75)
$lblDesc.Size = New-Object System.Drawing.Size(600, 60)
$lblDesc.ForeColor = [System.Drawing.Color]::FromArgb(180, 188, 200)
$lblDesc.Font = $defFont
$form.Controls.Add($lblDesc)

# 格式示例
$lblDemo = New-Object System.Windows.Forms.Label
$lblDemo.Text = "激活码格式示例"
$lblDemo.Location = New-Object System.Drawing.Point(32, 155)
$lblDemo.Size = New-Object System.Drawing.Size(200, 25)
$lblDemo.ForeColor = [System.Drawing.Color]::FromArgb(200, 208, 220)
$lblDemo.Font = New-Object System.Drawing.Font($defFont.FontFamily, 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblDemo)

$lblDemo2 = New-Object System.Windows.Forms.Label
$lblDemo2.Text = "XXXXX-XXXXX-XXXXX-XXXXX"
$lblDemo2.Location = New-Object System.Drawing.Point(32, 180)
$lblDemo2.Size = New-Object System.Drawing.Size(300, 25)
$lblDemo2.ForeColor = [System.Drawing.Color]::FromArgb(150, 158, 170)
$lblDemo2.Font = $codeFont
$form.Controls.Add($lblDemo2)

# 输入框
$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Location = New-Object System.Drawing.Point(32, 220)
$txtKey.Size = New-Object System.Drawing.Size(600, 35)
$txtKey.BackColor = [System.Drawing.Color]::FromArgb(45, 51, 59)
$txtKey.ForeColor = [System.Drawing.Color]::White
$txtKey.BorderStyle = "None"
$txtKey.Font = $codeFont
$txtKey.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
$form.Controls.Add($txtKey)

# 取消按钮
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "取消"
$btnCancel.Size = New-Object System.Drawing.Size(120, 38)
$btnCancel.Location = New-Object System.Drawing.Point(390, 320)
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(58, 67, 80)
$btnCancel.ForeColor = [System.Drawing.Color]::White
$btnCancel.FlatStyle = "Flat"
$btnCancel.FlatAppearance.BorderSize = 0
$btnCancel.Cursor = "Hand"
$btnCancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel })
$form.Controls.Add($btnCancel)

# 确认按钮
$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text = "确认"
$btnOk.Size = New-Object System.Drawing.Size(120, 38)
$btnOk.Location = New-Object System.Drawing.Point(520, 320)
$btnOk.BackColor = [System.Drawing.Color]::FromArgb(90, 160, 255)
$btnOk.ForeColor = [System.Drawing.Color]::White
$btnOk.FlatStyle = "Flat"
$btnOk.FlatAppearance.BorderSize = 0
$btnOk.Cursor = "Hand"
$btnOk.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::OK })
$form.Controls.Add($btnOk)

# 按钮悬停效果
$btnOk.Add_MouseEnter({ $btnOk.BackColor = [System.Drawing.Color]::FromArgb(110, 180, 255) })
$btnOk.Add_MouseLeave({ $btnOk.BackColor = [System.Drawing.Color]::FromArgb(90, 160, 255) })
$btnCancel.Add_MouseEnter({ $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(78, 87, 100) })
$btnCancel.Add_MouseLeave({ $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(58, 67, 80) })

$form.AcceptButton = $btnOk
$form.CancelButton = $btnCancel

# 显示窗口
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $key = $txtKey.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($key)) {
        [System.Windows.Forms.MessageBox]::Show("请输入激活码", "提示", "OK", "Information")
        exit
    }
    
    try {
        $body = @{ key = $key }
        $response = Invoke-WebRequest -Uri $ApiUrl -Method Post -Body $body -Headers $reqHeaders -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $data = $response.Content | ConvertFrom-Json
        
        if ($data.code -eq 1) {
            $msg = "激活成功！`r`n对应游戏：{0}`r`n补丁文件：{1}`r`n授权已生效。" -f $data.data.game_name, $data.data.lua_filename
            [System.Windows.Forms.MessageBox]::Show($msg, "激活成功", "OK", "Information")
        } else {
            [System.Windows.Forms.MessageBox]::Show("激活失败：`r`n" + $data.msg, "激活失败", "OK", "Error")
        }
    } catch {
        $err = $_.Exception.Message
        [System.Windows.Forms.MessageBox]::Show("连接验证服务器失败，请检查网络。`r`n错误：" + $err, "网络错误", "OK", "Error")
    }
}