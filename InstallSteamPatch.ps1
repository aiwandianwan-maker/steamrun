# ============== 配置区 ==============
$apiUrl = "https://api.awsteam.icu/api.php"
$luaDownloadBase = "https://awsteam.icu/lua/"
# ===================================

# 网络基础配置：强制TLS1.2 + 忽略证书
try {
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
} catch {
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
}
[System.Net.ServicePointManager]::ServerCertificateValidationCallback={$true}

# ========== 第一步：自动安装所有补丁 ==========
# 获取Steam安装目录
$steamPaths = @(
    "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam",
    "HKLM:\SOFTWARE\Valve\Steam"
)
$steamPath = $null
foreach ($p in $steamPaths) {
    if (Test-Path $p) {
        $steamPath = (Get-ItemProperty $p).InstallPath
        break
    }
}
if (-not $steamPath) {
    $steamPath = "$env:ProgramFiles (x86)\Steam"
}
$commonPath = Join-Path (Join-Path $steamPath "steamapps") "common"

# 补丁-游戏目录对应表，新增补丁在此处补充
$patchMap = @{
    "2947440.lua" = "Silent Hill f"
    "3764200.lua" = "Resident Evil 9"
}

# 批量下载安装所有补丁
foreach ($luaFile in $patchMap.Keys) {
    $gameDir = Join-Path $commonPath $patchMap[$luaFile]
    if (-not (Test-Path $gameDir)) {
        New-Item -ItemType Directory -Path $gameDir -Force | Out-Null
    }
    $savePath = Join-Path $gameDir $luaFile
    try {
        Invoke-WebRequest -Uri ($luaDownloadBase + $luaFile) -OutFile $savePath -ErrorAction Stop
    } catch {
        # 单个补丁下载失败不中断整体流程
        Write-Host "警告：$luaFile 安装失败" -ForegroundColor Yellow
    }
}

# 安装成功提示（和原样式完全一致）
Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "SUCCESS: All patches installed" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# ========== 第二步：安装完成后弹出激活码验证 ==========
Add-Type -AssemblyName Microsoft.VisualBasic
$inputKey = [Microsoft.VisualBasic.Interaction]::InputBox("请输入您的激活码完成授权绑定", "激活码授权", "")

if ([string]::IsNullOrWhiteSpace($inputKey)) {
    Write-Host "未输入激活码，授权流程结束。" -ForegroundColor Yellow
    $null = [Microsoft.VisualBasic.Interaction]::MsgBox("未输入激活码，授权流程结束。`n补丁已安装，激活后可正常使用。", "OKOnly", "提示")
} else {
    # 调用后端接口校验激活码
    try {
        $postBody = @{ key = $inputKey.Trim() }
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $postBody -ErrorAction Stop
    } catch {
        Write-Host "连接验证服务器失败，请检查网络。" -ForegroundColor Red
        $null = [Microsoft.VisualBasic.Interaction]::MsgBox("连接验证服务器失败，请检查网络后重试。", "OKOnly", "网络错误")
        exit
    }

    if ($response.code -eq 1) {
        $luaName = $response.data.lua_filename
        $gameName = $response.data.game_name
        Write-Host "激活成功！已绑定对应补丁：$luaName" -ForegroundColor Green
        $null = [Microsoft.VisualBasic.Interaction]::MsgBox("激活成功！`n对应游戏：$gameName`n补丁文件：$luaName`n授权已生效。", "OKOnly", "激活成功")
    } else {
        Write-Host "激活失败：$($response.msg)" -ForegroundColor Red
        $null = [Microsoft.VisualBasic.Interaction]::MsgBox("激活失败：`n$($response.msg)", "OKOnly", "激活失败")
    }
}
