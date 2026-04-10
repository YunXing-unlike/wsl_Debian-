#!/bin/bash
# ============================================
# 青龙面板(WSL1 Ubuntu 20.04)一键部署脚本
# 版本: 1.0
# 作者: 元宝
# 最后更新: 2026-04-10
# ============================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为WSL1环境
check_wsl1_environment() {
    log_info "检查WSL1环境..."
    
    if ! grep -q "Microsoft" /proc/version; then
        log_error "当前环境不是WSL，请确保在WSL1中运行此脚本"
        exit 1
    fi
    
    # 检查是否为WSL1（WSL2有完整Linux内核）
    if uname -r | grep -q "WSL2"; then
        log_warning "检测到WSL2环境，本脚本主要针对WSL1优化"
    fi
    
    # 检查systemd支持
    if systemctl --version > /dev/null 2>&1; then
        log_warning "检测到systemd支持，但脚本将使用替代服务管理方案"
    else
        log_info "确认无systemd支持，使用替代服务管理方案"
    fi
}

# 配置国内镜像源
configure_mirrors() {
    log_info "配置国内镜像源..."
    
    # 备份原始源列表
    if [ ! -f /etc/apt/sources.list.bak ]; then
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    fi
    
    # 使用阿里云镜像源
    sudo sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
    sudo sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
    
    # 配置npm镜像源
    npm config set registry https://registry.npmmirror.com/
    npm config set disturl https://npmmirror.com/mirrors/node/
    
    # 配置pip镜像源
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
    
    log_success "镜像源配置完成"
}

# 安装系统依赖
install_system_dependencies() {
    log_info "更新系统包列表..."
    sudo apt-get update
    
    log_info "安装系统依赖..."
    sudo apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        python3 \
        python3-pip \
        python3-venv \
        sqlite3 \
        libsqlite3-dev \
        ca-certificates \
        gnupg \
        lsb-release
    
    log_success "系统依赖安装完成"
}

# 安装Node.js和npm
install_nodejs() {
    log_info "安装Node.js 20.x..."
    
    # 添加NodeSource仓库
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    # 验证安装
    node_version=$(node --version)
    npm_version=$(npm --version)
    log_success "Node.js ${node_version} 和 npm ${npm_version} 安装成功"
    
    # 处理npm disturl错误（Node.js 20.x兼容性修复）
    log_info "处理npm配置兼容性问题..."
    npm config delete disturl 2>/dev/null || true
    npm cache clean --force
    
    # 更新npm到最新稳定版本
    sudo npm install -g npm@latest
    
    log_success "Node.js环境配置完成"
}

# 安装pnpm
install_pnpm() {
    log_info "安装pnpm..."
    
    # 使用npm安装指定版本的pnpm
    sudo npm install -g pnpm@8.3.1
    
    # 配置pnpm镜像源
    pnpm config set registry https://registry.npmmirror.com/
    
    pnpm_version=$(pnpm --version)
    log_success "pnpm ${pnpm_version} 安装成功"
}

# 安装青龙面板
install_qinglong() {
    log_info "安装青龙面板..."
    
    # 全局安装青龙
    sudo npm install -g @whyour/qinglong@latest
    
    # 创建应用目录
    QL_DIR="/opt/qinglong"
    QL_DATA_DIR="/opt/qinglong/data"
    
    sudo mkdir -p "$QL_DATA_DIR"
    sudo chown -R $USER:$USER "$QL_DIR"
    
    # 设置环境变量
    echo "export QL_DIR=\"$(npm root -g)/@whyour/qinglong\"" >> ~/.bashrc
    echo "export QL_DATA_DIR=\"$QL_DATA_DIR\"" >> ~/.bashrc
    echo "export PATH=\"\$PATH:$(npm root -g)/@whyour/qinglong/bin\"" >> ~/.bashrc
    
    # 立即生效
    export QL_DIR="$(npm root -g)/@whyour/qinglong"
    export QL_DATA_DIR="$QL_DATA_DIR"
    export PATH="$PATH:$(npm root -g)/@whyour/qinglong/bin"
    
    # 复制配置文件
    cp "$QL_DIR/.env.example" "$QL_DIR/.env" 2>/dev/null || true
    
    log_success "青龙面板安装完成"
}

# 配置青龙面板
configure_qinglong() {
    log_info "配置青龙面板..."
    
    # 创建必要的目录结构
    mkdir -p "$QL_DATA_DIR/scripts" \
             "$QL_DATA_DIR/log" \
             "$QL_DATA_DIR/db" \
             "$QL_DATA_DIR/config"
    
    # 生成默认配置文件
    if [ ! -f "$QL_DATA_DIR/config/config.sh" ]; then
        cat > "$QL_DATA_DIR/config/config.sh" << 'EOF'
#!/bin/bash
# 青龙面板配置文件

# 面板设置
QL_PORT=5700
QL_BASE_URL="/"

# 数据库设置
DB_TYPE="sqlite3"
DB_PATH="$QL_DATA_DIR/db/qinglong.db"

# 日志设置
LOG_LEVEL="info"
LOG_PATH="$QL_DATA_DIR/log"

# 安全设置
ENABLE_AUTH=true
JWT_SECRET=$(openssl rand -base64 32)
EOF
        chmod +x "$QL_DATA_DIR/config/config.sh"
    fi
    
    log_success "青龙面板配置完成"
}

# 创建启动脚本（无systemd方案）
create_startup_script() {
    log_info "创建启动脚本（适配无systemd环境）..."
    
    # 创建启动脚本
    cat > /tmp/qinglong-start.sh << 'EOF'
#!/bin/bash
# 青龙面板启动脚本（WSL1兼容版）

set -e

QL_DIR="$(npm root -g)/@whyour/qinglong"
QL_DATA_DIR="/opt/qinglong/data"

# 加载环境变量
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# 检查必要环境变量
if [ -z "$QL_DIR" ] || [ -z "$QL_DATA_DIR" ]; then
    echo "错误：未设置QL_DIR或QL_DATA_DIR环境变量"
    exit 1
fi

# 切换到青龙目录
cd "$QL_DIR"

# 检查是否已运行
PID_FILE="/tmp/qinglong.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "青龙面板已在运行 (PID: $OLD_PID)"
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

# 启动青龙面板
echo "启动青龙面板..."
node "$QL_DIR/lib/app.js" > "$QL_DATA_DIR/log/qinglong.log" 2>&1 &
PID=$!

# 保存PID
echo $PID > "$PID_FILE"

# 等待服务启动
sleep 5

# 检查服务状态
if kill -0 "$PID" 2>/dev/null; then
    echo "青龙面板启动成功！"
    echo "PID: $PID"
    echo "日志文件: $QL_DATA_DIR/log/qinglong.log"
    echo "访问地址: http://localhost:5700"
else
    echo "青龙面板启动失败，请检查日志"
    rm -f "$PID_FILE"
    exit 1
fi
EOF
    
    # 创建停止脚本
    cat > /tmp/qinglong-stop.sh << 'EOF'
#!/bin/bash
# 青龙面板停止脚本

PID_FILE="/tmp/qinglong.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "停止青龙面板 (PID: $PID)..."
        kill $PID
        sleep 2
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 $PID
        fi
        echo "青龙面板已停止"
    else
        echo "青龙面板未运行"
    fi
    rm -f "$PID_FILE"
else
    echo "青龙面板未运行"
fi
EOF
    
    # 创建服务管理脚本
    cat > /tmp/qinglong-service.sh << 'EOF'
#!/bin/bash
# 青龙面板服务管理脚本

case "$1" in
    start)
        bash /tmp/qinglong-start.sh
        ;;
    stop)
        bash /tmp/qinglong-stop.sh
        ;;
    restart)
        bash /tmp/qinglong-stop.sh
        sleep 2
        bash /tmp/qinglong-start.sh
        ;;
    status)
        PID_FILE="/tmp/qinglong.pid"
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                echo "青龙面板正在运行 (PID: $PID)"
                echo "访问地址: http://localhost:5700"
            else
                echo "青龙面板已停止"
                rm -f "$PID_FILE"
            fi
        else
            echo "青龙面板已停止"
        fi
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    
    # 设置权限并安装脚本
    chmod +x /tmp/qinglong-*.sh
    sudo mv /tmp/qinglong-start.sh /usr/local/bin/qinglong-start
    sudo mv /tmp/qinglong-stop.sh /usr/local/bin/qinglong-stop
    sudo mv /tmp/qinglong-service.sh /usr/local/bin/qinglong-service
    
    log_success "启动脚本创建完成"
}

# 预留自定义配置入口
custom_configuration_hook() {
    log_info "=== 自定义配置入口 ==="
    log_info "在此处可以添加您的自定义配置"
    log_info "当前目录: $(pwd)"
    log_info "QL_DIR: $QL_DIR"
    log_info "QL_DATA_DIR: $QL_DATA_DIR"
    
    # 示例：创建自定义脚本目录
    mkdir -p "$QL_DATA_DIR/scripts/custom"
    
    # 示例：创建自定义环境变量文件
    if [ ! -f "$QL_DATA_DIR/config/custom.env" ]; then
        cat > "$QL_DATA_DIR/config/custom.env" << 'EOF'
# 自定义环境变量
# 在此处添加您的自定义环境变量
# 例如：
# MY_CUSTOM_VAR="value"
# ANOTHER_VAR="another_value"
EOF
        log_info "已创建自定义环境变量文件: $QL_DATA_DIR/config/custom.env"
    fi
    
    log_info "=== 自定义配置完成 ==="
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查关键命令
    for cmd in node npm pnpm python3 pip3; do
        if command -v $cmd >/dev/null 2>&1; then
            log_success "$cmd 已安装: $($cmd --version 2>/dev/null | head -1)"
        else
            log_error "$cmd 未安装"
            return 1
        fi
    done
    
    # 检查青龙安装
    if [ -d "$(npm root -g)/@whyour/qinglong" ]; then
        log_success "青龙面板已安装"
    else
        log_error "青龙面板安装失败"
        return 1
    fi
    
    # 检查目录结构
    for dir in "$QL_DATA_DIR" "$QL_DATA_DIR/scripts" "$QL_DATA_DIR/log" "$QL_DATA_DIR/db"; do
        if [ -d "$dir" ]; then
            log_success "目录存在: $dir"
        else
            log_error "目录不存在: $dir"
            return 1
        fi
    done
    
    log_success "安装验证通过"
    return 0
}

# 显示使用说明
show_usage() {
    cat << EOF

============================================
青龙面板部署完成！
============================================

管理命令：
1. 启动青龙面板：qinglong-start
2. 停止青龙面板：qinglong-stop
3. 服务管理：qinglong-service {start|stop|restart|status}

访问地址：http://localhost:5700

重要目录：
- 青龙主程序：$QL_DIR
- 数据目录：$QL_DATA_DIR
- 脚本目录：$QL_DATA_DIR/scripts
- 日志目录：$QL_DATA_DIR/log

环境变量已添加到 ~/.bashrc，重启终端或执行以下命令生效：
source ~/.bashrc

自定义配置：
您可以在以下位置添加自定义配置：
1. $QL_DATA_DIR/config/config.sh - 主配置文件
2. $QL_DATA_DIR/config/custom.env - 自定义环境变量
3. $QL_DATA_DIR/scripts/custom/ - 自定义脚本目录

故障排除：
1. 查看日志：tail -f $QL_DATA_DIR/log/qinglong.log
2. 检查进程：ps aux | grep node
3. 重新启动：qinglong-service restart

============================================
EOF
}

# 主函数
main() {
    echo "==========================================="
    echo "青龙面板(WSL1 Ubuntu 20.04)一键部署脚本"
    echo "==========================================="
    
    # 检查环境
    check_wsl1_environment
    
    # 步骤1：配置镜像源
    configure_mirrors
    
    # 步骤2：安装系统依赖
    install_system_dependencies
    
    # 步骤3：安装Node.js和npm
    install_nodejs
    
    # 步骤4：安装pnpm
    install_pnpm
    
    # 步骤5：安装青龙面板
    install_qinglong
    
    # 步骤6：配置青龙面板
    configure_qinglong
    
    # 步骤7：创建启动脚本
    create_startup_script
    
    # 步骤8：自定义配置入口（用户可在此处添加自定义配置）
    custom_configuration_hook
    
    # 步骤9：验证安装
    if verify_installation; then
        log_success "青龙面板部署成功！"
    else
        log_error "部署过程中出现问题，请检查日志"
        exit 1
    fi
    
    # 显示使用说明
    show_usage
    
    # 提示用户启动服务
    echo ""
    read -p "是否立即启动青龙面板？(y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        qinglong-start
    else
        echo "您可以使用 'qinglong-start' 命令手动启动青龙面板"
    fi
}

# 执行主函数
main "$@"
