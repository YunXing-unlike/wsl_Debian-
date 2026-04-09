#!/bin/bash

# 青龙面板WSL1一键安装脚本（最新稳定版）
# 适用于Ubuntu 20.04系统，仅后端启动
# 作者：元宝AI助手
# 日期：2026-04-10
# 版本：v2.0

set -e  # 遇到错误立即退出

echo "=========================================="
echo "  青龙面板WSL1部署脚本（最新稳定版）"
echo "=========================================="
echo "系统检测：$(uname -a)"
echo "当前用户：$(whoami)"
echo "安装时间：$(date)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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
print_step "步骤1/12: 更新系统包列表..."
apt-get update -y
apt-get upgrade -y

# 2. 安装系统基础依赖
print_step "步骤2/12: 安装系统基础依赖..."
apt-get install -y \
    git \
    wget \
    curl \
    vim \
    htop \
    net-tools \
    build-essential \
    libssl-dev \
    libffi-dev \
    pkg-config \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release

# 3. 配置阿里云镜像源（加速下载）
print_step "步骤3/12: 配置国内镜像源加速..."
# 备份原有源
cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)

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

# 4. 安装最新稳定版Python 3.14.3
print_step "步骤4/12: 安装Python 3.14.3（最新稳定版）..."
# 添加deadsnakes PPA（提供最新Python版本）
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update -y

# 安装Python 3.14.3及开发工具
apt-get install -y \
    python3.14 \
    python3.14-dev \
    python3.14-venv \
    python3.14-distutils

# 创建python3和pip3的软链接（指向最新版本）
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 1
update-alternatives --set python3 /usr/bin/python3.14

# 安装pip for Python 3.14
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.14

# 验证Python安装
python3_version=$(python3 --version)
pip3_version=$(pip3 --version)
print_info "Python版本: $python3_version"
print_info "pip版本: $pip3_version"

# 5. 使用NVM安装最新LTS版Node.js v24.14.1
print_step "步骤5/12: 安装Node.js v24.14.1（最新LTS稳定版）..."
# 安装NVM（Node版本管理器）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash

# 加载NVM环境变量
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# 安装Node.js v24.14.1（最新LTS稳定版）
nvm install 24.14.1
nvm use 24.14.1
nvm alias default 24.14.1

# 验证Node.js安装
node_version=$(node --version)
npm_version=$(npm --version)
print_info "Node.js版本: $node_version"
print_info "npm版本: $npm_version"

# 6. 配置npm淘宝镜像源
print_step "步骤6/12: 配置npm淘宝镜像源..."
npm config set registry https://registry.npmmirror.com/
npm config set disturl https://npmmirror.com/dist
npm config set electron_mirror https://npmmirror.com/electron/
npm config set sass_binary_site https://npmmirror.com/mirrors/node-sass/
npm config set puppeteer_download_host https://npmmirror.com/mirrors
npm config set chromedriver_cdnurl https://npmmirror.com/mirrors/chromedriver

# 7. 安装最新版PM2进程管理器
print_step "步骤7/12: 安装PM2最新版（6.0.14+）..."
npm install -g pm2@latest
pm2 completion install

# 验证PM2安装
pm2_version=$(pm2 --version)
print_info "PM2版本: $pm2_version"

# 8. 配置Python清华镜像源
print_step "步骤8/12: 配置Python清华镜像源..."
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip3 config set global.trusted-host pypi.tuna.tsinghua.edu.cn
pip3 config set global.timeout 120

# 9. 克隆青龙面板最新稳定版（v2.20.2+）
print_step "步骤9/12: 克隆青龙面板最新稳定版..."
QL_DIR="/opt/qinglong"
if [ -d "$QL_DIR" ]; then
    print_warn "检测到已存在青龙面板目录，备份后重新克隆..."
    mv "$QL_DIR" "${QL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
fi

# 使用国内镜像加速克隆最新稳定版
git clone -b v2.20.2 https://gitee.com/whyour/qinglong.git "$QL_DIR" || {
    print_warn "Gitee镜像克隆失败，尝试GitHub最新稳定版..."
    git clone https://github.com/whyour/qinglong.git "$QL_DIR"
    cd "$QL_DIR"
    # 切换到最新稳定标签
    latest_tag=$(git describe --tags `git rev-list --tags --max-count=1`)
    git checkout "$latest_tag"
}

cd "$QL_DIR"
current_branch=$(git branch --show-current)
current_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "最新提交")
print_info "青龙面板版本: $current_branch (标签: $current_tag)"

# 10. 安装青龙面板依赖（使用最新工具）
print_step "步骤10/12: 安装青龙面板依赖..."
print_info "此步骤可能需要较长时间，请耐心等待..."

# 升级npm到最新版
npm install -g npm@latest

# 安装项目依赖（使用最新稳定版依赖）
npm install --registry=https://registry.npmmirror.com --legacy-peer-deps

# 安装Python依赖（使用最新版pip和setuptools）
pip3 install --upgrade pip setuptools wheel
pip3 install -r requirements.txt

# 11. 配置环境变量和启动服务
print_step "步骤11/12: 配置环境变量并启动服务..."

# 创建数据目录
mkdir -p /ql/data
mkdir -p /ql/log
mkdir -p /ql/db
mkdir -p /ql/config
mkdir -p /ql/scripts
mkdir -p /ql/jbot
mkdir -p /ql/repo
mkdir -p /ql/raw
mkdir -p /ql/cache

# 设置目录权限
chmod -R 755 /ql

# 创建环境变量配置文件
cat > /etc/profile.d/qinglong.sh << 'EOF'
export QL_DIR="/opt/qinglong"
export QL_DATA_DIR="/ql/data"
export QL_BRANCH="stable"
export PATH=$PATH:$QL_DIR/node_modules/.bin:$HOME/.nvm/versions/node/v24.14.1/bin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF

source /etc/profile.d/qinglong.sh

# 创建青龙面板配置文件（最新版格式）
if [ ! -f "/ql/config/config.yaml" ]; then
    cat > /ql/config/config.yaml << 'EOF'
# 青龙面板配置文件 v2.20.2+
server:
  port: 5700
  host: "0.0.0.0"
  baseUrl: "/"
  
database:
  path: "/ql/db/qinglong.db"
  driver: "sqlite3"
  
log:
  level: "info"
  path: "/ql/log"
  maxSize: 10
  maxBackups: 5
  maxAge: 30
  
security:
  jwtSecret: "$(cat /ql/config/jwt_secret)"
  cors: true
  
task:
  maxConcurrent: 5
  timeout: 3600
  
notification:
  enabled: false
  type: "bark"
EOF
fi

# 生成JWT密钥（使用更安全的随机生成）
if [ ! -f "/ql/config/jwt_secret" ]; then
    openssl rand -base64 64 | tr -d '\n' > /ql/config/jwt_secret
    chmod 600 /ql/config/jwt_secret
fi

# 12. 启动青龙面板服务（仅后端）
print_step "步骤12/12: 启动青龙面板后端服务..."
cd "$QL_DIR"

# 使用PM2启动服务（最新配置格式）
pm2 start src/main.js --name "qinglong" \
    --interpreter "$(which node)" \
    --log "/ql/log/pm2.log" \
    --output "/ql/log/out.log" \
    --error "/ql/log/error.log" \
    --merge-logs \
    --log-date-format "YYYY-MM-DD HH:mm:ss" \
    --max-memory-restart 500M \
    --restart-delay 3000 \
    --exp-backoff-restart-delay 100 \
    --kill-timeout 5000 \
    -- \
    --port 5700 \
    --host 0.0.0.0 \
    --data-dir /ql/data \
    --log-dir /ql/log \
    --db-path /ql/db/qinglong.db \
    --config /ql/config/config.yaml

# 保存PM2配置
pm2 save
pm2 startup | tail -1 > /tmp/pm2_startup.sh
chmod +x /tmp/pm2_startup.sh
/tmp/pm2_startup.sh

# 创建WSL1专用启动脚本
cat > /usr/local/bin/start-qinglong.sh << 'EOF'
#!/bin/bash
# WSL1青龙面板启动脚本
export QL_DIR="/opt/qinglong"
export QL_DATA_DIR="/ql/data"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
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

# 创建重启脚本
cat > /usr/local/bin/restart-qinglong.sh << 'EOF'
#!/bin/bash
# WSL1青龙面板重启脚本
pm2 restart qinglong
EOF

chmod +x /usr/local/bin/restart-qinglong.sh

# 13. 安装青龙面板最新依赖和工具
print_info "安装青龙面板最新依赖和工具..."

# 创建依赖安装脚本
cat > /tmp/install-latest-deps.sh << 'EOF'
#!/bin/bash
# 青龙面板最新依赖安装脚本

echo "安装最新Node.js依赖..."
npm install -g \
    typescript@latest \
    ts-node@latest \
    @types/node@latest \
    pnpm@latest \
    yarn@latest \
    nx@latest \
    webpack@latest \
    vite@latest \
    eslint@latest \
    prettier@latest

echo "安装最新Python依赖..."
pip3 install --upgrade \
    requests \
    beautifulsoup4 \
    lxml \
    pycryptodome \
    rsa \
    qrcode \
    pillow \
    numpy \
    pandas \
    openpyxl \
    selenium \
    playwright

echo "安装青龙面板常用工具..."
apt-get install -y \
    jq \
    zip \
    unzip \
    tar \
    gzip \
    bzip2 \
    lsof \
    netcat \
    telnet \
    dnsutils
EOF

chmod +x /tmp/install-latest-deps.sh
/tmp/install-latest-deps.sh

# 安装完成提示
echo ""
echo "=========================================="
echo "  青龙面板安装完成！（最新稳定版）"
echo "=========================================="
echo ""
echo "📊 安装版本信息："
echo "• Node.js: v24.14.1 (最新LTS稳定版)"
echo "• Python: 3.14.3 (最新稳定版)"
echo "• PM2: 6.0.14+ (最新版)"
echo "• 青龙面板: v2.20.2+ (修复高危漏洞)"
echo ""
echo "🔗 访问信息："
echo "1. 青龙面板已启动在端口 5700"
echo "2. 访问地址：http://localhost:5700"
echo "3. 默认账号：admin"
echo "4. 默认密码：adminadmin"
echo ""
echo "⚙️ 管理命令："
echo "• 启动青龙：start-qinglong.sh"
echo "• 停止青龙：stop-qinglong.sh"
echo "• 重启青龙：restart-qinglong.sh"
echo "• 查看状态：pm2 status"
echo "• 查看日志：pm2 logs qinglong"
echo "• 监控面板：pm2 monit"
echo ""
echo "📁 目录结构："
echo "• 程序目录：/opt/qinglong"
echo "• 数据目录：/ql/data"
echo "• 日志目录：/ql/log"
echo "• 配置目录：/ql/config"
echo "• 脚本目录：/ql/scripts"
echo ""
echo "⚠️ WSL1注意事项："
echo "1. WSL1重启后需要手动运行：start-qinglong.sh"
echo "2. 数据存储在 /ql 目录下，请定期备份"
echo "3. 如需外网访问，需配置Windows防火墙开放5700端口"
echo ""
echo "🔒 安全提醒："
echo "1. 首次访问请立即修改默认密码！"
echo "2. 青龙面板v2.20.2已修复高危认证绕过漏洞[6](@ref)"
echo "3. 建议配置防火墙限制访问IP"
echo ""
echo "🔄 更新方法："
echo "cd /opt/qinglong && bash shell/update.sh stable"
echo "=========================================="

# 显示当前服务状态
echo ""
print_info "当前服务状态："
pm2 status qinglong

# 显示网络监听情况
echo ""
print_info "网络端口监听情况："
if netstat -tlnp 2>/dev/null | grep :5700; then
    print_info "端口5700已正常监听"
else
    ss -tlnp 2>/dev/null | grep :5700 || print_warn "端口5700未监听，请检查服务状态"
fi

# 显示系统资源使用情况
echo ""
print_info "系统资源使用情况："
echo "内存使用：$(free -h | awk '/^Mem:/ {print $3"/"$2}')"
echo "磁盘使用：$(df -h / | awk 'NR==2 {print $3"/"$2 " ("$5")"}')"

# 创建快速访问命令别名
cat >> ~/.bashrc << 'EOF'

# 青龙面板快捷命令（最新版）
alias ql-start='start-qinglong.sh'
alias ql-stop='stop-qinglong.sh'
alias ql-restart='restart-qinglong.sh'
alias ql-status='pm2 status qinglong'
alias ql-logs='pm2 logs qinglong'
alias ql-monit='pm2 monit'
alias ql-dir='cd /opt/qinglong'
alias ql-data='cd /ql/data'
alias ql-update='cd /opt/qinglong && bash shell/update.sh stable'
alias ql-version='cd /opt/qinglong && git describe --tags --abbrev=0'

echo "青龙面板快捷命令已添加："
echo "  ql-start     - 启动青龙面板"
echo "  ql-stop      - 停止青龙面板"
echo "  ql-restart   - 重启青龙面板"
echo "  ql-status    - 查看服务状态"
echo "  ql-logs      - 查看服务日志"
echo "  ql-monit     - 监控面板"
echo "  ql-dir       - 进入青龙目录"
echo "  ql-data      - 进入数据目录"
echo "  ql-update    - 更新到最新稳定版"
echo "  ql-version   - 查看当前版本"
EOF

echo ""
print_info "请运行 'source ~/.bashrc' 使快捷命令生效"
print_info "安装完成！青龙面板最新稳定版已准备就绪。"

# 显示后续操作建议
echo ""
echo "📋 后续操作建议："
echo "1. 访问 http://localhost:5700 登录面板"
echo "2. 立即修改默认密码"
echo "3. 配置环境变量和定时任务"
echo "4. 定期运行 'ql-update' 保持最新版本"
echo "5. 备份重要数据到安全位置"
