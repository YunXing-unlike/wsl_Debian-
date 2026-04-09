#!/bin/bash

# 青龙面板WSL1 Ubuntu 20.04一键安装脚本
# 作者：元宝
# 日期：2026-04-10
# 说明：适用于WSL1环境，非Docker部署

set -e

echo "=========================================="
echo "  青龙面板WSL1 Ubuntu 20.04一键安装脚本   "
echo "=========================================="

# 1. 配置国内源（阿里云源）
echo "步骤1/11：配置阿里云国内源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo sed -i "s@http://.*archive.ubuntu.com@https://mirrors.aliyun.com@g" /etc/apt/sources.list
sudo sed -i "s@http://.*security.ubuntu.com@https://mirrors.aliyun.com@g" /etc/apt/sources.list

# 2. 更新系统
echo "步骤2/11：更新系统软件包..."
sudo apt update
sudo apt upgrade -y

# 3. 安装基础工具
echo "步骤3/11：安装基础工具..."
sudo apt install -y curl wget git vim htop net-tools build-essential

# 4. 安装Node.js 20.x（最新LTS版本）
echo "步骤4/11：安装Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node --version
npm --version

# 5. 安装Python3及相关工具
echo "步骤5/11：安装Python3及相关工具..."
sudo apt install -y python3 python3-pip python3-venv python3-dev
python3 --version

# 配置pip国内源
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# 6. 安装Redis
echo "步骤6/11：安装Redis..."
sudo apt install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server

# 7. 安装MySQL（可选，青龙面板推荐）
echo "步骤7/11：安装MySQL 8.0..."
sudo apt install -y mysql-server
sudo systemctl enable mysql
sudo systemctl start mysql

# 初始化MySQL（设置root密码为空，便于青龙面板连接）
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 8. 安装进程管理工具pm2
echo "步骤8/11：安装进程管理工具pm2..."
sudo npm install -g pm2
sudo npm install -g pnpm

# 9. 克隆青龙面板仓库
echo "步骤9/11：克隆青龙面板仓库..."
cd ~
if [ -d "qinglong" ]; then
    echo "青龙目录已存在，跳过克隆..."
else
    git clone https://github.com/whyour/qinglong.git
fi

cd qinglong

# 10. 安装青龙面板依赖
echo "步骤10/11：安装青龙面板依赖..."
npm config set registry https://registry.npmmirror.com
npm install

# 11. 配置环境并启动服务
echo "步骤11/11：配置环境并启动服务..."

# 创建环境配置文件
if [ ! -f ".env" ]; then
    cp .env.example .env
    # 修改默认配置
    sed -i 's/127.0.0.1/0.0.0.0/g' .env  # 允许外部访问
fi

# 启动青龙面板
pm2 start src/main.js --name qinglong
pm2 save

# 设置WSL启动时自动运行（针对WSL1的特殊处理）
cat > ~/start-qinglong.sh << 'EOF'
#!/bin/bash
cd ~/qinglong
pm2 resurrect
EOF

chmod +x ~/start-qinglong.sh

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
echo "3. 安装常用依赖："
echo "   登录后进入【依赖管理】，安装以下依赖："
echo ""
echo "   Node.js依赖："
echo "   axios crypto-js jsdom date-fns tough-cookie"
echo "   tslib ws@7.4.3 ts-md5 jieba fs form-data"
echo "   json5 global-agent png-js @types/node"
echo "   require typescript js-base64 moment"
echo ""
echo "   Python3依赖："
echo "   requests canvas ping3 jieba PyExecJS aiohttp"
echo ""
echo "4. WSL1启动青龙面板："
echo "   每次启动WSL后，运行：~/start-qinglong.sh"
echo ""
echo "5. 查看运行状态："
echo "   pm2 status          # 查看进程状态"
echo "   pm2 logs qinglong   # 查看日志"
echo ""
echo "=========================================="
echo "注意：由于WSL1限制，青龙面板的定时任务可能"
echo "      在WSL关闭时暂停，建议保持WSL运行状态。"
echo "=========================================="
