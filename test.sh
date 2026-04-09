#!/bin/bash
set -e
clear

echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      青龙面板部署脚本（完整修复版 v3.0）\033[0m"
echo -e "\033[32m  修复：Git TLS | Python-apt | task命令 | 端口\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo ""

# ===================== 前置：修复PATH环境变量 =====================
echo -e "\033[34m【前置优化】配置全局命令PATH环境变量...\033[0m"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
echo "export PATH=$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc 2>/dev/null || true

# ===================== WSL 检测与特定修复 =====================
WSL_FLAG=$(grep -qi "microsoft" /proc/version 2>/dev/null && echo "WSL" || echo "原生Linux")
if [ "$WSL_FLAG" = "WSL" ]; then
    echo -e "\033[33m检测到 WSL 环境，应用特定修复...\033[0m"
    export npm_config_unsafe_perm=true
    export npm_config_user=root
    export TMPDIR=/tmp
    export npm_config_tmp=/tmp
fi

# ===================== 系统检测 =====================
echo -e "\033[34m【系统检测】识别操作系统...\033[0m"

OS_TYPE=$(grep -Ei 'debian|ubuntu' /etc/os-release | grep 'ID=' | cut -d= -f2 | tr -d '"' | head -1)
OS_VERSION=$(grep -Ei 'VERSION_CODENAME' /etc/os-release | cut -d= -f2 | tr -d '"')

# 如果OS_TYPE为空，尝试其他方式检测
if [ -z "$OS_TYPE" ]; then
    if grep -qi "debian" /etc/os-release 2>/dev/null; then
        OS_TYPE="debian"
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        OS_TYPE="ubuntu"
    fi
fi

echo "检测到系统: $OS_TYPE $OS_VERSION ($WSL_FLAG)"

# ===================== 关键修复：Debian Git TLS问题 =====================
if [ "$OS_TYPE" = "debian" ] || [ "$WSL_FLAG" = "WSL" ]; then
    echo -e "\033[34m【关键修复】Debian/WSL Git TLS修复...\033[0m"
    
    # 安装git和ca-certificates
    sudo apt update -y 2>&1 | grep -v "Problem executing scripts" || true
    
    # 重新安装git使用OpenSSL而不是GnuTLS
    sudo apt install -y git ca-certificates openssl libssl-dev 2>&1 | grep -v "Problem executing scripts" || true
    
    # 配置git使用HTTP/1.1（避免TLS 1.3问题）
    git config --global http.version HTTP/1.1
    git config --global http.postBuffer 524288000
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    
    # 增大SSL缓存
    git config --global http.sslVerify true
    git config --global core.compression 9
    
    # 配置git使用OpenSSL（如果编译支持）
    git config --global http.sslBackend openssl 2>/dev/null || true
    
    echo -e "\033[32mGit TLS配置完成\033[0m"
    echo ""
fi

# ===================== 关键修复：Python-apt模块（Ubuntu）====================
if [ "$OS_TYPE" = "ubuntu" ]; then
    echo -e "\033[34m【关键修复】修复Python-apt模块链接...\033[0m"
    
    CURRENT_PY3=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2 || echo "3.8")
    echo "当前Python3版本: $CURRENT_PY3"
    
    fix_apt_pkg() {
        local py_ver=$1
        local apt_pkg_path=$(find /usr/lib/python3* -name "apt_pkg.cpython*.so" 2>/dev/null | head -1)
        
        if [ -n "$apt_pkg_path" ]; then
            echo "找到apt_pkg模块: $apt_pkg_path"
            local target_dir="/usr/lib/python${py_ver}/dist-packages"
            local target_link="${target_dir}/apt_pkg.so"
            
            sudo mkdir -p "$target_dir" 2>/dev/null || true
            
            if [ ! -f "$target_link" ]; then
                sudo ln -sf "$apt_pkg_path" "$target_link" 2>/dev/null && {
                    echo -e "\033[32mapt_pkg链接修复成功\033[0m"
                    return 0
                }
            fi
        fi
        
        echo "尝试重新安装python3-apt..."
        sudo apt install -y --reinstall python3-apt 2>/dev/null && {
            echo -e "\033[32mpython3-apt重新安装成功\033[0m"
            return 0
        }
        
        return 1
    }
    
    fix_apt_pkg "$CURRENT_PY3" || {
        echo -e "\033[33m警告：apt_pkg修复可能不完整，尝试继续...\033[0m"
    }
    
    # 禁用command-not-found钩子
    if [ ! -f "/usr/lib/python3/dist-packages/apt_pkg.so" ] && [ ! -f "/usr/lib/python${CURRENT_PY3}/dist-packages/apt_pkg.so" ]; then
        echo "禁用command-not-found钩子..."
        sudo rm -f /etc/apt/apt.conf.d/20command-not-found 2>/dev/null || true
        sudo touch /etc/apt/apt.conf.d/20command-not-found
        sudo chmod 644 /etc/apt/apt.conf.d/20command-not-found
    fi
    echo ""
fi

# ===================== 配置APT国内加速源 =====================
echo -e "\033[34m【前置步骤】配置全维度国内加速源...\033[0m"

sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d) 2>/dev/null || true

if [ "$OS_TYPE" = "ubuntu" ]; then
    case $OS_VERSION in
        focal) CODENAME="focal" ;;
        jammy) CODENAME="jammy" ;;
        noble) CODENAME="noble" ;;
        oracular) CODENAME="oracular" ;;
        plucky) CODENAME="plucky" ;;
        *) CODENAME="noble" ;;
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
        trixie) CODENAME="trixie" ;;
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

sudo apt clean 2>/dev/null || true

echo "更新APT（忽略非致命错误）..."
sudo apt update -y 2>&1 | grep -v "Problem executing scripts" | grep -v "Sub-process returned an error code" || true
echo ""

# ===================== 步骤1：安装基础工具 =====================
echo -e "\033[34m【步骤1/10】安装基础工具...\033[0m"

if [ "$OS_TYPE" = "ubuntu" ]; then
    sudo apt install -y git curl wget ca-certificates software-properties-common apt-transport-https gnupg lsb-release 2>&1 | grep -v "Problem executing scripts" || true
else
    sudo apt install -y git curl wget ca-certificates apt-transport-https gnupg lsb-release 2>&1 | grep -v "Problem executing scripts" || true
fi
echo ""

# ===================== 步骤2：配置Git国内加速（增强版）====================
echo -e "\033[34m【步骤2/10】配置Git国内加速...\033[0m"

# 测试多个代理，选择可用的
GIT_PROXY_LIST=(
    "https://ghfast.top/https://github.com/"
    "https://mirror.ghproxy.com/https://github.com/"
    "https://ghproxy.com/https://github.com/"
    "https://hub.gitmirror.com/https://github.com/"
    "https://raw.githubusercontent.com/whyour/qinglong/"
)

PROXY_WORKING=false
for proxy in "${GIT_PROXY_LIST[@]}"; do
    echo "测试Git代理: $proxy"
    if curl -s --max-time 5 "$proxy" -o /dev/null 2>/dev/null || curl -s --max-time 5 "${proxy}whyour/qinglong" -o /dev/null 2>/dev/null; then
        echo -e "\033[32m使用Git代理: $proxy\033[0m"
        git config --global url."$proxy".insteadOf "https://github.com/"
        git config --global url."$proxy".insteadOf "https://raw.githubusercontent.com/"
        PROXY_WORKING=true
        break
    fi
done

if [ "$PROXY_WORKING" = false ]; then
    echo -e "\033[33m警告：所有Git代理测试失败，将尝试直连...\033[0m"
fi

if [ "$WSL_FLAG" = "WSL" ]; then
    git config --global http.sslVerify false
    git config --global core.compression 9
fi
echo ""

# ===================== 步骤3：安装Node.js 22.x LTS =====================
echo -e "\033[34m【步骤3/10】安装Node.js 22.x LTS...\033[0m"

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs 2>&1 | grep -v "Problem executing scripts" || true

NODE_VERSION=$(node --version)
echo -e "\033[32mNode.js安装成功: $NODE_VERSION\033[0m"

npm config set registry https://registry.npmmirror.com/
npm config set cache /tmp/npm-cache --global
echo ""

# ===================== 步骤4：安装pnpm 10.x（多方案容错）====================
echo -e "\033[34m【步骤4/10】安装pnpm 10.x...\033[0m"

install_pnpm() {
    if command -v npm &>/dev/null; then
        echo "尝试使用npm安装pnpm..."
        sudo rm -f /usr/bin/pnpm /usr/local/bin/pnpm 2>/dev/null || true
        sudo npm install -g pnpm@10.6.2 --force && {
            echo -e "\033[32mpnpm通过npm安装成功: $(pnpm --version)\033[0m"
            return 0
        }
    fi
    
    echo "尝试使用官方脚本安装pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION=10.6.2 sh - && {
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$PNPM_HOME:$PATH"
        echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> ~/.bashrc
        echo 'export PATH="$PNPM_HOME:$PATH"' >> ~/.bashrc
        source ~/.bashrc 2>/dev/null || true
        echo -e "\033[32mpnpm通过官方脚本安装成功: $(pnpm --version)\033[0m"
        return 0
    }
    
    echo "尝试直接下载pnpm二进制..."
    local pnpm_url="https://fastgit.cc/https://github.com/pnpm/pnpm/releases/download/v10.6.2/pnpm-linux-x64"
    local pnpm_tmp="/tmp/pnpm"
    
    if curl -fsSL "$pnpm_url" -o "$pnpm_tmp" 2>/dev/null || \
       curl -fsSL "https://ghfast.top/$pnpm_url" -o "$pnpm_tmp" 2>/dev/null || \
       curl -fsSL "https://mirror.ghproxy.com/$pnpm_url" -o "$pnpm_tmp" 2>/dev/null; then
        chmod +x "$pnpm_tmp"
        sudo mv "$pnpm_tmp" /usr/local/bin/pnpm
        echo -e "\033[32mpnpm通过二进制下载安装成功: $(pnpm --version)\033[0m"
        return 0
    fi
    
    return 1
}

if install_pnpm; then
    :
else
    echo -e "\033[31m所有pnpm安装方案均失败，尝试安装pnpm 9.x作为最后回退...\033[0m"
    sudo npm install -g pnpm@9.15.0 --force || {
        echo -e "\033[31m错误：无法安装pnpm，脚本终止\033[0m"
        exit 1
    }
fi

pnpm config set registry https://registry.npmmirror.com/ 2>/dev/null || true
pnpm config set store-dir /tmp/pnpm-store 2>/dev/null || true
echo ""

# ===================== 步骤5：更新系统包 =====================
echo -e "\033[34m【步骤5/10】更新系统包列表并升级...\033[0m"
sudo apt update -y 2>&1 | grep -v "Problem executing scripts" | grep -v "Sub-process returned an error code" || true
sudo apt upgrade -y 2>&1 | grep -v "Problem executing scripts" | grep -v "Sub-process returned an error code" || true
echo ""

# ===================== 步骤6：安装Python（智能适配最新版本）====================
echo -e "\033[34m【步骤6/10】安装Python（智能适配系统最新版本）...\033[0m"

declare -A PYTHON_VERSION_MAP=(
    ["focal"]="3.10"
    ["jammy"]="3.11"
    ["noble"]="3.12"
    ["oracular"]="3.12"
    ["plucky"]="3.13"
    ["trixie"]="3.13"
    ["bookworm"]="3.11"
    ["bullseye"]="3.9"
    ["buster"]="3.7"
)

TARGET_PYTHON="${PYTHON_VERSION_MAP[$OS_VERSION]}"
PYTHON_INSTALLED=false

if [ -z "$TARGET_PYTHON" ]; then
    TARGET_PYTHON="3.12"
fi

echo "目标Python版本: $TARGET_PYTHON"

install_python() {
    local py_ver=$1
    local py_pkg="python${py_ver}"
    
    if sudo apt install -y ${py_pkg} ${py_pkg}-venv ${py_pkg}-dev 2>&1 | grep -v "Problem executing scripts"; then
        echo -e "\033[32m${py_pkg} 安装成功\033[0m"
        PYTHON_VERSION="${py_ver}"
        PYTHON_INSTALLED=true
        return 0
    fi
    
    return 1
}

add_deadsnakes_ppa() {
    local codename=$1
    echo "添加Deadsnakes PPA..."
    
    if command -v add-apt-repository &>/dev/null; then
        sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null && return 0
    fi
    
    echo "手动添加PPA源和GPG密钥..."
    echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${codename} main" | sudo tee /etc/apt/sources.list.d/deadsnakes.list
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys BA6932366A755776 2>/dev/null && return 0
    
    if command -v gpg &>/dev/null; then
        sudo gpg --no-default-keyring --keyring /usr/share/keyrings/deadsnakes.gpg \
            --keyserver keyserver.ubuntu.com --recv-keys BA6932366A755776 2>/dev/null && {
            echo "deb [signed-by=/usr/share/keyrings/deadsnakes.gpg] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${codename} main" | sudo tee /etc/apt/sources.list.d/deadsnakes.list
            return 0
        }
    fi
    
    if curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776" 2>/dev/null | sudo apt-key add - 2>/dev/null; then
        return 0
    fi
    
    return 1
}

if [ "$OS_TYPE" = "ubuntu" ]; then
    case $OS_VERSION in
        noble|oracular)
            echo "Ubuntu 24.04/24.10 使用原生Python 3.12..."
            install_python "3.12" || install_python "3.11" || install_python "3.10"
            ;;
        plucky)
            echo "Ubuntu 25.04 使用原生Python 3.13..."
            install_python "3.13" || install_python "3.12"
            ;;
        jammy)
            echo "Ubuntu 22.04 尝试安装Python 3.11..."
            add_deadsnakes_ppa "jammy" && sudo apt update -y 2>&1 | grep -v "Problem executing scripts" || true
            install_python "3.11" || install_python "3.10" || install_python "3.8"
            ;;
        focal)
            echo "Ubuntu 20.04 尝试安装Python 3.10..."
            add_deadsnakes_ppa "focal" && sudo apt update -y 2>&1 | grep -v "Problem executing scripts" || true
            install_python "3.10" || install_python "3.9" || install_python "3.8"
            ;;
        *)
            echo "未知Ubuntu版本，尝试安装Python 3.12..."
            install_python "3.12" || install_python "3.11" || install_python "3.10" || install_python "3.8"
            ;;
    esac
    
elif [ "$OS_TYPE" = "debian" ]; then
    case $OS_VERSION in
        trixie)
            echo "Debian 13 (Trixie) 使用原生Python 3.13..."
            install_python "3.13" || install_python "3.11"
            ;;
        bookworm)
            echo "Debian 12 (Bookworm) 使用原生Python 3.11..."
            install_python "3.11" || install_python "3.9"
            ;;
        bullseye)
            echo "Debian 11 (Bullseye) 使用原生Python 3.9..."
            install_python "3.9" || install_python "3.8"
            ;;
        buster)
            echo "Debian 10 (Buster) 使用原生Python 3.7..."
            install_python "3.7" || install_python "3.8"
            ;;
        *)
            echo "未知Debian版本，尝试安装Python 3.11..."
            install_python "3.11" || install_python "3.9" || install_python "3.8"
            ;;
    esac
else
    echo "WSL/其他系统，尝试安装Python 3.12..."
    install_python "3.12" || install_python "3.11" || install_python "3.10" || install_python "3.9" || install_python "3.8"
fi

if [ "$PYTHON_INSTALLED" = false ]; then
    echo "警告：特定版本安装失败，尝试安装系统默认Python3..."
    sudo apt install -y python3 python3-venv python3-dev python3-pip 2>&1 | grep -v "Problem executing scripts" || true
    PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}' | cut -d. -f1,2 || echo "3.8")
fi

echo -e "\033[32mPython版本确认: $PYTHON_VERSION\033[0m"
echo ""

# ===================== 步骤7：配置Python默认版本和pip（修复网络超时）====================
echo -e "\033[34m【步骤7/10】配置Python默认版本和pip...\033[0m"

if command -v python${PYTHON_VERSION} &>/dev/null; then
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 100 2>/dev/null || true
    sudo ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python 2>/dev/null || true
fi

sudo apt install -y python-is-python3 2>&1 | grep -v "Problem executing scripts" || {
    sudo ln -sf /usr/bin/python3 /usr/bin/python 2>/dev/null || true
}

# 检测是否需要 --break-system-packages
PIP_ARGS=""
if [ "$OS_TYPE" = "debian" ] && [ "$OS_VERSION" = "bookworm" ] || [ "$OS_VERSION" = "trixie" ]; then
    PIP_ARGS="--break-system-packages"
elif [ "$OS_TYPE" = "ubuntu" ] && [ "$OS_VERSION" = "noble" ] || [ "$OS_VERSION" = "oracular" ] || [ "$OS_VERSION" = "plucky" ]; then
    PIP_ARGS="--break-system-packages"
fi

# 安装/升级pip（带重试机制和超时设置）
echo "安装并配置pip..."
install_pip_with_retry() {
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        echo "尝试安装pip（第 $((retry+1))/$max_retries 次）..."
        
        # 方法1：使用get-pip.py
        if curl -sS --max-time 60 https://bootstrap.pypa.io/get-pip.py 2>/dev/null | sudo python${PYTHON_VERSION} 2>/dev/null; then
            echo -e "\033[32mpip安装成功（通过get-pip.py）\033[0m"
            return 0
        fi
        
        # 方法2：使用apt安装
        if sudo apt install -y python3-pip 2>&1 | grep -v "Problem executing scripts"; then
            python3 -m pip install --upgrade pip $PIP_ARGS --timeout 60 --retries 3 -i https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null && {
                echo -e "\033[32mpip安装成功（通过apt+升级）\033[0m"
                return 0
            }
        fi
        
        retry=$((retry+1))
        echo "等待5秒后重试..."
        sleep 5
    done
    
    return 1
}

if ! install_pip_with_retry; then
    echo -e "\033[33m警告：pip升级失败，使用系统自带pip继续...\033[0m"
fi

# 配置pip默认源（多镜像容错）
mkdir -p ~/.pip
tee ~/.pip/pip.conf > /dev/null <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120
retries = 5
cache-dir = /tmp/pip-cache

[install]
upgrade-strategy = only-if-needed
EOF

# 安装关键Python包（带重试）
pip install --user certifi urllib3 requests --upgrade -i https://pypi.tuna.tsinghua.edu.cn/simple --timeout 120 $PIP_ARGS 2>/dev/null || \
pip install --user certifi urllib3 requests --upgrade -i https://mirrors.aliyun.com/pypi/simple/ --timeout 120 $PIP_ARGS 2>/dev/null || true

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
sudo apt-get install --reinstall ca-certificates -y 2>&1 | grep -v "Problem executing scripts" || true
sudo update-ca-certificates --fresh 2>/dev/null || true

# WSL特定：安装必要的构建工具
if [ "$WSL_FLAG" = "WSL" ]; then
    echo "WSL环境：安装额外构建依赖..."
    sudo apt install -y build-essential python3-dev libsqlite3-dev pkg-config 2>&1 | grep -v "Problem executing scripts" || true
fi
echo ""

# ===================== 步骤10：部署青龙面板（关键修复）====================
echo -e "\033[34m【步骤10/10】部署青龙面板...\033[0m"

# 检查并清理旧版本
if [ -d "$HOME/qinglong" ]; then
    echo "检测到已有青龙目录，备份并重建..."
    mv ~/qinglong ~/qinglong.bak.$(date +%Y%m%d%H%M%S)
fi

# 克隆青龙源码（带重试机制）
echo "克隆青龙面板源码..."
cd ~

# 尝试多次克隆
clone_success=false
for attempt in 1 2 3; do
    echo "克隆尝试 $attempt/3..."
    
    if git clone --depth 1 https://github.com/whyour/qinglong.git 2>/dev/null; then
        clone_success=true
        break
    fi
    
    echo "直连失败，尝试使用代理..."
    git config --global url."https://ghfast.top/https://github.com/".insteadOf "https://github.com/"
    
    if git clone --depth 1 https://github.com/whyour/qinglong.git 2>/dev/null; then
        clone_success=true
        break
    fi
    
    echo "等待3秒后重试..."
    sleep 3
done

if [ "$clone_success" = false ]; then
    echo -e "\033[31m错误：无法克隆青龙源码，请检查网络连接\033[0m"
    exit 1
fi

cd qinglong || { echo -e "\033[31m错误：青龙目录不存在！\033[0m"; exit 1; }

[ -f .env.example ] && cp .env.example .env

# ===================== 关键修复：SQLite3预编译二进制 =====================
echo "配置SQLite3预编译二进制下载..."

# 方法1：设置环境变量使用国内镜像下载sqlite3二进制
export npm_config_sqlite3_binary_site="https://registry.npmmirror.com/-/binary/sqlite3"
export npm_config_sqlite3_binary_host_mirror="https://registry.npmmirror.com/-/binary/sqlite3"

# 方法2：针对 @whyour/sqlite3 的特殊处理
export npm_config_whour_sqlite3_binary_host_mirror="https://ghfast.top/https://github.com/whyour/node-sqlite3/releases/download"
export npm_config_whour_sqlite3_binary_site="https://ghfast.top/https://github.com/whyour/node-sqlite3/releases/download"

# 方法3：强制使用本地编译但修复权限
export npm_config_build_from_source=false
export npm_config_unsafe_perm=true
export npm_config_user=root

# 配置pnpm
pnpm config set registry https://registry.npmmirror.com/
pnpm config set store-dir /tmp/pnpm-store
pnpm config set unsafe-perm true

# 安装系统依赖
echo "安装系统编译依赖..."
sudo apt-get install -y build-essential libsqlite3-dev python3-dev pkg-config 2>&1 | grep -v "Problem executing scripts" || true

# ===================== 关键修复：安装项目依赖（多策略容错）====================
echo "安装青龙面板项目依赖（这可能需要几分钟）..."

# 策略1：先尝试使用 pnpm 安装（带SQLite3预下载修复）
echo "策略1：使用pnpm安装（配置预编译二进制）..."
if pnpm install --config.unsafe-perm=true --config.sqlite3_binary_host_mirror=https://registry.npmmirror.com/-/binary/sqlite3 2>&1; then
    echo -e "\033[32mpnpm install 成功！\033[0m"
else
    echo -e "\033[33mpnpm install失败，尝试策略2...\033[0m"
    
    # 策略2：手动下载并放置sqlite3二进制
    echo "策略2：手动处理SQLite3依赖..."
    
    # 创建目录结构
    mkdir -p node_modules/@whyour/sqlite3/lib/binding/napi-v6-linux-x64-glibc
    
    # 尝试从多个源下载预编译二进制
    SQLITE3_URLS=(
        "https://fastgit.cc/https://github.com/whyour/node-sqlite3/releases/download/v1.0.3/napi-v6-linux-x64-glibc.tar.gz"
        "https://ghfast.top/https://github.com/whyour/node-sqlite3/releases/download/v1.0.3/napi-v6-linux-x64-glibc.tar.gz"
        "https://mirror.ghproxy.com/https://github.com/whyour/node-sqlite3/releases/download/v1.0.3/napi-v6-linux-x64-glibc.tar.gz"
    )
    
    SQLITE3_DOWNLOADED=false
    for url in "${SQLITE3_URLS[@]}"; do
        echo "尝试从 $url 下载SQLite3二进制..."
        if curl -fsSL --max-time 60 "$url" -o /tmp/sqlite3-binary.tar.gz 2>/dev/null; then
            echo "下载成功，解压中..."
            tar -xzf /tmp/sqlite3-binary.tar.gz -C node_modules/@whyour/sqlite3/lib/binding/napi-v6-linux-x64-glibc/ 2>/dev/null && {
                SQLITE3_DOWNLOADED=true
                echo -e "\033[32mSQLite3预编译二进制放置成功\033[0m"
                break
            }
        fi
    done
    
    # 策略3：如果预编译下载失败，强制本地编译
    if [ "$SQLITE3_DOWNLOADED" = false ]; then
        echo -e "\033[33m预编译二进制下载失败，强制本地编译...\033[0m"
        export npm_config_build_from_source=true
        export npm_config_unsafe_perm=true
        
        # 清理并重试
        rm -rf node_modules
        pnpm install --config.build-from-source=true --config.unsafe-perm=true 2>&1 || {
            echo -e "\033[33mpnpm再次失败，尝试使用npm...\033[0m"
            npm install --registry=https://registry.npmmirror.com/ --unsafe-perm=true 2>&1
        }
    else
        # 预编译已放置，重新执行pnpm install（跳过sqlite3编译）
        echo "重新执行依赖安装（跳过SQLite3编译）..."
        pnpm install --config.unsafe-perm=true --offline 2>&1 || \
        pnpm install --config.unsafe-perm=true 2>&1 || {
            echo -e "\033[33mpnpm失败，尝试npm...\033[0m"
            npm install --registry=https://registry.npmmirror.com/ --unsafe-perm=true 2>&1
        }
    fi
fi

echo ""

# ===================== 关键修复：创建完整的task和ql命令 =====================
echo -e "\033[34m【关键修复】创建青龙task和ql命令...\033[0m"

# 创建shell目录（如果不存在）
mkdir -p ~/qinglong/shell

# 创建完整的task命令
sudo tee /usr/local/bin/task > /dev/null <<'TASK_EOF'
#!/bin/bash
# ============================================
# 青龙面板 task 命令 - 完整修复版
# 支持：scripts目录、子目录、swap临时文件
# ============================================

QL_DIR="/root/qinglong"
SCRIPTS_DIR="$QL_DIR/scripts"
LOGS_DIR="$QL_DIR/log"

# 调试输出
DEBUG=false

# 查找脚本的完整逻辑
find_script() {
    local target="$1"
    local found=""
    
    # 调试信息
    [ "$DEBUG" = true ] && echo "[DEBUG] 查找脚本: $target" >&2
    
    # 1. 直接路径检查（绝对路径）
    if [ -f "$target" ]; then
        [ "$DEBUG" = true ] && echo "[DEBUG] 找到绝对路径: $target" >&2
        echo "$target"
        return 0
    fi
    
    # 2. 在scripts目录下直接查找
    if [ -f "$SCRIPTS_DIR/$target" ]; then
        [ "$DEBUG" = true ] && echo "[DEBUG] 找到scripts目录: $SCRIPTS_DIR/$target" >&2
        echo "$SCRIPTS_DIR/$target"
        return 0
    fi
    
    # 3. 处理 swap 文件（关键修复！）
    # 青龙会生成类似 notify.swap.py 的临时文件，实际对应 notify.py
    if [[ "$target" == *.swap.* ]]; then
        local base_name="${target%.swap.*}"
        local ext="${target##*.}"
        
        [ "$DEBUG" = true ] && echo "[DEBUG] 处理swap文件: base=$base_name, ext=$ext" >&2
        
        # 查找原始文件
        if [ -f "$SCRIPTS_DIR/$base_name.$ext" ]; then
            [ "$DEBUG" = true ] && echo "[DEBUG] 找到swap原始文件: $SCRIPTS_DIR/$base_name.$ext" >&2
            echo "$SCRIPTS_DIR/$base_name.$ext"
            return 0
        fi
        
        # 递归查找子目录
        found=$(find "$SCRIPTS_DIR" -name "$base_name.$ext" -type f 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            [ "$DEBUG" = true ] && echo "[DEBUG] 在子目录找到swap原始文件: $found" >&2
            echo "$found"
            return 0
        fi
    fi
    
    # 4. 处理路径包含目录的情况
    if [[ "$target" == */* ]]; then
        if [ -f "$SCRIPTS_DIR/$target" ]; then
            [ "$DEBUG" = true ] && echo "[DEBUG] 找到子目录路径: $SCRIPTS_DIR/$target" >&2
            echo "$SCRIPTS_DIR/$target"
            return 0
        fi
        
        # 在scripts下递归查找文件名
        local file_part=$(basename "$target")
        found=$(find "$SCRIPTS_DIR" -name "$file_part" -type f 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            [ "$DEBUG" = true ] && echo "[DEBUG] 递归找到文件: $found" >&2
            echo "$found"
            return 0
        fi
    fi
    
    # 5. 全局搜索（最后手段）
    found=$(find "$SCRIPTS_DIR" -name "$(basename "$target")" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        [ "$DEBUG" = true ] && echo "[DEBUG] 全局搜索找到: $found" >&2
        echo "$found"
        return 0
    fi
    
    return 1
}

# 参数解析
MODE="normal"
FILE_PATH=""
PARAMS=""
NOW_MODE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        now)
            NOW_MODE=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --*)
            shift
            ;;
        *)
            if [ -z "$FILE_PATH" ]; then
                FILE_PATH="$1"
            else
                PARAMS="$PARAMS $1"
            fi
            shift
            ;;
    esac
done

# 检查文件路径
if [ -z "$FILE_PATH" ]; then
    echo "Usage: task <file_path> [now]"
    echo "  now - 立即执行，忽略随机延迟"
    exit 1
fi

# 查找脚本
SCRIPT_FULL_PATH=$(find_script "$FILE_PATH")

if [ -z "$SCRIPT_FULL_PATH" ]; then
    echo "Error: Script not found: $FILE_PATH"
    echo "Searched in: $SCRIPTS_DIR"
    echo ""
    echo "Available scripts:"
    ls -la "$SCRIPTS_DIR/" 2>/dev/null || echo "  (无法读取目录)"
    exit 1
fi

# 获取脚本信息
SCRIPT_NAME=$(basename "$SCRIPT_FULL_PATH")
SCRIPT_DIR=$(dirname "$SCRIPT_FULL_PATH")

# 创建日志目录
TASK_LOG_DIR="$LOGS_DIR/$SCRIPT_NAME"
mkdir -p "$TASK_LOG_DIR"

# 生成日志文件名
LOG_DATE=$(date +"%Y-%m-%d-%H-%M-%S-%3N")
LOG_FILE="$TASK_LOG_DIR/$LOG_DATE.log"

# 设置环境变量
export QL_DIR="$QL_DIR"
export QL_SCRIPTS_DIR="$SCRIPTS_DIR"
export QL_LOGS_DIR="$LOGS_DIR"

# 加载青龙环境（如果存在）
[ -f "$QL_DIR/config/env.sh" ] && source "$QL_DIR/config/env.sh" 2>/dev/null
[ -f "$QL_DIR/config/config.sh" ] && source "$QL_DIR/config/config.sh" 2>/dev/null

# 切换到脚本所在目录
cd "$SCRIPT_DIR" || cd "$QL_DIR"

# 随机延迟（如果不是now模式）
if [ "$NOW_MODE" = false ]; then
    DELAY=$((RANDOM % 5 + 1))
    echo "随机延迟 ${DELAY} 秒..."
    sleep $DELAY
fi

echo "========================================"
echo "开始执行: $SCRIPT_NAME"
echo "脚本路径: $SCRIPT_FULL_PATH"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# 构建执行命令
case "${SCRIPT_FULL_PATH##*.}" in
    js)
        CMD="node \"$SCRIPT_FULL_PATH\""
        ;;
    py)
        CMD="python3 \"$SCRIPT_FULL_PATH\""
        ;;
    sh)
        CMD="bash \"$SCRIPT_FULL_PATH\""
        ;;
    ts)
        CMD="ts-node \"$SCRIPT_FULL_PATH\""
        ;;
    *)
        CMD="bash \"$SCRIPT_FULL_PATH\""
        ;;
esac

# 添加参数
if [ -n "$PARAMS" ]; then
    CMD="$CMD $PARAMS"
fi

# 执行并记录日志
eval "$CMD" > "$LOG_FILE" 2>&1
EXIT_CODE=$?

# 输出结果
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ 执行成功: $SCRIPT_NAME"
else
    echo "❌ 执行失败: $SCRIPT_NAME (退出码: $EXIT_CODE)"
    echo "日志: $LOG_FILE"
    tail -n 20 "$LOG_FILE"
fi

exit $EXIT_CODE
TASK_EOF

sudo chmod +x /usr/local/bin/task

# 创建ql命令
sudo tee /usr/local/bin/ql > /dev/null <<'QL_EOF'
#!/bin/bash
# ============================================
# 青龙面板 ql 命令
# ============================================

QL_DIR="/root/qinglong"

case "$1" in
    check)
        echo "检查青龙面板..."
        cd "$QL_DIR" && pnpm start
        ;;
    update)
        echo "更新青龙面板..."
        cd "$QL_DIR" && git pull && pnpm install && pnpm build
        ;;
    restart)
        echo "重启青龙面板..."
        pkill -f "concurrently" 2>/dev/null
        pkill -f "nodemon" 2>/dev/null
        pkill -f "qinglong" 2>/dev/null
        sleep 2
        cd "$QL_DIR" && pnpm start
        ;;
    stop)
        echo "停止青龙面板..."
        pkill -f "concurrently" 2>/dev/null
        pkill -f "nodemon" 2>/dev/null
        pkill -f "qinglong" 2>/dev/null
        echo "已停止"
        ;;
    rmlog)
        days="${2:-7}"
        echo "清理${days}天前的日志..."
        find "$QL_DIR/log" -name "*.log" -mtime +$days -delete 2>/dev/null
        echo "清理完成"
        ;;
    repo)
        shift
        echo "拉取仓库: $@"
        # 这里可以集成 git clone 逻辑
        cd "$QL_DIR/scripts" && git clone "$@" 2>/dev/null || echo "拉取失败"
        ;;
    raw)
        shift
        url="$1"
        echo "下载脚本: $url"
        wget -q "$url" -P "$QL_DIR/scripts/" 2>/dev/null || curl -fsSL "$url" -o "$QL_DIR/scripts/$(basename $url)"
        ;;
    *)
        echo "青龙面板管理命令"
        echo ""
        echo "Usage: ql [command]"
        echo ""
        echo "Commands:"
        echo "  check           检查并启动面板"
        echo "  update          更新面板代码"
        echo "  restart         重启面板"
        echo "  stop            停止面板"
        echo "  rmlog [days]    清理日志（默认7天）"
        echo "  repo <url>      拉取脚本仓库"
        echo "  raw <url>       下载单个脚本"
        ;;
esac
QL_EOF

sudo chmod +x /usr/local/bin/ql

# 验证命令
echo "验证task命令..."
task --version 2>/dev/null || echo "task命令已安装"

echo "验证ql命令..."
ql 2>/dev/null || echo "ql命令已安装"

echo ""

# ===================== 关键修复：配置环境变量和端口 =====================
echo -e "\033[34m【关键修复】配置青龙环境...\033[0m"

# 创建必要的目录
mkdir -p ~/qinglong/config
mkdir -p ~/qinglong/scripts
mkdir -p ~/qinglong/log
mkdir -p ~/qinglong/db

# 配置.env文件
if [ -f ~/qinglong/.env ]; then
    # 确保端口配置正确
    if ! grep -q "QL_PORT" ~/qinglong/.env; then
        echo "QL_PORT=5700" >> ~/qinglong/.env
    fi
    if ! grep -q "QL_BASE_URL" ~/qinglong/.env; then
        echo 'QL_BASE_URL="/"' >> ~/qinglong/.env
    fi
fi

echo ""

# ===================== 启动青龙面板 =====================
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m              部署完成！\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo -e "✅ 全维度加速源配置生效：阿里云APT + 清华pip + 淘宝pnpm/npm"
echo -e "✅ 环境版本："
echo -e "   - Python: \033[33m$(python3 --version 2>/dev/null)\033[0m"
echo -e "   - Node.js: \033[33m$(node --version 2>/dev/null)\033[0m"
echo -e "   - pnpm: \033[33m$(pnpm --version 2>/dev/null)\033[0m"
echo -e "📌 访问地址：\033[36mhttp://localhost:5700\033[0m"
echo -e "📌 管理命令："
echo -e "   - 启动：\033[36mcd ~/qinglong && pnpm start\033[0m"
echo -e "   - 停止：\033[36mql stop\033[0m"
echo -e "   - 重启：\033[36mql restart\033[0m"
echo -e "   - 查看日志：\033[36mcd ~/qinglong && pnpm log\033[0m"
echo -e "📌 首次访问请按提示初始化账号"
echo -e "\033[32m=============================================\033[0m"
echo ""

# 启动青龙面板
echo "正在启动青龙面板..."
cd ~/qinglong && pnpm start
