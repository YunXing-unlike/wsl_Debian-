#!/bin/bash
# 青龙面板WSL1 Ubuntu 20.04一键安装脚本
# 版本：v3.0.0
# 作者：元宝
# 日期：2026-04-10
# 描述：专为WSL1环境优化，解决网络问题和依赖冲突

set -e

echo "=========================================="
echo "  青龙面板WSL1 Ubuntu 20.04一键安装脚本  "
echo "  版本：v3.0.0                           "
echo "=========================================="

# 0. 环境检测
echo "检测系统环境..."
OS_INFO=$(lsb_release -ds 2>/dev/null || echo "Ubuntu 20.04")
echo "操作系统: $OS_INFO"
echo "WSL版本: $(uname -r)"

# 1. 配置国内源
echo "步骤1/12：配置国内源..."
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
echo "步骤2/12：更新系统软件包..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git vim htop net-tools build-essential ca-certificates

# 3. 安装Node.js 16.x（使用二进制包）
echo "步骤3/12：安装Node.js 16.x..."
NODE_VERSION="16.20.2"
ARCH=$(uname -m)

echo "检测系统架构: $ARCH"
if [ "$ARCH" = "x86_64" ]; then
    ARCH="x64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
else
    echo "未知架构，使用x64"
    ARCH="x64"
fi

echo "下载Node.js v${NODE_VERSION} for ${ARCH}..."
cd /tmp
wget https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz
tar -xJf node-v${NODE_VERSION}-linux-${ARCH}.tar.xz
sudo cp -r node-v${NODE_VERSION}-linux-${ARCH}/* /usr/local/
rm -rf node-v${NODE_VERSION}-linux-${ARCH}*

# 验证安装
echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"

# 4. 配置npm国内源
echo "步骤4/12：配置npm国内源..."
npm config set registry https://registry.npmmirror.com
echo "npm registry已设置为: $(npm config get registry)"

# 5. 安装Python3
echo "步骤5/12：安装Python3及相关工具..."
sudo apt install -y python3 python3-pip python3-venv python3-dev python3-distutils
echo "Python3版本: $(python3 --version)"

# 配置pip国内源
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# 6. 安装SQLite3
echo "步骤6/12：安装SQLite3数据库..."
sudo apt install -y sqlite3 libsqlite3-dev
sqlite3 --version

# 7. 安装Redis
echo "步骤7/12：安装Redis..."
sudo apt install -y redis-server
# 配置Redis以无需systemd方式运行
sudo sed -i 's/^supervised systemd/supervised no/' /etc/redis/redis.conf
sudo sed -i 's/^bind 127.0.0.1/# bind 127.0.0.1/' /etc/redis/redis.conf
sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
sudo sed -i 's/^daemonize no/daemonize yes/' /etc/redis/redis.conf

# 8. 克隆青龙面板仓库
echo "步骤8/12：克隆青龙面板仓库..."
cd ~
if [ -d "qinglong" ]; then
    echo "青龙目录已存在，更新代码..."
    cd qinglong
    git stash
    git pull
else
    echo "克隆青龙面板仓库..."
    # 使用Gitee镜像
    git clone https://gitee.com/whyour/qinglong.git
    if [ ! -d "qinglong" ]; then
        echo "Gitee镜像失败，尝试GitHub..."
        git clone https://github.com/whyour/qinglong.git
    fi
    cd qinglong
fi

# 9. 修复React版本冲突
echo "步骤9/12：修复React版本冲突..."
# 创建修复脚本
cat > fix_react_version.js << 'EOF'
const fs = require('fs');
const path = require('path');

// 读取package.json
const pkgPath = path.join(__dirname, 'package.json');
let pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

console.log('当前React版本:', pkg.dependencies?.react || pkg.devDependencies?.react || '未找到');

// 强制使用React 17.0.2
if (!pkg.dependencies) pkg.dependencies = {};
pkg.dependencies["react"] = "17.0.2";
pkg.dependencies["react-dom"] = "17.0.2";

// 添加overrides解决子依赖冲突
if (!pkg.overrides) pkg.overrides = {};
pkg.overrides["react"] = "17.0.2";
pkg.overrides["react-dom"] = "17.0.2";

// 保存修改
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
console.log('已修复React版本为17.0.2');
EOF

node fix_react_version.js
rm -f fix_react_version.js

# 10. 安装青龙面板依赖
echo "步骤10/12：安装青龙面板依赖..."
echo "这可能需要一些时间，请耐心等待..."

# 清理缓存
rm -rf node_modules
rm -f package-lock.json
rm -f yarn.lock

# 使用npm安装依赖（强制使用legacy模式解决peer依赖冲突）
echo "使用npm安装依赖（legacy模式）..."
npm cache clean --force
npm install --legacy-peer-deps --loglevel=error

if [ $? -eq 0 ]; then
    echo "✓ 依赖安装成功"
else
    echo "尝试使用--force模式..."
    npm install --force --loglevel=error
    if [ $? -eq 0 ]; then
        echo "✓ 依赖安装成功（force模式）"
    else
        echo "✗ 依赖安装失败，尝试最小化安装..."
        # 安装核心依赖
        npm install express sqlite3 redis --legacy-peer-deps
        echo "⚠️ 依赖安装不完整，部分功能可能受限"
    fi
fi

# 11. 创建管理脚本
echo "步骤11/12：创建管理脚本..."

cat > ~/ql.sh << 'EOF'
#!/bin/bash
# 青龙面板管理脚本
# 版本：v3.0.0

QL_DIR="$HOME/qinglong"
QL_PORT=5700
VERSION="v3.0.0"

show_help() {
    echo "青龙面板管理脚本 $VERSION"
    echo "用法: $0 {start|stop|restart|status|logs|update|reset|version}"
    echo ""
    echo "命令:"
    echo "  start    启动青龙面板"
    echo "  stop     停止青龙面板"
    echo "  restart  重启青龙面板"
    echo "  status   查看服务状态"
    echo "  logs     查看运行日志"
    echo "  update   更新青龙面板"
    echo "  reset    重置安装（危险！）"
    echo "  version  显示版本信息"
    echo "  help     显示帮助信息"
}

start_service() {
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
        npm install --legacy-peer-deps --loglevel=error
    fi
    
    if pgrep -f "src/main.js" > /dev/null; then
        echo "青龙面板已在运行 (PID: $(pgrep -f "src/main.js"))"
    else
        echo "启动青龙面板..."
        nohup npm start > ~/qinglong.log 2>&1 &
        sleep 5
        
        if pgrep -f "src/main.js" > /dev/null; then
            echo "✓ 青龙面板启动成功"
            echo "访问地址: http://localhost:${QL_PORT}"
        else
            echo "✗ 青龙面板启动失败"
            echo "查看日志: tail -f ~/qinglong.log"
            return 1
        fi
    fi
}

stop_service() {
    echo "停止青龙面板服务..."
    pkill -f "src/main.js" 2>/dev/null && echo "青龙面板已停止" || echo "青龙面板未在运行"
}

show_status() {
    echo "=== 青龙面板服务状态 ==="
    echo "版本: $VERSION"
    echo "安装目录: $QL_DIR"
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
    else
        echo "  ✗ 未运行"
    fi
    
    echo ""
    echo "系统信息:"
    echo "  Node.js: $(node --version 2>/dev/null || echo '未安装')"
    echo "  npm: $(npm --version 2>/dev/null || echo '未安装')"
    echo "  Python3: $(python3 --version 2>/dev/null || echo '未安装')"
}

show_logs() {
    echo "显示青龙面板日志:"
    if [ -f ~/qinglong.log ]; then
        tail -50 ~/qinglong.log
    else
        echo "日志文件不存在"
    fi
}

update_service() {
    echo "更新青龙面板..."
    cd "$QL_DIR"
    git pull
    npm install --legacy-peer-deps
    echo "更新完成，请重启服务: $0 restart"
}

reset_service() {
    echo "警告：这将重置青龙面板安装！"
    read -p "确定要继续吗？所有数据将丢失！(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stop_service
        rm -rf "$QL_DIR"
        echo "已删除青龙面板目录"
        echo "请重新运行安装脚本"
    else
        echo "已取消"
    fi
}

# 主逻辑
case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 2
        start_service
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    update)
        update_service
        ;;
    reset)
        reset_service
        ;;
    version)
        echo "青龙面板管理脚本 $VERSION"
        echo "安装时间: $(stat -c %y "$0" 2>/dev/null | cut -d' ' -f1 || echo "未知")"
        ;;
    help|"")
        show_help
        ;;
    *)
        echo "错误：未知命令 '$1'"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x ~/ql.sh

# 创建快捷命令
cat >> ~/.bashrc << 'EOF'

# 青龙面板快捷命令
if [ -f ~/ql.sh ]; then
    alias ql='~/ql.sh'
    alias ql-start='~/ql.sh start'
    alias ql-stop='~/ql.sh stop'
    alias ql-status='~/ql.sh status'
    alias ql-logs='~/ql.sh logs'
    alias ql-restart='~/ql.sh restart'
    alias ql-update='~/ql.sh update'
    alias ql-version='~/ql.sh version'
    
    # 自动显示状态（可选）
    if [ ! -f ~/.no_ql_auto_status ]; then
        echo "青龙面板已安装，使用 'ql' 命令管理"
    fi
fi
EOF

# 12. 首次启动服务
echo "步骤12/12：首次启动服务..."
# 启动Redis
sudo redis-server /etc/redis/redis.conf --daemonize yes
sleep 2

# 启动青龙面板
cd ~/qinglong
nohup npm start > ~/qinglong.log 2>&1 &
sleep 15

# 显示安装结果
echo ""
echo "=========================================="
echo "          安装完成！                     "
echo "=========================================="
echo ""
echo "✅ 服务状态:"
~/ql.sh status
echo ""
echo "📋 管理命令:"
echo "  ql start     # 启动青龙面板"
echo "  ql stop      # 停止青龙面板"
echo "  ql restart   # 重启青龙面板"
echo "  ql status    # 查看服务状态"
echo "  ql logs      # 查看运行日志"
echo "  ql update    # 更新青龙面板"
echo "  ql version   # 显示版本信息"
echo "  ql help      # 显示帮助信息"
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
echo "  2. 禁用自动状态提示: touch ~/.no_ql_auto_status"
echo "  3. 查看详细日志: tail -f ~/qinglong.log"
echo ""
echo "🔧 故障排除:"
echo "  1. 如果无法访问: ql logs 查看错误信息"
echo "  2. 端口冲突: 修改 ~/qinglong/.env 中的 PORT"
echo "  3. 重新安装依赖: cd ~/qinglong && rm -rf node_modules && npm install --legacy-peer-deps"
echo "  4. 重置安装: ql reset (危险！会删除所有数据)"
echo ""
echo "=========================================="
echo "脚本版本: v3.0.0"
echo "安装时间: $(date)"
echo "=========================================="
