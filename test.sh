#!/bin/bash

# 青龙面板一键安装脚本 for WSL1 Ubuntu 20.04
# 作者：元宝
# 日期：2026-04-09

set -e

echo "========================================="
echo "青龙面板一键安装脚本"
echo "系统要求：WSL1 Ubuntu 20.04"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本：sudo bash $0"
    exit 1
fi

# 1. 备份并配置阿里云源
echo "步骤1/11：配置阿里云软件源..."
cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)

cat > /etc/apt/sources.list << 'EOF'
# 阿里云 Ubuntu 20.04 (focal) 镜像源
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# 2. 更新系统包
echo "步骤2/11：更新系统包..."
apt update && apt upgrade -y

# 3. 安装基础工具
echo "步骤3/11：安装基础工具..."
apt install -y git wget curl vim net-tools build-essential

# 4. 安装Node.js 16.x（青龙面板需要Node.js 14+）
echo "步骤4/11：安装Node.js 16.x..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt install -y nodejs

# 验证Node.js安装
node --version
npm --version

# 5. 安装Python3和pip
echo "步骤5/11：安装Python3和pip..."
apt install -y python3 python3-pip python3-venv

# 验证Python安装
python3 --version
pip3 --version

# 6. 安装pnpm（青龙面板推荐使用）
echo "步骤6/11：安装pnpm..."
npm install -g pnpm

# 7. 通过npm安装青龙面板
echo "步骤7/11：安装青龙面板..."
npm install -g @whyour/qinglong

# 8. 创建青龙面板目录结构
echo "步骤8/11：创建目录结构..."
QL_DIR="/opt/qinglong"
mkdir -p $QL_DIR
cd $QL_DIR

# 创建必要的子目录
mkdir -p data/{config,scripts,log,db,upload,repo,raw}

# 9. 配置环境变量
echo "步骤9/11：配置环境变量..."
cat > /etc/profile.d/qinglong.sh << 'EOF'
export QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
export QL_DATA_DIR="/opt/qinglong/data"
export PATH=$PATH:$QL_DIR/bin
EOF

source /etc/profile.d/qinglong.sh

# 创建.env配置文件
cat > $QL_DIR/.env << 'EOF'
# 青龙面板配置文件
PORT=5700
QL_DIR=/usr/lib/node_modules/@whyour/qinglong
QL_DATA_DIR=/opt/qinglong/data
QL_BASE_URL=/
TZ=Asia/Shanghai
EOF

# 10. 安装青龙面板依赖
echo "步骤10/11：安装青龙面板依赖..."

# 配置npm镜像源（加速下载）
npm config set registry https://registry.npmmirror.com/

# 配置pip镜像源
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# 进入青龙面板目录安装依赖
cd /usr/lib/node_modules/@whyour/qinglong

# 安装项目依赖
npm install

# 安装青龙面板常用的Node.js依赖
echo "安装Node.js依赖..."
npm install -g crypto-js prettytable dotenv jsdom date-fns tough-cookie tslib ws@7.4.3 ts-md5 jsdom-g jieba fs form-data json5 global-agent png-js @types/node require typescript js-base64 axios moment ds

# 安装Python3依赖
echo "安装Python3依赖..."
pip3 install requests canvas ping3 jieba aiohttp

# 安装Linux系统依赖
echo "安装Linux系统依赖..."
apt install -y libxml2-dev libxslt1-dev python3-dev gcc

# 11. 启动青龙面板服务
echo "步骤11/11：配置启动服务..."

# 创建systemd服务文件（如果可用）
if [ -d /etc/systemd/system ]; then
    cat > /etc/systemd/system/qinglong.service << 'EOF'
[Unit]
Description=Qinglong Panel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/lib/node_modules/@whyour/qinglong
EnvironmentFile=/opt/qinglong/.env
ExecStart=/usr/bin/node /usr/lib/node_modules/@whyour/qinglong/src/main.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qinglong
    systemctl start qinglong
    echo "青龙面板已配置为systemd服务"
else
    # WSL1可能没有systemd，使用pm2管理
    npm install -g pm2
    pm2 start /usr/lib/node_modules/@whyour/qinglong/src/main.js --name qinglong
    pm2 save
    pm2 startup
    echo "青龙面板已使用pm2启动"
fi

# 输出安装完成信息
echo "========================================="
echo "青龙面板安装完成！"
echo "========================================="
echo "访问地址：http://localhost:5700"
echo "数据目录：/opt/qinglong/data"
echo ""
echo "重要提示："
echo "1. 首次访问请按照页面提示完成初始化设置"
echo "2. 如需添加更多依赖，请登录面板后在【依赖管理】中添加"
echo "3. 常用依赖已预安装，包括："
echo "   - Node.js: crypto-js, axios, ws@7.4.3等"
echo "   - Python3: requests, aiohttp, jieba等"
echo "4. 查看服务状态："
if [ -d /etc/systemd/system ]; then
    echo "   sudo systemctl status qinglong"
else
    echo "   pm2 status"
fi
echo "========================================="
