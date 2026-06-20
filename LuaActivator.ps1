# 激活码验证独立程序
try {
    $ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Web
} catch {
    exit
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
[System.Net.ServicePointManager]::Expect100Continue = $false
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$ApiUrl = "http://47.100.104.45/api.php"

# 字体容错
try {
    $defFont = New-Object System.Drawing.Font("Microsoft YaHei", 10)
    $titleFont = New-Object System.Drawing.Font("Microsoft YaHei", 16, [System.Drawing.FontStyle]::Bold)
} catch {
    $defFont = [System.Drawing.SystemFonts]::DefaultFont
    $titleFont = New-Object System.Drawing.Font($defFont.FontFamily, 16, [System.Drawing.FontStyle]::Bold)
}

while ($true) {
    # ============= 【UI 样式：仿 Steam 激活码窗口】 =============
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "输入您的产品激活码"
    $form.Size = New-Object System.Drawing.Size(580, 320)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(35, 39, 42)   # 蒸汽深色背景
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
    $lblTitle.Size = New-Object System.Drawing.Size(500, 30)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($lblTitle)

    # 说明
    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = "输入激活码完成补丁授权绑定，激活后将与当前 Steam 账号永久绑定。`r`n请确保输入的激活码与您购买的补丁产品一致。"
    $lblDesc.Location = New-Object System.Drawing.Point(30, 65)
    $lblDesc.Size = New-Object System.Drawing.Size(500, 45)
    $lblDesc.ForeColor = [System.Drawing.Color]::FromArgb(180, 188, 200)
    $lblDesc.Font = New-Object System.Drawing.Font($defFont.FontFamily, 10)
    $form.Controls.Add($lblDesc)

    # 示例提示
    $lblDemo = New-Object System.Windows.Forms.Label
    $lblDemo.Text = "激活码格式示例"
    $lblDemo.Location = New-Object System.Drawing.Point(30, 135)
    $lblDemo.Size = New-Object System.Drawing.Size(200, 20)
    $lblDemo.ForeColor = [System.Drawing.Color]::FromArgb(200, 208, 220)
    $lblDemo.Font = New-Object System.Drawing.Font($defFont.FontFamily, 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblDemo)

    $lblDemo2 = New-Object System.Windows.Forms.Label
    $lblDemo2.Text = "XXXXX-XXXXX-XXXXX-XXXXX"
    $lblDemo2.Location = New-Object System.Drawing.Point(30, 160)
    $lblDemo2.Size = New-Object System.Drawing.Size(300, 25)
    $lblDemo2.ForeColor = [System.Drawing.Color]::FromArgb(160, 168, 180)
    $lblDemo2.Font = New-Object System.Drawing.Font($defFont.FontFamily, 10)
    $form.Controls.Add($lblDemo2)

    # 输入框
    $txtKey = New-Object System.Windows.Forms.TextBox
    $txtKey.Location = New-Object System.Drawing.Point(30, 200)
    $txtKey.Size = New-Object System.Drawing.Size(500, 35)
    $txtKey.BackColor = [System.Drawing.Color]::FromArgb(47, 53, 58)
    $txtKey.ForeColor = [System.Drawing.Color]::White
    $txtKey.BorderStyle = "None"
    $txtKey.Font = New-Object System.Drawing.Font($defFont.FontFamily, 12)
    $txtKey.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
    $form.Controls.Add($txtKey)

    # 取消按钮
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "取消"
    $btnCancel.Size = New-Object System.Drawing.Size(100, 36)
    $btnCancel.Location = New-Object System.Drawing.Point(310, 260)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(58, 67, 80)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.FlatAppearance.BorderSize = 0
    $btnCancel.Cursor = "Hand"
    $btnCancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel })
    $form.Controls.Add($btnCancel)

    # 确认按钮 (改成蒸汽蓝)
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "确认"
    $btnOk.Size = New-Object System.Drawing.Size(100, 36)
    $btnOk.Location = New-Object System.Drawing.Point(430, 260)
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(62, 107, 200)
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.FlatStyle = "Flat"
    $btnOk.FlatAppearance.BorderSize = 0
    $btnOk.Cursor = "Hand"
    $btnOk.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::OK })
    $form.Controls.Add($btnOk)

    # 按钮悬停效果
    $btnOk.Add_MouseEnter({ $btnOk.BackColor = [System.Drawing.Color]::FromArgb(92, 137, 230) })
    $btnOk.Add_MouseLeave({ $btnOk.BackColor = [System.Drawing.Color]::FromArgb(62, 107, 200) })
    $btnCancel.Add_MouseEnter({ $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(78, 87, 100) })
    $btnCancel.Add_MouseLeave({ $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(58, 67, 80) })

    $form.AcceptButton = $btnOk
    $form.CancelButton = $btnCancel

    # 显示窗口并等待操作
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
        $form.Dispose()
        exit
    }

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $key = $txtKey.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($key)) {
            [System.Windows.Forms.MessageBox]::Show("请输入激活码", "提示", "OK", "Information")
            $form.Dispose()
            continue
        }
        
        # ====== 精准读取 Steam 安装路径与当前登录 ID ======
        $steamid = $null
        $steamPath = $null
        $steamProc = Get-Process -Name "steam" -ErrorAction SilentlyContinue
        
        if (-not $steamProc) {
            [System.Windows.Forms.MessageBox]::Show("未检测到 Steam 正在运行。`r`n请先登录您的 Steam 客户端，再重新点击确认。", "未登录 Steam", "OK", "Information")
            $form.Dispose()
            continue
        }
        
        try {
            $regPath = "HKCU:\Software\Valve\Steam"
            $steamPath = (Get-ItemProperty -Path $regPath -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
            if ([string]::IsNullOrWhiteSpace($steamPath)) {
                $regPath = "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"
                $steamPath = (Get-ItemProperty -Path $regPath -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
            }
        } catch {}
        
        if ([string]::IsNullOrWhiteSpace($steamPath)) {
            $commonPaths = @("C:\Program Files (x86)\Steam","D:\Program Files (x86)\Steam","D:\Steam","E:\Steam","C:\Steam")
            foreach ($p in $commonPaths) {
                if (Test-Path "$p\config\loginusers.vdf") { $steamPath = $p; break }
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($steamPath)) {
            [System.Windows.Forms.MessageBox]::Show("无法识别 Steam 安装位置。`r`n请确保 Steam 已正确安装并登录。", "路径错误", "OK", "Error")
            $form.Dispose()
            continue
        }

        $vdfPath = Join-Path $steamPath "config\loginusers.vdf"
        if (-not (Test-Path $vdfPath)) {
            [System.Windows.Forms.MessageBox]::Show("没有读取到 Steam 的登录文件 (loginusers.vdf)。`r`n请确保已登录 Steam，并尝试【右键】此激活工具，选择""以管理员身份运行""。", "读取 Steam 失败", "OK", "Error")
            $form.Dispose()
            continue
        }

        try {
            $vdfContent = Get-Content $vdfPath -Raw
            if ($vdfContent -match '"(\d+)"\s*\{[^}]*"MostRecent"\s*"1"') {
                $steamid = $matches[1]
            }
        } catch {}
        
        if ([string]::IsNullOrWhiteSpace($steamid)) {
            [System.Windows.Forms.MessageBox]::Show("获取当前登录的 Steam 账号 ID 失败。`r`n请确认您在客户端中已成功登录，并将此账号标记为【记住密码】。", "读取 ID 失败", "OK", "Error")
            $form.Dispose()
            continue
        }

        try {
            $getUrl = $ApiUrl + "?key=" + [System.Web.HttpUtility]::UrlEncode($key) + "&steamid=" + $steamid
            $responseText = curl.exe -s $getUrl
            try {
                $data = $responseText | ConvertFrom-Json
            } catch {
                [System.Windows.Forms.MessageBox]::Show("服务器返回错误，可能由于网络波动导致。`r`n" + $responseText, "网络响应异常", "OK", "Error")
                $form.Dispose()
                continue
            }

            if ($data.code -eq 1) {
                $luaFileName = $data.lua
                $luaFolder = Join-Path $steamPath "config\lua"
                if (-not (Test-Path $luaFolder)) { New-Item -ItemType Directory -Force -Path $luaFolder | Out-Null }

                try {
                    $luaBaseUrl = "http://47.100.104.45/lua/"
                    $luaFullUrl = $luaBaseUrl + $luaFileName
                    $luaLocalPath = Join-Path $luaFolder $luaFileName
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($luaFullUrl, $luaLocalPath)
                    
                    $gameName = $data.data.game_name
                    if ([string]::IsNullOrWhiteSpace($gameName)) { $gameName = "已激活补丁" }
                    
                    # ============= 【UI 样式：仿 Steam 激活成功弹窗】 =============
                    $formSuccess = New-Object System.Windows.Forms.Form
                    $formSuccess.Size = New-Object System.Drawing.Size(480, 220)
                    $formSuccess.StartPosition = "CenterScreen"
                    $formSuccess.BackColor = [System.Drawing.Color]::FromArgb(32, 38, 48)
                    $formSuccess.FormBorderStyle = "None"
                    $formSuccess.TopMost = $true
                    
                    # 成功标题：加上游戏名
                    $lblTitleSuccess = New-Object System.Windows.Forms.Label
                    $lblTitleSuccess.Text = "激活成功：$gameName"
                    $lblTitleSuccess.Font = New-Object System.Drawing.Font("Microsoft YaHei", 14, [System.Drawing.FontStyle]::Bold)
                    $lblTitleSuccess.Location = New-Object System.Drawing.Point(30, 30)
                    $lblTitleSuccess.Size = New-Object System.Drawing.Size(400, 30)
                    $lblTitleSuccess.ForeColor = [System.Drawing.Color]::White
                    $formSuccess.Controls.Add($lblTitleSuccess)
                    
                    # 成功副标题
                    $lblDescSuccess = New-Object System.Windows.Forms.Label
                    $lblDescSuccess.Text = "您的产品激活码已被成功激活。相关产品现在已与您的 Steam 账户永久关联。`r`n您必须登录此账户才能访问您刚刚在 Steam 上激活的产品。"
                    $lblDescSuccess.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
                    $lblDescSuccess.Location = New-Object System.Drawing.Point(30, 70)
                    $lblDescSuccess.Size = New-Object System.Drawing.Size(420, 70)
                    $lblDescSuccess.ForeColor = [System.Drawing.Color]::FromArgb(190, 195, 200)
                    $formSuccess.Controls.Add($lblDescSuccess)
                    
                    # 底部 蓝色条 + 确定按钮
                    $btnSuccessPanel = New-Object System.Windows.Forms.Panel
                    $btnSuccessPanel.Dock = "Bottom"
                    $btnSuccessPanel.Height = 50
                    $btnSuccessPanel.BackColor = [System.Drawing.Color]::FromArgb(62, 107, 200)
                    $formSuccess.Controls.Add($btnSuccessPanel)

                    $btnOkSuccess = New-Object System.Windows.Forms.Button
                    $btnOkSuccess.Text = "确定"
                    $btnOkSuccess.Size = New-Object System.Drawing.Size(480, 50) # 撑满宽度
                    $btnOkSuccess.Location = New-Object System.Drawing.Point(0, 0)
                    $btnOkSuccess.BackColor = [System.Drawing.Color]::Transparent
                    $btnOkSuccess.ForeColor = [System.Drawing.Color]::White
                    $btnOkSuccess.FlatStyle = "Flat"
                    $btnOkSuccess.FlatAppearance.BorderSize = 0
                    $btnOkSuccess.Font = New-Object System.Drawing.Font("Microsoft YaHei", 11)
                    $btnOkSuccess.Cursor = "Hand"
                    $btnOkSuccess.Add_MouseEnter({ $btnOkSuccess.BackColor = [System.Drawing.Color]::FromArgb(92, 137, 230) })
                    $btnOkSuccess.Add_MouseLeave({ $btnOkSuccess.BackColor = [System.Drawing.Color]::Transparent })
                    $btnOkSuccess.Add_Click({ $formSuccess.Close() })
                    $btnSuccessPanel.Controls.Add($btnOkSuccess)

                    $formSuccess.ShowDialog()
                    $form.Dispose()
                    break

                } catch {
                    [System.Windows.Forms.MessageBox]::Show("激活成功，但 Lua 补丁下载失败。`r`n请确保阿里云服务器 `/lua/` 文件夹里有对应的文件。`r`n错误：" + $_.Exception.Message, "下载提醒", "OK", "Warning")
                    $form.Dispose()
                    break
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("激活失败：`r`n" + $data.msg, "激活失败", "OK", "Error")
                $form.Dispose()
                continue
            }
        } catch {
            $err = $_.Exception.Message
            [System.Windows.Forms.MessageBox]::Show("连接验证服务器失败，请检查网络。`r`n错误：" + $err, "网络错误", "OK", "Error")
            $form.Dispose()
            continue
        }
    }
}
