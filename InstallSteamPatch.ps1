#Requires -RunAsAdministrator
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# 配置区，无需改动
$ZipUrl = "https://aiwandianwan-maker.github.io/steamrun/patch.zip"
$TempZip = "$env:TEMP\steam_patch.zip"
$TempUnzip = "$env:TEMP\steam_patch_temp"
$CopyList = @("config","dwmapi.dll","OpenSteamTool.dll","xinput1_4.dll","steam.cfg","opensteamtool.toml")

# 自动查找Steam路径
$SteamRoot = $null
# 读取用户注册表
if(Test-Path "HKCU:\Software\Valve\Steam"){
    $regInfo = Get-ItemProperty "HKCU:\Software\Valve\Steam"
    if($regInfo.SteamPath -and (Test-Path "$($regInfo.SteamPath)\steam.exe")){
        $SteamRoot = $regInfo.SteamPath.TrimEnd('\')
    }
}
# 读取系统注册表
if(-not $SteamRoot){
    if(Test-Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"){
        $regInfo = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
        if($regInfo.InstallPath -and (Test-Path "$($regInfo.InstallPath)\steam.exe")){
            $SteamRoot = $regInfo.InstallPath.TrimEnd('\')
        }
    }
}
# 扫描C/D/E/F盘Steam目录
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
# 从运行中的Steam进程识别
if(-not $SteamRoot){
    $steamProc = Get-Process steam
    if($steamProc){
        $exePath = $steamProc[0].Path
        $SteamRoot = Split-Path $exePath -Parent
    }
}
# 未找到Steam，直接报错退出
if(-not $SteamRoot -or -not (Test-Path "$SteamRoot\steam.exe")){
    Write-Host "`n❌ ERROR: Cannot locate Steam folder" -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# 静默关闭所有Steam进程
Get-Process steam,steamwebhelper,steamerrorreporter | Stop-Process -Force
Start-Sleep -Seconds 2

# 静默下载补丁包
try{
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($ZipUrl,$TempZip)
}catch{
    Write-Host "`n❌ ERROR: Patch download failed" -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# 解压文件
if(Test-Path $TempUnzip){Remove-Item $TempUnzip -Recurse -Force}
New-Item $TempUnzip -ItemType Directory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip,$TempUnzip)

# 静默批量复制，无逐条打印
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

# 锁定cfg只读
$cfgFullPath = Join-Path $SteamRoot "steam.cfg"
if(Test-Path $cfgFullPath){
    (Get-Item $cfgFullPath).Attributes += [System.IO.FileAttributes]::ReadOnly
}

# 清理临时文件
Remove-Item $TempZip -Force
Remove-Item $TempUnzip -Recurse -Force

# 仅输出最终结果（唯一可见输出）
Write-Host "`n=====================================" -ForegroundColor Cyan
if($installComplete){
    Write-Host "✅ SUCCESS: All patches installed" -ForegroundColor Green
}else{
    Write-Host "⚠️ WARNING: Some patch files missing" -ForegroundColor DarkYellow
}
Write-Host "=====================================`n" -ForegroundColor Cyan

# 启动Steam，等待回车关闭
Start-Sleep -Seconds 2
Start-Process "$SteamRoot\steam.exe"
Read-Host "Press Enter to close window"
exit 0
