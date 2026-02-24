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
    # 컨테이너 안에서 비 root면 apt/brew 스킵 (이미지는 빌드 시 root로 패키지 설치됨)
    if [ "$IN_CONTAINER" = "1" ] && [ "$EUID" -ne 0 ]; then
        echo "📦 Skipping system packages (container, non-root). 이미지 빌드 시 설치된 패키지를 사용합니다."
        return 0
    fi

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
            [ "$EUID" -eq 0 ] && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - || curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
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
    # 컨테이너 비 root: --user만 시도 (sudo 없음)
    if [ "$IN_CONTAINER" = "1" ] && [ "$EUID" -ne 0 ]; then
        if command -v pip3 &> /dev/null; then
            pip3 install --user gpustat 2>/dev/null || true
        elif command -v pip &> /dev/null; then
            pip install --user gpustat 2>/dev/null || true
        fi
        return 0
    fi
    echo "🐍 Installing pip packages..."
    if command -v pip3 &> /dev/null; then
        if [ "$EUID" -eq 0 ] || [ "$IN_CONTAINER" = "1" ]; then
            pip3 install gpustat 2>/dev/null || true
        else
            pip3 install --user gpustat 2>/dev/null || sudo pip3 install gpustat
        fi
    elif command -v pip &> /dev/null; then
        if [ "$EUID" -eq 0 ] || [ "$IN_CONTAINER" = "1" ]; then
            pip install gpustat 2>/dev/null || true
        else
            pip install --user gpustat 2>/dev/null || sudo pip install gpustat
        fi
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
    
    # npm으로 Claude Code 전역 설치 (root 또는 컨테이너면 sudo 없이)
    if ! command -v claude &> /dev/null; then
        echo "   Installing @anthropic-ai/claude-code..."
        if [ "$EUID" -eq 0 ] || [ "$IN_CONTAINER" = "1" ]; then
            npm install -g @anthropic-ai/claude-code
        else
            sudo npm install -g @anthropic-ai/claude-code
        fi
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

# UTF-8 로케일: bash/tmux 등에서도 한글 깨짐 방지 (도커 등에서 bash로 들어오면 .zshenv가 안 읽힘)
add_utf8_to_bash() {
    local home_dir="${1:-$HOME}"
    local bashrc="$home_dir/.bashrc"
    local bash_profile="$home_dir/.bash_profile"
    local marker="dotfiles: UTF-8 locale"
    for f in "$bashrc" "$bash_profile"; do
        [ -f "$f" ] && grep -q "$marker" "$f" 2>/dev/null && continue
        touch "$f" 2>/dev/null || true
        echo "" >> "$f"
        echo "# $marker (한글)" >> "$f"
        echo 'export LANG=en_US.UTF-8' >> "$f"
        echo 'export LC_ALL=en_US.UTF-8' >> "$f"
        echo 'export LC_CTYPE=en_US.UTF-8' >> "$f"
        echo "   UTF-8 locale added to $f"
    done
}
add_utf8_to_bash "$HOME"

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

# --- 컨테이너 root 전용: 별도 사용자(dev) 생성 + dotfiles 연결 → Claude만 그 사용자로 실행해 --dangerously-skip-permissions 가능
CONTAINER_CLAUDE_USER="${CONTAINER_CLAUDE_USER:-dev}"
if [ "$IN_CONTAINER" = "1" ] && [ "$EUID" -eq 0 ]; then
    if getent passwd "$CONTAINER_CLAUDE_USER" &>/dev/null; then
        echo "👤 User $CONTAINER_CLAUDE_USER already exists (Claude runs as this user for --dangerously-skip-permissions)."
    else
        echo "👤 Creating user $CONTAINER_CLAUDE_USER (container stays root; Claude will run as this user)."
        useradd -m -s /bin/zsh "$CONTAINER_CLAUDE_USER" 2>/dev/null || true
    fi
    if getent passwd "$CONTAINER_CLAUDE_USER" &>/dev/null; then
        DEV_HOME="$(getent passwd "$CONTAINER_CLAUDE_USER" | cut -d: -f6)"
        BACKUP_DIR_DEV="$DEV_HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
        export HOME="$DEV_HOME"
        export BACKUP_DIR="$BACKUP_DIR_DEV"
        mkdir -p "$HOME/.tmux" "$HOME/.config"
        [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
        [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
        [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true
        link_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
        link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
        link_file "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
        [ -L "$HOME/.tmux/statusbar.tmux" ] && rm "$HOME/.tmux/statusbar.tmux"
        [ -f "$HOME/.tmux/statusbar.tmux" ] && [ ! -L "$HOME/.tmux/statusbar.tmux" ] && mkdir -p "$BACKUP_DIR_DEV" && mv "$HOME/.tmux/statusbar.tmux" "$BACKUP_DIR_DEV/" 2>/dev/null || true
        if [[ "$DOTFILES_DIR" == "$DEV_HOME"/* ]]; then
            ln -sf "../${DOTFILES_DIR#$DEV_HOME/}/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux" 2>/dev/null || true
        else
            ln -sf "$DOTFILES_DIR/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux" 2>/dev/null || true
        fi
        [ -d "$HOME/.tmux/plugins/tpm" ] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" 2>/dev/null || true
        link_file "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
        link_file "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"
        link_file "$DOTFILES_DIR/caludecode/CLAUDE.md" "$HOME/CLAUDE.md"
        add_utf8_to_bash "$DEV_HOME"
        chown -R "$CONTAINER_CLAUDE_USER:$CONTAINER_CLAUDE_USER" "$DEV_HOME" 2>/dev/null || true
        echo "   Dotfiles linked for $CONTAINER_CLAUDE_USER. Run 'claude' or 'cauto' as root → runs as $CONTAINER_CLAUDE_USER with --dangerously-skip-permissions."
    fi
fi

echo "✅ Installation Complete! Restart your terminal (or run 'exec zsh')."
echo ""
echo "💡 Tmux: 이미 실행 중이면 설정이 안 읽힙니다. tmux 안에서 Ctrl+a 누른 뒤 r 로 설정 리로드, 또는 tmux 완전히 종료 후 다시 실행."
echo "💡 Docker에서 한글 깨짐: bash로 들어왔으면 위에서 .bashrc/.bash_profile에 UTF-8을 넣었음. 새 터미널을 열거나 source ~/.bashrc 후 tmux를 다시 띄우세요. 로케일이 없으면 sudo locale-gen en_US.UTF-8 또는 이미지에 해당 로케일이 있는지 확인하세요."