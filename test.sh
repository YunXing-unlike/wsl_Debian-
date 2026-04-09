#!/bin/bash

# 青龙面板WSL1 Ubuntu 20.04一键安装脚本（无systemd版）
# 作者：元宝
# 日期：2026-04-10
# 说明：适用于WSL1环境，无systemd依赖，使用SQLite数据库

set -e

echo "=========================================="
echo "  青龙面板WSL1 Ubuntu 20.04一键安装脚本   "
echo "=========================================="
echo "注意：本脚本专为WSL1设计，无systemd依赖"
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

# 4. 安装Node.js 20.x（最新LTS版本）
echo "步骤4/12：安装Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"

# 5. 安装Python3及相关工具
echo "步骤5/12：安装Python3及相关工具..."
sudo apt install -y python3 python3-pip python3-venv python3-dev
echo "Python3版本: $(python3 --version)"

# 配置pip国内源
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# 6. 安装SQLite3（青龙面板默认数据库）
echo "步骤6/12：安装SQLite3数据库..."
sudo apt install -y sqlite3 libsqlite3-dev
sqlite3 --version

# 7. 安装Redis（编译安装，避免systemd依赖）
echo "步骤7/12：安装Redis（编译安装）..."
sudo apt install -y build-essential tcl

# 下载最新稳定版Redis
REDIS_VERSION="7.2.4"
cd /tmp
wget https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
tar xzf redis-${REDIS_VERSION}.tar.gz
cd redis-${REDIS_VERSION}
make -j$(nproc)
sudo make install

# 创建Redis配置目录
sudo mkdir -p /etc/redis
sudo cp redis.conf /etc/redis/

# 配置Redis以守护进程方式运行（无systemd）
sudo sed -i 's/^daemonize no/daemonize yes/' /etc/redis/redis.conf
sudo sed -i 's/^supervised.*/supervised no/' /etc/redis/redis.conf
sudo sed -i 's/^bind 127.0.0.1/# bind 127.0.0.1/' /etc/redis/redis.conf
sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# 8. 安装进程管理工具pm2
echo "步骤8/12：安装进程管理工具pm2..."
sudo npm install -g pm2
sudo npm install -g pnpm
npm config set registry https://registry.npmmirror.com

# 9. 克隆青龙面板仓库
echo "步骤9/12：克隆青龙面板仓库..."
cd ~
if [ -d "qinglong" ]; then
    echo "青龙目录已存在，跳过克隆..."
    cd qinglong
    git pull
else
    git clone https://github.com/whyour/qinglong.git
    cd qinglong
fi

# 10. 安装青龙面板依赖
echo "步骤10/12：安装青龙面板依赖..."
npm install

# 11. 创建WSL1专用启动脚本
echo "步骤11/12：创建WSL1专用启动脚本..."

# 创建Redis启动脚本
cat > ~/start-redis.sh << 'EOF'
#!/bin/bash
# 启动Redis（无systemd方式）
echo "启动Redis服务..."
sudo redis-server /etc/redis/redis.conf --daemonize yes
sleep 2
redis-cli ping
if [ $? -eq 0 ]; then
    echo "✓ Redis启动成功"
else
    echo "✗ Redis启动失败"
    exit 1
fi
EOF

chmod +x ~/start-redis.sh

# 创建青龙面板启动脚本
cat > ~/start-qinglong.sh << 'EOF'
#!/bin/bash
# 启动青龙面板（WSL1专用）
echo "启动青龙面板服务..."

# 检查Redis是否运行
if ! redis-cli ping > /dev/null 2>&1; then
    echo "Redis未运行，正在启动..."
    ~/start-redis.sh
fi

# 启动青龙面板
cd ~/qinglong
pm2 start src/main.js --name qinglong
pm2 save

echo "青龙面板启动完成！"
echo "访问地址：http://localhost:5700"
EOF

chmod +x ~/start-qinglong.sh

# 创建停止脚本
cat > ~/stop-qinglong.sh << 'EOF'
#!/bin/bash
# 停止青龙面板
echo "停止青龙面板服务..."
cd ~/qinglong
pm2 stop qinglong
pm2 delete qinglong
echo "青龙面板已停止"
EOF

chmod +x ~/stop-qinglong.sh

# 创建重启脚本
cat > ~/restart-qinglong.sh << 'EOF'
#!/bin/bash
# 重启青龙面板
echo "重启青龙面板服务..."
~/stop-qinglong.sh
sleep 2
~/start-qinglong.sh
EOF

chmod +x ~/restart-qinglong.sh

# 12. 创建WSL启动自动运行脚本
echo "步骤12/12：创建WSL启动自动运行脚本..."
cat > ~/.bashrc_qinglong << 'EOF'
# 青龙面板WSL1自动启动配置
if [ ! -f ~/.qinglong_auto_start_disable ]; then
    echo "检测到WSL启动，正在检查青龙面板服务..."
    
    # 检查Redis是否运行
    if ! redis-cli ping > /dev/null 2>&1; then
        echo "启动Redis服务..."
        sudo redis-server /etc/redis/redis.conf --daemonize yes > /dev/null 2>&1
    fi
    
    # 检查青龙面板是否运行
    if ! pm2 list | grep -q "qinglong"; then
        echo "启动青龙面板..."
        cd ~/qinglong
        pm2 start src/main.js --name qinglong > /dev/null 2>&1
        pm2 save > /dev/null 2>&1
    fi
    
    echo "青龙面板服务状态："
    pm2 list | grep -A2 "qinglong"
fi
EOF

# 添加到.bashrc
if ! grep -q "bashrc_qinglong" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# 青龙面板自动启动" >> ~/.bashrc
    echo "source ~/.bashrc_qinglong" >> ~/.bashrc
fi

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
echo "   ~/start-qinglong.sh    # 启动青龙面板"
echo "   ~/stop-qinglong.sh     # 停止青龙面板"
echo "   ~/restart-qinglong.sh  # 重启青龙面板"
echo "   ~/start-redis.sh       # 启动Redis"
echo ""
echo "4. 禁用自动启动："
echo "   touch ~/.qinglong_auto_start_disable"
echo ""
echo "5. 查看运行状态："
echo "   pm2 status              # 查看进程状态"
echo "   pm2 logs qinglong       # 查看青龙面板日志"
echo "   redis-cli ping          # 检查Redis状态"
echo ""
echo "6. 安装常用依赖："
echo "   登录青龙面板后，进入【依赖管理】安装："
echo "   Node.js: axios crypto-js jsdom date-fns"
echo "   Python3: requests canvas ping3 jieba"
echo ""
echo "=========================================="
echo "数据库说明："
echo "- 使用SQLite3作为默认数据库，无需额外配置"
echo "- 数据文件位置：~/qinglong/db/"
echo "- Redis用于缓存和会话管理"
echo "=========================================="
