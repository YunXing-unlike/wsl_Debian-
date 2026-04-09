#!/bin/bash
# 青龙面板WSL1 Ubuntu 20.04一键安装脚本
# 版本：v2.1.0
# 作者：元宝
# 日期：2026-04-10
# 描述：专为WSL1环境优化，解决网络问题和依赖冲突

set -e

echo "=========================================="
echo "  青龙面板WSL1 Ubuntu 20.04一键安装脚本  "
echo "  版本：v2.1.0                           "
echo "=========================================="

# 0. 环境检测
echo "检测系统环境..."
OS_INFO=$(lsb_release -ds 2>/dev/null || echo "Ubuntu 20.04")
echo "操作系统: $OS_INFO"
echo "WSL版本: $(uname -r)"

# 1. 配置国内源
echo "步骤1/13：配置国内源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list > /dev/null << 'EOF'
# 阿里云镜像源
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# 2. 更新系统
echo "步骤2/13：更新系统软件包..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git vim htop net-tools build-essential ca-certificates

# 3. 安装Node.js 16.x（多源备用方案）
echo "步骤3/13：安装Node.js 16.x..."
install_nodejs() {
    echo "尝试方案1：使用NodeSource官方源..."
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - && sudo apt install -y nodejs && return 0
    
    echo "方案1失败，尝试方案2：使用淘宝镜像..."
    curl -fsSL https://npmmirror.com/mirrors/node/v16.20.2/setup_16.x | sudo -E bash - && sudo apt install -y nodejs && return 0
    
    echo "方案2失败，尝试方案3：直接下载二进制包..."
    NODE_VERSION="16.20.2"
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="x64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    else
        ARCH="x64"
    fi
    
    cd /tmp
    wget https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz
    tar -xJf node-v${NODE_VERSION}-linux-${ARCH}.tar.xz
    sudo cp -r node-v${NODE_VERSION}-linux-${ARCH}/* /usr/local/
    rm -rf node-v${NODE_VERSION}-linux-${ARCH}*
    
    # 验证安装
    if command -v node &> /dev/null; then
        return 0
    else
        return 1
    fi
}

if install_nodejs; then
    echo "✓ Node.js安装成功"
    echo "Node.js版本: $(node --version)"
    echo "npm版本: $(npm --version)"
else
    echo "✗ Node.js安装失败，使用apt默认版本"
    sudo apt install -y nodejs npm
    echo "Node.js版本: $(node --version)"
    echo "npm版本: $(npm --version)"
fi

# 4. 安装Python3
echo "步骤4/13：安装Python3及相关工具..."
sudo apt install -y python3 python3-pip python3-venv python3-dev python3-distutils
echo "Python3版本: $(python3 --version)"

# 配置pip国内源
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# 5. 安装SQLite3
echo "步骤5/13：安装SQLite3数据库..."
sudo apt install -y sqlite3 libsqlite3-dev
sqlite3 --version

# 6. 安装Redis
echo "步骤6/13：安装Redis..."
sudo apt install -y redis-server
# 配置Redis以无需systemd方式运行
sudo sed -i 's/^supervised systemd/supervised no/' /etc/redis/redis.conf
sudo sed -i 's/^bind 127.0.0.1/# bind 127.0.0.1/' /etc/redis/redis.conf
sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
sudo sed -i 's/^daemonize no/daemonize yes/' /etc/redis/redis.conf

# 7. 配置npm和安装pnpm
echo "步骤7/13：配置npm和安装pnpm..."
# 配置npm国内源
npm config set registry https://registry.npmmirror.com
npm config set disturl https://npmmirror.com/dist
npm config set puppeteer_download_host https://npmmirror.com/mirrors
npm config set electron_mirror https://npmmirror.com/mirrors/electron/
npm config set sass_binary_site https://npmmirror.com/mirrors/node-sass/

# 安装pnpm（使用国内镜像）
npm install -g pnpm@7.33.0 --registry=https://registry.npmmirror.com
echo "pnpm版本: $(pnpm --version)"

# 配置pnpm国内源
pnpm config set registry https://registry.npmmirror.com

# 8. 克隆青龙面板仓库
echo "步骤8/13：克隆青龙面板仓库..."
cd ~
if [ -d "qinglong" ]; then
    echo "青龙目录已存在，更新代码..."
    cd qinglong
    git stash
    git pull
else
    echo "克隆青龙面板仓库..."
    # 尝试多个镜像源
    git clone https://github.com/whyour/qinglong.git || \
    git clone https://gitee.com/whyour/qinglong.git || \
    git clone https://ghproxy.com/https://github.com/whyour/qinglong.git
    
    if [ ! -d "qinglong" ]; then
        echo "✗ 克隆失败，请检查网络连接"
        exit 1
    fi
    cd qinglong
fi

# 9. 修复可能存在的依赖问题
echo "步骤9/13：修复依赖问题..."
# 备份原始package.json
if [ -f "package.json" ]; then
    cp package.json package.json.bak
fi

# 创建修复脚本
cat > fix_deps.js << 'EOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

// 锁定React版本以避免冲突
if (!pkg.resolutions) pkg.resolutions = {};
pkg.resolutions["react"] = "17.0.2";
pkg.resolutions["react-dom"] = "17.0.2";

// 确保使用固定版本
if (pkg.dependencies) {
    pkg.dependencies["react"] = "17.0.2";
    pkg.dependencies["react-dom"] = "17.0.2";
} else if (pkg.devDependencies) {
    pkg.devDependencies["react"] = "17.0.2";
    pkg.devDependencies["react-dom"] = "17.0.2";
}

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('已修复package.json中的依赖版本');
EOF

node fix_deps.js
rm -f fix_deps.js

# 10. 安装青龙面板依赖
echo "步骤10/13：安装青龙面板依赖..."
echo "这可能需要一些时间，请耐心等待..."

# 清理缓存
rm -rf node_modules
rm -rf ~/.pnpm-store
rm -f package-lock.json
rm -f pnpm-lock.yaml
rm -f yarn.lock

# 安装依赖（尝试多种方式）
install_dependencies() {
    echo "尝试使用pnpm安装依赖..."
    pnpm install --loglevel=error && return 0
    
    echo "pnpm安装失败，尝试使用npm安装（legacy模式）..."
    npm cache clean --force
    npm install --legacy-peer-deps --loglevel=error && return 0
    
    echo "npm安装失败，尝试使用cnpm..."
    npm install -g cnpm --registry=https://registry.npmmirror.com
    cnpm install && return 0
    
    return 1
}

if install_dependencies; then
    echo "✓ 依赖安装成功"
else
    echo "✗ 依赖安装失败，尝试最小化安装..."
    # 最小化安装核心依赖
    npm install express sqlite3 redis
    echo "⚠️ 依赖安装不完整，部分功能可能受限"
fi

# 11. 创建启动脚本
echo "步骤11/13：创建启动脚本..."

# 创建服务管理脚本
cat > ~/ql-manage.sh << 'EOF'
#!/bin/bash
# 青龙面板服务管理脚本
# 版本：v2.1.0

QL_DIR="$HOME/qinglong"
QL_PORT=5700
VERSION="v2.1.0"

case "$1" in
    start)
        echo "启动青龙面板服务..."
        
        # 启动Redis
        if ! redis-cli ping > /dev/null 2>&1; then
            echo "启动Redis..."
            sudo redis-server /etc/redis/redis.conf --daemonize yes
            sleep 2
        fi
        
        # 启动青龙面板
        cd "$QL_DIR"
        if [ ! -d "node_modules" ]; then
            echo "未找到依赖，正在安装..."
            pnpm install --loglevel=error || npm install --legacy-peer-deps --loglevel=error
        fi
        
        if pgrep -f "src/main.js" > /dev/null; then
            echo "青龙面板已在运行 (PID: $(pgrep -f "src/main.js"))"
        else
            echo "启动青龙面板..."
            nohup pnpm start > ~/qinglong.log 2>&1 &
            sleep 5
            
            if pgrep -f "src/main.js" > /dev/null; then
                echo "✓ 青龙面板启动成功"
                echo "访问地址: http://localhost:${QL_PORT}"
            else
                echo "✗ 青龙面板启动失败"
                echo "查看日志: tail -f ~/qinglong.log"
                exit 1
            fi
        fi
        ;;
    
    stop)
        echo "停止青龙面板服务..."
        pkill -f "src/main.js" && echo "青龙面板已停止" || echo "青龙面板未在运行"
        ;;
    
    restart)
        echo "重启青龙面板服务..."
        $0 stop
        sleep 2
        $0 start
        ;;
    
    status)
        echo "=== 青龙面板服务状态 ==="
        echo "版本: $VERSION"
        echo ""
        
        # 检查Redis
        echo "Redis状态:"
        if redis-cli ping > /dev/null 2>&1; then
            echo "  ✓ 运行正常"
        else
            echo "  ✗ 未运行"
        fi
        
        echo ""
        echo "青龙面板状态:"
        QL_PID=$(pgrep -f "src/main.js")
        if [ -n "$QL_PID" ]; then
            echo "  ✓ 运行中 (PID: $QL_PID)"
            echo "  访问地址: http://localhost:${QL_PORT}"
            
            # 检查端口
            if netstat -tln 2>/dev/null | grep -q ":${QL_PORT}"; then
                echo "  端口状态: ✓ 5700端口监听正常"
            else
                echo "  端口状态: ✗ 5700端口未监听"
            fi
            
            # 检查进程运行时间
            if [ -f "/proc/$QL_PID" ]; then
                UPTIME=$(ps -o etime= -p "$QL_PID" | xargs)
                echo "  运行时间: $UPTIME"
            fi
        else
            echo "  ✗ 未运行"
        fi
        
        echo ""
        echo "磁盘使用:"
        du -sh "$QL_DIR" 2>/dev/null | awk '{print "  青龙目录: "$1}'
        ;;
    
    logs)
        echo "显示青龙面板日志:"
        if [ -f ~/qinglong.log ]; then
            tail -50 ~/qinglong.log
        else
            echo "日志文件不存在"
        fi
        ;;
    
    update)
        echo "更新青龙面板..."
        cd "$QL_DIR"
        git pull
        pnpm install --loglevel=error || npm install --legacy-peer-deps
        $0 restart
        ;;
    
    resetdb)
        echo "重置数据库（危险操作！）"
        read -p "确定要重置数据库吗？所有数据将丢失！(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            $0 stop
            rm -f "$QL_DIR/db/qinglong.db"
            echo "数据库已重置"
            $0 start
        else
            echo "已取消"
        fi
        ;;
    
    version)
        echo "青龙面板管理脚本 $VERSION"
        echo "青龙面板目录: $QL_DIR"
        echo "安装时间: $(stat -c %y "$0" 2>/dev/null | cut -d' ' -f1 || echo "未知")"
        ;;
    
    *)
        echo "青龙面板管理脚本 $VERSION"
        echo "用法: $0 {start|stop|restart|status|logs|update|resetdb|version}"
        echo ""
        echo "命令:"
        echo "  start    启动青龙面板"
        echo "  stop     停止青龙面板"
        echo "  restart  重启青龙面板"
        echo "  status   查看服务状态"
        echo "  logs     查看运行日志"
        echo "  update   更新青龙面板"
        echo "  resetdb  重置数据库（危险！）"
        echo "  version  显示版本信息"
        exit 1
        ;;
esac
EOF

chmod +x ~/ql-manage.sh

# 12. 创建自动启动配置
echo "步骤12/13：创建自动启动配置..."
cat >> ~/.bashrc << 'EOF'

# 青龙面板自动启动配置
if [ -f ~/ql-manage.sh ]; then
    # 检查是否禁用自动启动
    if [ ! -f ~/.qinglong_no_auto_start ]; then
        # 延迟启动，避免干扰其他初始化
        (sleep 5 && ~/ql-manage.sh status >/dev/null 2>&1) &
    fi
    
    # 添加命令别名
    alias ql='~/ql-manage.sh'
    alias ql-start='~/ql-manage.sh start'
    alias ql-stop='~/ql-manage.sh stop'
    alias ql-status='~/ql-manage.sh status'
    alias ql-logs='~/ql-manage.sh logs'
    alias ql-restart='~/ql-manage.sh restart'
fi
EOF

# 13. 首次启动服务
echo "步骤13/13：首次启动服务..."
# 启动Redis
sudo redis-server /etc/redis/redis.conf --daemonize yes
sleep 2

# 启动青龙面板
cd ~/qinglong
nohup pnpm start > ~/qinglong.log 2>&1 &
sleep 10

# 显示安装结果
echo ""
echo "=========================================="
echo "          安装完成！                     "
echo "=========================================="
echo ""
echo "✅ 服务状态:"
~/ql-manage.sh status
echo ""
echo "📋 管理命令:"
echo "  ql start     # 启动青龙面板"
echo "  ql stop      # 停止青龙面板"
echo "  ql restart   # 重启青龙面板"
echo "  ql status    # 查看服务状态"
echo "  ql logs      # 查看运行日志"
echo "  ql update    # 更新青龙面板"
echo "  ql version   # 显示版本信息"
echo ""
echo "🌐 访问地址:"
echo "  http://localhost:5700"
echo ""
echo "📁 重要目录:"
echo "  安装目录: ~/qinglong"
echo "  数据库: ~/qinglong/db/"
echo "  配置文件: ~/qinglong/config/"
echo "  日志文件: ~/qinglong.log"
echo ""
echo "⚙️  配置说明:"
echo "  1. 首次访问需要设置管理员账号密码"
echo "  2. 禁用自动启动: touch ~/.qinglong_no_auto_start"
echo "  3. 启用自动启动: rm ~/.qinglong_no_auto_start"
echo ""
echo "🔧 故障排除:"
echo "  1. 如果无法访问: ql logs 查看错误信息"
echo "  2. 端口冲突: 修改 ~/qinglong/.env 中的 PORT"
echo "  3. 重新安装依赖: cd ~/qinglong && rm -rf node_modules && pnpm install"
echo ""
echo "=========================================="
echo "脚本版本: v2.1.0"
echo "安装时间: $(date)"
echo "=========================================="
