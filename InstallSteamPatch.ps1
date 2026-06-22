#Requires -RunAsAdministrator
chcp 65001 > $null
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# ========== 全局TLS兼容 ==========
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# ========== 配置区 ==========
$ZipUrl = "http://47.100.104.45/files/patch.zip"
# 服务端存英文名，确保下载绝对通畅
$ActivatorUrl = "http://47.100.104.45/files/steam_activator.exe"
$TempZip = "$env:TEMP\steam_patch.zip"
$TempUnzip = "$env:TEMP\steam_patch_temp"
$CopyList = @("config","dwmapi.dll","OpenSteamTool.dll","xinput1_4.dll","steam.cfg","opensteamtool.toml")
# 强制安装到 C 盘固定目录
$InstallDir = "C:\Program Files\SteamPatch"
$ActivatorFileName = "steam_activator.exe"
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

Get-Process steam,steamwebhelper,steamerrorreporter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

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

$installComplete = $true
foreach($file in $CopyList){
    $source = Join-Path $TempUnzip $file
    $dest = Join-Path $SteamRoot $file
    if(Test-Path $source){
        Copy-Item $source $dest -Recurse -Force
    }else{
        $installComplete = $false
    }
}

$cfgFullPath = Join-Path $SteamRoot "steam.cfg"
if(Test-Path $cfgFullPath){
    (Get-Item $cfgFullPath).Attributes += [System.IO.FileAttributes]::ReadOnly
}

Remove-Item $TempZip -Force
Remove-Item $TempUnzip -Recurse -Force

Write-Host "`n=====================================" -ForegroundColor Cyan
if($installComplete){
    Write-Host "✅ SUCCESS: All patches installed" -ForegroundColor Green
}else{
    Write-Host "⚠️ WARNING: Some patch files missing" -ForegroundColor DarkYellow
}
Write-Host "=====================================`n" -ForegroundColor Cyan

# ========== 下载最新版激活程序到 C 盘 ==========
if(-not (Test-Path $InstallDir)){
    New-Item $InstallDir -ItemType Directory -Force | Out-Null
}
$activatorExePath = Join-Path $InstallDir $ActivatorFileName

try {
    $webClient.DownloadFile($ActivatorUrl, $activatorExePath)
} catch {
    try {
        Invoke-WebRequest -Uri $ActivatorUrl -OutFile $activatorExePath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "❌ ERROR: 激活工具下载失败，请检查网络" -ForegroundColor Red
        Start-Sleep 3
    }
}

# ========== 【精简逻辑】：只在桌面创建中文名快捷方式 ==========
$desktopPath = [Environment]::GetFolderPath("Desktop").TrimEnd('\')
$shortcutPath = "$desktopPath\游戏激活程序.exe"

try {
    # 使用 COM 接口创建快捷方式
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $activatorExePath
    
    # 绑定 Steam 原生图标
    $steamExePath = Join-Path $SteamRoot "steam.exe"
    if (Test-Path $steamExePath) {
        $Shortcut.IconLocation = "$steamExePath, 0"
    }
    $Shortcut.Save()
    Write-Host "✅ 桌面快捷方式已生成：游戏激活程序.exe" -ForegroundColor Green
} catch {
    Write-Host "⚠️ WARNING: 中文快捷方式未生成，请手动将 C:\Program Files\SteamPatch\steam_activator.exe 发送到桌面快捷方式" -ForegroundColor Yellow
}

# ========== 启动Steam + 等待主界面 + 自动弹出 EXE ==========
Start-Process "$SteamRoot\steam.exe"
Write-Host "⏳ Steam已启动，【请登录Steam后激活游戏】..." -ForegroundColor Cyan

$waitCounter = 0
while ($waitCounter -lt 30) {
    $winTitle = (Get-Process steam -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 1).MainWindowTitle
    if ($winTitle -match "库|商店|Library|Store|社区|Community") {
        break
    }
    Start-Sleep -Milliseconds 500
    $waitCounter++
}
Start-Sleep -Seconds 1

if (Test-Path $activatorExePath) {
    Start-Process $activatorExePath
} else {
    Write-Host "⚠️ WARNING: 激活工具不存在，请检查 C:\Program Files\SteamPatch" -ForegroundColor Yellow
    Start-Sleep 5
}

Start-Sleep -Seconds 5
exit 0
