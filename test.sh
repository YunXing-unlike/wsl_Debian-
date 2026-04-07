#!/bin/bash
# ==================================================
# 青龙面板 WSL1 专用部署脚本（日志还原版）
# 适配 Ubuntu 20.04 | Node.js 20.x
# 适用于无 Docker 环境的 WSL1 或纯 Linux 系统
# 作者：根据日志还原
# 版本：v1.0
# ==================================================

set -e  # 遇到错误立即退出

# 颜色输出
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

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 用户运行此脚本！"
        exit 1
    fi
}

# 环境预检
check_environment() {
    log_info "========== 环境预检 =========="
    
    # 检测系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "系统: $NAME $VERSION"
        log_info "架构: $(uname -m)"
    else
        log_warn "无法检测系统信息"
    fi

    # 检测 WSL1（可选）
    if [[ $(uname -r) == *Microsoft* ]]; then
        log_info "检测到 WSL1 环境"
    else
        log_warn "未检测到 WSL1 环境，继续执行..."
    fi
}

# 清理旧环境
clean_old() {
    log_info "========== 清理旧环境 =========="
    
    # 停止青龙服务（如果存在）
    if command -v pm2 &> /dev/null; then
        pm2 delete qinglong 2>/dev/null || true
        pm2 save --force 2>/dev/null || true
    fi
    
    # 清理 npm 全局包
    npm uninstall -g @whyour/qinglong 2>/dev/null || true
    
    # 清理数据目录（谨慎操作）
    # rm -rf /ql/data  # 如需全新安装可取消注释
    
    log_info "旧环境清理完成"
}

# 更新系统并安装依赖
install_dependencies() {
    log_info "========== 更新系统 & 安装必备依赖 =========="
    
    apt-get update -y
    apt-get upgrade -y
    
    # 安装基础依赖
    apt-get install -y git curl wget tzdata perl openssl jq nginx procps netcat-openbsd openssh-client
    
    log_info "系统依赖安装完成"
}

# 安装 Node.js 20.x
install_nodejs() {
    log_info "========== 安装 Node.js 20.x LTS =========="
    
    # 添加 NodeSource 源
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    
    # 安装 Node.js
    apt-get install -y nodejs
    
    # 验证安装
    node_version=$(node -v)
    npm_version=$(npm -v)
    log_info "Node版本：$node_version | NPM版本：$npm_version"
}

# 配置国内镜像
setup_mirrors() {
    log_info "========== 配置国内镜像（Git/NPM/PIP） =========="
    
    # 配置 npm 镜像
    npm config set registry https://registry.npmmirror.com
    
    # 配置 git（可选）
    git config --global url."https://ghproxy.com/https://github.com".insteadOf "https://github.com" 2>/dev/null || true
    
    log_info "镜像配置完成"
}

# 安装青龙面板
install_qinglong() {
    log_info "========== 安装青龙面板 =========="
    
    # 全局安装青龙
    npm install -g @whyour/qinglong
    
    # 设置环境变量
    export QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
    export QL_DATA_DIR="/ql/data"
    
    # 永久写入环境变量（可选）
    echo "export QL_DIR=$QL_DIR" >> /etc/profile
    echo "export QL_DATA_DIR=$QL_DATA_DIR" >> /etc/profile
    source /etc/profile
    
    log_info "青龙面板安装完成"
}

# 初始化青龙目录结构
init_qinglong_dirs() {
    log_info "========== 初始化青龙目录结构 =========="
    
    # 创建必要目录
    mkdir -p /ql/data/config
    mkdir -p /ql/data/log
    mkdir -p /ql/data/db
    mkdir -p /ql/data/scripts
    mkdir -p /ql/data/log/.tmp
    mkdir -p /ql/data/repo
    mkdir -p /ql/data/raw
    mkdir -p /ql/data/log/update
    mkdir -p /ql/data/deps
    
    # 复制配置文件（如果不存在）
    QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
    
    [[ ! -s /ql/data/config/config.sh ]] && cp -f $QL_DIR/sample/config.sample.sh /ql/data/config/config.sh
    [[ ! -f /ql/data/config/task_before.sh ]] && cp -f $QL_DIR/sample/task.sample.sh /ql/data/config/task_before.sh
    [[ ! -f /ql/data/config/task_after.sh ]] && cp -f $QL_DIR/sample/task.sample.sh /ql/data/config/task_after.sh
    [[ ! -f /ql/data/config/extra.sh ]] && cp -f $QL_DIR/sample/extra.sample.sh /ql/data/config/extra.sh
    [[ ! -s /ql/data/scripts/notify.py ]] && cp -f $QL_DIR/sample/notify.py /ql/data/scripts/notify.py
    [[ ! -s /ql/data/scripts/sendNotify.js ]] && cp -f $QL_DIR/sample/notify.js /ql/data/scripts/sendNotify.js
    [[ ! -s /ql/data/scripts/ql_sample.js ]] && cp -f $QL_DIR/sample/ql_sample.js /ql/data/scripts/ql_sample.js
    [[ ! -s /ql/data/scripts/ql_sample.py ]] && cp -f $QL_DIR/sample/ql_sample.py /ql/data/scripts/ql_sample.py
    [[ ! -s /ql/data/deps/sendNotify.js ]] && cp -f $QL_DIR/sample/notify.js /ql/data/deps/sendNotify.js
    [[ ! -s /ql/data/deps/notify.py ]] && cp -f $QL_DIR/sample/notify.py /ql/data/deps/notify.py
    
    log_info "目录结构初始化完成"
}

# 启动服务
start_services() {
    log_info "========== 启动服务 =========="
    
    # 启动 nginx
    systemctl start nginx || service nginx start
    systemctl enable nginx 2>/dev/null || true
    
    # 启动青龙面板
    log_info "启动青龙面板..."
    
    # 进入青龙目录
    cd /usr/lib/node_modules/@whyour/qinglong
    
    # 安装 PM2（如果未安装）
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
    fi
    
    # 启动青龙
    pm2 start /usr/lib/node_modules/@whyour/qinglong/shell/start.sh --name qinglong
    
    # 保存 PM2 配置
    pm2 save
    pm2 startup 2>/dev/null || true
    
    log_info "服务启动完成"
}

# 显示访问信息
show_access_info() {
    log_info "========== 部署完成 =========="
    echo ""
    echo "✅ 青龙面板部署完成！"
    echo ""
    echo "📊 访问信息："
    echo "   - 面板地址：http://localhost:5700"
    echo "   - 默认账号：admin"
    echo "   - 默认密码：admin（首次登录需修改）"
    echo ""
    echo "📁 重要目录："
    echo "   - 青龙主目录：/usr/lib/node_modules/@whyour/qinglong"
    echo "   - 数据目录：/ql/data"
    echo "   - 配置文件：/ql/data/config/config.sh"
    echo ""
    echo "🛠️ 管理命令："
    echo "   - 启动青龙：pm2 start qinglong"
    echo "   - 停止青龙：pm2 stop qinglong"
    echo "   - 重启青龙：pm2 restart qinglong"
    echo "   - 查看日志：pm2 logs qinglong"
    echo ""
    echo "⚠️  注意：首次访问需按提示完成初始化设置"
    echo ""
}

# 主函数
main() {
    clear
    echo "=================================================="
    echo "      青龙面板 WSL1 专用部署脚本（日志还原版）"
    echo "           适配Ubuntu20.04 | Node20.x"
    echo "=================================================="
    echo ""
    
    # 执行步骤
    check_root
    check_environment
    clean_old
    install_dependencies
    install_nodejs
    setup_mirrors
    install_qinglong
    init_qinglong_dirs
    start_services
    show_access_info
    
    log_info "脚本执行完毕！"
}

# 执行主函数
main "$@"
