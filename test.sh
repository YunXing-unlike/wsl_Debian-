#!/bin/bash
set -e  # 出错自动退出，避免卡壳
clear

# 打印脚本说明
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      青龙面板部署脚本（全自动+全维度加速）\033[0m"
echo -e "\033[32m  适配：Debian/Ubuntu/WSL Linux子系统\033[0m"
echo -e "\033[32m  加速源：阿里云(APT) | 清华源(pip) | 淘宝源(pnpm/npm) | GitHub代理\033[0m"
echo -e "\033[32m  版本：Node.js 20 LTS | Python 3.10+ | pnpm 9.x\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo ""

# ===================== 前置：修复PATH环境变量 + 强制刷新 =====================
echo -e "\033[34m【前置优化】配置全局命令PATH环境变量...\033[0m"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
echo "export PATH=$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc 2>/dev/null || true
echo ""

# ===================== 前置：全维度国内加速源配置 =====================
echo -e "\033[34m【前置步骤】配置全维度国内加速源...\033[0m"

# 1. 自动识别系统版本
OS_TYPE=$(grep -Ei 'debian|ubuntu' /etc/os-release | grep 'ID=' | cut -d= -f2 | tr -d '"' | head -1)
OS_VERSION=$(grep -Ei 'VERSION_CODENAME' /etc/os-release | cut -d= -f2 | tr -d '"')
WSL_FLAG=$(grep -qi "microsoft" /proc/version 2>/dev/null && echo "WSL" || echo "原生Linux")

echo "检测到系统: $OS_TYPE $OS_VERSION ($WSL_FLAG)"

# 2. 配置APT阿里云源（自动备份+适配版本）
echo "配置APT阿里云源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d) 2>/dev/null || true

if [ "$OS_TYPE" = "ubuntu" ]; then
    case $OS_VERSION in
        focal) CODENAME="focal" ;;
        jammy) CODENAME="jammy" ;;
        noble) CODENAME="noble" ;;
        *) CODENAME="jammy" ;;
    esac
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $CODENAME main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $CODENAME-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $CODENAME-backports main restricted universe multiverse
EOF
elif [ "$OS_TYPE" = "debian" ]; then
    case $OS_VERSION in
        bookworm) CODENAME="bookworm" ;;
        bullseye) CODENAME="bullseye" ;;
        buster) CODENAME="buster" ;;
        *) CODENAME="bookworm" ;;
    esac
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/debian/ $CODENAME main non-free-firmware contrib non-free
deb-src http://mirrors.aliyun.com/debian/ $CODENAME main non-free-firmware contrib non-free
deb http://mirrors.aliyun.com/debian-security/ $CODENAME-security main non-free-firmware contrib non-free
deb-src http://mirrors.aliyun.com/debian-security/ $CODENAME-security main non-free-firmware contrib non-free
deb http://mirrors.aliyun.com/debian/ $CODENAME-updates main non-free-firmware contrib non-free
deb-src http://mirrors.aliyun.com/debian/ $CODENAME-updates main non-free-firmware contrib non-free
EOF
else
    # 兜底配置
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
EOF
fi

sudo apt clean
sudo apt update -y
echo ""

# 3. 配置Git国内加速
echo "配置Git国内加速..."
# 使用多个备选代理，自动选择可用的
GIT_PROXY_LIST=(
    "https://ghfast.top/https://github.com/"
    "https://mirror.ghproxy.com/https://github.com/"
    "https://ghproxy.com/https://github.com/"
    "https://hub.gitmirror.com/https://github.com/"
)

for proxy in "${GIT_PROXY_LIST[@]}"; do
    if curl -s --max-time 3 "$proxy" -o /dev/null 2>/dev/null; then
        echo "使用Git代理: $proxy"
        git config --global url."$proxy".insteadOf "https://github.com/"
        git config --global url."$proxy".insteadOf "https://raw.githubusercontent.com/"
        break
    fi
done

if [ "$WSL_FLAG" = "WSL" ]; then
    git config --global http.sslVerify false
    git config --global core.compression 9
fi
echo ""

# ===================== 1. 安装基础工具 =====================
echo -e "\033[34m【步骤1/10】安装基础工具(Git/curl/wget/ca-certificates)...\033[0m"
sudo apt install -y git curl wget ca-certificates software-properties-common apt-transport-https gnupg lsb-release
echo ""

# ===================== 2. 安装Node.js 20.x LTS =====================
echo -e "\033[34m【步骤2/10】安装Node.js 20.x LTS...\033[0m"

# 安装NodeSource源
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# 安装Node.js
sudo apt install -y nodejs

# 验证安装
NODE_VERSION=$(node --version)
echo -e "\033[32mNode.js安装成功: $NODE_VERSION\033[0m"

# 配置npm国内源
npm config set registry https://registry.npmmirror.com/
npm config set cache /tmp/npm-cache --global
echo ""

# ===================== 3. 安装pnpm 9.x =====================
echo -e "\033[34m【步骤3/10】安装pnpm 9.x...\033[0m"

# 使用官方安装脚本（国内镜像）
curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION=9.15.0 sh -

# 加载pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> ~/.bashrc
echo 'export PATH="$PNPM_HOME:$PATH"' >> ~/.bashrc

# 验证安装
if command -v pnpm &>/dev/null; then
    echo -e "\033[32mpnpm安装成功: $(pnpm --version)\033[0m"
else
    # 备用方案：使用npm安装pnpm
    echo "使用npm安装pnpm..."
    sudo npm install -g pnpm@9.15.0
    echo -e "\033[32mpnpm安装成功: $(pnpm --version)\033[0m"
fi

# 配置pnpm国内源
pnpm config set registry https://registry.npmmirror.com/
pnpm config set store-dir /tmp/pnpm-store
echo ""

# ===================== 4. 更新系统包 =====================
echo -e "\033[34m【步骤4/10】更新系统包列表并升级...\033[0m"
sudo apt update -y
sudo apt upgrade -y
echo ""

# ===================== 5. 安装Python（智能适配版本） =====================
echo -e "\033[34m【步骤5/10】安装Python（智能适配系统版本）...\033[0m"

install_python_from_source() {
    local PY_VERSION=$1
    echo "从源码编译安装 Python $PY_VERSION..."
    
    # 安装编译依赖
    sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
        libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev \
        wget tk-dev uuid-dev libgdbm-compat-dev
    
    cd /tmp
    wget "https://www.python.org/ftp/python/${PY_VERSION}/Python-${PY_VERSION}.tgz" --no-check-certificate || \
        wget "https://npm.taobao.org/mirrors/python/${PY_VERSION}/Python-${PY_VERSION}.tgz" --no-check-certificate
    
    tar -xzf "Python-${PY_VERSION}.tgz"
    cd "Python-${PY_VERSION}"
    
    ./configure --enable-optimizations --enable-shared --prefix=/usr/local \
        --with-ensurepip=install --enable-loadable-sqlite-extensions
    
    make -j$(nproc)
    sudo make altinstall
    
    cd ~
    rm -rf "/tmp/Python-${PY_VERSION}*"
}

# 根据系统版本智能选择Python版本
PYTHON_VERSION=""

if [ "$OS_TYPE" = "ubuntu" ]; then
    case $OS_VERSION in
        focal)
            # Ubuntu 20.04: 使用系统自带3.8或安装3.10
            echo "Ubuntu 20.04 detected. 尝试安装Python 3.10..."
            
            # 添加deadsnakes PPA
            sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || {
                echo "PPA添加失败，尝试手动添加..."
                sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 2>/dev/null || true
                echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/deadsnakes.list
                sudo apt update -y
            }
            
            sudo apt update -y
            
            # 尝试安装python3.10
            if sudo apt install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils 2>/dev/null; then
                PYTHON_VERSION="3.10"
                echo -e "\033[32mPython 3.10安装成功\033[0m"
            else
                echo "Python 3.10安装失败，使用系统自带Python 3.8..."
                sudo apt install -y python3.8 python3.8-venv python3.8-dev
                PYTHON_VERSION="3.8"
            fi
            ;;
            
        jammy)
            # Ubuntu 22.04: 默认3.10，可选3.11
            echo "Ubuntu 22.04 detected. 安装Python 3.11..."
            sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
            sudo apt update -y
            
            if sudo apt install -y python3.11 python3.11-venv python3.11-dev python3.11-distutils 2>/dev/null; then
                PYTHON_VERSION="3.11"
            else
                sudo apt install -y python3.10 python3.10-venv python3.10-dev
                PYTHON_VERSION="3.10"
            fi
            ;;
            
        noble)
            # Ubuntu 24.04: 默认3.12
            echo "Ubuntu 24.04 detected. 使用系统自带Python 3.12..."
            sudo apt install -y python3.12 python3.12-venv python3.12-dev
            PYTHON_VERSION="3.12"
            ;;
            
        *)
            # 未知版本：使用系统默认或安装3.10
            echo "未知Ubuntu版本，尝试安装Python 3.10..."
            sudo apt install -y python3 python3-venv python3-dev || install_python_from_source "3.10.13"
            PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2 || echo "3.10")
            ;;
    esac
    
elif [ "$OS_TYPE" = "debian" ]; then
    case $OS_VERSION in
        bookworm)
            echo "Debian 12 detected. 安装Python 3.11..."
            sudo apt install -y python3.11 python3.11-venv python3.11-dev
            PYTHON_VERSION="3.11"
            ;;
        bullseye)
            echo "Debian 11 detected. 安装Python 3.9..."
            sudo apt install -y python3.9 python3.9-venv python3.9-dev
            PYTHON_VERSION="3.9"
            ;;
        buster)
            echo "Debian 10 detected. 安装Python 3.7..."
            sudo apt install -y python3.7 python3.7-venv python3.7-dev
            PYTHON_VERSION="3.7"
            ;;
        *)
            echo "未知Debian版本，安装系统默认Python3..."
            sudo apt install -y python3 python3-venv python3-dev
            PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
            ;;
    esac
else
    # WSL或其他系统
    echo "WSL/其他系统，安装Python 3.10..."
    sudo apt install -y python3 python3-venv python3-dev || install_python_from_source "3.10.13"
    PYTHON_VERSION="3.10"
fi

echo -e "\033[32mPython版本确认: $PYTHON_VERSION\033[0m"
echo ""

# ===================== 6. 配置Python默认版本和pip =====================
echo -e "\033[34m【步骤6/10】配置Python默认版本和pip...\033[0m"

# 设置默认python3
if command -v python${PYTHON_VERSION} &>/dev/null; then
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 2>/dev/null || true
    sudo ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python 2>/dev/null || true
fi

# 确保python命令可用
sudo apt install -y python-is-python3 2>/dev/null || true

# 安装/升级pip
echo "安装并配置pip..."
curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python${PYTHON_VERSION} 2>/dev/null || \
    sudo apt install -y python3-pip

# 升级pip并配置清华源
python3 -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || true

# 配置pip默认源
mkdir -p ~/.pip
tee ~/.pip/pip.conf > /dev/null <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120
cache-dir = /tmp/pip-cache

[install]
upgrade-strategy = only-if-needed
EOF

# 安装关键Python包
pip install --user certifi urllib3 requests --upgrade -i https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || true

echo ""

# ===================== 7. 环境版本验证 =====================
echo -e "\033[34m【步骤7/10】验证环境版本...\033[0m"
echo -e "Python版本: \033[32m$(python3 --version 2>/dev/null | awk '{print $2}')\033[0m"
echo -e "pip版本: \033[32m$(pip3 --version 2>/dev/null | awk '{print $2}' | cut -d'/' -f1)\033[0m"
echo -e "Node.js版本: \033[32m$(node --version 2>/dev/null)\033[0m"
echo -e "npm版本: \033[32m$(npm --version 2>/dev/null)\033[0m"
echo -e "pnpm版本: \033[32m$(pnpm --version 2>/dev/null)\033[0m"
echo ""

# ===================== 8. 修复CA证书和网络依赖 =====================
echo -e "\033[34m【步骤8/10】修复CA证书和网络依赖...\033[0m"
sudo apt-get install --reinstall ca-certificates -y 2>/dev/null || true
sudo update-ca-certificates --fresh 2>/dev/null || true
echo ""

# ===================== 9. 部署青龙面板 =====================
echo -e "\033[34m【步骤9/10】部署青龙面板...\033[0m"

# 检查并清理旧版本
if [ -d "$HOME/qinglong" ]; then
    echo "检测到已有青龙目录，备份并重建..."
    mv ~/qinglong ~/qinglong.bak.$(date +%Y%m%d%H%M%S)
fi

# 克隆青龙源码
echo "克隆青龙面板源码..."
cd ~
git clone --depth 1 https://github.com/whyour/qinglong.git || {
    echo "Git克隆失败，尝试使用代理..."
    git config --global url."https://ghfast.top/https://github.com/".insteadOf "https://github.com/"
    git clone --depth 1 https://github.com/whyour/qinglong.git
}

cd qinglong || { echo -e "\033[31m错误：青龙目录不存在！\033[0m"; exit 1; }

# 复制环境变量配置
[ -f .env.example ] && cp .env.example .env

# 确认pnpm配置
pnpm config set registry https://registry.npmmirror.com/
pnpm config set store-dir /tmp/pnpm-store

# 安装系统依赖
echo "安装系统编译依赖..."
sudo apt-get install -y build-essential libsqlite3-dev 2>/dev/null || true

# 安装项目依赖
echo "安装青龙面板项目依赖（这可能需要几分钟）..."
pnpm install || {
    echo "pnpm install失败，尝试使用npm..."
    npm install --registry=https://registry.npmmirror.com/
}

echo ""

# ===================== 10. 启动青龙面板 =====================
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m              部署完成！🎉\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo -e "✅ 全维度加速源配置生效：阿里云APT + 清华pip + 淘宝pnpm/npm"
echo -e "✅ 环境版本："
echo -e "   - Python: \033[33m$(python3 --version 2>/dev/null)\033[0m"
echo -e "   - Node.js: \033[33m$(node --version 2>/dev/null)\033[0m"
echo -e "   - pnpm: \033[33m$(pnpm --version 2>/dev/null)\033[0m"
echo -e "📌 访问地址：\033[36mhttp://localhost:5700\033[0m"
echo -e "📌 管理命令："
echo -e "   - 启动：\033[36mcd ~/qinglong && pnpm start\033[0m"
echo -e "   - 停止：\033[36mcd ~/qinglong && pnpm stop\033[0m"
echo -e "   - 查看日志：\033[36mcd ~/qinglong && pnpm log\033[0m"
echo -e "📌 首次访问请按提示初始化账号"
echo -e "\033[32m=============================================\033[0m"
echo ""

# 启动青龙面板
echo "正在启动青龙面板..."
pnpm start
