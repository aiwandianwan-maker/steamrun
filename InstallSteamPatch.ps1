#Requires -RunAsAdministrator
$ProgressPreference = 'SilentlyContinue'
Write-Host "==================== Steam Patch Auto Install Tool ====================" -ForegroundColor Cyan

# Download URL Config
$ZipUrl = "https://aiwandianwan-maker.github.io/steamrun/patch.zip"
$TempZip = "$env:TEMP\steam_patch.zip"
$TempUnzip = "$env:TEMP\steam_patch_temp"
$CopyList = @("config","dwmapi.dll","OpenSteamTool.dll","xinput1_4.dll","steam.cfg","opensteamtool.toml")

# Auto Locate Steam Folder
$SteamRoot = $null
# Read User Registry
if(Test-Path "HKCU:\Software\Valve\Steam"){
    $regInfo = Get-ItemProperty "HKCU:\Software\Valve\Steam"
    if($regInfo.SteamPath -and (Test-Path "$($regInfo.SteamPath)\steam.exe")){
        $SteamRoot = $regInfo.SteamPath.TrimEnd('\')
        Write-Host "✅ Detected Steam from user registry: $SteamRoot" -ForegroundColor Green
    }
}
# Read System Registry
if(-not $SteamRoot){
    if(Test-Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"){
        $regInfo = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
        if($regInfo.InstallPath -and (Test-Path "$($regInfo.InstallPath)\steam.exe")){
            $SteamRoot = $regInfo.InstallPath.TrimEnd('\')
            Write-Host "✅ Detected Steam from system registry: $SteamRoot" -ForegroundColor Green
        }
    }
}
# Scan C/D/E/F Disk Steam Path
if(-not $SteamRoot){
    $diskArr = @("C:","D:","E:","F:")
    foreach($disk in $diskArr){
        $path1 = "$disk\Program Files (x86)\Steam"
        if(Test-Path "$path1\steam.exe"){
            $SteamRoot = $path1
            Write-Host "✅ Detected Steam at $path1" -ForegroundColor Green
            break
        }
        $path2 = "$disk\Steam"
        if(Test-Path "$path2\steam.exe"){
            $SteamRoot = $path2
            Write-Host "✅ Detected Steam at $path2" -ForegroundColor Green
            break
        }
    }
}
# Detect from running Steam Process
if(-not $SteamRoot){
    $steamProc = Get-Process steam -ErrorAction SilentlyContinue
    if($steamProc){
        $exePath = $steamProc[0].Path
        $SteamRoot = Split-Path $exePath -Parent
        Write-Host "✅ Detected Steam from running process: $SteamRoot" -ForegroundColor Green
    }
}
# Exit if Steam Not Found
if(-not $SteamRoot -or -not (Test-Path "$SteamRoot\steam.exe")){
    Write-Host "❌ Steam installation directory cannot be found, exit script." -ForegroundColor Red
    Read-Host "Press Enter to close window"
    exit 1
}

# Close All Steam Processes
Write-Host "`nTerminating all Steam background processes..." -ForegroundColor Yellow
Get-Process steam,steamwebhelper,steamerrorreporter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Download Patch Zip Package
Write-Host "`nDownloading patch resource package..." -ForegroundColor Yellow
try{
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($ZipUrl,$TempZip)
}catch{
    Write-Host "❌ Download failed, please check network or file link." -ForegroundColor Red
    Read-Host "Press Enter to close window"
    exit 1
}

# Clear & Create Temp Unzip Folder
if(Test-Path $TempUnzip){Remove-Item $TempUnzip -Recurse -Force}
New-Item $TempUnzip -ItemType Directory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip,$TempUnzip)

# Copy All Patch Files To Steam Folder
Write-Host "`nCopying patch files to Steam root directory..." -ForegroundColor Yellow
$installComplete = $true
foreach($file in $CopyList){
    $source = Join-Path $TempUnzip $file
    $dest = Join-Path $SteamRoot $file
    if(Test-Path $source){
        Copy-Item $source $dest -Recurse -Force
        Write-Host "✅ Copied file: $file" -ForegroundColor Green
    }else{
        Write-Host "❌ Missing resource file: $file" -ForegroundColor Red
        $installComplete = $false
    }
}

# Lock steam.cfg To Read Only
$cfgFullPath = Join-Path $SteamRoot "steam.cfg"
if(Test-Path $cfgFullPath){
    (Get-Item $cfgFullPath).Attributes += [System.IO.FileAttributes]::ReadOnly
    Write-Host "✅ steam.cfg set to read-only protection" -ForegroundColor Green
}

# Clean Temp Cache Files
Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item $TempUnzip -Recurse -Force -ErrorAction SilentlyContinue

# Finish & Launch Steam
Write-Host "`n==================== All Installation Finished ====================" -ForegroundColor Cyan
if($installComplete){
    Write-Host "✅ All patch resources installed successfully!" -ForegroundColor Green
}else{
    Write-Host "⚠️ Partial resource missing, please check your zip package" -ForegroundColor DarkYellow
}
Start-Sleep -Seconds 2
Start-Process "$SteamRoot\steam.exe"
Read-Host "Press Enter key to close this window"
exit 0
