#!/bin/bash

# 青龙面板WSL1一键安装脚本
# 适用于Ubuntu 20.04系统，仅后端启动
# 作者：元宝AI助手
# 日期：2026-04-10

set -e  # 遇到错误立即退出

echo "=========================================="
echo "  青龙面板WSL1部署脚本（仅后端启动）"
echo "=========================================="
echo "系统检测：$(uname -a)"
echo "当前用户：$(whoami)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用sudo运行此脚本"
    echo "使用方法：sudo bash $0"
    exit 1
fi

# 检查系统版本
if ! grep -q "20.04" /etc/os-release; then
    print_warn "检测到系统不是Ubuntu 20.04，继续执行但可能遇到兼容性问题"
fi

# 1. 更新系统包列表并升级现有包
print_info "步骤1/9: 更新系统包列表..."
apt-get update -y
apt-get upgrade -y

# 2. 安装系统基础依赖
print_info "步骤2/9: 安装系统基础依赖..."
apt-get install -y \
    git \
    wget \
    curl \
    vim \
    htop \
    net-tools \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    pkg-config

# 3. 配置阿里云镜像源（加速下载）
print_info "步骤3/9: 配置国内镜像源加速..."
# 备份原有源
cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d)

# 使用阿里云Ubuntu 20.04镜像源
cat > /etc/apt/sources.list << 'EOF'
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# 更新镜像源
apt-get update -y

# 4. 安装Node.js 16.x（青龙面板推荐版本）
print_info "步骤4/9: 安装Node.js 16.x..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# 验证Node.js安装
node_version=$(node -v)
npm_version=$(npm -v)
print_info "Node.js版本: $node_version"
print_info "npm版本: $npm_version"

# 5. 配置npm淘宝镜像源
print_info "步骤5/9: 配置npm淘宝镜像源..."
npm config set registry https://registry.npmmirror.com/
npm config set disturl https://npmmirror.com/dist
npm config set electron_mirror https://npmmirror.com/electron/
npm config set sass_binary_site https://npmmirror.com/mirrors/node-sass/

# 6. 安装PM2进程管理器
print_info "步骤6/9: 安装PM2进程管理器..."
npm install -g pm2
pm2 completion install

# 7. 克隆青龙面板仓库
print_info "步骤7/9: 克隆青龙面板仓库..."
QL_DIR="/opt/qinglong"
if [ -d "$QL_DIR" ]; then
    print_warn "检测到已存在青龙面板目录，备份后重新克隆..."
    mv "$QL_DIR" "${QL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
fi

# 使用国内镜像加速克隆
git clone https://gitee.com/whyour/qinglong.git "$QL_DIR" || {
    print_warn "Gitee镜像克隆失败，尝试GitHub..."
    git clone https://github.com/whyour/qinglong.git "$QL_DIR"
}

cd "$QL_DIR"

# 8. 安装青龙面板依赖
print_info "步骤8/9: 安装青龙面板依赖..."
print_info "此步骤可能需要较长时间，请耐心等待..."

# 安装项目依赖
npm install --registry=https://registry.npmmirror.com

# 安装Python依赖
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip3 install --upgrade pip
pip3 install -r requirements.txt

# 9. 配置环境变量和启动服务
print_info "步骤9/9: 配置环境变量并启动服务..."

# 创建数据目录
mkdir -p /ql/data
mkdir -p /ql/log
mkdir -p /ql/db
mkdir -p /ql/config
mkdir -p /ql/scripts
mkdir -p /ql/jbot
mkdir -p /ql/repo
mkdir -p /ql/raw

# 设置目录权限
chmod -R 755 /ql

# 创建环境变量配置文件
cat > /etc/profile.d/qinglong.sh << 'EOF'
export QL_DIR="/opt/qinglong"
export QL_DATA_DIR="/ql/data"
export PATH=$PATH:$QL_DIR/node_modules/.bin
EOF

source /etc/profile.d/qinglong.sh

# 创建青龙面板配置文件
if [ ! -f "/ql/config/config.yaml" ]; then
    cat > /ql/config/config.yaml << 'EOF'
# 青龙面板配置文件
server:
  port: 5700
  host: "0.0.0.0"
  
database:
  path: "/ql/db/qinglong.db"
  
log:
  level: "info"
  path: "/ql/log"
  
security:
  jwtSecret: "$(openssl rand -base64 32)"
EOF
fi

# 生成JWT密钥
if [ ! -f "/ql/config/jwt_secret" ]; then
    openssl rand -base64 32 > /ql/config/jwt_secret
    chmod 600 /ql/config/jwt_secret
fi

# 启动青龙面板服务（仅后端）
print_info "启动青龙面板后端服务..."
cd "$QL_DIR"

# 使用PM2启动服务
pm2 start src/main.js --name "qinglong" -- \
    --port 5700 \
    --host 0.0.0.0 \
    --data-dir /ql/data \
    --log-dir /ql/log \
    --db-path /ql/db/qinglong.db

# 保存PM2配置
pm2 save
pm2 startup | tail -1 > /tmp/pm2_startup.sh
chmod +x /tmp/pm2_startup.sh
/tmp/pm2_startup.sh

# 创建WSL1专用启动脚本（因为WSL1不支持systemd）
cat > /usr/local/bin/start-qinglong.sh << 'EOF'
#!/bin/bash
# WSL1青龙面板启动脚本
export QL_DIR="/opt/qinglong"
export QL_DATA_DIR="/ql/data"
cd "$QL_DIR"
pm2 resurrect
EOF

chmod +x /usr/local/bin/start-qinglong.sh

# 创建WSL1停止脚本
cat > /usr/local/bin/stop-qinglong.sh << 'EOF'
#!/bin/bash
# WSL1青龙面板停止脚本
pm2 stop qinglong
pm2 save
EOF

chmod +x /usr/local/bin/stop-qinglong.sh

# 10. 安装青龙面板常用依赖
print_info "安装青龙面板常用脚本依赖..."
print_info "此步骤可能需要较长时间..."

# 创建依赖安装脚本
cat > /tmp/install-deps.sh << 'EOF'
#!/bin/bash
# 青龙面板依赖安装脚本

echo "安装Node.js常用依赖..."
npm install -g \
    crypto-js \
    axios \
    request \
    png-js \
    @types/node \
    typescript \
    ts-md5 \
    jsdom \
    date-fns \
    tough-cookie \
    tslib \
    ws@7.4.3 \
    jieba \
    fs \
    form-data \
    json5 \
    global-agent

echo "安装Python常用依赖..."
pip3 install \
    requests \
    canvas \
    ping3 \
    jieba \
    beautifulsoup4 \
    lxml \
    pycryptodome \
    rsa \
    qrcode \
    pillow
EOF

chmod +x /tmp/install-deps.sh
/tmp/install-deps.sh

# 安装完成提示
echo ""
echo "=========================================="
echo "  青龙面板安装完成！"
echo "=========================================="
echo ""
echo "重要信息："
echo "1. 青龙面板已启动在端口 5700"
echo "2. 访问地址：http://localhost:5700"
echo "3. 默认账号：admin"
echo "4. 默认密码：adminadmin"
echo ""
echo "管理命令："
echo "• 启动青龙：start-qinglong.sh"
echo "• 停止青龙：stop-qinglong.sh"
echo "• 查看状态：pm2 status"
echo "• 查看日志：pm2 logs qinglong"
echo ""
echo "WSL1注意事项："
echo "1. WSL1重启后需要手动运行：start-qinglong.sh"
echo "2. 数据目录：/ql/data"
echo "3. 日志目录：/ql/log"
echo "4. 配置文件：/ql/config/config.yaml"
echo ""
echo "首次访问请立即修改默认密码！"
echo "=========================================="

# 显示当前服务状态
echo ""
print_info "当前服务状态："
pm2 status qinglong

# 显示网络监听情况
echo ""
print_info "网络端口监听情况："
netstat -tlnp | grep :5700 || echo "端口5700未监听，请检查服务状态"

# 创建快速访问命令别名
cat >> ~/.bashrc << 'EOF'

# 青龙面板快捷命令
alias ql-start='start-qinglong.sh'
alias ql-stop='stop-qinglong.sh'
alias ql-status='pm2 status qinglong'
alias ql-logs='pm2 logs qinglong'
alias ql-restart='pm2 restart qinglong'
alias ql-dir='cd /opt/qinglong'
alias ql-data='cd /ql/data'

echo "青龙面板快捷命令已添加："
echo "  ql-start     - 启动青龙面板"
echo "  ql-stop      - 停止青龙面板"
echo "  ql-status    - 查看服务状态"
echo "  ql-logs      - 查看服务日志"
echo "  ql-restart   - 重启青龙面板"
echo "  ql-dir       - 进入青龙目录"
echo "  ql-data      - 进入数据目录"
EOF

echo ""
print_info "请运行 'source ~/.bashrc' 使快捷命令生效"
print_info "安装完成！青龙面板已准备就绪。"
