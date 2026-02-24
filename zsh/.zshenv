# 모든 zsh 세션에서 맨 먼저 로드됨 (로그인/비로그인, 대화형/스크립트 공통)
# 한글/UTF-8: en_US.UTF-8이 없으면 C.UTF-8 사용 (도커 등 setlocale 경고 방지)
if locale -a 2>/dev/null | grep -qx en_US.UTF-8; then
  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8
else
  export LANG=C.UTF-8 LC_ALL=C.UTF-8 LC_CTYPE=C.UTF-8
fi

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
