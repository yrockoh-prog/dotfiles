# Dotfiles — 개발 환경 설정

Linux / macOS에서 사용하는 쉘, 터미널 멀티플렉서, 에디터, AI 코딩 도구 설정을 한 번에 적용하는 dotfiles입니다.

---

## 지원 기능 요약

| 영역 | 도구 | 주요 기능 |
|------|------|-----------|
| **쉘** | Zsh + Oh My Zsh | 테마, 자동완성, 문법 하이라이트, Git/Docker 플러그인, 커스텀 alias |
| **Git** | gitconfig | 전역 user.name / user.email / credential.helper store |
| **터미널** | Tmux | 마우스 지원, 직관적 분할, 중첩 Tmux 제어(F12), Tokyo Night 스타일 상태바 |
| **에디터** | Neovim | Tokyo Night 테마, Telescope 파일/검색, Tree-sitter, Lualine 상태바 |
| **AI 코딩** | Claude Code | 전역 설치, oh-my-claudecode·LSP·superpowers 플러그인, CLAUDE.md, `cauto`/`cu`(업데이트) |
| **설치** | install.sh | OS 감지, 패키지 설치, 심볼릭 링크, Oh My Zsh·플러그인 자동 설정 |

---

## 상세 기능

### 1. Zsh (`zsh/`)

- **Linux 터미널 한글**  
  - `.zshenv`: 모든 zsh 세션에서 `LANG`/`LC_ALL`/`LC_CTYPE=en_US.UTF-8` 설정 (한글 깨짐 방지).  
  - Linux에서만 `GTK_IM_MODULE`/`QT_IM_MODULE`/`XMODIFIERS`를 ibus 또는 fcitx로 지정해 한글 입력(IME) 가능.  
  - **한글이 여전히 깨지면**: 시스템에 로케일이 없을 수 있음. `locale -a`로 `en_US.UTF-8` 확인 후, 없으면 `sudo locale-gen en_US.UTF-8`(또는 `sudo dpkg-reconfigure locales`) 실행. 터미널 앱 프로필에서 **한글 지원 폰트**(예: Noto Sans Mono CJK KR, D2Coding) 사용 권장.
- **Oh My Zsh**  
  - 테마: `robbyrussell`  
  - 기본 에디터: `nvim`
- **플러그인**  
  - `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `docker`
- **Alias (`aliases.zsh`)**  
  - **파일/에디터**: `ll`, `vi`/`vim` → nvim, `..`, `z`  
  - **GPU**: `gpu` — Linux(gpustat 또는 nvidia-smi), Mac(powermetrics)  
  - **NPU**: `npu` — npustat 모니터링 (npustat 설치 시)  
  - **Docker**: `d`, `dps`, `dexec`  
  - **Claude Code**: `cauto`(권한 무시 모드), `cu` / `claude_update`(로컬에서 단축키로 전역 업데이트)

### 2. Tmux (`tmux/`)

#### Tmux 단축키가 동작하는 방식

Tmux에서는 **Prefix(접두키)** 를 먼저 누른 뒤, 그 다음에 한 글자 키를 눌러서 동작합니다.  
이 설정에서는 **Prefix = `Ctrl+a`** 입니다. (보통 tmux 기본값은 `Ctrl+b`인데, 이 dotfiles에서는 `Ctrl+a`로 바꿨습니다.)

- **즉, 모든 tmux 단축키 = `Ctrl+a` 누른 다음 → 키 하나 입력**

---

#### 이 설정에서 쓰는 단축키

| 입력 | 의미 | 하는 일 |
|------|------|----------|
| **Ctrl+a** 그다음 **&#124;** 또는 **v** | 세로 분할 | 화면을 **왼쪽/오른쪽**으로 나눔. 새 팬도 현재 디렉터리 유지. |
| **Ctrl+a** 그다음 **-** 또는 **s** | 가로 분할 | 화면을 **위/아래**로 나눔. 새 팬도 현재 디렉터리 유지. |
| **Ctrl+a** 그다음 **h/j/k/l** | 팬 이동 | vi 스타일 왼/아래/위/오른쪽. |
| **Ctrl+a** 그다음 **방향키** | 팬 이동 | 나눠진 구역(팬) 사이로 포커스 이동. |
| **Ctrl+a** 그다음 **&gt;/&lt;/+/_** | 팬 크기 | 오른/왼/아래/위로 조절. |
| **Ctrl+a** 그다음 **c** | 새 윈도우 | 새 탭처럼 쓰는 “윈도우” 생성. |
| **Ctrl+a** 그다음 **0~9** | 윈도우 이동 | 해당 번호의 윈도우(탭)로 이동. |
| **Ctrl+a** 그다음 **r** | 설정 리로드 | `~/.tmux.conf` 다시 읽기 (단축키·상태바 등 적용). |
| **Ctrl+a** 그다음 **Ctrl+a** | prefix 전달 | “Ctrl+a를 tmux가 아닌 쉘에 보내기” (예: bash에서 줄 맨 앞으로 가기). |

- **마우스**: 끌어서 팬 크기 조절, 클릭해서 포커스 이동 가능 (설정에서 켜 둠).
- **윈도우 번호**: 0이 아니라 **1부터** 시작하고, 윈도우를 닫으면 번호가 자동으로 다시 매겨짐.

---

#### F12 — 중첩 Tmux (로컬 ↔ 원격/도커)

로컬 PC에서 tmux를 켜고, 그 안에서 SSH로 서버에 들어가서 또 tmux를 켜면 **tmux가 두 겹**이 됩니다.  
이때 **Ctrl+a**를 누르면 “로컬 tmux”가 먼저 받아버려서, **안쪽(서버/도커) tmux**에는 키가 안 넘어갑니다.

**F12**는 이걸 해결하는 키입니다.

1. **F12 한 번 누름**  
   → 로컬 tmux가 “키 입력 받지 않음” 상태로 바뀜.  
   → 이후 **Ctrl+a** 등이 **안쪽 tmux(원격/도커)** 로 그대로 전달됨.  
   → 상태바가 **회색**으로 보이면 “지금 키가 안쪽으로 넘어가는 구간”이라고 보면 됨.

2. **F12 한 번 더 누름**  
   → 로컬 tmux가 다시 키를 받기 시작.  
   → **Ctrl+a**는 다시 로컬 tmux용.

정리하면:

- **로컬 tmux만 조작하고 싶을 때** → F12를 **해제**한 상태 (상태바가 보통 색).
- **원격/도커 tmux를 조작하고 싶을 때** → **F12** 눌러서 잠금 → 그 다음부터 **Ctrl+a** 등은 안쪽 tmux로 전달.

---

#### 상태바 (동적)

- **statusbar.tmux** (`~/.tmux/statusbar.tmux`로 링크): 1초 간격으로 갱신되는 동적 상태바.
- **표시 내용**: 세션명, PREFIX 표시, **CPU 사용률**, **RAM 사용량**, **GPU**(nvidia-smi), **HPU**(hl-smi), **NPU**(npustat), 날짜/시각. (해당 명령이 있으면만 표시)
- 복사 모드 등은 tmux 기본 표시.

---

- **기본**: Prefix `Ctrl+a`, 마우스 on, vi 모드(`mode-keys vi`), 윈도우/팬 인덱스 1부터, 자동 번호 재정렬.
- **의존성**: 동적 상태바 색 구간은 `bc`가 있으면 사용 (없어도 동작).

### 3. Git (`git/`)

- **전역 설정** (`~/.gitconfig`로 링크됨)
  - `user.name` = Youngrock
  - `user.email` = youngrock@mobilint.com
  - `credential.helper` = store (HTTPS 비밀번호 저장)
- 이름/이메일을 바꾸려면 `git/gitconfig` 파일을 수정한 뒤, 이미 링크된 환경에서는 그대로 반영됨.

### 4. Neovim (`nvim/`)

- **테마**: Tokyo Night (`tokyonight-night`)
- **기본 옵션**: 줄 번호/상대 번호, 마우스, 클립보드 연동, 대소문자 구분 검색
- **리더 키**: `Space`
- **플러그인**  
  - **Telescope**: `<Space>f` 파일 찾기, `<Space>g` live grep, `<Space>e` 파일 브라우저  
  - **Tree-sitter**: C, C++, Python, Lua, Bash, Dockerfile, JSON 하이라이트  
  - **Lualine**: 상태바
- **플러그인 매니저**: Lazy.nvim (자동 설치)

### 5. Claude Code (`caludecode/`)

- **CLAUDE.md**  
  - 역할: NPU/AI 개발 전문가, Python/C++/Docker  
  - 코드 스타일: PEP 8, Google C++ Style, 멀티스테이지 Docker  
  - 목표: NPU/GPU 병렬화, 지연 시간 최소화  
  - 제약: NPU 사용 전 확인, 하드웨어 의존 코드는 try-except
- **설치 스크립트**  
  - `@anthropic-ai/claude-code` 전역 설치  
  - `~/CLAUDE.md` → dotfiles의 `CLAUDE.md` 심볼릭 링크
- **플러그인 (install.sh)**  
  - [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode): 멀티 에이전트 오케스트레이션, `omc update`로 설정 동기화  
  - 공식 LSP: TypeScript, Pyright (Python)  
  - [superpowers](https://github.com/obra/superpowers-marketplace): Superpowers 플러그인  
  - 참조: [seongwoongcho/dotfiles](https://github.com/seongwoongcho/dotfiles)
- **업데이트 단축키**  
  - `cu` 또는 `claude_update`: 로컬에서 `npm install -g @anthropic-ai/claude-code` 실행

### 6. 설치 스크립트 (`install.sh`)

- **OS 감지**: Linux / Mac 자동 판별
- **패키지 설치**  
  - Mac: Homebrew → zsh, tmux, neovim, git, curl, wget, ripgrep, fd, node  
  - Linux: apt + NodeSource LTS → 동일 도구 + fd-find, nodejs, python3-pip  
  - pip: gpustat (GPU 모니터링, Linux에서 `gpu` alias가 사용)
- **Claude Code**: 전역 npm 설치 + `~/CLAUDE.md` 링크 + oh-my-claudecode, 공식 LSP, superpowers 플러그인 설치
- **Oh My Zsh**: 없으면 비대화형 설치
- **Zsh 플러그인**: zsh-autosuggestions, zsh-syntax-highlighting 클론
- **심볼릭 링크**  
  - `~/.zshenv` ← `zsh/.zshenv` (로케일/IME)  
  - `~/.zshrc` ← `zsh/.zshrc`  
  - `~/.tmux.conf` ← `tmux/.tmux.conf`  
  - `~/.tmux/statusbar.tmux` ← `tmux/statusbar.tmux`  
  - `~/.gitconfig` ← `git/gitconfig`  
  - `~/.config/nvim` ← `nvim`
- **Tmux**: TPM(Tmux Plugin Manager) 설치 (`~/.tmux/plugins/tpm`) 및 `install_plugins` 실행 — 나중에 .tmux.conf에 플러그인 추가 시 사용.
- **기존 설정**: 백업 후 링크 (백업 디렉터리: `~/dotfiles_backup_YYYYMMDD_HHMMSS`)
- **기본 쉘**: zsh로 변경 시도 (`chsh`). 실패 시 `~/.bashrc`와 `~/.bash_profile` 둘 다에 fallback 추가 — **로그인 셸**(Mac 터미널, SSH)은 `.bash_profile`만 읽으므로 둘 다 넣어야 새 터미널·tmux에서 자동으로 zsh 실행됨.
- **sudo로 실행 시**: 실제 사용자 `HOME` 사용 + 설치 끝에 생성된 디렉터리/링크 소유자를 해당 사용자로 복구 (팀 dotfiles 참고).

---

## 디렉터리 구조

```
dotfiles/
├── README.md           # 이 문서
├── install.sh          # 일괄 설치 스크립트
├── zsh/
│   ├── .zshenv         # 로케일 UTF-8 + Linux IME (한글) — 모든 zsh에서 먼저 로드
│   ├── .zshrc          # Oh My Zsh + 플러그인 + EDITOR
│   └── aliases.zsh     # OS별 alias (GPU/NPU/Docker/Claude)
├── tmux/
│   ├── .tmux.conf      # Prefix, 분할, hjkl/리사이즈, F12 중첩, 동적 상태바 로드
│   └── statusbar.tmux  # 동적 상태바 (CPU, RAM, GPU, HPU, NPU) — ~/.tmux/ 로 링크
├── git/
│   └── gitconfig       # user.name, user.email, credential.helper store
├── nvim/
│   └── init.lua        # 옵션, Lazy.nvim, 테마·Telescope·Tree-sitter·Lualine
└── caludecode/
    └── CLAUDE.md       # Claude Code용 프로젝트/역할 가이드
```

---

## Local / Remote / Docker에서 사용하기

이 dotfiles는 **로컬 PC**, **원격 서버**, **원격 서버 위 Docker 컨테이너** 세 곳에서 같은 설정을 쓰도록 구성해 두었습니다.

| 환경 | 가능 여부 | 비고 |
|------|-----------|------|
| **Local** (Mac/Linux) | ✅ | `./install.sh` 그대로 실행. Claude, Oh My Zsh, 전부 설치. |
| **Remote server** (Linux) | ✅ | 서버에 클론 후 동일하게 `./install.sh`. GPU 서버면 gpustat/nvidia-smi 활용. |
| **Docker on remote** | ✅ | local/remote와 동일하게 Claude 포함 설치. zsh, tmux, nvim, Claude 모두 적용. |

- **Tmux 중첩**: 로컬 → SSH(원격) → `docker exec`(컨테이너) 구조에서도 **F12**로 안쪽 Tmux에 키를 넘길 수 있음 (같은 `.tmux.conf` 사용 시 동일 동작).
- **Claude를 설치하지 않을 때만**: `DOTFILES_SKIP_CLAUDE=1 ./install.sh` 로 실행하면 Claude 관련 단계만 생략됨.

---

## 설치 방법 (단계별: Local → Remote → Docker)

아래 순서대로 하면 **로컬 → 원격 서버 → 원격 서버 위 Docker 컨테이너**까지 동일한 작업환경을 맞출 수 있습니다.

---

### 1단계: Local (내 PC)

1. **저장소 클론**  
   원하는 경로에 dotfiles를 받습니다.

   ```bash
   git clone <저장소 URL> ~/dotfiles
   cd ~/dotfiles
   ```

2. **설치 스크립트 실행**  
   (Mac이면 Homebrew, Linux면 apt 등이 자동으로 사용됩니다.)

   ```bash
   ./install.sh
   ```

3. **쉘 적용**  
   터미널을 다시 열거나:

   ```bash
   exec zsh
   ```

4. **확인**  
   `zsh`, `tmux`, `nvim`, `claude` 등이 설치·연결되었는지 확인합니다.

---

### 2단계: Remote server (원격 서버)

1. **로컬에서 SSH로 접속**

   ```bash
   ssh user@remote-server
   ```

2. **서버에 dotfiles 클론**  
   (서버에 git이 있어야 합니다. 없으면 `apt install git` 후 진행.)

   ```bash
   git clone <저장소 URL> ~/dotfiles
   cd ~/dotfiles
   ```

3. **설치 스크립트 실행**  
   (sudo 비밀번호를 물을 수 있습니다.)

   ```bash
   ./install.sh
   ```

4. **쉘 적용**

   ```bash
   exec zsh
   ```

5. **확인**  
   GPU 서버라면 `gpu`(gpustat/nvidia-smi) alias도 사용할 수 있습니다.

---

### 3단계: Docker container on remote server (원격 서버 위 컨테이너)

원격 서버에 이미 Docker가 돌고 있다고 가정합니다. **컨테이너 안에서** dotfiles를 쓰는 방법은 두 가지입니다.

#### 방법 A: 이미 실행 중인 컨테이너에 들어가서 설치

1. **로컬에서 원격 서버 접속 후, 컨테이너 접속**

   ```bash
   ssh user@remote-server
   docker exec -it <컨테이너 이름 또는 ID> bash
   ```

2. **컨테이너 안에 git이 있으면** 클론 후 설치:

   ```bash
   git clone <저장소 URL> ~/dotfiles
   cd ~/dotfiles
   ./install.sh
   exec zsh
   ```

3. **컨테이너에 git이 없으면**  
   - 호스트(원격 서버)의 `~/dotfiles`를 컨테이너에 마운트해서 쓰거나,  
   - 먼저 `apt update && apt install -y git curl` 로 의존성을 설치한 뒤 위 2번을 반복합니다.

#### 방법 B: 컨테이너가 이미 있는 경우

이미지 빌드는 하지 않고, **이미 떠 있는 컨테이너**에 들어가서 방법 A처럼 클론 후 `./install.sh`만 하면 됩니다. 컨테이너가 **root**로 떠 있으면 `claude`/`cauto` 권한 무시는 아래 참고의 **dev 우회**로 사용할 수 있습니다.

---

### 요약 한 줄 (이미 환경이 준비된 경우)

| 환경 | 할 일 |
|------|--------|
| Local | `git clone ... ~/dotfiles && cd ~/dotfiles && ./install.sh && exec zsh` |
| Remote | SSH 접속 후 위와 동일하게 클론 → `./install.sh` → `exec zsh` |
| Docker | 컨테이너 안에서 클론 → `./install.sh` → `exec zsh` |

- **Claude만 빼고 설치**: 어느 환경이든 `DOTFILES_SKIP_CLAUDE=1 ./install.sh`

---

## 요구 사항

- **Linux**: apt, sudo (또는 root)
- **Mac**: Xcode Command Line Tools 또는 Homebrew
- **공통**: git, curl  
- **NPU alias (`npu`)**: [npustat](https://github.com/.../npustat) 별도 설치 시 사용 가능

---

## 참고

- Neovim 첫 실행 시 Lazy.nvim이 플러그인을 자동 설치합니다.
- **Tmux 설정이 안 먹을 때**: (1) tmux는 서버가 뜰 때만 `~/.tmux.conf`를 읽습니다. 이미 떠 있으면 **Ctrl+a** 다음 **r** 로 리로드하거나 tmux 완전 종료 후 재실행. (2) 단축키가 안 먹히면 설정 문법 오류일 수 있음 — `tmux -f ~/.tmux.conf new` 로 실행해 보면 에러 메시지가 나옵니다. (3) **링크 깨짐**: `ls -la ~/.tmux.conf` 로 심볼릭 링크 확인. 빨간색/깨진 링크면 dotfiles 디렉터리에서 `./install.sh` 다시 실행하면 됩니다. (설치 스크립트는 dotfiles가 홈 아래 있을 때 상대 경로로 링크해 둠.)
- Tmux 중첩 사용 시: 로컬에서 **F12** → 원격/도커 Tmux 조작 → 다시 **F12**로 로컬로 복귀합니다.
- **Claude Code 권한 무시**: `claude`/`cauto`는 `--dangerously-skip-permissions`로 실행합니다. **root**(예: Docker에서 root로 들어가는 경우)에서는 보안상 이 옵션을 쓸 수 없어, 컨테이너 안에서 root로 `install.sh`를 실행하면 **dev** 사용자가 생성되고, root가 `claude`/`cauto`를 치면 **dev**로 위임 실행되어 권한 무시 모드가 동작합니다. 사용자 이름은 `CONTAINER_CLAUDE_USER=이름`으로 변경 가능합니다.
