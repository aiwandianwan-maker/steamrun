# 强制管理员权限
#Requires -RunAsAdministrator
$ProgressPreference = 'SilentlyContinue'
Write-Host "==================== Steam补丁自动部署工具 ====================" -ForegroundColor Cyan

# ========== 配置区（仅修改这里的下载地址） ==========
$ZipUrl = "https://aiwandianwan-maker.github.io/patch.zip"  # 替换你服务器zip直链
$TempZip = "$env:TEMP\steam_patch.zip"
$TempUnzip = "$env:TEMP\steam_patch_temp"
# 需要复制的文件/文件夹列表
$CopyItems = @("config","dwmapi.dll","OpenSteamTool.dll","xinput1_4.dll","steam.cfg","opensteamtool.toml")
# ==================================================

# 1. 多层逻辑自动获取Steam根目录
$SteamRoot = $null
# 第一层：当前用户注册表 HKCU
if(Test-Path "HKCU:\Software\Valve\Steam"){
    $reg = Get-ItemProperty "HKCU:\Software\Valve\Steam"
    if($reg.SteamPath -and (Test-Path "$($reg.SteamPath)\steam.exe")){
        $SteamRoot = $reg.SteamPath.TrimEnd('\')
        Write-Host "✅ 从用户注册表识别Steam: $SteamRoot" -ForegroundColor Green
    }
}
# 第二层：64位系统全局注册表 HKLM Wow6432Node
if(-not $SteamRoot){
    if(Test-Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"){
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
        if($reg.InstallPath -and (Test-Path "$($reg.InstallPath)\steam.exe")){
            $SteamRoot = $reg.InstallPath.TrimEnd('\')
            Write-Host "✅ 从系统注册表识别Steam: $SteamRoot" -ForegroundColor Green
        }
    }
}
# 第三层：兜底扫描 C D E F Program Files (x86)
if(-not $SteamRoot){
    $disks = @("C:","D:","E:","F:")
    foreach($d in $disks){
        $testPath = "$d\Program Files (x86)\Steam"
        if(Test-Path "$testPath\steam.exe"){
            $SteamRoot = $testPath
            Write-Host "✅ 磁盘目录扫描识别Steam: $SteamRoot" -ForegroundColor Green
            break
        }
        $testRoot = "$d\Steam"
        if(Test-Path "$testRoot\steam.exe"){
            $SteamRoot = $testRoot
            Write-Host "✅ 磁盘根目录扫描识别Steam: $SteamRoot" -ForegroundColor Green
            break
        }
    }
}
# 第四层：兜底读取正在运行的steam.exe进程
if(-not $SteamRoot){
    $steamProc = Get-Process steam -ErrorAction SilentlyContinue
    if($steamProc){
        $exePath = $steamProc[0].Path
        $SteamRoot = Split-Path $exePath -Parent
        Write-Host "✅ 从运行进程识别Steam: $SteamRoot" -ForegroundColor Green
    }
}
# 全部方式都失败则退出
if(-not $SteamRoot -or -not (Test-Path "$SteamRoot\steam.exe")){
    Write-Host "❌ 无法找到Steam安装目录，请确认Steam已安装并启动一次！" -ForegroundColor Red
    Read-Host "按回车关闭"
    exit 1
}

# 2. 强制关闭所有Steam进程
Write-Host "`n正在关闭Steam进程..." -ForegroundColor Yellow
Get-Process steam,steamwebhelper,steamerrorreporter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# 3. 服务器下载补丁压缩包
Write-Host "`n正在从服务器下载补丁包..." -ForegroundColor Yellow
try{
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($ZipUrl,$TempZip)
}catch{
    Write-Host "❌ 补丁包下载失败，请检查网络或下载链接！" -ForegroundColor Red
    Read-Host "按回车关闭"
    exit 1
}

# 4. 解压到临时目录
if(Test-Path $TempUnzip){Remove-Item $TempUnzip -Recurse -Force}
New-Item $TempUnzip -ItemType Directory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip,$TempUnzip)

# 5. 批量复制所有文件到Steam根目录
Write-Host "`n开始复制补丁文件至Steam目录..." -ForegroundColor Yellow
$allSuccess = $true
foreach($item in $CopyItems){
    $src = Join-Path $TempUnzip $item
    $dst = Join-Path $SteamRoot $item
    if(Test-Path $src){
        Copy-Item $src $dst -Recurse -Force
        Write-Host "✅ 已复制: $item" -ForegroundColor Green
    }else{
        Write-Host "❌ 缺失文件: $item" -ForegroundColor Red
        $allSuccess = $false
    }
}

# 6. 设置steam.cfg只读
$cfgPath = Join-Path $SteamRoot "steam.cfg"
if(Test-Path $cfgPath){
    (Get-Item $cfgPath).Attributes += [System.IO.FileAttributes]::ReadOnly
    Write-Host "✅ steam.cfg 已设置只读保护" -ForegroundColor Green
}

# 7. 清理临时文件
Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item $TempUnzip -Recurse -Force -ErrorAction SilentlyContinue

# 8. 完成，启动Steam
Write-Host "`n==================== 部署完成 ====================" -ForegroundColor Cyan
if($allSuccess){
    Write-Host "✅ 全部补丁文件安装成功！" -ForegroundColor Green
}else{
    Write-Host "⚠️ 存在部分文件缺失，请检查压缩包内容" -ForegroundColor DarkYellow
}
Start-Sleep -Seconds 2
Start-Process "$SteamRoot\steam.exe"
Read-Host "按回车键关闭窗口"
exit 0
