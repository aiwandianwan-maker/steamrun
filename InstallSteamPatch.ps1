#Requires -RunAsAdministrator
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# ========== 全局TLS兼容 + 证书忽略，确保Github文件下载正常 ==========
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# ========== 配置区 ==========
$ZipUrl = "https://aiwandianwan-maker.github.io/steamrun/patch.zip"
$ActivatorUrl = "https://aiwandianwan-maker.github.io/steamrun/LuaActivator.ps1"
$TempZip = "$env:TEMP\steam_patch.zip"
$TempUnzip = "$env:TEMP\steam_patch_temp"
$CopyList = @("config","dwmapi.dll","OpenSteamTool.dll","xinput1_4.dll","steam.cfg","opensteamtool.toml")
$InstallDir = "C:\Program Files\SteamPatch"
$ActivatorFileName = "LuaActivator.ps1"
# ============================

# ===== 补丁安装逻辑 完全保留 =====
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
    $steamProc = Get-Process steam
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

Get-Process steam,steamwebhelper,steamerrorreporter | Stop-Process -Force
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
# ===== 安装逻辑结束 =====

# ========== 后台静默安装激活程序 ==========
if(-not (Test-Path $InstallDir)){
    New-Item $InstallDir -ItemType Directory -Force | Out-Null
}

$activatorFullPath = Join-Path $InstallDir $ActivatorFileName

# 下载激活脚本，失败重试
try {
    $webClient.DownloadFile($ActivatorUrl, $activatorFullPath)
} catch {
    try {
        Invoke-WebRequest -Uri $ActivatorUrl -OutFile $activatorFullPath -UseBasicParsing -ErrorAction Stop
    } catch {}
}

# ========== 生成桌面启动bat（双击无额外黑框） ==========
$desktopPath = [Environment]::GetFolderPath("Desktop")
$batPath = Join-Path $desktopPath "游戏激活程序.bat"
$batContent = @"
@echo off
chcp 65001 >nul
start "" powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Program Files\SteamPatch\LuaActivator.ps1"
exit
"@
$batContent | Out-File $batPath -Encoding Default -Force

# ========== 启动Steam + 静默弹出激活窗口（无黑框） ==========
Start-Process "$SteamRoot\steam.exe"
Write-Host "🚀 Steam已启动，3秒后弹出激活窗口..." -ForegroundColor Gray

Start-Sleep -Seconds 3
if (Test-Path $activatorFullPath) {
    # 完全隐藏PowerShell窗口启动
    Start-Process powershell.exe -ArgumentList "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", "`"$activatorFullPath`"" -WindowStyle Hidden
}

# 主窗口5秒后自动关闭
Start-Sleep -Seconds 5
exit 0
