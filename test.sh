#!/bin/bash
# ==============================================================================
# 青龙面板 WSL1 Ubuntu 20.04 一键部署脚本 (Node.js 20 兼容版)
# 版本: 2.0.0
# 适用环境: WSL1 (Windows Subsystem for Linux 1) + Ubuntu 20.04 LTS
# 部署方式: 原生 NPM 安装 (非Docker方案)
# 关键修复: Node.js 20+ 兼容性、node-pre-gyp 预安装、环境变量配置
# ==============================================================================

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

# ==============================================================================
# 配置区 - 用户可自定义变量
# ==============================================================================

# 青龙面板安装目录
QL_DIR="${QL_DIR:-$HOME/qinglong}"
QL_DATA_DIR="${QL_DATA_DIR:-$QL_DIR/data}"

# 服务端口
QL_PORT="${QL_PORT:-5700}"

# 国内镜像源配置
APT_MIRROR="https://mirrors.aliyun.com/ubuntu"
NPM_REGISTRY="https://registry.npmmirror.com"
PIP_INDEX="https://pypi.tuna.tsinghua.edu.cn"

# Node.js 版本 (必须使用 20.18.1+ 以满足 undici@7 要求)
NODE_VERSION="20"

# Python 版本 (Ubuntu 20.04 默认 Python 3.8)
PYTHON_VERSION="3.8"

# 日志文件
LOG_FILE="/tmp/qinglong_install_$(date +%Y%m%d_%H%M%S).log"

# ==============================================================================
# 颜色定义
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# 日志函数
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# ==============================================================================
# 系统检测函数
# ==============================================================================

check_wsl1() {
    log_info "检测 WSL 环境..."
    
    if ! grep -q "microsoft" /proc/version 2>/dev/null && ! grep -q "Microsoft" /proc/version 2>/dev/null; then
        log_warn "未检测到 WSL 环境，但脚本将继续执行"
    else
        log_success "检测到 WSL 环境"
        if grep -q "WSL2" /proc/version 2>/dev/null; then
            log_warn "检测到 WSL2，本脚本为 WSL1 优化，但通常兼容 WSL2"
        else
            log_success "确认 WSL1 环境"
        fi
    fi
    
    # 检测 Ubuntu 版本
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "操作系统: $NAME $VERSION_ID"
        if [[ "$VERSION_ID" != "20.04" ]]; then
            log_warn "当前系统版本为 $VERSION_ID，脚本为 20.04 优化，可能兼容其他版本"
        fi
    fi
}

check_systemd() {
    log_info "检测系统服务管理器..."
    
    # WSL1 不支持 systemd，检测是否可用
    if command -v systemctl &> /dev/null && systemctl --version &> /dev/null; then
        log_warn "检测到 systemd 可用，但 WSL1 环境建议使用直接进程管理"
        USE_SYSTEMD=true
    else
        log_info "未检测到 systemd (符合 WSL1 特征)，将使用进程管理方案"
        USE_SYSTEMD=false
    fi
}

# ==============================================================================
# 步骤 1: 系统初始化与镜像源配置
# ==============================================================================

step1_system_init() {
    log_info "=========================================="
    log_info "步骤 1: 系统初始化与镜像源配置"
    log_info "=========================================="
    
    # 备份原配置
    if [[ -f /etc/apt/sources.list && ! -f /etc/apt/sources.list.bak ]]; then
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
        log_info "已备份原 APT 源配置"
    fi
    
    # 配置阿里云镜像源 (针对 Ubuntu 20.04 Focal)
    log_info "配置阿里云 APT 镜像源..."
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb ${APT_MIRROR} focal main restricted universe multiverse
deb ${APT_MIRROR} focal-updates main restricted universe multiverse
deb ${APT_MIRROR} focal-backports main restricted universe multiverse
deb ${APT_MIRROR} focal-security main restricted universe multiverse
EOF
    
    # 更新包列表
    log_info "更新 APT 包列表..."
    sudo apt-get update -y | tee -a "$LOG_FILE"
    
    # 安装基础工具 (包含编译工具以支持 node-gyp)
    log_info "安装基础系统工具及编译依赖..."
    sudo apt-get install -y \
        curl \
        wget \
        git \
        vim \
        nano \
        tzdata \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        build-essential \
        libssl-dev \
        libffi-dev \
        python3-dev \
        python3-distutils \
        2>&1 | tee -a "$LOG_FILE"
    
    # 设置时区为 Asia/Shanghai
    log_info "设置系统时区为 Asia/Shanghai..."
    sudo timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
    sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    
    log_success "系统初始化完成"
}

# ==============================================================================
# 步骤 2: Node.js 环境安装 (Node.js 20+ 强制版本)
# ==============================================================================

step2_install_nodejs() {
    log_info "=========================================="
    log_info "步骤 2: Node.js 环境安装 (必须使用 20.x)"
    log_info "=========================================="
    
    # 检查是否已安装 Node.js
    if command -v node &> /dev/null; then
        CURRENT_NODE=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        CURRENT_NODE_FULL=$(node --version)
        log_warn "检测到已安装 Node.js ${CURRENT_NODE_FULL}"
        
        # 检查版本是否为 20.x
        if [[ "$CURRENT_NODE" -lt 20 ]]; then
            log_error "青龙面板要求 Node.js >= 20.18.1，当前版本 ${CURRENT_NODE_FULL} 不满足要求"
            log_info "正在升级 Node.js 到 20.x..."
            uninstall_nodejs
        elif [[ "$CURRENT_NODE" -eq 20 ]]; then
            # 检查小版本是否 >= 18.1
            MINOR=$(node --version | cut -d'v' -f2 | cut -d'.' -f2)
            PATCH=$(node --version | cut -d'v' -f2 | cut -d'.' -f3)
            if [[ "$MINOR" -lt 18 ]] || ([[ "$MINOR" -eq 18 ]] && [[ "$PATCH" -lt 1 ]]); then
                log_warn "Node.js 版本 ${CURRENT_NODE_FULL} 低于 20.18.1，建议升级"
                read -p "是否升级 Node.js 到最新 20.x? (Y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    uninstall_nodejs
                fi
            else
                log_success "Node.js 版本符合要求 (>= 20.18.1)"
                return 0
            fi
        else
            log_success "Node.js 版本 ${CURRENT_NODE_FULL} 应该兼容"
            return 0
        fi
    fi
    
    # 使用 Nodesource 官方脚本安装 Node.js 20.x
    log_info "通过 NodeSource 安装 Node.js ${NODE_VERSION}.x..."
    
    # 清理可能存在的旧配置
    sudo rm -f /etc/apt/sources.list.d/nodesource.list*
    
    # 下载并执行 NodeSource 安装脚本
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash - | tee -a "$LOG_FILE"
    
    # 安装 Node.js
    sudo apt-get install -y nodejs | tee -a "$LOG_FILE"
    
    # 验证安装
    NODE_VER=$(node --version)
    NPM_VER=$(npm --version)
    log_success "Node.js ${NODE_VER} 安装成功"
    log_success "npm ${NPM_VER} 安装成功"
    
    # Node.js 20+ 配置: 废弃 npm config set，改用环境变量
    log_info "配置 npm 镜像 (Node.js 20+ 兼容方式)..."
    
    # 仅设置 registry，不设置已废弃的 node_gyp 和 disturl
    npm config set registry "${NPM_REGISTRY}"
    
    # 禁用 package-lock 以减少潜在冲突
    npm config set package-lock false
    
    log_success "npm 镜像配置完成"
}

uninstall_nodejs() {
    log_info "卸载现有 Node.js..."
    sudo apt-get remove -y nodejs npm 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    sudo rm -rf /etc/apt/sources.list.d/nodesource.list*
    sudo rm -rf /usr/lib/node_modules/npm
}

# ==============================================================================
# 步骤 3: Python 环境配置
# ==============================================================================

step3_install_python() {
    log_info "=========================================="
    log_info "步骤 3: Python 环境配置"
    log_info "=========================================="
    
    # Ubuntu 20.04 默认包含 Python 3.8，确保 pip 已安装
    log_info "检查 Python 环境..."
    
    PYTHON_CMD=$(command -v python3 || command -v python)
    if [[ -z "$PYTHON_CMD" ]]; then
        log_error "未检测到 Python，尝试安装..."
        sudo apt-get install -y python3 python3-pip python3-venv | tee -a "$LOG_FILE"
    else
        PYTHON_VER=$($PYTHON_CMD --version 2>&1)
        log_success "检测到 ${PYTHON_VER}"
    fi
    
    # 确保 pip 已安装并升级到最新版
    log_info "安装/升级 pip..."
    sudo apt-get install -y python3-pip python3-distutils | tee -a "$LOG_FILE"
    
    # 升级 pip 并配置国内镜像
    python3 -m pip install --upgrade pip --index-url "${PIP_INDEX}" 2>&1 | tee -a "$LOG_FILE"
    
    # 配置 pip 使用清华镜像
    mkdir -p ~/.pip
    tee ~/.pip/pip.conf > /dev/null <<EOF
[global]
index-url = ${PIP_INDEX}
trusted-host = pypi.tuna.tsinghua.edu.cn

[install]
use-mirrors = true
mirrors = https://pypi.tuna.tsinghua.edu.cn
EOF
    
    # 安装 node-gyp 所需的 Python 配置
    log_info "配置 node-gyp Python 路径..."
    export npm_config_python=$(which python3)
    
    log_success "Python 环境配置完成"
}

# ==============================================================================
# 步骤 4: 安装 pnpm 和 node-pre-gyp (青龙面板依赖)
# ==============================================================================

step4_install_pnpm() {
    log_info "=========================================="
    log_info "步骤 4: 安装 pnpm 和 node-pre-gyp"
    log_info "=========================================="
    
    # 先安装 node-pre-gyp (青龙面板官方要求)
    log_info "安装 node-pre-gyp (青龙面板依赖)..."
    npm install -g node-pre-gyp --registry="${NPM_REGISTRY}" 2>&1 | tee -a "$LOG_FILE"
    
    # 检查是否已安装 pnpm
    if command -v pnpm &> /dev/null; then
        PNPM_VER=$(pnpm --version)
        log_success "检测到 pnpm ${PNPM_VER}"
    else
        # 使用 npm 安装 pnpm 8.3.1 (青龙官方推荐版本)
        log_info "通过 npm 安装 pnpm@8.3.1..."
        npm install -g pnpm@8.3.1 --registry="${NPM_REGISTRY}" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 配置 pnpm 使用国内镜像
    pnpm config set registry "${NPM_REGISTRY}" 2>/dev/null || true
    
    # 添加到 PATH (针对 WSL 环境)
    if ! grep -q "pnpm" ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.local/share/pnpm:$PATH"' >> ~/.bashrc
        log_info "已将 pnpm 添加到 ~/.bashrc PATH"
    fi
    
    log_success "pnpm 和 node-pre-gyp 安装完成"
}

# ==============================================================================
# 步骤 5: 青龙面板安装 (使用环境变量替代废弃的 npm config)
# ==============================================================================

step5_install_qinglong() {
    log_info "=========================================="
    log_info "步骤 5: 安装青龙面板"
    log_info "=========================================="
    
    # 创建数据目录
    log_info "创建青龙面板数据目录: ${QL_DATA_DIR}"
    mkdir -p "${QL_DATA_DIR}"
    
    # 设置环境变量 (供青龙面板使用)
    export QL_DIR="${QL_DIR}"
    export QL_DATA_DIR="${QL_DATA_DIR}"
    
    # 持久化环境变量到 .bashrc
    if ! grep -q "QL_DIR=" ~/.bashrc; then
        echo "export QL_DIR=\"${QL_DIR}\"" >> ~/.bashrc
        echo "export QL_DATA_DIR=\"${QL_DATA_DIR}\"" >> ~/.bashrc
        log_info "已持久化 QL_DIR 和 QL_DATA_DIR 到 ~/.bashrc"
    fi
    
    # Node.js 20+ 关键修复: 使用环境变量替代废弃的 npm config set node_gyp
    log_info "配置 node-gyp 环境变量 (Node.js 20+ 兼容方式)..."
    
    # 设置 Python 路径环境变量 (替代 npm config set python)
    export npm_config_python=$(which python3)
    
    # 设置 node-gyp 使用国内镜像 (替代废弃的 npm config set node_gyp)
    export npm_config_node_gyp="https://cdn.npmmirror.com/binaries/node-gyp"
    
    # 设置二进制包镜像源 (关键: 避免从 GitHub 下载)
    export npm_config_canvas_binary_host_mirror="https://registry.npmmirror.com/-/binary/canvas"
    export npm_config_sqlite3_binary_host_mirror="https://registry.npmmirror.com/-/binary/sqlite3"
    export npm_config_sass_binary_site="https://registry.npmmirror.com/-/binary/node-sass"
    export npm_config_phantomjs_cdnurl="https://registry.npmmirror.com/-/binary/phantomjs"
    export npm_config_electron_mirror="https://registry.npmmirror.com/-/binary/electron/"
    export npm_config_puppeteer_download_host="https://registry.npmmirror.com/-/binary"
    
    # 使用 npm 全局安装青龙面板
    log_info "正在安装青龙面板 (@whyour/qinglong)，这可能需要几分钟..."
    
    # 使用 --unsafe-perm 避免权限问题，使用国内镜像加速
    npm install -g @whyour/qinglong \
        --registry="${NPM_REGISTRY}" \
        --unsafe-perm \
        2>&1 | tee -a "$LOG_FILE"
    
    # 验证安装
    if command -v qinglong &> /dev/null || npm list -g @whyour/qinglong &> /dev/null; then
        log_success "青龙面板安装成功"
    else
        log_error "青龙面板安装可能失败，请检查日志"
        return 1
    fi
}

# ==============================================================================
# 步骤 6: WSL1 服务管理配置 (替代 systemd)
# ==============================================================================

step6_setup_service() {
    log_info "=========================================="
    log_info "步骤 6: 配置服务管理 (WSL1 兼容方案)"
    log_info "=========================================="
    
    # 创建启动脚本 (包含 Node.js 20+ 环境变量)
    local START_SCRIPT="${QL_DIR}/start.sh"
    log_info "创建启动脚本: ${START_SCRIPT}"
    
    tee "${START_SCRIPT}" > /dev/null <<EOF
#!/bin/bash
# 青龙面板启动脚本 (WSL1 兼容版)

QL_DIR="${QL_DIR}"
QL_DATA_DIR="${QL_DATA_DIR}"
QL_PORT="${QL_PORT}"

# Node.js 20+ 环境变量配置
export npm_config_python=\$(which python3)
export npm_config_node_gyp="https://cdn.npmmirror.com/binaries/node-gyp"
export npm_config_canvas_binary_host_mirror="https://registry.npmmirror.com/-/binary/canvas"
export npm_config_sqlite3_binary_host_mirror="https://registry.npmmirror.com/-/binary/sqlite3"

# 检查是否已在运行
if pgrep -f "qinglong" > /dev/null; then
    echo "青龙面板已在运行"
    exit 0
fi

# 设置环境变量
export QL_DIR
export QL_DATA_DIR

# 启动青龙面板
echo "正在启动青龙面板..."
echo "数据目录: \${QL_DATA_DIR}"
echo "访问地址: http://localhost:\${QL_PORT}"

# 使用 nohup 后台运行
cd "\${QL_DIR}" || exit 1
nohup qinglong > "\${QL_DIR}/qinglong.log" 2>&1 &

sleep 2

# 检查启动状态
if pgrep -f "qinglong" > /dev/null; then
    echo "青龙面板启动成功"
    echo "日志文件: \${QL_DIR}/qinglong.log"
else
    echo "青龙面板启动失败，请检查日志"
    exit 1
fi
EOF
    
    chmod +x "${START_SCRIPT}"
    
    # 创建停止脚本
    local STOP_SCRIPT="${QL_DIR}/stop.sh"
    log_info "创建停止脚本: ${STOP_SCRIPT}"
    
    tee "${STOP_SCRIPT}" > /dev/null <<'EOF'
#!/bin/bash
# 青龙面板停止脚本

if pgrep -f "qinglong" > /dev/null; then
    echo "正在停止青龙面板..."
    pkill -f "qinglong"
    sleep 1
    if pgrep -f "qinglong" > /dev/null; then
        echo "强制终止..."
        pkill -9 -f "qinglong"
    fi
    echo "青龙面板已停止"
else
    echo "青龙面板未在运行"
fi
EOF
    
    chmod +x "${STOP_SCRIPT}"
    
    # 创建状态检查脚本
    local STATUS_SCRIPT="${QL_DIR}/status.sh"
    tee "${STATUS_SCRIPT}" > /dev/null <<'EOF'
#!/bin/bash
# 青龙面板状态检查

if pgrep -f "qinglong" > /dev/null; then
    PID=$(pgrep -f "qinglong" | head -1)
    echo "青龙面板运行中 (PID: ${PID})"
    echo "访问地址: http://localhost:5700"
    echo "日志文件: ${QL_DIR}/qinglong.log"
else
    echo "青龙面板未运行"
fi
EOF
    
    chmod +x "${STATUS_SCRIPT}"
    
    log_success "服务管理脚本创建完成"
    log_info "启动命令: ${START_SCRIPT}"
    log_info "停止命令: ${STOP_SCRIPT}"
    log_info "状态检查: ${STATUS_SCRIPT}"
}

# ==============================================================================
# 步骤 7: 初始化与首次启动
# ==============================================================================

step7_initialize() {
    log_info "=========================================="
    log_info "步骤 7: 初始化青龙面板"
    log_info "=========================================="
    
    # 执行首次启动 (初始化配置文件)
    log_info "执行首次启动以初始化配置..."
    
    export QL_DIR="${QL_DIR}"
    export QL_DATA_DIR="${QL_DATA_DIR}"
    
    # 临时前台运行以完成初始化
    timeout 10s qinglong 2>&1 | tee -a "$LOG_FILE" || true
    
    # 检查初始化结果
    if [[ -d "${QL_DATA_DIR}/config" ]] || [[ -d "${QL_DIR}/node_modules" ]]; then
        log_success "青龙面板初始化完成"
    else
        log_warn "初始化可能未完成，将在首次正式启动时继续"
    fi
    
    # 创建便利的软链接
    if [[ ! -L "$HOME/ql" ]]; then
        ln -s "${QL_DIR}" "$HOME/ql" 2>/dev/null || true
        log_info "创建快捷方式: ~/ql -> ${QL_DIR}"
    fi
}

# ==============================================================================
# 自定义扩展入口 (用户可在此插入自定义逻辑)
# ==============================================================================

custom_pre_install() {
    # 扩展点 1: 基础环境配置完成后、青龙安装前的自定义步骤
    log_info "=========================================="
    log_info "扩展点: 预安装自定义步骤"
    log_info "=========================================="
    
    # 示例: 安装额外的系统依赖
    # sudo apt-get install -y your-package
    
    # 示例: 配置自定义 hosts
    # echo "127.0.0.1 custom.domain" | sudo tee -a /etc/hosts
    
    log_info "预安装步骤完成 (如需自定义，请编辑脚本中的 custom_pre_install 函数)"
}

custom_post_install() {
    # 扩展点 2: 青龙安装完成后、启动前的自定义步骤
    log_info "=========================================="
    log_info "扩展点: 安装后自定义步骤"
    log_info "=========================================="
    
    # 示例: 下载自定义脚本到青龙目录
    # git clone https://github.com/your-repo/scripts.git "${QL_DATA_DIR}/scripts/custom"
    
    # 示例: 预配置青龙面板设置
    # tee "${QL_DATA_DIR}/config/config.sh" > /dev/null <<'EOF'
    # export QL_PORT=5700
    # export QL_WS_PORT=5600
    # EOF
    
    log_info "安装后步骤完成 (如需自定义，请编辑脚本中的 custom_post_install 函数)"
}

# ==============================================================================
# 主执行流程
# ==============================================================================

main() {
    echo -e "${GREEN}"
    cat <<'EOF'
    ____       __                   __   ____________ 
   / __ \_____/ /____  ____  ____  / /  / ____/ __ \
  / / / / ___/ __/ _ \/ __ \/ __ \/ /  / / __/ / / /
 / /_/ / /__/ /_/  __/ /_/ / /_/ / /  / /_/ / /_/ / 
/_____/\___/\__/\___/ .___/\____/_/   \____/_____/ 
                   /_/                              
EOF
    echo -e "${NC}"
    
    log_info "青龙面板 WSL1 一键部署脚本启动 (Node.js 20+ 兼容版)"
    log_info "日志文件: ${LOG_FILE}"
    
    # 执行检测
    check_wsl1
    check_systemd
    
    # 确认安装
    echo ""
    read -p "确认开始安装青龙面板到 ${QL_DIR}? (Y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n "$REPLY" ]]; then
        log_info "用户取消安装"
        exit 0
    fi
    
    # 执行安装步骤
    step1_system_init
    step2_install_nodejs
    step3_install_python
    step4_install_pnpm
    
    # 自定义扩展点 1
    custom_pre_install
    
    step5_install_qinglong
    
    # 自定义扩展点 2
    custom_post_install
    
    step6_setup_service
    step7_initialize
    
    # 完成提示
    echo ""
    log_success "=========================================="
    log_success "青龙面板部署完成!"
    log_success "=========================================="
    echo ""
    log_info "安装目录: ${QL_DIR}"
    log_info "数据目录: ${QL_DATA_DIR}"
    log_info "访问地址: http://localhost:${QL_PORT}"
    echo ""
    log_info "管理命令:"
    log_info "  启动: ${QL_DIR}/start.sh"
    log_info "  停止: ${QL_DIR}/stop.sh"
    log_info "  状态检查: ${QL_DIR}/status.sh"
    echo ""
    log_warn "注意: WSL1 重启后需要手动重新启动青龙面板"
    log_warn "建议: 在 Windows 启动文件夹创建快捷方式自动启动"
    echo ""
    log_info "详细日志: ${LOG_FILE}"
}

# 错误处理
trap 'log_error "脚本执行中断，请检查日志: ${LOG_FILE}"; exit 1' ERR INT TERM

# 执行主函数
main "$@"
