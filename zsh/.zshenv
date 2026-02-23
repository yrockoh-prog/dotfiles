# 모든 zsh 세션에서 맨 먼저 로드됨 (로그인/비로그인, 대화형/스크립트 공통)
# Linux 일반 터미널에서 한글 깨짐 방지
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# Linux: 한글 입력(IME) — 터미널에서 한글 타이핑 가능하도록
if [[ -n "${ZSH_VERSION:-}" ]] && [[ "$OSTYPE" == linux* ]]; then
  if command -v fcitx5 &>/dev/null || command -v fcitx &>/dev/null; then
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
  elif command -v ibus-daemon &>/dev/null; then
    export GTK_IM_MODULE=ibus
    export QT_IM_MODULE=ibus
    export XMODIFIERS=@im=ibus
  fi
fi
