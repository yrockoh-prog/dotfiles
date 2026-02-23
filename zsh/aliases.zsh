# --- OS 감지 ---
OS_TYPE=$(uname -s)

# --- 1. 파일 시스템 & 에디터 ---
if [ "$OS_TYPE" = "Darwin" ]; then
    alias ls='ls -G'  # Mac Color
else
    alias ls='ls --color=auto' # Linux Color
fi
alias ll='ls -alF'
alias vi='nvim'
alias vim='nvim'
alias ..='cd ..'
alias z='cd'

# --- 2. GPU 유틸리티 ---
if [ "$OS_TYPE" = "Linux" ]; then
    # NVIDIA GPU 모니터링 (gpustat 설치 시 사용, 없으면 nvidia-smi)
    if command -v gpustat &> /dev/null; then
        alias gpu='gpustat -i --color'
    else
        alias gpu='watch -n 0.5 -c "nvidia-smi"'
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    # Mac GPU 모니터링 (M1/M2/M3)
    alias gpu='sudo powermetrics --samplers gpu_power -i 1000 -n 1'
fi

# --- 3. NPU 유틸리티 ---
# NPU 상태 모니터링 (npustat 설치 시 작동)
alias npu='watch -n 0.5 -c "npustat"'

# --- 4. Docker ---
alias d='docker'
alias dps='docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"'
alias dexec='docker exec -it'

# --- 5. Claude Code ---
# 기본 실행: OMC 설정 동기화 후 샌드박스 + 권한 무시 모드로 실행
alias claude='omc update && IS_SANDBOX=1 command claude --dangerously-skip-permissions'

# 권한 무시만 (omc update 없이 빠르게 실행할 때)
alias cauto='IS_SANDBOX=1 command claude --dangerously-skip-permissions'

# 로컬에서 단축키로 Claude Code 업데이트
function claude_update() {
    echo "Updating Claude Code..."
    sudo npm install -g @anthropic-ai/claude-code
    echo "Done. Run 'claude --version' to check."
}
alias cu='claude_update'