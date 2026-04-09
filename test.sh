#!/bin/bash
#
# 青龙面板 WSL1 Ubuntu 20.04 一键部署脚本
# 
# 项目地址: https://github.com/yourusername/qinglong-wsl-deploy
# 描述: 本脚本用于在 WSL1 + Ubuntu 20.04 环境下脱离 Docker 和虚拟化技术部署青龙面板
# 适用环境: Windows WSL1 + Ubuntu 20.04 LTS
# 
# 作者: Assistant
# 版本: 1.0.0
# 日期: 2026-04-08
#

# ==============================================================================
# 颜色定义与输出函数
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 输出函数
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

step() {
    echo -e "\n${CYAN}${BOLD}[STEP $1]${NC} $2"
}

# ==============================================================================
# 全局配置变量
# ==============================================================================

# 国内加速源配置
GITHUB_MIRROR="https://gh.llkk.cc"
NPM_REGISTRY="https://registry.npmmirror.com"
PYPI_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
UBUNTU_MIRROR="https://mirrors.aliyun.com/ubuntu"
NODESOURCE_MIRROR="https://mirrors.aliyun.com/nodejs-release/"

# 青龙面板配置
QL_VERSION="2.17.10"
QL_DIR="$HOME/qinglong"
QL_DATA_DIR="$QL_DIR/data"
QL_PORT="5700"
QL_REPO="https://github.com/whyour/qinglong.git"

# Node.js 版本配置
NODE_VERSION="20.15.1"
NODE_VERSION_CANVAS="11.15.0"

# Python 版本配置
PYTHON_VERSION="3.10"

# 日志文件
LOG_FILE="$HOME/qinglong-install.log"
ERROR_LOG="$HOME/qinglong-error.log"

# ==============================================================================
# 初始化函数
# ==============================================================================

# 初始化日志
init_log() {
    echo "========================================" > "$LOG_FILE"
    echo "青龙面板安装日志 - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# 记录日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 检查WSL版本
check_wsl_version() {
    info "检查 WSL 版本..."
    
    if ! check_command wsl.exe; then
        error "未检测到 WSL 环境，请确保在 Windows WSL 环境中运行此脚本"
        exit 1
    fi
    
    # 检查WSL版本
    local wsl_version
    wsl_version=$(uname -r | grep -i microsoft | wc -l)
    
    if [ "$wsl_version" -eq 0 ]; then
        error "当前不在 WSL 环境中运行"
        exit 1
    fi
    
    # 检查是否为WSL1
    local wsl1_check
    wsl1_check=$(cat /proc/version | grep -c "WSL2")
    
    if [ "$wsl1_check" -gt 0 ]; then
        warning "检测到 WSL2 环境，但脚本为 WSL1 优化"
        read -p "是否继续安装? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        success "检测到 WSL1 环境，符合要求"
    fi
    
    log "WSL版本检查通过"
}

# 检查Ubuntu版本
check_ubuntu_version() {
    info "检查 Ubuntu 版本..."
    
    if [ ! -f /etc/os-release ]; then
        error "无法检测操作系统版本"
        exit 1
    fi
    
    source /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        error "当前系统不是 Ubuntu，检测到: $ID"
        exit 1
    fi
    
    if [ "$VERSION_ID" != "20.04" ]; then
        warning "当前 Ubuntu 版本为 $VERSION_ID，建议使用 20.04 LTS"
        read -p "是否继续安装? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        success "检测到 Ubuntu 20.04 LTS，符合要求"
    fi
    
    log "Ubuntu版本检查通过: $VERSION_ID"
}

# ==============================================================================
# 系统环境准备
# ==============================================================================

# 配置Ubuntu国内镜像源
setup_ubuntu_mirror() {
    step "1" "配置 Ubuntu 国内镜像源"
    
    info "备份原始源列表..."
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d) 2>/dev/null || true
    
    info "配置阿里云镜像源..."
    
    sudo tee /etc/apt/sources.list > /dev/null << 'EOF'
# 阿里云 Ubuntu 20.04 镜像源
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

# 源码镜像（可选，注释状态）
# deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
EOF

    success "Ubuntu 镜像源配置完成"
    log "Ubuntu镜像源已配置为阿里云"
    
    info "更新软件包列表..."
    sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        error "软件包列表更新失败，请检查网络连接"
        exit 1
    fi
    
    success "软件包列表更新完成"
}

# 安装系统基础依赖
install_system_deps() {
    step "2" "安装系统基础依赖"
    
    info "正在安装必要的系统依赖..."
    
    local deps=(
        # 基础工具
        curl wget git vim nano
        # 构建工具
        build-essential gcc g++ make
        # Python 构建依赖
        software-properties-common
        libssl-dev zlib1g-dev libbz2-dev
        libreadline-dev libsqlite3-dev
        libncursesw5-dev xz-utils tk-dev
        libxml2-dev libxmlsec1-dev libffi-dev
        liblzma-dev
        # Node.js 构建依赖
        python3-distutils
        # 其他常用库
        libcurl4-openssl-dev
        # Canvas 依赖
        libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev
        # 其他依赖
        pkg-config
    )
    
    sudo apt-get install -y "${deps[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        error "系统依赖安装失败"
        exit 1
    fi
    
    success "系统基础依赖安装完成"
    log "系统依赖安装完成"
}

# ==============================================================================
# Node.js 环境安装
# ==============================================================================

# 安装 fnm (Fast Node Manager)
install_fnm() {
    step "3" "安装 Node.js 版本管理器 (fnm)"
    
    if check_command fnm; then
        success "fnm 已安装，版本: $(fnm --version)"
        return 0
    fi
    
    info "正在安装 fnm..."
    
    # 使用国内加速源下载 fnm
    local fnm_url="${GITHUB_MIRROR}/https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip"
    
    curl -fsSL "$fnm_url" -o /tmp/fnm-linux.zip 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        # 备用方案：直接下载
        info "主下载源失败，尝试备用方案..."
        curl -fsSL "https://fnm.vercel.app/install" | bash 2>&1 | tee -a "$LOG_FILE"
    else
        unzip -o /tmp/fnm-linux.zip -d /tmp/fnm 2>&1 | tee -a "$LOG_FILE"
        sudo mv /tmp/fnm/fnm /usr/local/bin/
        sudo chmod +x /usr/local/bin/fnm
    fi
    
    # 配置 fnm 环境变量
    info "配置 fnm 环境变量..."
    
    if ! grep -q "fnm" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# fnm (Fast Node Manager) 配置
export FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env)"
fi
EOF
    fi
    
    # 立即生效
    export FNM_PATH="$HOME/.local/share/fnm"
    export PATH="$FNM_PATH:$PATH"
    eval "$(fnm env 2>/dev/null || true)"
    
    if check_command fnm; then
        success "fnm 安装成功，版本: $(fnm --version)"
        log "fnm安装成功"
    else
        error "fnm 安装失败"
        exit 1
    fi
}

# 配置 fnm 国内镜像
setup_fnm_mirror() {
    info "配置 fnm 国内镜像源..."
    
    # 添加到 .bashrc
    if ! grep -q "FNM_NODE_DIST_MIRROR" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << EOF

# fnm 国内镜像源配置
export FNM_NODE_DIST_MIRROR="https://npmmirror.com/mirrors/node/"
EOF
    fi
    
    export FNM_NODE_DIST_MIRROR="https://npmmirror.com/mirrors/node/"
    success "fnm 国内镜像源配置完成"
    log "fnm镜像源配置完成"
}

# 安装 Node.js
install_nodejs() {
    step "4" "安装 Node.js 环境"
    
    # 重新加载 fnm 环境
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env 2>/dev/null || true)"
    
    if ! check_command fnm; then
        error "fnm 未正确安装"
        exit 1
    fi
    
    info "安装 Node.js v${NODE_VERSION}..."
    
    fnm install "$NODE_VERSION" 2>&1 | tee -a "$LOG_FILE"
    fnm default "$NODE_VERSION" 2>&1 | tee -a "$LOG_FILE"
    fnm use "$NODE_VERSION" 2>&1 | tee -a "$LOG_FILE"
    
    # 重新加载环境
    eval "$(fnm env)"
    
    if check_command node; then
        success "Node.js 安装成功"
        info "Node.js 版本: $(node --version)"
        info "npm 版本: $(npm --version)"
        log "Node.js安装成功: $(node --version)"
    else
        error "Node.js 安装失败"
        exit 1
    fi
}

# 配置 npm/pnpm 国内镜像
setup_npm_mirror() {
    step "5" "配置 npm/pnpm 国内镜像源"
    
    info "配置 npm 使用淘宝镜像..."
    npm config set registry "$NPM_REGISTRY" 2>&1 | tee -a "$LOG_FILE"
    
    info "安装 pnpm..."
    npm install -g pnpm 2>&1 | tee -a "$LOG_FILE"
    
    info "配置 pnpm 使用淘宝镜像..."
    pnpm config set registry "$NPM_REGISTRY" 2>&1 | tee -a "$LOG_FILE"
    
    success "npm/pnpm 镜像源配置完成"
    info "npm registry: $(npm config get registry)"
    info "pnpm registry: $(pnpm config get registry)"
    log "npm/pnpm镜像源配置完成"
}

# ==============================================================================
# Python 环境安装
# ==============================================================================

# 安装 Python 3.10
install_python() {
    step "6" "安装 Python 3.10 环境"
    
    # 检查当前 Python 版本
    local current_python
    current_python=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2)
    
    if [ "$current_python" = "3.10" ]; then
        success "Python 3.10 已安装"
        return 0
    fi
    
    info "添加 Python 3.10 PPA 源..."
    # 先安装添加 PPA 所需的依赖
    sudo apt-get install -y software-properties-common 2>&1 | tee -a "$LOG_FILE"
    
    # 添加 deadsnakes PPA
    sudo add-apt-repository -y ppa:deadsnakes/ppa 2>&1 | tee -a "$LOG_FILE"
    
    # 强制更新 apt 缓存
    sudo apt-get clean 2>&1 | tee -a "$LOG_FILE"
    sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
    
    info "安装 Python 3.10..."
    # 使用 --fix-missing 参数处理可能的包缺失问题
    sudo apt-get install -y --fix-missing python3.10 python3.10-dev python3.10-venv 2>&1 | tee -a "$LOG_FILE"
    
    # 检查安装是否成功
    if ! command -v python3.10 &>/dev/null; then
        warning "Python 3.10 安装可能失败，尝试备用方案..."
        # 备用：从源码编译或使用 pyenv
        info "使用系统默认 Python3..."
    fi
    
    info "安装 pip..."
    # 使用 get-pip.py 安装 pip
    curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py 2>&1 | tee -a "$LOG_FILE"
    
    if command -v python3.10 &>/dev/null; then
        sudo python3.10 /tmp/get-pip.py 2>&1 | tee -a "$LOG_FILE"
        # 设置 Python 3.10 为默认版本
        sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 2>&1 | tee -a "$LOG_FILE"
        sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 2>&1 | tee -a "$LOG_FILE"
    else
        # 使用系统默认 Python3
        sudo python3 /tmp/get-pip.py 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 配置 pip 国内镜像
    info "配置 pip 国内镜像..."
    mkdir -p "$HOME/.pip"
    cat > "$HOME/.pip/pip.conf" << EOF
[global]
index-url = $PYPI_MIRROR
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
    
    # 升级 pip
    python3 -m pip install --upgrade pip 2>&1 | tee -a "$LOG_FILE" || true
    
    success "Python 环境安装完成"
    info "Python 版本: $(python3 --version)"
    info "pip 版本: $(pip --version 2>/dev/null || echo 'pip 未安装')"
    log "Python安装完成: $(python3 --version)"
}

# ==============================================================================
# 青龙面板安装
# ==============================================================================

# 配置 Git 使用 HTTPS 替代 SSH
setup_git_config() {
    info "配置 Git 使用 HTTPS 协议..."
    
    # 配置 Git 使用 https 替代 ssh
    git config --global url."https://github.com/".insteadOf "git@github.com:"
    git config --global url."https://gh.llkk.cc/https://github.com/".insteadOf "https://github.com/"
    
    # 配置 Git 使用镜像加速
    git config --global url."https://gh.llkk.cc/https://github.com/".insteadOf "git://github.com/"
    
    success "Git 配置完成"
}

# 克隆青龙面板源码
clone_qinglong() {
    step "7" "下载青龙面板源码"
    
    # 先配置 git
    setup_git_config
    
    if [ -d "$QL_DIR" ]; then
        warning "检测到已存在的青龙目录: $QL_DIR"
        read -p "是否删除并重新安装? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            info "备份旧数据..."
            mv "$QL_DIR" "$QL_DIR.backup.$(date +%Y%m%d%H%M%S)"
        else
            info "使用现有目录继续安装..."
            return 0
        fi
    fi
    
    info "克隆青龙面板源码..."
    info "使用镜像源: ${GITHUB_MIRROR}"
    
    local repo_url="${GITHUB_MIRROR}/${QL_REPO}"
    
    git clone -b "v${QL_VERSION}" --depth 1 "$repo_url" "$QL_DIR" 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        # 尝试直接克隆
        info "镜像克隆失败，尝试直接克隆..."
        git clone -b "v${QL_VERSION}" --depth 1 "$QL_REPO" "$QL_DIR" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    if [ ! -d "$QL_DIR" ]; then
        error "青龙面板源码克隆失败"
        exit 1
    fi
    
    success "青龙面板源码下载完成"
    log "青龙面板源码克隆完成"
}

# 安装青龙面板依赖
install_qinglong_deps() {
    step "8" "安装青龙面板依赖"
    
    cd "$QL_DIR" || exit 1
    
    info "安装 Node.js 依赖..."
    info "这可能需要较长时间，请耐心等待..."
    
    # 删除可能损坏的 lock 文件
    rm -f pnpm-lock.yaml package-lock.json 2>/dev/null || true
    
    # 配置 npm/pnpm 使用 GitHub 镜像
    npm config set registry "$NPM_REGISTRY"
    pnpm config set registry "$NPM_REGISTRY" 2>/dev/null || true
    
    # 使用 pnpm 安装依赖
    local install_success=false
    
    # 尝试使用 pnpm 安装
    if pnpm install --no-frozen-lockfile 2>&1 | tee -a "$LOG_FILE"; then
        install_success=true
    else
        warning "pnpm 安装失败，尝试使用 npm..."
        rm -rf node_modules 2>/dev/null || true
        
        # 使用 npm 安装
        if npm install 2>&1 | tee -a "$LOG_FILE"; then
            install_success=true
        fi
    fi
    
    if [ "$install_success" != true ]; then
        error "Node.js 依赖安装失败"
        error "请检查网络连接或手动执行: cd $QL_DIR && npm install"
        
        # 不退出，继续尝试后续步骤
        warning "继续安装，但青龙面板可能无法正常运行"
    else
        success "Node.js 依赖安装完成"
        log "Node.js依赖安装完成"
    fi
    
    # 检查 node_modules 是否存在
    if [ ! -d "node_modules" ]; then
        error "node_modules 目录不存在，依赖安装可能失败"
        return 1
    fi
    
    # 构建前端
    info "构建前端项目..."
    if ! pnpm build:front 2>&1 | tee -a "$LOG_FILE"; then
        warning "pnpm 构建前端失败，尝试 npm..."
        npm run build:front 2>&1 | tee -a "$LOG_FILE" || warning "前端构建失败"
    fi
    
    # 构建后端
    info "构建后端项目..."
    if ! pnpm build:back 2>&1 | tee -a "$LOG_FILE"; then
        warning "pnpm 构建后端失败，尝试 npm..."
        npm run build:back 2>&1 | tee -a "$LOG_FILE" || warning "后端构建失败"
    fi
    
    # 检查构建结果
    if [ -d "back" ] && [ -f "back/app.js" ] || [ -f "back/dist/app.js" ]; then
        success "青龙面板构建完成"
        log "青龙面板构建完成"
    else
        warning "构建可能不完整，但将继续安装"
        info "可以尝试手动构建: cd $QL_DIR && npm run build"
    fi
}

# 安装 Python 依赖
install_python_deps() {
    step "9" "安装 Python 依赖"
    
    info "安装青龙面板 Python 依赖..."
    
    # 注意：canvas 是 Node.js 包，不是 Python 包
    local python_deps=(
        requests
        ping3
        jieba
        aiohttp
        PyExecJS
        pycryptodome
        redis
        httpx
        bs4
        Pillow
        lxml
    )
    
    local success_count=0
    local fail_count=0
    
    for dep in "${python_deps[@]}"; do
        info "安装 $dep..."
        if pip install "$dep" -i "$PYPI_MIRROR" 2>&1 | tee -a "$LOG_FILE"; then
            ((success_count++))
        else
            warning "$dep 安装失败，继续安装其他依赖..."
            ((fail_count++))
        fi
    done
    
    success "Python 依赖安装完成: 成功 $success_count 个, 失败 $fail_count 个"
    log "Python依赖安装完成"
}

# 安装 PM2 进程管理器
install_pm2() {
    step "10" "安装 PM2 进程管理器"
    
    if check_command pm2; then
        success "PM2 已安装，版本: $(pm2 --version)"
        return 0
    fi
    
    info "安装 PM2..."
    npm install -g pm2 2>&1 | tee -a "$LOG_FILE"
    
    if check_command pm2; then
        success "PM2 安装成功"
        log "PM2安装成功"
    else
        error "PM2 安装失败"
        exit 1
    fi
}

# 配置青龙面板
configure_qinglong() {
    step "11" "配置青龙面板"
    
    info "创建数据目录..."
    mkdir -p "$QL_DATA_DIR"/{config,log,db,scripts,repo,raw}
    
    info "创建基础配置文件..."
    
    # 创建 config.sh 配置文件
    cat > "$QL_DATA_DIR/config/config.sh" << EOF
# 青龙面板配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 面板端口
export QL_PORT="${QL_PORT}"

# 数据目录
export QL_DATA_DIR="${QL_DATA_DIR}"

# 日志级别 (debug/info/warn/error)
export QL_LOG_LEVEL="info"

# 自动更新
export QL_AUTO_UPDATE="true"

# 通知配置（可选）
# export PUSH_KEY=""
# export BARK_PUSH=""
# export BARK_SOUND=""
# export DD_BOT_TOKEN=""
# export DD_BOT_SECRET=""
# export FSKEY=""
# export GOBOT_URL=""
# export GOBOT_QQ=""
# export GOBOT_TOKEN=""
EOF

    success "青龙面板基础配置完成"
    log "青龙面板配置完成"
}

# 创建启动脚本
create_start_script() {
    step "12" "创建启动脚本"
    
    info "创建青龙面板启动脚本..."
    
    # 查找 PM2 路径
    local pm2_path
    pm2_path=$(which pm2 2>/dev/null || echo "$(npm config get prefix)/bin/pm2")
    
    cat > "$QL_DIR/start.sh" << EOF
#!/bin/bash
# 青龙面板启动脚本

QL_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$QL_DIR" || exit 1

# 加载环境
export PATH="\$HOME/.local/share/fnm:\$PATH"
eval "\$(fnm env 2>/dev/null || true)"
fnm use default 2>/dev/null || true

# 查找 PM2
PM2_CMD="${pm2_path}"
if ! command -v pm2 &>/dev/null; then
    PM2_CMD="\$(npm config get prefix)/bin/pm2"
fi

# 检查入口文件
APP_ENTRY="./back/dist/app.js"
if [ ! -f "\$APP_ENTRY" ]; then
    APP_ENTRY="./back/app.js"
fi

if [ ! -f "\$APP_ENTRY" ]; then
    echo "[错误] 找不到入口文件: \$APP_ENTRY"
    echo "请确保已正确构建项目: cd \$QL_DIR && npm run build"
    exit 1
fi

# 启动面板
echo "正在启动青龙面板..."
echo "数据目录: \$QL_DIR/data"
echo "入口文件: \$APP_ENTRY"
echo "访问地址: http://localhost:5700"
echo ""

# 使用 PM2 启动
\$PM2_CMD delete qinglong 2>/dev/null || true
\$PM2_CMD start "\$APP_ENTRY" --name qinglong --cwd "\$QL_DIR" --log-date-format "YYYY-MM-DD HH:mm:ss"

echo ""
echo "青龙面板启动完成！"
echo "查看日志: \$PM2_CMD logs qinglong"
echo "停止服务: \$PM2_CMD stop qinglong"
echo "重启服务: \$PM2_CMD restart qinglong"
EOF

    chmod +x "$QL_DIR/start.sh"
    
    # 创建停止脚本
    cat > "$QL_DIR/stop.sh" << EOF
#!/bin/bash
# 青龙面板停止脚本

# 查找 PM2
PM2_CMD="${pm2_path}"
if ! command -v pm2 &>/dev/null; then
    PM2_CMD="\$(npm config get prefix)/bin/pm2"
fi

echo "正在停止青龙面板..."
\$PM2_CMD stop qinglong 2>/dev/null || true
\$PM2_CMD delete qinglong 2>/dev/null || true
echo "青龙面板已停止"
EOF

    chmod +x "$QL_DIR/stop.sh"
    
    # 创建状态检查脚本
    cat > "$QL_DIR/status.sh" << EOF
#!/bin/bash
# 青龙面板状态检查脚本

# 查找 PM2
PM2_CMD="${pm2_path}"
if ! command -v pm2 &>/dev/null; then
    PM2_CMD="\$(npm config get prefix)/bin/pm2"
fi

echo "===== 青龙面板运行状态 ====="
\$PM2_CMD status qinglong

echo ""
echo "===== 端口监听状态 ====="
netstat -tlnp 2>/dev/null | grep 5700 || ss -tlnp | grep 5700 || echo "端口 5700 未监听"

echo ""
echo "===== 最近日志 ====="
\$PM2_CMD logs qinglong --lines 20 --timestamp
EOF

    chmod +x "$QL_DIR/status.sh"
    
    success "启动脚本创建完成"
    log "启动脚本创建完成"
}

# ==============================================================================
# 主安装流程
# ==============================================================================

main() {
    clear
    echo "========================================"
    echo "  青龙面板 WSL1 Ubuntu 20.04 部署脚本"
    echo "========================================"
    echo ""
    echo "环境要求:"
    echo "  - Windows WSL1"
    echo "  - Ubuntu 20.04 LTS"
    echo "  - 脱离 Docker 部署"
    echo ""
    echo "安装路径: $QL_DIR"
    echo "数据目录: $QL_DATA_DIR"
    echo "访问端口: $QL_PORT"
    echo ""
    echo "========================================"
    echo ""
    
    read -p "是否开始安装? [Y/n]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]?$ ]]; then
        info "安装已取消"
        exit 0
    fi
    
    # 初始化日志
    init_log
    
    # 检查环境
    check_wsl_version
    check_ubuntu_version
    
    # 安装流程
    setup_ubuntu_mirror
    install_system_deps
    install_fnm
    setup_fnm_mirror
    install_nodejs
    setup_npm_mirror
    install_python
    install_pm2
    clone_qinglong
    install_qinglong_deps
    install_python_deps
    configure_qinglong
    create_start_script
    
    # 完成
    echo ""
    echo "========================================"
    success "青龙面板安装完成！"
    echo "========================================"
    echo ""
    echo "启动命令:"
    echo "  cd $QL_DIR && ./start.sh"
    echo ""
    echo "停止命令:"
    echo "  cd $QL_DIR && ./stop.sh"
    echo ""
    echo "状态检查:"
    echo "  cd $QL_DIR && ./status.sh"
    echo ""
    echo "访问地址:"
    echo "  http://localhost:$QL_PORT"
    echo ""
    echo "日志文件:"
    echo "  $LOG_FILE"
    echo ""
    echo "========================================"
    echo ""
    
    log "安装完成"
    
    # 询问是否立即启动
    read -p "是否立即启动青龙面板? [Y/n]: " start_now
    if [[ "$start_now" =~ ^[Yy]?$ ]]; then
        cd "$QL_DIR" && ./start.sh
    fi
}

# 错误处理
trap 'error "安装过程中出现错误，请查看日志: $LOG_FILE"' ERR

# 运行主函数
main "$@"
