#!/bin/bash

# 青龙面板WSL1 Ubuntu 20.04一键安装脚本（修正版）
# 解决React版本冲突问题
# 作者：元宝
# 日期：2026-04-10

set -e

echo "=========================================="
echo "  青龙面板WSL1 Ubuntu 20.04一键安装脚本   "
echo "=========================================="
echo "注意：本脚本专为WSL1设计，解决依赖冲突问题"
echo "=========================================="

# 1. 配置国内源（阿里云源）
echo "步骤1/12：配置阿里云国内源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo sed -i "s@http://.*archive.ubuntu.com@https://mirrors.aliyun.com@g" /etc/apt/sources.list
sudo sed -i "s@http://.*security.ubuntu.com@https://mirrors.aliyun.com@g" /etc/apt/sources.list

# 2. 更新系统
echo "步骤2/12：更新系统软件包..."
sudo apt update
sudo apt upgrade -y

# 3. 安装基础工具
echo "步骤3/12：安装基础工具..."
sudo apt install -y curl wget git vim htop net-tools build-essential

# 4. 安装nvm（Node版本管理器）
echo "步骤4/12：安装nvm（Node版本管理器）..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# 加载nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# 5. 安装Node.js 16.x（青龙面板兼容版本）
echo "步骤5/12：安装Node.js 16.x（青龙面板兼容版本）..."
nvm install 16.20.2
nvm use 16.20.2
nvm alias default 16.20.2
echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"

# 6. 安装Python3及相关工具
echo "步骤6/12：安装Python3及相关工具..."
sudo apt install -y python3 python3-pip python3-venv python3-dev
echo "Python3版本: $(python3 --version)"

# 配置pip国内源
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# 7. 安装SQLite3
echo "步骤7/12：安装SQLite3数据库..."
sudo apt install -y sqlite3 libsqlite3-dev
sqlite3 --version

# 8. 安装Redis
echo "步骤8/12：安装Redis（编译安装）..."
sudo apt install -y build-essential tcl

# 下载Redis
REDIS_VERSION="7.2.4"
cd /tmp
wget https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
tar xzf redis-${REDIS_VERSION}.tar.gz
cd redis-${REDIS_VERSION}
make -j$(nproc)
sudo make install

# 配置Redis
sudo mkdir -p /etc/redis
sudo cp redis.conf /etc/redis/
sudo sed -i 's/^daemonize no/daemonize yes/' /etc/redis/redis.conf
sudo sed -i 's/^supervised.*/supervised no/' /etc/redis/redis.conf
sudo sed -i 's/^bind 127.0.0.1/# bind 127.0.0.1/' /etc/redis/redis.conf
sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# 9. 安装pnpm（替代npm，更好的依赖管理）
echo "步骤9/12：安装pnpm..."
npm install -g pnpm@8.15.0
pnpm config set registry https://registry.npmmirror.com
echo "pnpm版本: $(pnpm --version)"

# 10. 克隆青龙面板仓库
echo "步骤10/12：克隆青龙面板仓库..."
cd ~
if [ -d "qinglong" ]; then
    echo "青龙目录已存在，跳过克隆..."
else
    git clone https://github.com/whyour/qinglong.git
fi

cd qinglong

# 11. 安装青龙面板依赖（使用pnpm解决版本冲突）
echo "步骤11/12：安装青龙面板依赖..."
echo "注意：使用pnpm安装，解决React版本冲突..."

# 先清理可能的缓存
rm -rf node_modules
rm -rf pnpm-lock.yaml

# 使用pnpm安装依赖
pnpm install --prod

# 如果pnpm安装失败，尝试使用npm的legacy模式
if [ $? -ne 0 ]; then
    echo "pnpm安装失败，尝试使用npm legacy模式..."
    npm cache clean --force
    rm -rf node_modules
    npm install --legacy-peer-deps
fi

# 12. 创建启动脚本
echo "步骤12/12：创建启动脚本..."

# 创建Redis启动脚本
cat > ~/start-redis.sh << 'EOF'
#!/bin/bash
# 启动Redis
echo "启动Redis服务..."
if ! redis-cli ping > /dev/null 2>&1; then
    sudo redis-server /etc/redis/redis.conf --daemonize yes
    sleep 2
    if redis-cli ping > /dev/null 2>&1; then
        echo "✓ Redis启动成功"
    else
        echo "✗ Redis启动失败"
        exit 1
    fi
else
    echo "✓ Redis已在运行"
fi
EOF

chmod +x ~/start-redis.sh

# 创建青龙面板启动脚本
cat > ~/start-qinglong.sh << 'EOF'
#!/bin/bash
# 启动青龙面板
echo "启动青龙面板服务..."

# 检查并启动Redis
~/start-redis.sh

# 启动青龙面板
cd ~/qinglong
if ! pnpm list 2>/dev/null | grep -q "qinglong"; then
    echo "正在启动青龙面板..."
    pnpm start
else
    echo "青龙面板已在运行"
fi
EOF

chmod +x ~/start-qinglong.sh

# 创建停止脚本
cat > ~/stop-qinglong.sh << 'EOF'
#!/bin/bash
# 停止青龙面板
echo "停止青龙面板服务..."
cd ~/qinglong
if pnpm list 2>/dev/null | grep -q "qinglong"; then
    pnpm stop
    echo "青龙面板已停止"
else
    echo "青龙面板未在运行"
fi
EOF

chmod +x ~/stop-qinglong.sh

# 创建PM2管理脚本
cat > ~/pm2-manage.sh << 'EOF'
#!/bin/bash
# PM2管理脚本
cd ~/qinglong

case "$1" in
    start)
        pm2 start ecosystem.config.js
        pm2 save
        echo "青龙面板已通过PM2启动"
        ;;
    stop)
        pm2 stop qinglong
        echo "青龙面板已停止"
        ;;
    restart)
        pm2 restart qinglong
        echo "青龙面板已重启"
        ;;
    status)
        pm2 status
        ;;
    logs)
        pm2 logs qinglong
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

chmod +x ~/pm2-manage.sh

# 首次启动服务
echo "首次启动青龙面板服务..."
~/start-redis.sh
~/start-qinglong.sh

echo "=========================================="
echo "          安装完成！请按以下步骤操作：       "
echo "=========================================="
echo ""
echo "1. 访问青龙面板："
echo "   在浏览器中打开：http://localhost:5700"
echo ""
echo "2. 初始设置："
echo "   首次访问需要设置管理员账号和密码"
echo ""
echo "3. 管理命令："
echo "   ~/start-qinglong.sh     # 启动青龙面板"
echo "   ~/stop-qinglong.sh      # 停止青龙面板"
echo "   ~/pm2-manage.sh start   # PM2启动（推荐）"
echo "   ~/pm2-manage.sh status  # 查看状态"
echo "   ~/pm2-manage.sh logs    # 查看日志"
echo ""
echo "4. 常用依赖安装："
echo "   登录面板后，进入【依赖管理】安装："
echo ""
echo "   Node.js依赖："
echo "   axios crypto-js jsdom date-fns"
echo "   tough-cookie tslib ws@7.4.3"
echo "   ts-md5 jieba fs form-data"
echo "   json5 global-agent png-js"
echo ""
echo "   Python3依赖："
echo "   requests canvas ping3 jieba"
echo "   PyExecJS aiohttp"
echo ""
echo "5. 重启WSL后启动："
echo "   运行: ~/start-redis.sh && ~/start-qinglong.sh"
echo ""
echo "=========================================="
echo "问题解决："
echo "1. 如果无法访问面板，检查端口：netstat -tlnp | grep 5700"
echo "2. 查看日志：cd ~/qinglong && pnpm logs"
echo "3. 重置依赖：rm -rf node_modules && pnpm install"
echo "=========================================="
