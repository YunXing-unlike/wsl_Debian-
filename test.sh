#!/bin/bash

# 青龙面板WSL1 Ubuntu 20.04一键安装脚本（国内源优化版）
# 解决网络问题和依赖冲突
# 作者：元宝
# 日期：2026-04-10

set -e

echo "=========================================="
echo "  青龙面板WSL1 Ubuntu 20.04一键安装脚本   "
echo "=========================================="
echo "使用国内源加速，解决网络问题"
echo "=========================================="

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

# 3. 直接安装Node.js 16.x（不使用nvm）
echo "步骤3/12：安装Node.js 16.x..."
# 使用NodeSource二进制包
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs

# 验证安装
echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"

# 4. 安装Python3及相关工具
echo "步骤4/12：安装Python3及相关工具..."
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
echo "步骤5/12：安装SQLite3数据库..."
sudo apt install -y sqlite3 libsqlite3-dev
sqlite3 --version

# 6. 安装Redis
echo "步骤6/12：安装Redis..."
sudo apt install -y redis-server
# 配置Redis以无需systemd方式运行
sudo sed -i 's/^supervised systemd/supervised no/' /etc/redis/redis.conf
sudo sed -i 's/^bind 127.0.0.1/# bind 127.0.0.1/' /etc/redis/redis.conf
sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# 7. 安装pnpm
echo "步骤7/12：安装pnpm..."
# 配置npm国内源
npm config set registry https://registry.npmmirror.com
npm config set disturl https://npmmirror.com/dist
# 安装pnpm
npm install -g pnpm@7.33.0
echo "pnpm版本: $(pnpm --version)"

# 8. 克隆青龙面板仓库（使用国内镜像）
echo "步骤8/12：克隆青龙面板仓库..."
cd ~
if [ -d "qinglong" ]; then
    echo "青龙目录已存在，更新代码..."
    cd qinglong
    git pull
else
    echo "克隆青龙面板仓库..."
    # 使用Gitee镜像
    git clone https://gitee.com/whyour/qinglong.git
    cd qinglong
fi

# 9. 安装青龙面板依赖
echo "步骤9/12：安装青龙面板依赖..."
# 清理可能的缓存
rm -rf node_modules
rm -f package-lock.json
rm -f pnpm-lock.yaml

# 配置pnpm国内源
pnpm config set registry https://registry.npmmirror.com

# 安装依赖
echo "正在安装依赖，这可能需要一些时间..."
pnpm install --loglevel=error

# 如果pnpm失败，使用npm的legacy模式
if [ $? -ne 0 ]; then
    echo "pnpm安装失败，尝试使用npm legacy模式..."
    npm cache clean --force
    rm -rf node_modules
    npm install --legacy-peer-deps --loglevel=error
fi

echo "依赖安装完成！"

# 10. 创建启动脚本
echo "步骤10/12：创建启动脚本..."

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

# 切换到青龙目录
cd ~/qinglong

# 检查是否已安装依赖
if [ ! -d "node_modules" ]; then
    echo "未找到node_modules，正在安装依赖..."
    pnpm install --loglevel=error || npm install --legacy-peer-deps --loglevel=error
fi

# 检查进程是否已在运行
if pgrep -f "qinglong" > /dev/null; then
    echo "✓ 青龙面板已在运行"
else
    echo "启动青龙面板..."
    # 使用青龙面板自带的启动脚本
    pnpm start &
    sleep 5
    if pgrep -f "qinglong" > /dev/null; then
        echo "✓ 青龙面板启动成功"
    else
        echo "✗ 青龙面板启动失败"
        exit 1
    fi
fi
EOF

chmod +x ~/start-qinglong.sh

# 创建停止脚本
cat > ~/stop-qinglong.sh << 'EOF'
#!/bin/bash
# 停止青龙面板
echo "停止青龙面板服务..."
cd ~/qinglong
pkill -f "qinglong" 2>/dev/null && echo "青龙面板已停止" || echo "青龙面板未在运行"
EOF

chmod +x ~/stop-qinglong.sh

# 创建状态检查脚本
cat > ~/check-status.sh << 'EOF'
#!/bin/bash
echo "=== 服务状态检查 ==="
echo "1. Redis状态:"
if redis-cli ping > /dev/null 2>&1; then
    echo "   ✓ Redis运行正常"
else
    echo "   ✗ Redis未运行"
fi

echo ""
echo "2. 青龙面板状态:"
if pgrep -f "qinglong" > /dev/null; then
    echo "   ✓ 青龙面板运行中 (PID: $(pgrep -f "qinglong"))"
    echo "   访问地址: http://localhost:5700"
else
    echo "   ✗ 青龙面板未运行"
fi

echo ""
echo "3. 端口监听状态:"
if netstat -tlnp 2>/dev/null | grep -q ":5700"; then
    echo "   ✓ 端口5700已被监听"
else
    echo "   ✗ 端口5700未被监听"
fi
EOF

chmod +x ~/check-status.sh

# 11. 创建PM2启动脚本（可选）
cat > ~/start-with-pm2.sh << 'EOF'
#!/bin/bash
# 使用PM2启动青龙面板
echo "使用PM2启动青龙面板..."

# 启动Redis
~/start-redis.sh

# 检查是否已安装pm2
if ! command -v pm2 &> /dev/null; then
    echo "安装pm2..."
    npm install -g pm2
fi

# 启动青龙面板
cd ~/qinglong
pm2 start src/main.js --name qinglong
pm2 save
pm2 startup

echo "青龙面板已通过PM2启动"
echo "查看状态: pm2 status"
echo "查看日志: pm2 logs qinglong"
EOF

chmod +x ~/start-with-pm2.sh

# 12. 首次启动
echo "步骤11/12：首次启动服务..."
~/start-redis.sh
sleep 2

echo "启动青龙面板..."
cd ~/qinglong
nohup pnpm start > ~/qinglong.log 2>&1 &
sleep 10

echo "步骤12/12：验证安装..."
~/check-status.sh

echo ""
echo "=========================================="
echo "          安装完成！请按以下步骤操作：       "
echo "=========================================="
echo ""
echo "1. 访问青龙面板："
echo "   在浏览器中打开：http://localhost:5700"
echo ""
echo "2. 如果无法访问，请等待1-2分钟让服务完全启动"
echo ""
echo "3. 管理命令："
echo "   ~/start-qinglong.sh     # 启动青龙面板"
echo "   ~/stop-qinglong.sh      # 停止青龙面板"
echo "   ~/check-status.sh       # 检查服务状态"
echo "   ~/start-with-pm2.sh     # 使用PM2启动（推荐）"
echo ""
echo "4. 查看日志："
echo "   tail -f ~/qinglong.log  # 查看青龙面板日志"
echo "   tail -f /var/log/redis/redis-server.log  # 查看Redis日志"
echo ""
echo "5. 常见问题解决："
echo "   a. 如果端口被占用：修改 ~/qinglong/.env 中的PORT"
echo "   b. 如果依赖安装失败：cd ~/qinglong && rm -rf node_modules && pnpm install"
echo "   c. 如果启动失败：查看 ~/qinglong/log 目录下的日志"
echo ""
echo "=========================================="
echo "安装日志已保存到: ~/qinglong.log"
echo "=========================================="
