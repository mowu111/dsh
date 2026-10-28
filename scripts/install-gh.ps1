<#
  GitHub CLI 安装向导 (wizard)
  ------------------------------------------------
  用途：在一台全新的 Windows 机器上，从零把 GitHub CLI 装好并登录。
  用法：powershell -ExecutionPolicy Bypass -File .\scripts\install-gh.ps1

  设计约定：
  - 每个阶段清屏，只显示当前要做的一件事
  - 每个阶段结束有确认门，Ctrl+C 可随时退出
  - 幂等：已装 / 已登录的步骤会自动跳过
  - 不写 .env、不碰 CI 密钥：gh 把 token 存在 Windows 凭据管理器里
#>
#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

$Total        = 6
$script:Stage = 0
$GhExe        = $null

# ---------- 展示层 ----------
function Write-Head {
    param([int]$N, [string]$Title)
    Clear-Host
    $script:Stage = $N
    $bar = '  ' + ('-' * 52)
    Write-Host ''
    Write-Host ("  GitHub CLI 安装向导       阶段 {0}/{1}" -f $N, $Total) -ForegroundColor Cyan
    Write-Host $bar -ForegroundColor DarkGray
    Write-Host ("  " + $Title) -ForegroundColor White
    Write-Host $bar -ForegroundColor DarkGray
    Write-Host ''
}
function Say  { param([string]$M, [string]$C = 'Gray');   Write-Host "  $M" -ForegroundColor $C }
function Step { param([string]$M); Write-Host "  > $M" -ForegroundColor Yellow }
function Ok   { param([string]$M); Write-Host "  [OK] $M" -ForegroundColor Green }
function Warn { param([string]$M); Write-Host "  [!] $M" -ForegroundColor DarkYellow }
function Gate {
    param([string]$M = '按 Enter 继续，Ctrl+C 随时退出')
    Write-Host ''
    Write-Host "  $M " -ForegroundColor DarkGray -NoNewline
    [void](Read-Host)
}
function Confirm-Action {
    param([string]$M)
    while ($true) {
        Write-Host "  $M [y/N] " -ForegroundColor Yellow -NoNewline
        $a = Read-Host
        if ($a -match '^(y|yes)$') { return $true }
        if ($a -eq '' -or $a -match '^(n|no)$') { return $false }
    }
}

# ---------- 工具层 ----------
function Update-Path {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($m, $u, $env:Path | Where-Object { $_ }) -join ';'
}
function Find-Gh {
    $c = Get-Command gh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in @(
        "$env:ProgramFiles\GitHub CLI\gh.exe",
        "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe",
        "$env:LOCALAPPDATA\GitHubCLI\bin\gh.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\gh.exe"
    )) { if ($p -and (Test-Path $p)) { return $p } }
    return $null
}
function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 回退安装：直连 github.com 失败时（国内常见），经镜像下载官方 zip，
# 用官方 checksums.txt 校验 SHA256 后再解压，用户级安装、不需要管理员。
function Install-GhViaZip {
    param([string]$Version = '2.103.3', [string]$Mirror = 'https://ghproxy.net/')
    $dir  = Join-Path $env:TEMP 'gh-install'
    $dest = Join-Path $env:LOCALAPPDATA 'Programs\gh'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $src = "$Mirror" + "https://github.com/cli/cli/releases/download/v$Version"
    $zip = Join-Path $dir 'gh.zip'
    $sums = Join-Path $dir 'checksums.txt'

    Step "下载 gh_${Version}_windows_amd64.zip（经镜像 $Mirror）"
    & curl.exe -L --fail --max-time 900 -s -o $zip "$src/gh_${Version}_windows_amd64.zip"
    if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 1MB) {
        Warn 'zip 下载失败'
        return $null
    }
    Ok ("已下载 " + [math]::Round((Get-Item $zip).Length / 1MB, 2) + ' MB')

    Step '校验 SHA256'
    & curl.exe -L --fail --max-time 120 -s -o $sums "$src/gh_${Version}_checksums.txt"
    $actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    $expect = $null
    if (Test-Path $sums) {
        $expect = (Get-Content $sums | Select-String 'windows_amd64\.zip' |
                   ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1)
    }
    if ($expect -and $expect -eq $actual) {
        Ok '校验通过'
    } elseif ($expect) {
        Warn "校验不一致，停止安装（期望 $expect / 实际 $actual）"
        return $null
    } else {
        Warn '拿不到官方校验和，无法校验；如不放心请手动从 cli.github.com 安装'
    }

    Step "解压到 $dest"
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Expand-Archive -Path $zip -DestinationPath $dest -Force

    $bin = Join-Path $dest 'bin'
    $uPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($uPath -notlike "*$bin*") {
        $joined = if ([string]::IsNullOrEmpty($uPath)) { $bin } else { $uPath.TrimEnd(';') + ';' + $bin }
        [Environment]::SetEnvironmentVariable('Path', $joined, 'User')
        Ok '已加入用户 PATH'
    }
    Update-Path
    return (Join-Path $bin 'gh.exe')
}
function Gh-LoggedIn {
    if (-not $script:GhExe) { return $false }
    & $script:GhExe auth status *> $null
    return ($LASTEXITCODE -eq 0)
}

# ============================================================
# 阶段 1：环境体检（只读，无产出）
# ============================================================
Write-Head 1 '环境体检'
Say '先确认这台机器的底子，不改动任何东西。'
Write-Host ''
$os  = [Environment]::OSVersion.Version
Say ("操作系统        Windows {0}.{1} (build {2})" -f $os.Major, $os.Minor, $os.Build)
Say ("PowerShell      {0}" -f $PSVersionTable.PSVersion)

$wg = (Get-Command winget -ErrorAction SilentlyContinue)
if ($wg) { Ok ("winget          " + (& winget --version 2>$null)) }
else      { Warn 'winget          未找到 —— 装 gh 需要手动下载 MSI' }

Update-Path
$script:GhExe = Find-Gh
if ($script:GhExe) {
    $v = (& $script:GhExe --version 2>$null | Select-Object -First 1)
    Ok ("gh              " + $v)
    if (Gh-LoggedIn) { Ok 'gh 登录状态     已登录' } else { Warn 'gh 登录状态     未登录（阶段 4 处理）' }
} else {
    Warn 'gh              未安装（阶段 2 处理）'
}

if (Is-Admin) { Say '当前权限        管理员' } else { Warn '当前权限        普通用户 —— 安装时可能弹 UAC，点「是」即可' }
Gate

# ============================================================
# 阶段 2：安装 gh（纯动作）
# ============================================================
Write-Head 2 '安装 GitHub CLI'
if ($script:GhExe) {
    Ok '已经装了，跳过这一步。'
    Gate
} else {
    Say '将执行：'
    Write-Host '    winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements' -ForegroundColor DarkCyan
    Write-Host ''
    Say '来源：winget 官方仓库（对应 https://cli.github.com/ 的 Windows 包）'
    if (Confirm-Action '现在开始安装？') {
        Step '正在下载并安装，可能需要几分钟，期间可能弹 UAC…'
        Write-Host ''
        & winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
        Write-Host ''
        Update-Path
        $script:GhExe = Find-Gh

        if (-not $script:GhExe) {
            Warn 'winget 没装成（常见原因：直连 github.com 被阻断）。'
            Say '改用回退方案：经镜像下载官方 zip，校验 SHA256 后解压安装。'
            Write-Host ''
            if (Confirm-Action '走回退方案？') {
                $script:GhExe = Install-GhViaZip
            } else {
                Warn '已取消回退。'
            }
        }
        if ($script:GhExe) { Ok '安装完成' } else { Warn '仍未安装成功，进阶段 3 再查一次' }
    } else {
        Warn '已跳过安装。'
    }
    Gate
}

# ============================================================
# 阶段 3：验证安装（产出：版本号）
# ============================================================
Write-Head 3 '验证安装'
Update-Path
if (-not $script:GhExe) { $script:GhExe = Find-Gh }

if ($script:GhExe) {
    Ok ("找到 gh: " + $script:GhExe)
    Write-Host ''
    $ver = & $script:GhExe --version 2>&1
    $ver | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
    Ok 'gh 可执行，阶段通过。'
} else {
    Warn '仍然找不到 gh。'
    Say '常见原因：winget 装完需要新终端才刷新 PATH。'
    Say '请关掉这个窗口，重新打开 PowerShell，再跑一次本脚本；'
    Say '它会在阶段 1 直接识别到已装好的 gh。'
    Gate '按 Enter 结束'
    exit 1
}
Gate

# ============================================================
# 阶段 4：登录 GitHub（纯动作，凭据进凭据管理器）
# ============================================================
Write-Head 4 '登录 GitHub'
if (Gh-LoggedIn) {
    Ok '已经登录过了，跳过。'
    & $script:GhExe auth status 2>&1 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
    Gate
} else {
    Say '接下来 gh 会：'
    Say '  1. 在终端打印 8 位一次性代码'
    Say '  2. 自动打开浏览器到 github.com/login/device'
    Say '  3. 你在浏览器里粘贴/核对那 8 位代码，点 Authorize'
    Write-Host ''
    Warn '重要：浏览器里显示的代码必须和终端里的一致，否则不要确认。'
    Write-Host ''
    if (Confirm-Action '开始登录？') {
        Step '即将调用 gh auth login（浏览器授权流程）…'
        Write-Host ''
        & $script:GhExe auth login --hostname github.com --git-protocol https --web
        Write-Host ''
        if (Gh-LoggedIn) { Ok '登录成功' } else { Warn '登录似乎没完成，阶段 5 会再核一遍' }
    } else {
        Warn '已跳过登录。'
    }
    Gate
}

# ============================================================
# 阶段 5：验证身份（产出：账号名 + git 凭据配置）
# ============================================================
Write-Head 5 '验证身份'
if (Gh-LoggedIn) {
    & $script:GhExe auth status 2>&1 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
    Write-Host ''
    Step '正在确认账号…'
    $login = (& $script:GhExe api user -q .login 2>$null)
    if ($login) { Ok ("当前账号：" + $login) } else { Warn '拿不到账号名，可能网络受限，但不影响 gh 可用' }
    Write-Host ''
    Step '配置 git 使用 gh 的凭据（以后 git push 不再问密码）'
    & $script:GhExe auth setup-git 2>&1 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
    Ok 'git 凭据已接管'
} else {
    Warn '还没登录，跳过身份验证。你可以之后手动跑：gh auth login'
}
Gate

# ============================================================
# 阶段 6：收尾（纯输出）
# ============================================================
Write-Head 6 '收尾'
Ok 'GitHub CLI 就绪。'
Write-Host ''
Say '常用命令：' 'Cyan'
Write-Host '    gh repo list                     列出你的仓库' -ForegroundColor DarkGray
Write-Host '    gh repo clone owner/name         克隆仓库' -ForegroundColor DarkGray
Write-Host '    gh pr list                       看 PR' -ForegroundColor DarkGray
Write-Host '    gh pr create --fill              从当前分支提 PR' -ForegroundColor DarkGray
Write-Host '    gh issue list                    看 issue' -ForegroundColor DarkGray
Write-Host '    gh auth status                   查登录状态' -ForegroundColor DarkGray
Write-Host '    gh auth switch                   切账号' -ForegroundColor DarkGray
Write-Host ''
Say '卸载：winget uninstall --id GitHub.cli'
Say '文档：https://cli.github.com/manual/'
Write-Host ''
Write-Host ('  ' + ('=' * 52)) -ForegroundColor Green
Write-Host '   全部 6 个阶段完成' -ForegroundColor Green
Write-Host ('  ' + ('=' * 52)) -ForegroundColor Green
Write-Host ''
