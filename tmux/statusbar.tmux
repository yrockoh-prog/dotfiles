#!/usr/bin/env bash
# Tmux statusbar configuration script
# Displays CPU, RAM, GPU, NPU usage dynamically

set -e
set -o pipefail

cwd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

main() {
  tmux set-hook -g client-resized "run-shell '~/.tmux/statusbar.tmux'"

  # Left status: session name
  tmux set -g status-left "\
#[fg=#ffffff,bg=#444444,bold] #S \
#[fg=#444444,bg=#1c1c1c]\
"

  # Right status length
  local STATUS_RIGHT_LENGTH=80
  if [ "$(tmux display-message -p '#{client_width}' 2>/dev/null)" -lt 100 ] 2>/dev/null; then
    STATUS_RIGHT_LENGTH=4
  fi

  tmux set -g status-right-length $STATUS_RIGHT_LENGTH
  tmux set-hook -g client-attached "set -g status-right-length 1; run-shell 'sleep 1.1'; set -g status-right-length $STATUS_RIGHT_LENGTH;"

  local session_name=$(tmux display-message -p '#S')

  # Prefix indicator + datetime placeholder
  tmux set -g status-right "\
#[fg=#ffffff,bg=#005fd7]#{?client_prefix, PREFIX ,}\
#[default]\
"

  # CPU
  tmux set -ga status-right "#($cwd/statusbar.tmux component-cpu -S $session_name)"

  # RAM
  tmux set -ga status-right "#($cwd/statusbar.tmux component-ram -S $session_name)"

  # GPU (NVIDIA)
  if command -v nvidia-smi &> /dev/null && (lsmod 2>/dev/null | grep -q nvidia || nvidia-smi &>/dev/null); then
    tmux set -ga status-right "#($cwd/statusbar.tmux component-gpu -S $session_name)"
  fi

  # HPU (Intel Gaudi/Habana)
  if command -v hl-smi &> /dev/null; then
    tmux set -ga status-right "#($cwd/statusbar.tmux component-hpu -S $session_name)"
  fi

  # NPU
  if command -v npustat &> /dev/null; then
    tmux set -ga status-right "#($cwd/statusbar.tmux component-npu -S $session_name)"
  fi

  # Datetime
  tmux set -ga status-right "\
#[fg=#303030,bg=#1c1c1c,nobold]\
#[fg=#9e9e9e,bg=#303030] %m/%d %H:%M \
"

  # Window status
  tmux setw -g window-status-format "\
#[fg=#0087af,bg=#1c1c1c] #{?#{m:*M*,#F},#[fg=#121212]#[bg=#5faf5f],}#I#F\
#[fg=#bcbcbc,bg=#1c1c1c] #{=20:window_name}\
#[bg=#1c1c1c] \
"

  tmux setw -g window-status-current-format "\
#[fg=#1c1c1c,bg=#0087af,nobold]\
#[fg=#5fffff,bg=#0087af] #{?#{m:*M*,#F},#[fg=#121212]#[bg=#5faf5f],}#I#F\
#[fg=#ffffff,bg=#0087af,bold] #{=25:window_name}\
#{?pane_synchronized,#[fg=#d7ff00] (SYNC),} \
#[fg=#0087af,bg=#1c1c1c,nobold]\
"
}

cpu-usage() {
  if [ "$(uname)" = "Darwin" ]; then
    top -l 2 -s 1 2>/dev/null | grep -E "^CPU" | tail -1 | awk '{ printf "%.1f\n", $3 + $5 }'
  else
    cat <(grep 'cpu ' /proc/stat) <(sleep 1 && grep 'cpu ' /proc/stat) 2>/dev/null | \
      awk -v RS="" '{printf "%.1f\n", ($13-$2+$15-$4)*100/($13-$2+$15-$4+$16-$5)}' 2>/dev/null
  fi
}

component-cpu() {
  local cpu_percentage=$(cpu-usage)
  if [ -z "$cpu_percentage" ]; then return 1; fi

  local bgcolor fgcolor
  if command -v bc &>/dev/null; then
    if   (( $(echo "$cpu_percentage >= 80" | bc -l 2>/dev/null) )); then bgcolor='#aa2626'; fgcolor='white'
    elif (( $(echo "$cpu_percentage >= 60" | bc -l 2>/dev/null) )); then bgcolor='#802323'; fgcolor='white'
    elif (( $(echo "$cpu_percentage >= 40" | bc -l 2>/dev/null) )); then bgcolor='#562020'; fgcolor='white'
    elif (( $(echo "$cpu_percentage >= 20" | bc -l 2>/dev/null) )); then bgcolor='#3a1e1e'; fgcolor='white'
    else bgcolor='#2c1d1d'; fgcolor='#888888'; fi
  else
    bgcolor='#3a1e1e'; fgcolor='white'
  fi

  printf "#[bg=#1c1c1c,fg=$bgcolor,nobold]"
  printf "#[bg=$bgcolor,fg=$fgcolor]  CPU %2.0f%% #[default]" $cpu_percentage
}

component-ram() {
  local mem_used mem_total mem_percentage

  case $(uname -s) in
    Linux)
      if ! command -v free &> /dev/null; then return 1; fi
      IFS=" " read -r mem_used mem_total mem_percentage <<<"$(free -m | awk '/^Mem/ { print (($3+$5)/1024), ($2/1024), (($3+$5)/$2*100) }')"
    ;;
    Darwin)
      if ! command -v vm_stat &> /dev/null; then return 1; fi
      mem_used=$(vm_stat | grep ' active\|wired ' | sed 's/[^0-9]//g' | paste -sd ' ' - | \
          awk -v pagesize=$(pagesize 2>/dev/null || echo 4096) '{ printf "%.2f\n", ($1 + $2) * pagesize / 1024^3 }')
      mem_total=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Memory:" | awk '{ print $2 }')
      mem_percentage=$(echo "$mem_used $mem_total" | awk '{ printf "%.0f", 100 * $1 / $2 }')
    ;;
    *) return 1;;
  esac

  if [ -z "$mem_percentage" ]; then return 1; fi

  local bgcolor fgcolor
  if command -v bc &>/dev/null; then
    if   (( $(echo "$mem_percentage >= 90" | bc -l 2>/dev/null) )); then bgcolor='#e67700'; fgcolor='black'
    elif (( $(echo "$mem_percentage >= 75" | bc -l 2>/dev/null) )); then bgcolor='#B57A0A'; fgcolor='black'
    elif (( $(echo "$mem_percentage >= 50" | bc -l 2>/dev/null) )); then bgcolor='#755515'; fgcolor='white'
    else bgcolor='#35301F'; fgcolor='white'; fi
  else
    bgcolor='#755515'; fgcolor='white'
  fi

  printf "#[bg=$bgcolor,fg=$fgcolor]  RAM %.1f/%.0fG #[default]" $mem_used $mem_total
}

component-gpu() {
  local gpu_util
  if command -v nvidia-smi &> /dev/null; then
    gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | awk '{s+=$1} END {if(NR>0) print s/NR}')
  fi
  if [ -z "$gpu_util" ]; then return 1; fi

  local bgcolor fgcolor
  if command -v bc &>/dev/null; then
    if   (( $(echo "$gpu_util >= 90" | bc -l 2>/dev/null) )); then bgcolor='#40C057'; fgcolor='black'
    elif (( $(echo "$gpu_util >= 75" | bc -l 2>/dev/null) )); then bgcolor='#3EAE51'; fgcolor='black'
    elif (( $(echo "$gpu_util >= 50" | bc -l 2>/dev/null) )); then bgcolor='#398A44'; fgcolor='black'
    elif (( $(echo "$gpu_util >= 25" | bc -l 2>/dev/null) )); then bgcolor='#356537'; fgcolor='white'
    else bgcolor='#30412A'; fgcolor='white'; fi
  else
    bgcolor='#398A44'; fgcolor='black'
  fi

  printf "#[bg=$bgcolor,fg=$fgcolor] GPU %3.0f%% #[default]" "$gpu_util"
}

component-hpu() {
  local hpu_util
  if command -v hl-smi &> /dev/null; then
    hpu_util=$(hl-smi --query-aip=utilization.aip --format=csv,noheader,nounits 2>/dev/null | awk '{s+=$1} END {if(NR>0) print s/NR}')
  fi
  if [ -z "$hpu_util" ]; then return 1; fi

  local bgcolor fgcolor
  if command -v bc &>/dev/null; then
    if   (( $(echo "$hpu_util >= 90" | bc -l 2>/dev/null) )); then bgcolor='#1971c2'; fgcolor='white'
    elif (( $(echo "$hpu_util >= 75" | bc -l 2>/dev/null) )); then bgcolor='#1864ab'; fgcolor='white'
    elif (( $(echo "$hpu_util >= 50" | bc -l 2>/dev/null) )); then bgcolor='#1c5a99'; fgcolor='white'
    elif (( $(echo "$hpu_util >= 25" | bc -l 2>/dev/null) )); then bgcolor='#1e4f87'; fgcolor='white'
    else bgcolor='#1f4575'; fgcolor='#888888'; fi
  else
    bgcolor='#1c5a99'; fgcolor='white'
  fi

  printf "#[bg=$bgcolor,fg=$fgcolor] HPU %3.0f%% #[default]" "$hpu_util"
}

component-npu() {
  local npu_util
  if command -v npustat &> /dev/null; then
    npu_util=$(npustat --no-header 2>/dev/null | awk '{s+=$NF} END {if(NR>0) print s/NR}' | tr -d '%')
  fi
  if [ -z "$npu_util" ]; then return 1; fi

  local bgcolor fgcolor
  if command -v bc &>/dev/null; then
    if   (( $(echo "$npu_util >= 90" | bc -l 2>/dev/null) )); then bgcolor='#9c36b5'; fgcolor='white'
    elif (( $(echo "$npu_util >= 75" | bc -l 2>/dev/null) )); then bgcolor='#862e9c'; fgcolor='white'
    elif (( $(echo "$npu_util >= 50" | bc -l 2>/dev/null) )); then bgcolor='#6c2d82'; fgcolor='white'
    elif (( $(echo "$npu_util >= 25" | bc -l 2>/dev/null) )); then bgcolor='#522c68'; fgcolor='white'
    else bgcolor='#3b2b4e'; fgcolor='#888888'; fi
  else
    bgcolor='#6c2d82'; fgcolor='white'
  fi

  printf "#[bg=$bgcolor,fg=$fgcolor] NPU %3.0f%% #[default]" "$npu_util"
}

if [[ -z "$1" ]]; then
  main
elif declare -f "$1" > /dev/null 2>&1; then
  "$@"
else
  echo "Unknown command: $1"
  exit 1
fi
