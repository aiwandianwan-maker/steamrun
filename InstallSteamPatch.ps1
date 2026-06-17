#Requires -RunAsAdministrator
$ProgressPreference = 'SilentlyContinue'
Write-Host "==================== Steam Patch Auto Install Tool ====================" -ForegroundColor Cyan

# Config Area — Only modify the download link below
$ZipUrl = "https://aiwandianwan-maker.github.io/steamrun/patch.rar"
$TempZip = "$env:TEMP\steam_patch.rar"
$TempUnzip = "$env:TEMP\steam_patch_temp"
$CopyItems = @("config","dwmapi.dll","OpenSteamTool.dll","xinput1_4.dll","steam.cfg","opensteamtool.toml")

# Step1: Auto detect Steam root folder
$SteamRoot = $null
# 1. User Registry HKCU
if(Test-Path "HKCU:\Software\Valve\Steam"){
    $reg = Get-ItemProperty "HKCU:\Software\Valve\Steam"
    if($reg.SteamPath -and (Test-Path "$($reg.SteamPath)\steam.exe")){
        $SteamRoot = $reg.SteamPath.TrimEnd('\')
        Write-Host "✅ Detected Steam from user registry: $SteamRoot" -ForegroundColor Green
    }
}
# 2. System Registry HKLM Wow6432Node
if(-not $SteamRoot){
    if(Test-Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"){
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
        if($reg.InstallPath -and (Test-Path "$($reg.InstallPath)\steam.exe")){
            $SteamRoot = $reg.InstallPath.TrimEnd('\')
            Write-Host "✅ Detected Steam from system registry: $SteamRoot" -ForegroundColor Green
        }
    }
}
# 3. Scan C/D/E/F disk Program Files (x86) & root Steam folder
if(-not $SteamRoot){
    $disks = @("C:","D:","E:","F:")
    foreach($d in $disks){
        $testPath = "$d\Program Files (x86)\Steam"
        if(Test-Path "$testPath\steam.exe"){
            $SteamRoot = $testPath
            Write-Host "✅ Detected Steam from $d\Program Files (x86)\Steam" -ForegroundColor Green
            break
        }
        $testRoot = "$d\Steam"
        if(Test-Path "$testRoot\steam.exe"){
            $SteamRoot = $testRoot
            Write-Host "✅ Detected Steam from $d\Steam" -ForegroundColor Green
            break
        }
    }
}
# 4. Fallback: running steam.exe process
if(-not $SteamRoot){
    $steamProc = Get-Process steam -ErrorAction SilentlyContinue
    if($steamProc){
        $exePath = $steamProc[0].Path
        $SteamRoot = Split-Path $exePath -Parent
        Write-Host "✅ Detected Steam from running process: $SteamRoot" -ForegroundColor Green
    }
}
# Fail if no Steam found
if(-not $SteamRoot -or -not (Test-Path "$SteamRoot\steam.exe")){
    Write-Host "❌ Cannot find Steam installation folder, exit." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# Step2: Kill all Steam processes
Write-Host "`nClosing all Steam processes..." -ForegroundColor Yellow
Get-Process steam,steamwebhelper,steamerrorreporter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Step3: Download patch archive from github pages
Write-Host "`nDownloading patch package from server..." -ForegroundColor Yellow
try{
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($ZipUrl,$TempZip)
}catch{
    Write-Host "❌ Failed to download patch file, check network or link." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# Step4: Extract archive to temp folder
if(Test-Path $TempUnzip){Remove-Item $TempUnzip -Recurse -Force}
New-Item $TempUnzip -ItemType Directory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
# Support rar/zip, if your file is zip replace .rar to .zip
if($TempZip.EndsWith(".zip")){
    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip,$TempUnzip)
}

# Step5: Copy all patch files to Steam root
Write-Host "`nCopying patch files to Steam directory..." -ForegroundColor Yellow
$allSuccess = $true
foreach($item in $CopyItems){
    $src = Join-Path $TempUnzip $item
    $dst = Join-Path $SteamRoot $item
    if(Test-Path $src){
        Copy-Item $src $dst -Recurse -Force
        Write-Host "✅ Copied: $item" -ForegroundColor Green
    }else{
        Write-Host "❌ Missing file: $item" -ForegroundColor Red
        $allSuccess = $false
    }
}

# Step6: Set steam.cfg read-only attribute
$cfgPath = Join-Path $SteamRoot "steam.cfg"
if(Test-Path $cfgPath){
    (Get-Item $cfgPath).Attributes += [System.IO.FileAttributes]::ReadOnly
    Write-Host "✅ steam.cfg set to read-only mode" -ForegroundColor Green
}

# Step7: Clean temporary files
Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item $TempUnzip -Recurse -Force -ErrorAction SilentlyContinue

# Step8: Finish and launch Steam
Write-Host "`n==================== Installation Complete ====================" -ForegroundColor Cyan
if($allSuccess){
    Write-Host "✅ All patch files installed successfully!" -ForegroundColor Green
}else{
    Write-Host "⚠️ Some files missing, please check your patch archive" -ForegroundColor DarkYellow
}
Start-Sleep -Seconds 2
Start-Process "$SteamRoot\steam.exe"
Read-Host "Press Enter to close window"
exit 0
