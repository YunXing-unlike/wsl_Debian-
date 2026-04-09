#!/bin/bash

# 青龙面板一键安装脚本 for WSL1 Ubuntu 20.04
# 作者：元宝
# 日期：2026-04-09
# 修复版本：解决Node.js版本、git权限和版本兼容性问题

set -e

echo "========================================="
echo "青龙面板一键安装脚本 for WSL1 Ubuntu 20.04"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本：sudo bash $0"
    exit 1
fi

# 0. 检查系统信息
echo "步骤0/13：检查系统环境..."
echo "系统版本：$(lsb_release -d 2>/dev/null | cut -f2 || echo "Ubuntu 20.04")"
echo "WSL版本：WSL1（无Linux内核）"

# 1. 备份并配置阿里云源
echo "步骤1/13：配置阿里云软件源..."
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)
fi

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
echo "步骤2/13：更新系统包..."
apt update && apt upgrade -y

# 3. 安装基础工具
echo "步骤3/13：安装基础工具..."
apt install -y git wget curl vim net-tools build-essential ca-certificates gnupg

# 4. 安装Node.js 20.x（青龙面板需要Node.js 14+，最新版建议18+）
echo "步骤4/13：安装Node.js 20.x..."
# 清理旧的Node.js版本
apt remove -y nodejs npm 2>/dev/null || true
apt autoremove -y

# 安装Node.js 20.x（更稳定）
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 验证Node.js安装
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo "Node.js版本: $NODE_VERSION"
echo "npm版本: $NPM_VERSION"

if [[ ! "$NODE_VERSION" =~ ^v2[0-9]\. ]]; then
    echo "警告：Node.js版本可能过低，建议使用Node.js 20.x"
fi

# 5. 安装Python3和pip
echo "步骤5/13：安装Python3和pip..."
apt install -y python3 python3-pip python3-venv python3-dev

# 验证Python安装
python3 --version
pip3 --version

# 6. 配置npm和git使用国内镜像
echo "步骤6/13：配置npm和git镜像源..."
# 配置npm使用淘宝镜像
npm config set registry https://registry.npmmirror.com/
npm config set disturl https://npmmirror.com/dist
npm config set electron_mirror https://npmmirror.com/mirrors/electron/
npm config set sass_binary_site https://npmmirror.com/mirrors/node-sass/

# 配置git使用https（避免ssh密钥问题）
git config --global url."https://".insteadOf git://
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://gitcode.com/".insteadOf git@gitcode.com:

# 7. 安装pnpm（使用兼容版本）
echo "步骤7/13：安装pnpm..."
# 先更新npm到最新版本
npm install -g npm@latest

# 安装与Node.js 20兼容的pnpm版本
npm install -g pnpm@8.15.0

# 验证pnpm安装
pnpm --version

# 8. 安装青龙面板（使用npm直接安装最新版）
echo "步骤8/13：安装青龙面板..."
echo "正在从npm安装青龙面板最新版..."

# 方法1：尝试从npm直接安装
if npm install -g @whyour/qinglong@latest; then
    echo "青龙面板安装成功！"
    QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
else
    echo "npm安装失败，尝试从GitHub镜像安装..."
    
    # 方法2：从GitCode镜像克隆（国内访问更快）
    cd /tmp
    if git clone https://gitcode.com/whyour/qinglong.git; then
        echo "从GitCode克隆成功！"
        cd qinglong
        
        # 安装项目依赖
        npm install --registry=https://registry.npmmirror.com
        
        # 移动到全局位置
        QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
        mkdir -p "$(dirname "$QL_GLOBAL_DIR")"
        mv /tmp/qinglong "$QL_GLOBAL_DIR"
    else
        echo "GitCode克隆失败，尝试从GitHub备份源安装..."
        
        # 方法3：使用备份源
        cd /tmp
        git clone https://github.com/whyour/qinglong.git qinglong-backup
        cd qinglong-backup
        
        # 安装项目依赖
        npm install --registry=https://registry.npmmirror.com
        
        # 移动到全局位置
        QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
        mkdir -p "$(dirname "$QL_GLOBAL_DIR")"
        mv /tmp/qinglong-backup "$QL_GLOBAL_DIR"
    fi
fi

# 验证青龙面板安装
if [ -d "$QL_GLOBAL_DIR" ]; then
    echo "青龙面板已安装到：$QL_GLOBAL_DIR"
    
    # 检查版本
    if [ -f "$QL_GLOBAL_DIR/package.json" ]; then
        QL_VERSION=$(grep '"version"' "$QL_GLOBAL_DIR/package.json" | head -1 | awk -F: '{print $2}' | sed 's/[", ]//g')
        echo "青龙面板版本：v$QL_VERSION"
        
        # 检查是否为安全版本
        if [[ "$QL_VERSION" < "2.20.2" ]]; then
            echo "警告：当前版本(v$QL_VERSION)可能存在安全漏洞[1,2](@ref)"
            echo "建议升级到v2.20.2或更高版本"
        fi
    fi
else
    echo "错误：青龙面板安装失败！"
    exit 1
fi

# 9. 创建青龙面板目录结构
echo "步骤9/13：创建目录结构..."
QL_DIR="/opt/qinglong"
mkdir -p $QL_DIR
cd $QL_DIR

# 创建必要的子目录
mkdir -p data/{config,scripts,log,db,upload,repo,raw,deps,env}

# 设置权限
chmod -R 755 $QL_DIR/data

# 10. 配置环境变量
echo "步骤10/13：配置环境变量..."
cat > /etc/profile.d/qinglong.sh << 'EOF'
export QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
export QL_DATA_DIR="/opt/qinglong/data"
export PATH=$PATH:$QL_DIR/bin
export NODE_PATH="/usr/lib/node_modules"
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
NODE_PATH=/usr/lib/node_modules
EOF

# 11. 安装青龙面板依赖
echo "步骤11/13：安装青龙面板依赖..."

# 配置pip镜像源
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip3 config set global.extra-index-url https://mirrors.aliyun.com/pypi/simple/

# 进入青龙面板目录
cd "$QL_GLOBAL_DIR"

# 安装项目依赖
echo "安装青龙面板核心依赖..."
npm install --registry=https://registry.npmmirror.com --legacy-peer-deps

# 安装青龙面板常用的Node.js依赖
echo "安装Node.js依赖..."
npm install --registry=https://registry.npmmirror.com --legacy-peer-deps \
  crypto-js \
  prettytable \
  dotenv \
  jsdom \
  date-fns \
  tough-cookie \
  tslib \
  ws@7.4.3 \
  ts-md5 \
  jsdom-g \
  jieba \
  form-data \
  json5 \
  global-agent \
  png-js \
  @types/node \
  typescript \
  js-base64 \
  axios \
  moment \
  node-schedule \
  cron-parser \
  sqlite3

# 安装Python3依赖
echo "安装Python3依赖..."
pip3 install --upgrade pip
pip3 install requests canvas ping3 jieba aiohttp beautifulsoup4 lxml pycryptodome pillow

# 安装Linux系统依赖
echo "安装Linux系统依赖..."
apt install -y libxml2-dev libxslt1-dev gcc libffi-dev libssl-dev \
  libjpeg-dev libpng-dev libfreetype6-dev libsqlite3-dev

# 12. 创建启动脚本
echo "步骤12/13：创建启动脚本..."

# 创建启动脚本
cat > /usr/local/bin/start-qinglong << 'EOF'
#!/bin/bash
cd /usr/lib/node_modules/@whyour/qinglong
export PORT=5700
export QL_DIR=/usr/lib/node_modules/@whyour/qinglong
export QL_DATA_DIR=/opt/qinglong/data
export TZ=Asia/Shanghai
export NODE_PATH=/usr/lib/node_modules
node src/main.js
EOF

chmod +x /usr/local/bin/start-qinglong

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
Environment=PORT=5700
Environment=QL_DIR=/usr/lib/node_modules/@whyour/qinglong
Environment=QL_DATA_DIR=/opt/qinglong/data
Environment=TZ=Asia/Shanghai
Environment=NODE_PATH=/usr/lib/node_modules
ExecStart=/usr/bin/node src/main.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qinglong
    systemctl start qinglong
    echo "青龙面板已配置为systemd服务"
    
    # 等待服务启动
    sleep 3
    echo "服务状态："
    systemctl status qinglong --no-pager | head -20
else
    # WSL1可能没有systemd，使用pm2管理
    echo "检测到WSL1环境，使用pm2管理进程..."
    npm install -g pm2
    
    # 创建pm2配置文件
    cat > /opt/qinglong/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'qinglong',
    script: '/usr/lib/node_modules/@whyour/qinglong/src/main.js',
    cwd: '/usr/lib/node_modules/@whyour/qinglong',
    env: {
      PORT: 5700,
      QL_DIR: '/usr/lib/node_modules/@whyour/qinglong',
      QL_DATA_DIR: '/opt/qinglong/data',
      TZ: 'Asia/Shanghai',
      NODE_PATH: '/usr/lib/node_modules'
    },
    exec_mode: 'fork',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    error_file: '/opt/qinglong/data/log/error.log',
    out_file: '/opt/qinglong/data/log/out.log',
    log_file: '/opt/qinglong/data/log/combined.log',
    time: true
  }]
}
EOF
    
    pm2 start /opt/qinglong/ecosystem.config.js
    pm2 save
    
    # 创建pm2开机启动脚本
    pm2 startup | tail -1 > /tmp/pm2_startup.sh
    bash /tmp/pm2_startup.sh
    rm -f /tmp/pm2_startup.sh
    
    echo "青龙面板已使用pm2启动"
fi

# 13. 验证安装
echo "步骤13/13：验证安装..."
sleep 5

# 检查服务是否运行
if [ -d /etc/systemd/system ]; then
    if systemctl is-active --quiet qinglong; then
        echo "✓ 青龙面板服务正在运行"
    else
        echo "✗ 青龙面板服务未运行，请检查日志"
        systemctl status qinglong --no-pager
    fi
else
    if pm2 status | grep -q "qinglong"; then
        echo "✓ 青龙面板服务正在运行（pm2管理）"
    else
        echo "✗ 青龙面板服务未运行，请检查日志"
        pm2 status
    fi
fi

# 输出安装完成信息
echo "========================================="
echo "青龙面板安装完成！"
echo "========================================="
echo "访问地址：http://localhost:5700"
echo "如果无法访问，请确保Windows防火墙允许端口5700"
echo ""
echo "数据目录：/opt/qinglong/data"
echo "配置文件：/opt/qinglong/.env"
echo "主程序目录：$QL_GLOBAL_DIR"
echo ""
echo "重要安全提示："
echo "1. 青龙面板v2.20.1及之前版本存在高危安全漏洞[1,2](@ref)"
echo "2. 请确保安装的是v2.20.2或更高版本"
echo "3. 建议不要将青龙面板暴露在公网"
echo "4. 定期更新到最新版本"
echo ""
echo "常用命令："
if [ -d /etc/systemd/system ]; then
    echo "启动：sudo systemctl start qinglong"
    echo "停止：sudo systemctl stop qinglong"
    echo "重启：sudo systemctl restart qinglong"
    echo "状态：sudo systemctl status qinglong"
    echo "日志：sudo journalctl -u qinglong -f"
else
    echo "启动：pm2 start qinglong"
    echo "停止：pm2 stop qinglong"
    echo "重启：pm2 restart qinglong"
    echo "状态：pm2 status"
    echo "日志：pm2 logs qinglong"
fi
echo ""
echo "手动启动命令："
echo "cd /usr/lib/node_modules/@whyour/qinglong && node src/main.js"
echo ""
echo "故障排除："
echo "1. 如果端口5700被占用，请修改/opt/qinglong/.env中的PORT"
echo "2. 查看日志：/opt/qinglong/data/log/"
echo "3. 重新安装依赖：cd $QL_GLOBAL_DIR && npm install"
echo "========================================="
