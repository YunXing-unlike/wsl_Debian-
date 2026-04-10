#!/bin/bash

# ============================================
# 青龙面板 WSL1 Ubuntu 20.04 一键部署脚本
# 版本：v1.0
# 作者：元宝
# 日期：2026-04-10
# ============================================

set -e  # 遇到错误立即退出

echo "============================================"
echo "青龙面板 WSL1 环境部署脚本"
echo "系统要求：Ubuntu 20.04 (WSL1)"
echo "============================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用sudo或以root用户运行此脚本"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if ! grep -q "Ubuntu 20.04" /etc/os-release; then
        log_warn "检测到系统不是Ubuntu 20.04，继续执行但可能遇到兼容性问题"
    fi
    
    if ! grep -q "WSL" /proc/version; then
        log_warn "未检测到WSL环境，继续执行但可能遇到兼容性问题"
    fi
}

# 配置国内软件源
configure_sources() {
    log_info "配置国内软件源..."
    
    # 备份原有源
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    
    # 使用清华源（Ubuntu 20.04 focal）
    cat > /etc/apt/sources.list << 'EOF'
# 清华大学 Ubuntu 20.04 镜像源
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
EOF
    
    log_info "软件源配置完成"
}

# 安装系统基础依赖
install_base_deps() {
    log_info "更新系统包列表..."
    apt-get update -y
    
    log_info "安装系统基础工具..."
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    unzip \
    jq \
    cron \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-venv \
    python3-pip \
    g++ \
    make \
    python3 \
    pkg-config \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev
    
    log_info "基础依赖安装完成"
}

# 安装Node.js环境
install_nodejs() {
    log_info "安装Node.js 20.x LTS版本（青龙面板兼容版本）..."
    
    # 卸载旧版本Node.js（如果已安装）
    apt-get remove -y nodejs
    apt-get autoremove -y
    
    # 使用NodeSource安装Node.js 20.x
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get update
    apt-get install -y nodejs
    
    # 验证安装
    node_version=$(node --version)
    npm_version=$(npm --version)
    log_info "Node.js版本: $node_version"
    log_info "npm版本: $npm_version"
    
    # 配置npm国内镜像源
    log_info "配置npm国内镜像源..."
    npm config set registry https://registry.npmmirror.com/
    
    log_info "Node.js环境配置完成"
}

# 安装Python环境
install_python() {
    log_info "配置Python环境..."
    
    # Ubuntu 20.04自带Python 3.8，满足青龙面板要求
    python_version=$(python3 --version)
    log_info "系统Python版本: $python_version"
    
    # 配置pip国内镜像源
    log_info "配置pip国内镜像源..."
    pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    pip3 config set global.trusted-host pypi.tuna.tsinghua.edu.cn
    
    # 升级pip
    pip3 install --upgrade pip
    
    log_info "Python环境配置完成"
}

# 安装pnpm包管理器
install_pnpm() {
    log_info "安装pnpm包管理器..."
    
    # 安装pnpm（青龙面板推荐版本）
    npm install -g pnpm@8.3.1
    
    # 配置pnpm国内镜像源
    pnpm config set registry https://registry.npmmirror.com/
    
    pnpm_version=$(pnpm --version)
    log_info "pnpm版本: $pnpm_version"
    
    log_info "pnpm安装完成"
}

# 安装青龙面板
install_qinglong() {
    log_info "安装青龙面板..."
    
    # 全局安装node-gyp（必需的原生模块构建工具）
    log_info "安装原生模块构建工具..."
    npm install -g node-gyp
    
    # 安装青龙面板（使用npm而不是pnpm）
    log_info "使用npm安装青龙面板..."
    npm install -g @whyour/qinglong@latest --force
    
    log_info "青龙面板安装完成"
}
# 初始化青龙面板
init_qinglong() {
    log_info "初始化青龙面板..."
    
    # 创建数据目录
    QL_DATA_DIR="/opt/qinglong/data"
    mkdir -p $QL_DATA_DIR/{config,scripts,log,db,upload}
    
    # 设置目录权限
    chmod -R 755 /opt/qinglong
    
    log_info "创建青龙面板配置文件..."
    
    # 创建环境配置文件
    cat > /opt/qinglong/.env << 'EOF'
# 青龙面板环境配置
QL_DIR="/opt/qinglong"
QL_DATA_DIR="/opt/qinglong/data"
QL_PORT=5700
QL_BASE_URL="/"
QL_LOG_LEVEL="info"

# 数据库配置
QL_DB_TYPE="sqlite"
QL_DB_PATH="/opt/qinglong/data/db/qinglong.db"

# JWT配置
QL_JWT_SECRET=$(openssl rand -base64 32)
QL_JWT_EXPIRES_IN="7d"

# 时区配置
TZ=Asia/Shanghai
EOF
    
    # 设置环境变量
    echo "export QL_DIR=\"/opt/qinglong\"" >> /etc/profile
    echo "export QL_DATA_DIR=\"/opt/qinglong/data\"" >> /etc/profile
    echo "export PATH=\$PATH:/opt/qinglong/bin" >> /etc/profile
    
    source /etc/profile
    
    log_info "青龙面板初始化完成"
}

# 安装进程管理工具
install_process_manager() {
    log_info "安装PM2进程管理器..."
    
    # 安装PM2（用于WSL1环境下的进程管理）
    npm install -g pm2
    
    log_info "PM2安装完成"
}

# 配置青龙面板服务
configure_service() {
    log_info "配置青龙面板服务..."
    
    # 创建PM2启动配置文件
    cat > /opt/qinglong/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'qinglong',
    script: 'qinglong',
    cwd: '/opt/qinglong',
    args: 'start',
    interpreter: 'none',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      QL_DIR: '/opt/qinglong',
      QL_DATA_DIR: '/opt/qinglong/data',
      PORT: 5700
    },
    env_production: {
      NODE_ENV: 'production'
    },
    output: '/opt/qinglong/logs/qinglong-out.log',
    error: '/opt/qinglong/logs/qinglong-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss'
  }]
};
EOF
    
    # 创建系统服务脚本（备用）
    cat > /etc/init.d/qinglong << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          qinglong
# Required-Start:    $local_fs $network
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Qinglong Panel Service
# Description:       Timed task management platform
### END INIT INFO

QL_DIR="/opt/qinglong"
QL_DATA_DIR="/opt/qinglong/data"
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

case "$1" in
  start)
    echo "启动青龙面板..."
    cd $QL_DIR
    pm2 start ecosystem.config.js --env production
    ;;
  stop)
    echo "停止青龙面板..."
    pm2 stop qinglong
    ;;
  restart)
    echo "重启青龙面板..."
    pm2 restart qinglong
    ;;
  status)
    pm2 status qinglong
    ;;
  *)
    echo "使用方法: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0
EOF
    
    chmod +x /etc/init.d/qinglong
    
    log_info "服务配置完成"
}

# 安装常用依赖包
install_common_deps() {
    log_info "安装常用Python依赖包..."
    
    # 安装青龙面板常用的Python依赖
    pip3 install \
        requests \
        beautifulsoup4 \
        lxml \
        pycryptodome \
        pillow \
        pyexecjs \
        pytz \
        schedule \
        aiohttp \
        redis \
        httpx \
        loguru \
        colorama \
        pandas \
        numpy \
        openpyxl
    
    log_info "常用依赖安装完成"
}

# 启动青龙面板
start_qinglong() {
    log_info "启动青龙面板服务..."
    
    # 使用PM2启动青龙面板
    cd /opt/qinglong
    pm2 start ecosystem.config.js --env production
    pm2 save
    pm2 startup
    
    log_info "青龙面板启动完成"
}

# 显示部署信息
show_deploy_info() {
    echo ""
    echo "============================================"
    echo "🎉 青龙面板部署完成！"
    echo "============================================"
    echo ""
    echo "📊 部署信息汇总："
    echo "--------------------------------------------"
    echo "• 安装目录: /opt/qinglong"
    echo "• 数据目录: /opt/qinglong/data"
    echo "• 服务端口: 5700"
    echo "• 访问地址: http://localhost:5700"
    echo ""
    echo "🛠️ 服务管理命令："
    echo "--------------------------------------------"
    echo "• 启动服务: pm2 start qinglong"
    echo "• 停止服务: pm2 stop qinglong"
    echo "• 重启服务: pm2 restart qinglong"
    echo "• 查看状态: pm2 status qinglong"
    echo "• 查看日志: pm2 logs qinglong"
    echo ""
    echo "📁 目录结构："
    echo "--------------------------------------------"
    echo "/opt/qinglong/"
    echo "├── data/           # 数据目录"
    echo "│   ├── config/     # 配置文件"
    echo "│   ├── scripts/    # 脚本文件"
    echo "│   ├── log/        # 日志文件"
    echo "│   ├── db/         # 数据库文件"
    echo "│   └── upload/     # 上传文件"
    echo "├── .env           # 环境配置"
    echo "└── ecosystem.config.js  # PM2配置"
    echo ""
    echo "🔧 后续配置："
    echo "--------------------------------------------"
    echo "1. 首次访问 http://localhost:5700 完成初始化设置"
    echo "2. 在青龙面板中配置脚本仓库和环境变量"
    echo "3. 根据需要安装额外的Node.js和Python依赖"
    echo ""
    echo "⚠️  注意事项："
    echo "--------------------------------------------"
    echo "• WSL1环境不支持systemd，使用PM2管理进程"
    echo "• 重启WSL后需要手动启动服务：pm2 resurrect"
    echo "• 建议将PM2设置为开机自启"
    echo ""
    echo "============================================"
}

# 主函数
main() {
    log_info "开始青龙面板部署流程..."
    
    # 执行部署步骤
    check_root
    check_system
    configure_sources
    install_base_deps
    install_nodejs
    install_python
    install_pnpm
    install_qinglong
    init_qinglong
    install_process_manager
    configure_service
    install_common_deps
    start_qinglong
    
    show_deploy_info
    
    log_info "部署脚本执行完毕！"
}

# 执行主函数
main "$@"
