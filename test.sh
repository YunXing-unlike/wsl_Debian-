#!/bin/bash

# 青龙面板一键安装脚本 for WSL1 Ubuntu 20.04
# 作者：元宝
# 日期：2026-04-09
# 修复版本：修复npm配置问题，优化安装流程

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

# 4. 安装Node.js 20.x
echo "步骤4/13：安装Node.js 20.x..."
# 清理旧的Node.js版本
apt remove -y nodejs npm 2>/dev/null || true
apt autoremove -y

# 安装Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 验证Node.js安装
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo "Node.js版本: $NODE_VERSION"
echo "npm版本: $NPM_VERSION"

# 5. 安装Python3和pip
echo "步骤5/13：安装Python3和pip..."
apt install -y python3 python3-pip python3-venv python3-dev

# 验证Python安装
python3 --version
pip3 --version

# 6. 配置镜像源
echo "步骤6/13：配置镜像源..."

# 配置npm使用淘宝镜像
npm config set registry https://registry.npmmirror.com/

# 配置git使用https
git config --global url."https://".insteadOf git://
git config --global url."https://github.com/".insteadOf git@github.com:

# 创建npm配置
cat > ~/.npmrc << EOF
registry=https://registry.npmmirror.com/
sass_binary_site=https://npmmirror.com/mirrors/node-sass/
phantomjs_cdnurl=https://npmmirror.com/mirrors/phantomjs/
electron_mirror=https://npmmirror.com/mirrors/electron/
chromedriver_cdnurl=https://npmmirror.com/mirrors/chromedriver/
operadriver_cdnurl=https://npmmirror.com/mirrors/operadriver/
fse_binary_host_mirror=https://npmmirror.com/mirrors/fsevents
node_sqlite3_binary_host_mirror=https://npmmirror.com/mirrors
sqlite3_binary_host_mirror=https://npmmirror.com/mirrors
sharp_binary_host=https://npmmirror.com/mirrors/sharp/
sharp_libvips_binary_host=https://npmmirror.com/mirrors/sharp-libvips/
canvas_binary_host_mirror=https://npmmirror.com/mirrors/canvas
nodejieba_binary_host_mirror=https://npmmirror.com/mirrors/nodejieba
EOF

# 配置pip镜像源
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
extra-index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = pypi.tuna.tsinghua.edu.cn mirrors.aliyun.com
timeout = 120
EOF

# 7. 安装pnpm
echo "步骤7/13：安装pnpm..."
# 先更新npm
npm install -g npm@latest

# 安装pnpm
npm install -g pnpm

# 验证pnpm安装
pnpm --version

# 8. 安装青龙面板
echo "步骤8/13：安装青龙面板..."
echo "正在从npm安装青龙面板..."

# 创建临时目录
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 尝试从npm安装青龙面板
echo "方法1: 尝试从npm安装青龙面板..."
if npm install @whyour/qinglong@2.20.2; then
    echo "✓ 青龙面板安装成功！"
    QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
    mkdir -p "$(dirname "$QL_GLOBAL_DIR")"
    
    # 检查是否安装成功
    if [ -d "node_modules/@whyour/qinglong" ]; then
        mv node_modules/@whyour/qinglong "$QL_GLOBAL_DIR"
    else
        # 尝试其他路径
        if [ -d "node_modules" ]; then
            mv node_modules/* "$QL_GLOBAL_DIR" 2>/dev/null || true
        fi
    fi
else
    echo "✗ npm安装失败，尝试从GitHub安装..."
    
    # 方法2: 从GitHub克隆
    echo "方法2: 尝试从GitHub克隆青龙面板..."
    cd /tmp
    rm -rf qinglong-install
    git clone https://github.com/whyour/qinglong.git qinglong-install
    cd qinglong-install
    
    # 安装依赖
    npm install
    
    QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
    mkdir -p "$(dirname "$QL_GLOBAL_DIR")"
    
    # 复制文件
    if [ -d "/tmp/qinglong-install" ]; then
        cp -r /tmp/qinglong-install/* "$QL_GLOBAL_DIR"/
    fi
fi

# 清理临时目录
cd /
rm -rf "$TEMP_DIR" 2>/dev/null || true

# 验证安装
if [ ! -d "/usr/lib/node_modules/@whyour/qinglong" ]; then
    echo "错误：青龙面板安装失败！尝试创建符号链接..."
    
    # 尝试在全局node_modules中查找
    if [ -d "/usr/local/lib/node_modules/@whyour/qinglong" ]; then
        ln -sf /usr/local/lib/node_modules/@whyour/qinglong /usr/lib/node_modules/@whyour/qinglong
        QL_GLOBAL_DIR="/usr/local/lib/node_modules/@whyour/qinglong"
    else
        # 尝试在用户目录查找
        USER_QL_DIR=$(find /root -name "qinglong" -type d 2>/dev/null | head -1)
        if [ -n "$USER_QL_DIR" ]; then
            mkdir -p /usr/lib/node_modules/@whyour
            ln -sf "$USER_QL_DIR" /usr/lib/node_modules/@whyour/qinglong
            QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
        else
            echo "错误：无法找到青龙面板安装目录！"
            echo "请尝试手动安装：npm install -g @whyour/qinglong"
            exit 1
        fi
    fi
fi

QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
echo "青龙面板已安装到：$QL_GLOBAL_DIR"

# 9. 创建青龙面板目录结构
echo "步骤9/13：创建目录结构..."
QL_DIR="/opt/qinglong"
mkdir -p $QL_DIR
cd $QL_DIR

# 创建必要的子目录
for dir in config scripts log db upload repo raw deps env; do
    mkdir -p "data/$dir"
done

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

# 进入青龙面板目录
cd "$QL_GLOBAL_DIR"

# 安装项目依赖
echo "安装青龙面板核心依赖..."
npm install --legacy-peer-deps

# 安装必要的Node.js依赖
echo "安装Node.js依赖..."
npm install --legacy-peer-deps \
  crypto-js \
  prettytable \
  dotenv \
  jsdom \
  date-fns \
  tough-cookie \
  tslib \
  ws@7.4.3 \
  ts-md5 \
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
  cron-parser

# 安装Python3依赖
echo "安装Python3依赖..."
pip3 install --upgrade pip
pip3 install requests beautifulsoup4 lxml pycryptodome pillow

# 尝试安装其他Python依赖
pip3 install canvas ping3 aiohttp 2>/dev/null || echo "某些Python依赖安装失败，将在青龙面板中自动安装"

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

# 创建服务管理脚本
cat > /usr/local/bin/ql << 'EOF'
#!/bin/bash
case "$1" in
    start)
        echo "启动青龙面板..."
        cd /usr/lib/node_modules/@whyour/qinglong
        export PORT=5700
        export QL_DIR=/usr/lib/node_modules/@whyour/qinglong
        export QL_DATA_DIR=/opt/qinglong/data
        export TZ=Asia/Shanghai
        export NODE_PATH=/usr/lib/node_modules
        nohup node src/main.js > /opt/qinglong/data/log/qinglong.log 2>&1 &
        echo "青龙面板已启动，日志: /opt/qinglong/data/log/qinglong.log"
        ;;
    stop)
        echo "停止青龙面板..."
        pkill -f "node.*qinglong" 2>/dev/null || true
        echo "青龙面板已停止"
        ;;
    restart)
        echo "重启青龙面板..."
        pkill -f "node.*qinglong" 2>/dev/null || true
        sleep 2
        cd /usr/lib/node_modules/@whyour/qinglong
        export PORT=5700
        export QL_DIR=/usr/lib/node_modules/@whyour/qinglong
        export QL_DATA_DIR=/opt/qinglong/data
        export TZ=Asia/Shanghai
        export NODE_PATH=/usr/lib/node_modules
        nohup node src/main.js > /opt/qinglong/data/log/qinglong.log 2>&1 &
        echo "青龙面板已重启"
        ;;
    status)
        if pgrep -f "node.*qinglong" > /dev/null; then
            echo "青龙面板正在运行"
            ps aux | grep -E "node.*qinglong" | grep -v grep
        else
            echo "青龙面板未运行"
        fi
        ;;
    log)
        tail -f /opt/qinglong/data/log/qinglong.log
        ;;
    *)
        echo "用法: ql {start|stop|restart|status|log}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/ql

# 13. 启动青龙面板
echo "步骤13/13：启动青龙面板..."
echo "正在启动青龙面板..."

# 创建日志目录
mkdir -p /opt/qinglong/data/log

# 启动服务
cd "$QL_GLOBAL_DIR"
export PORT=5700
export QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
export QL_DATA_DIR="/opt/qinglong/data"
export TZ=Asia/Shanghai
export NODE_PATH="/usr/lib/node_modules"

# 后台启动青龙面板
nohup node src/main.js > /opt/qinglong/data/log/qinglong.log 2>&1 &

# 等待5秒让服务启动
sleep 5

# 检查是否启动成功
if pgrep -f "node.*qinglong" > /dev/null; then
    echo "✓ 青龙面板启动成功！"
    
    # 检查端口是否监听
    if netstat -tlnp 2>/dev/null | grep -q ":5700"; then
        echo "✓ 端口5700正在监听"
    else
        echo "⚠ 端口5700未监听，但进程已启动"
    fi
else
    echo "✗ 青龙面板启动失败，查看日志："
    tail -20 /opt/qinglong/data/log/qinglong.log
    echo "尝试手动启动..."
    cd "$QL_GLOBAL_DIR"
    node src/main.js &
    sleep 3
fi

# 输出安装完成信息
echo ""
echo "========================================="
echo "青龙面板安装完成！"
echo "========================================="
echo ""
echo "重要信息："
echo "访问地址：http://localhost:5700"
echo "如果无法访问，请检查："
echo "1. Windows防火墙是否允许端口5700"
echo "2. 使用命令 'netstat -tlnp | grep 5700' 检查端口监听"
echo "3. 使用命令 'ps aux | grep qinglong' 检查进程"
echo ""
echo "目录结构："
echo "主程序：/usr/lib/node_modules/@whyour/qinglong"
echo "数据目录：/opt/qinglong/data"
echo "配置文件：/opt/qinglong/.env"
echo "日志文件：/opt/qinglong/data/log/qinglong.log"
echo ""
echo "管理命令："
echo "启动：ql start"
echo "停止：ql stop"
echo "重启：ql restart"
echo "状态：ql status"
echo "查看日志：ql log 或 tail -f /opt/qinglong/data/log/qinglong.log"
echo ""
echo "手动启动："
echo "cd /usr/lib/node_modules/@whyour/qinglong"
echo "node src/main.js"
echo ""
echo "初始化步骤："
echo "1. 访问 http://localhost:5700"
echo "2. 按照页面提示设置用户名和密码"
echo "3. 在青龙面板的【依赖管理】中安装所需依赖"
echo ""
echo "常用依赖："
echo "Node.js: canvas, png-js, jsdom, crypto-js"
echo "Python3: requests, beautifulsoup4, lxml, pycryptodome"
echo ""
echo "如果遇到问题，请查看日志：/opt/qinglong/data/log/qinglong.log"
echo "========================================="
echo ""
echo "启动完成！请在浏览器中访问 http://localhost:5700"
