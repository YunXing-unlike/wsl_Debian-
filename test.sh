#!/bin/bash
set -e  # 出错自动退出，避免卡壳
clear

# 打印脚本说明
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      青龙面板部署脚本（全自动+全维度加速）\033[0m"
echo -e "\033[32m  适配：Ubuntu 20.04/22.04/24.04/24.10/25.04\033[0m"
echo -e "\033[32m        Debian 11/12/13 (Trixie)\033[0m"
echo -e "\033[32m        WSL1/WSL2 全系列\033[0m"
echo -e "\033[32m  加速源：阿里云(APT) | 清华源(pip) | 淘宝源(pnpm/npm) | GitHub代理\033[0m"
echo -e "\033[32m  版本：Node.js 22 LTS | Python 3.10-3.13 | pnpm 10.x\033[0m"
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
        focal) CODENAME="focal" ;;      # 20.04
        jammy) CODENAME="jammy" ;;      # 22.04
        noble) CODENAME="noble" ;;      # 24.04
        oracular) CODENAME="oracular" ;; # 24.10
        plucky) CODENAME="plucky" ;;    # 25.04
        *) CODENAME="noble" ;;          # 默认24.04
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
        trixie) CODENAME="trixie" ;;    # 13
        bookworm) CODENAME="bookworm" ;; # 12
        bullseye) CODENAME="bullseye" ;; # 11
        buster) CODENAME="buster" ;;    # 10
        *) CODENAME="bookworm" ;;       # 默认12
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
    # 兜底配置 - Ubuntu 24.04 LTS
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
EOF
fi

sudo apt clean
sudo apt update -y
echo ""

# ===================== 步骤1：安装基础工具（必须先安装git）====================
echo -e "\033[34m【步骤1/10】安装基础工具(Git/curl/wget/ca-certificates)...\033[0m"
sudo apt install -y git curl wget ca-certificates software-properties-common apt-transport-https gnupg lsb-release
echo ""

# ===================== 步骤2：配置Git国内加速（现在git已安装）====================
echo -e "\033[34m【步骤2/10】配置Git国内加速...\033[0m"
GIT_PROXY_LIST=(
    "https://ghfast.top/https://github.com/"
    "https://mirror.ghproxy.com/https://github.com/"
    "https://ghproxy.com/https://github.com/"
    "https://hub.gitmirror.com/https://github.com/"
    "https://raw.githubusercontent.com/"
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

# ===================== 步骤3：安装Node.js 22.x LTS =====================
echo -e "\033[34m【步骤3/10】安装Node.js 22.x LTS...\033[0m"

# 安装NodeSource源 (Node.js 22.x)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -

# 安装Node.js
sudo apt install -y nodejs

# 验证安装
NODE_VERSION=$(node --version)
echo -e "\033[32mNode.js安装成功: $NODE_VERSION\033[0m"

# 配置npm国内源
npm config set registry https://registry.npmmirror.com/
npm config set cache /tmp/npm-cache --global
echo ""

# ===================== 步骤4：安装pnpm 10.x =====================
echo -e "\033[34m【步骤4/10】安装pnpm 10.x...\033[0m"

# 使用官方安装脚本（国内镜像）
curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION=10.6.2 sh -

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
    sudo npm install -g pnpm@10.6.2
    echo -e "\033[32mpnpm安装成功: $(pnpm --version)\033[0m"
fi

# 配置pnpm国内源
pnpm config set registry https://registry.npmmirror.com/
pnpm config set store-dir /tmp/pnpm-store
echo ""

# ===================== 步骤5：更新系统包 =====================
echo -e "\033[34m【步骤5/10】更新系统包列表并升级...\033[0m"
sudo apt update -y
sudo apt upgrade -y
echo ""

# ===================== 步骤6：安装Python（智能适配最新版本）====================
echo -e "\033[34m【步骤6/10】安装Python（智能适配系统最新版本）...\033[0m"

# 定义Python版本映射（各系统最新稳定版）
declare -A PYTHON_VERSION_MAP=(
    # Ubuntu版本
    ["focal"]="3.10"      # 20.04 - 通过PPA安装3.10
    ["jammy"]="3.11"      # 22.04 - 通过PPA安装3.11（原生3.10）
    ["noble"]="3.12"      # 24.04 - 原生3.12
    ["oracular"]="3.12"   # 24.10 - 原生3.12
    ["plucky"]="3.13"     # 25.04 - 原生3.13（开发版）
    # Debian版本
    ["trixie"]="3.13"     # 13 - 原生3.13 [^49^][^50^]
    ["bookworm"]="3.11"   # 12 - 原生3.11
    ["bullseye"]="3.9"    # 11 - 原生3.9
    ["buster"]="3.7"      # 10 - 原生3.7
)

TARGET_PYTHON="${PYTHON_VERSION_MAP[$OS_VERSION]}"
PYTHON_INSTALLED=false

if [ -z "$TARGET_PYTHON" ]; then
    TARGET_PYTHON="3.12"  # 默认回退
fi

echo "目标Python版本: $TARGET_PYTHON"

# 安装Python函数
install_python() {
    local py_ver=$1
    local py_pkg="python${py_ver}"
    
    # 尝试直接安装（系统自带或已配置源）
    if sudo apt install -y ${py_pkg} ${py_pkg}-venv ${py_pkg}-dev 2>/dev/null; then
        echo -e "\033[32m${py_pkg} 安装成功\033[0m"
        PYTHON_VERSION="${py_ver}"
        PYTHON_INSTALLED=true
        return 0
    fi
    
    # 如果失败且是Ubuntu，尝试Deadsnakes PPA
    if [ "$OS_TYPE" = "ubuntu" ] && [ "$py_ver" != "3.12" ] && [ "$py_ver" != "3.13" ]; then
        echo "尝试通过Deadsnakes PPA安装 ${py_ver}..."
        sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || {
            # 手动添加PPA（兼容WSL）
            sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 2>/dev/null || true
            echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${OS_VERSION} main" | sudo tee /etc/apt/sources.list.d/deadsnakes.list
        }
        sudo apt update -y
        
        # 再次尝试安装
        if sudo apt install -y ${py_pkg} ${py_pkg}-venv ${py_pkg}-dev ${py_pkg}-distutils 2>/dev/null; then
            echo -e "\033[32m${py_pkg} 通过PPA安装成功\033[0m"
            PYTHON_VERSION="${py_ver}"
            PYTHON_INSTALLED=true
            return 0
        fi
    fi
    
    return 1
}

# 主安装逻辑
if [ "$OS_TYPE" = "ubuntu" ]; then
    case $OS_VERSION in
        noble|oracular)
            # Ubuntu 24.04/24.10 - 原生Python 3.12
            echo "Ubuntu 24.04/24.10 使用原生Python 3.12..."
            install_python "3.12" || install_python "3.11" || install_python "3.10"
            ;;
        plucky)
            # Ubuntu 25.04 - 原生Python 3.13
            echo "Ubuntu 25.04 使用原生Python 3.13..."
            install_python "3.13" || install_python "3.12"
            ;;
        jammy)
            # Ubuntu 22.04 - 尝试3.11，回退3.10
            echo "Ubuntu 22.04 尝试安装Python 3.11..."
            install_python "3.11" || install_python "3.10" || install_python "3.8"
            ;;
        focal)
            # Ubuntu 20.04 - 尝试3.10，回退3.8
            echo "Ubuntu 20.04 尝试安装Python 3.10..."
            install_python "3.10" || install_python "3.9" || install_python "3.8"
            ;;
        *)
            # 未知Ubuntu版本
            echo "未知Ubuntu版本，尝试安装Python 3.12..."
            install_python "3.12" || install_python "3.11" || install_python "3.10" || install_python "3.8"
            ;;
    esac
    
elif [ "$OS_TYPE" = "debian" ]; then
    case $OS_VERSION in
        trixie)
            # Debian 13 - 原生Python 3.13 [^49^][^50^]
            echo "Debian 13 (Trixie) 使用原生Python 3.13..."
            install_python "3.13" || install_python "3.11"
            ;;
        bookworm)
            # Debian 12 - 原生Python 3.11
            echo "Debian 12 (Bookworm) 使用原生Python 3.11..."
            install_python "3.11" || install_python "3.9"
            ;;
        bullseye)
            # Debian 11 - 原生Python 3.9
            echo "Debian 11 (Bullseye) 使用原生Python 3.9..."
            install_python "3.9" || install_python "3.8"
            ;;
        buster)
            # Debian 10 - 原生Python 3.7
            echo "Debian 10 (Buster) 使用原生Python 3.7..."
            install_python "3.7" || install_python "3.8"
            ;;
        *)
            echo "未知Debian版本，尝试安装Python 3.11..."
            install_python "3.11" || install_python "3.9" || install_python "3.8"
            ;;
    esac
else
    # WSL或其他系统
    echo "WSL/其他系统，尝试安装Python 3.12..."
    install_python "3.12" || install_python "3.11" || install_python "3.10" || install_python "3.9" || install_python "3.8"
fi

# 最终回退方案
if [ "$PYTHON_INSTALLED" = false ]; then
    echo "警告：特定版本安装失败，尝试安装系统默认Python3..."
    sudo apt install -y python3 python3-venv python3-dev python3-pip
    PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2 || echo "3.8")
fi

echo -e "\033[32mPython版本确认: $PYTHON_VERSION\033[0m"
echo ""

# ===================== 步骤7：配置Python默认版本和pip =====================
echo -e "\033[34m【步骤7/10】配置Python默认版本和pip...\033[0m"

# 设置默认python3
if command -v python${PYTHON_VERSION} &>/dev/null; then
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 100 2>/dev/null || true
    sudo ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python 2>/dev/null || true
fi

# 确保python命令可用
sudo apt install -y python-is-python3 2>/dev/null || {
    sudo ln -sf /usr/bin/python3 /usr/bin/python 2>/dev/null || true
}

# 安装/升级pip
echo "安装并配置pip..."
curl -sS https://bootstrap.pypa.io/get-pip.py 2>/dev/null | sudo python${PYTHON_VERSION} 2>/dev/null || {
    # 备用方案
    sudo apt install -y python3-pip
    python3 -m pip install --upgrade pip
}

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

# ===================== 步骤8：环境版本验证 =====================
echo -e "\033[34m【步骤8/10】验证环境版本...\033[0m"
echo -e "Python版本: \033[32m$(python3 --version 2>/dev/null | awk '{print $2}')\033[0m"
echo -e "pip版本: \033[32m$(pip3 --version 2>/dev/null | awk '{print $2}' | cut -d'/' -f1)\033[0m"
echo -e "Node.js版本: \033[32m$(node --version 2>/dev/null)\033[0m"
echo -e "npm版本: \033[32m$(npm --version 2>/dev/null)\033[0m"
echo -e "pnpm版本: \033[32m$(pnpm --version 2>/dev/null)\033[0m"
echo ""

# ===================== 步骤9：修复CA证书和网络依赖 =====================
echo -e "\033[34m【步骤9/10】修复CA证书和网络依赖...\033[0m"
sudo apt-get install --reinstall ca-certificates -y 2>/dev/null || true
sudo update-ca-certificates --fresh 2>/dev/null || true
echo ""

# ===================== 步骤10：部署青龙面板 =====================
echo -e "\033[34m【步骤10/10】部署青龙面板...\033[0m"

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

# ===================== 启动青龙面板 =====================
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
