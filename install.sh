#!/bin/bash
set -e

# sudo로 실행 시 실제 사용자 HOME 사용 (참고: 팀 dotfiles)
if [[ -n "${SUDO_USER:-}" ]]; then
    if command -v getent &>/dev/null; then
        HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        HOME=$(eval echo "~$SUDO_USER")
    fi
    export HOME
fi

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Docker/컨테이너 여부 (chsh 스킵 등에만 사용). Claude는 local/remote/컨테이너 모두 동일하게 설치
# Claude 스킵은 DOTFILES_SKIP_CLAUDE=1 일 때만
[ -f /.dockerenv ] || [ -n "${container:-}" ] && IN_CONTAINER=1 || IN_CONTAINER=0
[ "${DOTFILES_SKIP_CLAUDE:-0}" = "1" ] && SKIP_CLAUDE=1 || true

# --- 1. OS 감지 ---
get_os() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "Mac";;
        *)          echo "Unknown";;
    esac
}

OS_TYPE=$(get_os)
echo "🖥️  Detected OS: $OS_TYPE"

# --- 2. 패키지 설치 ---
install_packages() {
    if [ "$OS_TYPE" == "Mac" ]; then
        if ! command -v brew &> /dev/null; then
            echo "🍺 Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        echo "📦 Installing packages (brew)..."
        brew update
        # Node.js는 Claude Code 실행을 위해 필수
        brew install zsh tmux neovim git curl wget ripgrep fd node
        
    elif [ "$OS_TYPE" == "Linux" ]; then
        echo "📦 Installing packages (apt)..."
        # Node.js 최신 LTS 버전 설치 (Ubuntu 기본 패키지는 구버전일 수 있음)
        if ! command -v node &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        fi
        
        if [ "$EUID" -ne 0 ]; then
             sudo apt-get update && sudo apt-get install -y zsh tmux neovim git curl wget ripgrep fd-find nodejs python3-pip
        else
             apt-get update && apt-get install -y zsh tmux neovim git curl wget ripgrep fd-find nodejs python3-pip
        fi
    fi
}

# --- 2-1. pip 패키지 (GPU 모니터링 등) ---
install_pip_packages() {
    echo "🐍 Installing pip packages..."
    if command -v pip3 &> /dev/null; then
        pip3 install --user gpustat 2>/dev/null || sudo pip3 install gpustat
    elif command -v pip &> /dev/null; then
        pip install --user gpustat 2>/dev/null || sudo pip install gpustat
    else
        echo "   Skipping gpustat (pip not found). Install python3-pip and re-run."
    fi
}

# --- 3. Claude Code 설정 (DOTFILES_SKIP_CLAUDE=1 일 때만 생략) ---
install_claude() {
    if [ "${SKIP_CLAUDE:-0}" = "1" ]; then
        echo "🤖 Skipping Claude Code (DOTFILES_SKIP_CLAUDE=1)."
        return 0
    fi
    echo "🤖 Setting up Claude Code..."
    
    # npm으로 Claude Code 전역 설치
    if ! command -v claude &> /dev/null; then
        echo "   Installing @anthropic-ai/claude-code..."
        sudo npm install -g @anthropic-ai/claude-code
    fi

    # PATH에 로컬 bin 추가 (claude가 여기 설치될 수 있음)
    export PATH="$HOME/.local/bin:$PATH"

    # CLAUDE.md 심볼릭 링크 (홈 디렉토리에 두어 전역 컨텍스트로 사용)
    link_file "$DOTFILES_DIR/caludecode/CLAUDE.md" "$HOME/CLAUDE.md"

    # Oh My Claudecode 플러그인 (팀 동료 dotfiles 참조: https://github.com/seongwoongcho/dotfiles)
    echo "   Setting up oh-my-claudecode plugin..."
    claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode 2>/dev/null || true
    claude plugin install oh-my-claudecode 2>/dev/null || true
    command -v omc &>/dev/null && omc update 2>/dev/null || true

    # 공식 LSP 플러그인 (선택)
    echo "   Adding Claude Code LSP plugins..."
    claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
    for pkg in typescript-lsp@claude-plugins-official pyright-lsp@claude-plugins-official; do
        claude plugin install "$pkg" 2>/dev/null || true
    done

    # Superpowers 플러그인
    echo "   Installing superpowers plugin..."
    claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true
    claude plugin install superpowers@superpowers-marketplace 2>/dev/null || true
}

# --- 4. 심볼릭 링크 생성 함수 ---
# dotfiles가 $HOME 아래에 있으면 상대 경로로 링크 (다른 머신/경로에서도 깨지지 않음)
link_file() {
    local src=$1
    local dest=$2
    local link_target="$src"
    if [[ "$DOTFILES_DIR" == "$HOME"/* ]]; then
        # dotfiles가 $HOME 아래면 상대 경로로 링크 (이동/다른 머신에서도 유지)
        link_target="${DOTFILES_DIR#$HOME/}/${src#$DOTFILES_DIR/}"
        link_target="${link_target#/}"
    fi
    mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ]; then rm "$dest"; elif [ -f "$dest" ] || [ -d "$dest" ]; then
        echo "   Backing up $dest to $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR"
    fi
    ln -s "$link_target" "$dest"
    echo "🔗 Linked: $dest -> $link_target"
}

# --- 실행 로직 ---
install_packages
install_pip_packages
install_claude

# Oh My Zsh 설치
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "🎨 Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Zsh 플러그인 설치
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting

# 설정 파일 연결
echo "🔗 Linking config files..."
link_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
mkdir -p "$HOME/.tmux"
# statusbar.tmux: ~/.tmux/ 기준 상대 경로로 링크 (link_file은 $HOME 기준이라 별도 처리)
if [ -L "$HOME/.tmux/statusbar.tmux" ]; then rm "$HOME/.tmux/statusbar.tmux"; fi
if [ -f "$HOME/.tmux/statusbar.tmux" ] && [ ! -L "$HOME/.tmux/statusbar.tmux" ]; then
  mkdir -p "$BACKUP_DIR"
  mv "$HOME/.tmux/statusbar.tmux" "$BACKUP_DIR/statusbar.tmux" 2>/dev/null || true
fi
if [[ "$DOTFILES_DIR" == "$HOME"/* ]]; then
  ln -s "../${DOTFILES_DIR#$HOME/}/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux"
else
  ln -s "$DOTFILES_DIR/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux"
fi
echo "🔗 Linked: ~/.tmux/statusbar.tmux -> statusbar.tmux"
# TPM (Tmux Plugin Manager) — 플러그인 사용 시 필요
[ -d "$HOME/.tmux/plugins/tpm" ] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
bash "$HOME/.tmux/plugins/tpm/bin/install_plugins" 2>/dev/null || true

link_file "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
link_file "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

# 기본 쉘을 zsh로 변경 시도 (실패해도 아래 .bashrc fallback으로 터미널/tmux에서 zsh 실행됨)
ZSH_PATH=$(command -v zsh 2>/dev/null)
if [ -n "$ZSH_PATH" ] && [ "$IN_CONTAINER" = "0" ]; then
    if [ "$SHELL" != "$ZSH_PATH" ]; then
        echo "🐚 Changing default shell to zsh..."
        if chsh -s "$ZSH_PATH" 2>/dev/null; then
            echo "   Default shell set to zsh."
        else
            echo "   chsh failed (권한/환경 제한). .bashrc에 fallback 추가함 — 새 터미널/tmux에서 자동으로 zsh 실행됩니다."
        fi
    fi
fi

# bash가 떠도 자동으로 zsh로 넘어가도록 fallback 추가
# 로그인 셸(Mac 터미널, SSH)은 .bash_profile만 읽음 → 둘 다에 넣어야 함
add_zsh_launcher() {
    local file="$1"
    [ -z "$ZSH_PATH" ] && return 0
    [ -f "$file" ] && grep -q "dotfiles: exec zsh" "$file" 2>/dev/null && return 0
    echo "" >> "$file"
    echo "# dotfiles: exec zsh when bash is interactive" >> "$file"
    echo 'if [ -n "$BASH_VERSION" ] && [[ $- == *i* ]]; then' >> "$file"
    printf '  [ -x "%s" ] && exec %s -l\n' "$ZSH_PATH" "$ZSH_PATH" >> "$file"
    echo "fi" >> "$file"
    echo "🔗 Added zsh launcher to $file (bash → zsh)"
}
if [ -n "$ZSH_PATH" ] && [ "$IN_CONTAINER" = "0" ]; then
    add_zsh_launcher "$HOME/.bashrc"
    add_zsh_launcher "$HOME/.bash_profile"
fi

# sudo로 실행했을 때 생성된 디렉터리/링크 소유자를 실제 사용자로
if [[ -n "${SUDO_USER:-}" ]]; then
    SUDO_GROUP=$(id -gn "$SUDO_USER" 2>/dev/null || true)
    if [[ -n "$SUDO_GROUP" ]]; then
        echo "🔧 Fixing ownership for $SUDO_USER..."
        for dir in "$HOME/.oh-my-zsh" "$HOME/.zplug" "$HOME/.config" "$HOME/.tmux" \
                   "$HOME/.cache/nvim" "$HOME/.local" "$HOME/.zshrc" "$HOME/.bashrc" \
                   "$HOME/.bash_profile" "$HOME/.gitconfig" "$HOME/.tmux.conf" \
                   "$HOME/.config/nvim" "$HOME/CLAUDE.md"; do
            [[ -e "$dir" ]] && chown -R "$SUDO_USER:$SUDO_GROUP" "$dir" 2>/dev/null || true
        done
    fi
fi

echo "✅ Installation Complete! Restart your terminal (or run 'exec zsh')."
echo ""
echo "💡 Tmux: 이미 실행 중이면 설정이 안 읽힙니다. tmux 안에서 Ctrl+a 누른 뒤 r 로 설정 리로드, 또는 tmux 완전히 종료 후 다시 실행."