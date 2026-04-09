#!/bin/bash

# 青龙面板一键安装脚本 for WSL1 Ubuntu 20.04
# 修复版本：解决npm配置警告和版本问题
# 日期：2026-04-09

set -e

echo "========================================="
echo "青龙面板一键安装脚本 for WSL1 Ubuntu 20.04"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本：sudo bash $0"
    exit 1
fi

# 1. 备份并配置阿里云源
echo "步骤1/12：配置阿里云软件源..."
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)
fi

cat > /etc/apt/sources.list << 'EOF'
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
echo "步骤2/12：更新系统包..."
apt update && apt upgrade -y

# 3. 安装基础工具
echo "步骤3/12：安装基础工具..."
apt install -y git wget curl vim net-tools build-essential ca-certificates gnupg

# 4. 安装Node.js 20.x
echo "步骤4/12：安装Node.js 20.x..."
# 清理旧的Node.js版本
apt remove -y nodejs npm 2>/dev/null || true
apt autoremove -y

# 安装Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"

# 5. 安装Python3和pip
echo "步骤5/12：安装Python3和pip..."
apt install -y python3 python3-pip python3-venv python3-dev

# 验证Python安装
python3 --version
pip3 --version

# 6. 配置镜像源
echo "步骤6/12：配置镜像源..."

# 只配置必要的npm镜像源，避免不兼容的配置
npm config set registry https://registry.npmmirror.com/

# 配置git使用https
git config --global url."https://".insteadOf git://
git config --global url."https://github.com/".insteadOf git@github.com:

# 创建简单的npm配置
cat > ~/.npmrc << EOF
registry=https://registry.npmmirror.com/
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
echo "步骤7/12：安装pnpm..."
# 检查是否已安装pnpm
if command -v pnpm &> /dev/null; then
    echo "✓ pnpm 已安装，版本: $(pnpm --version)"
else
    # 安装pnpm
    npm install -g pnpm
    echo "pnpm版本: $(pnpm --version)"
fi

# 8. 检查并安装青龙面板
echo "步骤8/12：安装青龙面板..."

# 检查是否已安装青龙面板
if [ -d "/usr/lib/node_modules/@whyour/qinglong" ] || [ -d "/usr/local/lib/node_modules/@whyour/qinglong" ]; then
    echo "✓ 青龙面板已安装，跳过安装步骤"
    
    # 查找青龙面板安装位置
    if [ -d "/usr/lib/node_modules/@whyour/qinglong" ]; then
        QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
    elif [ -d "/usr/local/lib/node_modules/@whyour/qinglong" ]; then
        QL_GLOBAL_DIR="/usr/local/lib/node_modules/@whyour/qinglong"
    fi
else
    echo "正在安装青龙面板..."
    
    # 方法1: 尝试安装最新版（不指定版本号）
    if npm install -g @whyour/qinglong; then
        echo "✓ 青龙面板安装成功！"
    else
        echo "npm安装失败，尝试从GitHub克隆..."
        
        # 方法2: 从GitHub克隆
        cd /tmp
        if git clone https://github.com/whyour/qinglong.git; then
            cd qinglong
            npm install
            
            # 移动到全局位置
            QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
            mkdir -p "$(dirname "$QL_GLOBAL_DIR")"
            mv /tmp/qinglong "$QL_GLOBAL_DIR"
            echo "✓ 从GitHub克隆安装成功！"
        else
            echo "✗ 所有安装方法都失败，请检查网络连接"
            exit 1
        fi
    fi
    
    # 确定安装位置
    if [ -d "/usr/lib/node_modules/@whyour/qinglong" ]; then
        QL_GLOBAL_DIR="/usr/lib/node_modules/@whyour/qinglong"
    elif [ -d "/usr/local/lib/node_modules/@whyour/qinglong" ]; then
        QL_GLOBAL_DIR="/usr/local/lib/node_modules/@whyour/qinglong"
    else
        # 尝试查找
        QL_GLOBAL_DIR=$(find /usr -name "qinglong" -type d 2>/dev/null | grep "node_modules" | head -1)
        if [ -z "$QL_GLOBAL_DIR" ]; then
            QL_GLOBAL_DIR=$(npm root -g)/@whyour/qinglong
        fi
    fi
fi

echo "青龙面板目录: $QL_GLOBAL_DIR"

# 9. 创建青龙面板目录结构
echo "步骤9/12：创建目录结构..."
QL_DIR="/opt/qinglong"
mkdir -p $QL_DIR
cd $QL_DIR

# 创建必要的子目录
for dir in config scripts log db upload repo raw deps env; do
    mkdir -p "data/$dir" 2>/dev/null || true
done

# 设置权限
chmod -R 755 $QL_DIR/data 2>/dev/null || true

# 10. 配置环境变量
echo "步骤10/12：配置环境变量..."
cat > /etc/profile.d/qinglong.sh << 'EOF'
export QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
export QL_DATA_DIR="/opt/qinglong/data"
export PATH=$PATH:$QL_DIR/bin
export NODE_PATH="/usr/lib/node_modules"
EOF

source /etc/profile.d/qinglong.sh

# 创建.env配置文件
cat > $QL_DIR/.env << 'EOF'
PORT=5700
QL_DIR=/usr/lib/node_modules/@whyour/qinglong
QL_DATA_DIR=/opt/qinglong/data
QL_BASE_URL=/
TZ=Asia/Shanghai
NODE_PATH=/usr/lib/node_modules
EOF

# 11. 安装依赖
echo "步骤11/12：安装依赖..."

# 进入青龙面板目录
cd "$QL_GLOBAL_DIR"

# 检查是否已安装依赖
if [ -d "node_modules" ] && [ -n "$(ls -A node_modules 2>/dev/null)" ]; then
    echo "✓ Node.js依赖已安装，跳过"
else
    echo "安装青龙面板核心依赖..."
    npm install --legacy-peer-deps
fi

# 安装必要的Node.js依赖
echo "检查Node.js依赖..."
for pkg in crypto-js axios moment ws@7.4.3 jsdom date-fns; do
    if [ ! -d "node_modules/$(echo $pkg | cut -d'@' -f1)" ]; then
        echo "安装 $pkg..."
        npm install $pkg --legacy-peer-deps
    fi
done

# 检查Python依赖
echo "检查Python依赖..."
if pip3 show requests &> /dev/null; then
    echo "✓ Python依赖已安装"
else
    echo "安装Python依赖..."
    pip3 install requests beautifulsoup4 lxml pycryptodome
fi

# 12. 创建启动脚本
echo "步骤12/12：创建启动脚本..."

# 创建管理脚本
cat > /usr/local/bin/ql << 'EOF'
#!/bin/bash
QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
QL_DATA_DIR="/opt/qinglong/data"

case "$1" in
    start)
        echo "启动青龙面板..."
        cd "$QL_DIR"
        export PORT=5700
        export QL_DIR="$QL_DIR"
        export QL_DATA_DIR="$QL_DATA_DIR"
        export TZ=Asia/Shanghai
        nohup node src/main.js > "$QL_DATA_DIR/log/qinglong.log" 2>&1 &
        echo "青龙面板已启动，日志: $QL_DATA_DIR/log/qinglong.log"
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
        cd "$QL_DIR"
        export PORT=5700
        export QL_DIR="$QL_DIR"
        export QL_DATA_DIR="$QL_DATA_DIR"
        export TZ=Asia/Shanghai
        nohup node src/main.js > "$QL_DATA_DIR/log/qinglong.log" 2>&1 &
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
        tail -f "$QL_DATA_DIR/log/qinglong.log"
        ;;
    *)
        echo "用法: ql {start|stop|restart|status|log}"
        echo ""
        echo "手动启动命令:"
        echo "cd $QL_DIR && node src/main.js"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/ql

# 创建日志目录
mkdir -p /opt/qinglong/data/log

# 输出安装完成信息
echo ""
echo "========================================="
echo "青龙面板安装完成！"
echo "========================================="
echo ""
echo "重要信息："
echo "1. 根据文档内容，青龙面板支持 Python3、JavaScript、Shell、Typescript"
echo "2. 默认端口：5700"
echo "3. 访问地址：http://localhost:5700"
echo ""
echo "已安装的组件："
echo "- Node.js $(node --version)"
echo "- npm $(npm --version)"
echo "- pnpm $(pnpm --version 2>/dev/null || echo '未安装')"
echo "- Python3 $(python3 --version)"
echo "- 青龙面板目录: $QL_GLOBAL_DIR"
echo ""
echo "管理命令："
echo "启动：ql start"
echo "停止：ql stop"
echo "重启：ql restart"
echo "状态：ql status"
echo "查看日志：ql log"
echo ""
echo "初始化步骤："
echo "1. 启动青龙面板：ql start"
echo "2. 访问 http://localhost:5700"
echo "3. 按照页面提示完成初始化设置"
echo ""
echo "注意：如果之前已安装过青龙面板，本脚本会跳过已安装的组件"
echo "========================================="
