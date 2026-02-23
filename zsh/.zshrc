export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# 플러그인 로드
plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker)

source $ZSH/oh-my-zsh.sh

# 기본 에디터
export EDITOR='nvim'

# 커스텀 Alias 로드 (클론 경로가 ~/dotfiles 또는 ~/.dotfiles 모두 지원)
if [ -f "$HOME/dotfiles/zsh/aliases.zsh" ]; then
    source "$HOME/dotfiles/zsh/aliases.zsh"
elif [ -f "$HOME/.dotfiles/zsh/aliases.zsh" ]; then
    source "$HOME/.dotfiles/zsh/aliases.zsh"
fi