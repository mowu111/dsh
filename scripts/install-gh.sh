#!/usr/bin/env bash
#
# GitHub CLI (gh) 安装向导
# 由 /wizard 生成 · 2026-10-28 · 官方站点 https://cli.github.com/
#
# 用法（Git Bash）：
#   bash scripts/install-gh.sh
#
# 说明：这个流程没有需要写进 .env 的密钥 —— gh 把 token 存进 Windows
# 凭据管理器，向导因此只做「动作 + 确认门」，不调用 write_env / set_secret。
#
# 所有内容都在“STAGES”标记以下，标记以上的库来自 template.sh，未做改动。

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# Wizard library: delightful, consistent UX, identical across every wizard.
# ──────────────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  BLUE=$(tput setaf 4); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1)
else
  BOLD=""; DIM=""; RESET=""; BLUE=""; GREEN=""; YELLOW=""; RED=""
fi

TOTAL_STAGES=0

_STAGE_INDEX=0
ENV_FILE="${ENV_FILE:-.env}"
WRITTEN_ENV=()
WRITTEN_SECRET=()
SKIPPED=()

_clear() {
  [[ -t 1 ]] || return 0
  if command -v tput >/dev/null 2>&1; then tput clear; else printf '\033[2J\033[3J\033[H'; fi
}

banner() {
  _clear
  printf '\n%s%s  %s%s\n' "$BOLD" "$BLUE" "$1" "$RESET"
  printf '%s  %s stages%s\n\n' "$DIM" "$TOTAL_STAGES" "$RESET"
  printf '%s  You drive the browser; this wizard tells you exactly what to do and\n' "$DIM"
  printf '  captures the values you copy back. Stop any time with Ctrl-C and re-run\n'
  printf '  later, since it remembers values already saved.%s\n' "$RESET"
  pause "Ready to start?"
}

stage() {
  _clear
  _STAGE_INDEX=$((_STAGE_INDEX + 1))
  printf '\n%s%s▸ Stage %s/%s · %s%s\n' \
    "$BOLD" "$BLUE" "$_STAGE_INDEX" "$TOTAL_STAGES" "$1" "$RESET"
}

say()  { printf '  %s\n' "$1"; }
step() { printf '  %s•%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s⚠ %s%s\n' "$YELLOW" "$1" "$RESET"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }

open_url() {
  local url="$1"
  printf '  %s↗ opening%s %s\n' "$GREEN" "$RESET" "$url"
  { if   command -v wslview     >/dev/null 2>&1; then wslview "$url"
    elif command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$url"
    elif command -v xdg-open    >/dev/null 2>&1; then xdg-open "$url"
    elif command -v open        >/dev/null 2>&1; then open "$url"
    else warn "couldn't open a browser; visit it manually: $url"; fi
  } >/dev/null 2>&1 || warn "couldn't open a browser, so visit it manually: $url"
}

pause() {
  printf '  %s%s%s ' "$DIM" "${1:-Press Enter to continue}" "$RESET"
  read -r _ || true
}

confirm() {
  local reply=""
  printf '  %s? %s [y/N] ' "$YELLOW" "$1"
  read -r reply || true
  [[ "$reply" =~ ^[Yy] ]]
}

_existing() {
  [[ -f "$ENV_FILE" ]] || return 1
  local line; line=$(grep -E "^${1}=" "$ENV_FILE" | tail -n1) || return 1
  printf '%s' "${line#*=}"
}

ask() {
  local key="$1" prompt="$2" current input
  current=$(_existing "$key" || true)
  if [[ -n "$current" ]]; then
    printf '  %s%s%s %s[Enter keeps current]%s ' "$BOLD" "$prompt" "$RESET" "$DIM" "$RESET"
  else
    printf '  %s%s%s ' "$BOLD" "$prompt" "$RESET"
  fi
  read -r input || true
  [[ -z "$input" && -n "$current" ]] && input="$current"
  printf -v "$key" '%s' "$input"
}

ask_secret() {
  local key="$1" prompt="$2" current input
  current=$(_existing "$key" || true)
  if [[ -n "$current" ]]; then
    printf '  %s%s%s %s[Enter keeps current]%s ' "$BOLD" "$prompt" "$RESET" "$DIM" "$RESET"
  else
    printf '  %s%s%s ' "$BOLD" "$prompt" "$RESET"
  fi
  read -rs input || true
  printf '\n'
  [[ -z "$input" && -n "$current" ]] && input="$current"
  printf -v "$key" '%s' "$input"
}

write_env() {
  local key="$1" value="$2" tmp
  touch "$ENV_FILE"
  tmp=$(mktemp)
  grep -vE "^${key}=" "$ENV_FILE" > "$tmp" || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
  WRITTEN_ENV+=("$key")
  printf '  %s✓ wrote%s %s → %s\n' "$GREEN" "$RESET" "$key" "$ENV_FILE"
}

set_secret() {
  local name="$1" value="$2"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if printf '%s' "$value" | gh secret set "$name" >/dev/null 2>&1; then
      WRITTEN_SECRET+=("$name")
      printf '  %s✓ set%s GitHub secret %s\n' "$GREEN" "$RESET" "$name"
      return
    fi
  fi
  SKIPPED+=("GitHub secret $name (set it manually: gh secret set $name)")
  warn "skipped GitHub secret $name: gh not ready; set it later"
}

set_var() {
  local name="$1" value="$2"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if gh variable set "$name" --body "$value" >/dev/null 2>&1; then
      printf '  %s✓ set%s GitHub variable %s\n' "$GREEN" "$RESET" "$name"
      return
    fi
  fi
  SKIPPED+=("GitHub variable $name")
  warn "skipped GitHub variable $name, gh not ready; set it later"
}

finish() {
  _clear
  printf '\n%s%s  ✓ Setup complete%s\n' "$BOLD" "$GREEN" "$RESET"
  (( ${#WRITTEN_ENV[@]} ))    && note "wrote ${#WRITTEN_ENV[@]} value(s) to $ENV_FILE: ${WRITTEN_ENV[*]}"
  (( ${#WRITTEN_SECRET[@]} )) && note "set ${#WRITTEN_SECRET[@]} GitHub secret(s): ${WRITTEN_SECRET[*]}"
  if (( ${#SKIPPED[@]} )); then
    printf '\n'; warn "still to do by hand:"
    for s in "${SKIPPED[@]}"; do note "  - $s"; done
  fi
  printf '\n'
}

# ──────────────────────────────────────────────────────────────────────────
# STAGES
# ──────────────────────────────────────────────────────────────────────────

GH_VERSION="2.103.3"
GH_HOME="/d/软件/gh"                 # 安装根目录（D 盘，按工作台规则）
GH_CONFIG_DIR_WIN='D:\软件\gh-config' # gh 配置目录（不写 C 盘）
GIT_CONFIG_WIN='D:\软件\git-config\.gitconfig' # git 全局配置（不写 C:\Users\...\.gitconfig）
MIRROR="https://ghproxy.net/"          # 直连 github.com 失败时的镜像

# git 的全局配置落在 D 盘，避免往 C 盘用户目录写东西
if [ -f "/d/软件/git-config/.gitconfig" ]; then
  export GIT_CONFIG_GLOBAL="$GIT_CONFIG_WIN"
fi

# gh 可执行文件位置：先看 PATH，再看已知路径
gh_bin() {
  local p
  if command -v gh >/dev/null 2>&1; then command -v gh; return 0; fi
  for p in "$GH_HOME/bin/gh.exe" \
           "$HOME/AppData/Local/Programs/gh/bin/gh.exe" \
           "/c/Program Files/GitHub CLI/gh.exe"; do
    [ -x "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

gh_logged_in() {
  local g; g=$(gh_bin 2>/dev/null) || return 1
  GH_CONFIG_DIR="$GH_CONFIG_DIR_WIN" "$g" auth status >/dev/null 2>&1
}

TOTAL_STAGES=6

banner "GitHub CLI (gh) 安装"

# ── 1 环境体检 ─────────────────────────────────────────────────────────────
stage "环境体检"
say "先看这台机器的底子，只读，不改任何东西。"
echo
note "bash      $(bash --version | head -1)"
note "curl      $(command -v curl || echo '缺失')"
note "unzip     $(command -v unzip || echo '缺失')"
if command -v winget.exe >/dev/null 2>&1; then
  note "winget    可用"
else
  note "winget    不可用（将走镜像下载）"
fi
if g=$(gh_bin 2>/dev/null); then
  ok "gh 已安装：$("${g}" --version | head -1)"
  if gh_logged_in; then ok "登录状态：已登录"; else warn "登录状态：未登录（阶段 4 处理）"; fi
else
  warn "gh：未安装（阶段 2 处理）"
fi
pause

# ── 2 安装 ────────────────────────────────────────────────────────────────
stage "安装 GitHub CLI"
if g=$(gh_bin 2>/dev/null); then
  ok "已经装了，跳过。"
  pause
else
  say "将把 gh $GH_VERSION 装到 $GH_HOME"
  if confirm "开始安装？"; then
    installed=0
    if command -v winget.exe >/dev/null 2>&1; then
      step "先试 winget（会弹 UAC 就点“是”）…"
      if winget.exe install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements; then
        installed=1
      else
        warn "winget 失败（这台机器上常见：直连 github.com 被证书吊销检查掐断）"
      fi
    fi
    if (( installed == 0 )); then
      step "改用镜像下载官方 zip：$MIRROR"
      tmp=$(mktemp -d)
      base="${MIRROR}https://github.com/cli/cli/releases/download/v${GH_VERSION}"
      if curl -L --fail --max-time 900 -o "$tmp/gh.zip" \
           "$base/gh_${GH_VERSION}_windows_amd64.zip"; then
        ok "下载完成：$(du -h "$tmp/gh.zip" | cut -f1)"
        step "下载官方校验和并比对"
        if curl -L --fail --max-time 120 -o "$tmp/sums.txt" \
             "$base/gh_${GH_VERSION}_checksums.txt"; then
          want=$(grep 'windows_amd64\.zip' "$tmp/sums.txt" | awk '{print $1}' | head -1)
          have=$(sha256sum "$tmp/gh.zip" | awk '{print $1}')
          if [ -n "$want" ] && [ "$want" = "$have" ]; then
            ok "SHA256 一致"
          else
            warn "校验不一致，停止安装（期望 ${want:-空} / 实际 $have）"
            rm -rf "$tmp"; pause; exit 1
          fi
        else
          warn "拿不到官方校验和，无法校验；如不放心请手动从 cli.github.com 安装"
        fi
        step "解压到 $GH_HOME"
        mkdir -p "$GH_HOME"
        unzip -q -o "$tmp/gh.zip" -d "$GH_HOME"
        ok "解压完成：$(du -sh "$GH_HOME" | cut -f1)"
        step "把 D:\\软件\\gh\\bin 写进用户 PATH"
        powershell.exe -NoProfile -Command \
          "\$p=[Environment]::GetEnvironmentVariable('Path','User'); if(\$p -notlike '*软件\\gh\\bin*'){[Environment]::SetEnvironmentVariable('Path',\$p.TrimEnd(';')+';D:\\软件\\gh\\bin','User')}" \
          && ok "PATH 已更新（新开终端生效）" || warn "PATH 更新失败，请手动添加 D:\\软件\\gh\\bin"
        rm -rf "$tmp"
      else
        warn "镜像下载也失败，安装中止。可手动安装：https://cli.github.com/"
        pause; exit 1
      fi
    fi
    # 让本进程能找到刚装好的 gh
    export PATH="$GH_HOME/bin:$PATH"
    if g=$(gh_bin 2>/dev/null); then ok "安装完成：$("${g}" --version | head -1)"; else warn "装完了但仍找不到 gh"; fi
  else
    warn "已跳过安装。"
  fi
  pause
fi

# ── 3 验证 ────────────────────────────────────────────────────────────────
stage "验证安装"
export PATH="$GH_HOME/bin:$PATH"
if g=$(gh_bin 2>/dev/null); then
  ok "找到 gh：$g"
  echo
  "${g}" --version | while IFS= read -r line; do note "$line"; done
  pause
else
  warn "找不到 gh。常见原因：新装的程序需要新终端才刷新 PATH。"
  say "关掉这个窗口，重新打开 Git Bash，再跑一次本脚本即可。"
  pause "按 Enter 结束"
  exit 1
fi

# ── 4 登录 ────────────────────────────────────────────────────────────────
stage "登录 GitHub"
if gh_logged_in; then
  ok "已经登录过了，跳过。"
  GH_CONFIG_DIR="$GH_CONFIG_DIR_WIN" "$(gh_bin)" auth status 2>&1 | while IFS= read -r l; do note "$l"; done || true
  pause
else
  say "接下来 gh 会打印一个 8 位一次性代码，并打开浏览器。"
  step "浏览器打开 github.com/login/device"
  step "粘贴那 8 位代码，点 Continue"
  step "确认是 GitHub CLI，点 Authorize"
  echo
  warn "浏览器里显示的代码必须和终端里一致，否则不要确认。"
  echo
  if confirm "开始登录？"; then
    GH_CONFIG_DIR="$GH_CONFIG_DIR_WIN" "$(gh_bin)" auth login \
      --hostname github.com --git-protocol https --web || warn "登录没有完成"
    if gh_logged_in; then ok "登录成功"; else warn "仍未登录，阶段 5 会再查一次"; fi
  else
    warn "已跳过登录。"
  fi
  pause
fi

# ── 5 验证身份 ────────────────────────────────────────────────────────────
stage "验证身份"
export GH_CONFIG_DIR="$GH_CONFIG_DIR_WIN"
if gh_logged_in; then
  "$(gh_bin)" auth status 2>&1 | while IFS= read -r l; do note "$l"; done || true
  echo
  step "确认账号"
  login=$("$(gh_bin)" api user --jq .login 2>/dev/null || true)
  if [ -n "$login" ]; then ok "当前账号：$login"; else warn "取不到账号名，可能网络受限"; fi
  echo
  step "让 git 使用 gh 的凭据（以后 clone / push 不用输密码）"
  # 不用 gh auth setup-git：它把含中文的路径写进 .gitconfig 时会变成乱码，
  # 凭据助手因此失效。让 git 自己写，编码正常。
  if command -v git >/dev/null 2>&1; then
    # 必须用正斜杠（cygpath -m）：helper 由 sh 执行，反斜杠会被当成转义符，
    # 路径被吃掉后报 "could not read Username"。
    gh_win=$(cygpath -m "$(gh_bin)" 2>/dev/null || printf '%s' "$(gh_bin)")
    if git config --global credential."https://github.com".helper "!${gh_win} auth git-credential" \
       && git config --global credential."https://gist.github.com".helper "!${gh_win} auth git-credential"; then
      ok "git 凭据已接管"
    else
      warn "写 git 凭据配置失败"
    fi
  else
    warn "没装 git，跳过（gh 本身不受影响）"
  fi
else
  warn "还没登录，跳过。之后可以手动：gh auth login"
fi
pause

# ── 6 收尾 ────────────────────────────────────────────────────────────────
stage "收尾"
ok "GitHub CLI 就绪。"
echo
say "常用命令："
note "  gh repo list                    列出仓库"
note "  gh repo clone owner/name        克隆"
note "  gh pr list / gh pr create       看 PR / 提 PR"
note "  gh issue list                   看 issue"
note "  gh auth status                  查登录状态"
note "  gh auth switch                  切账号"
echo
note "官方文档 https://cli.github.com/manual/"
pause

finish
