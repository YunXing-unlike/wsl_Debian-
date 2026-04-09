#!/bin/bash
set -e
clear

echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      青龙面板部署脚本（修复版 v2.0）\033[0m"
echo -e "\033[32m  修复：WSL权限问题 | 网络超时 | 预编译二进制下载\033[0m"
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
    # WSL 权限修复：禁用 sqlite3 的权限检查
    export npm_config_unsafe_perm=true
    export npm_config_user=root
    # 使用 /tmp 作为构建目录（内存文件系统，权限问题较少）
    export TMPDIR=/tmp
    export npm_config_tmp=/tmp
fi

# ===================== 前置：全维度国内加速源配置 =====================
echo -e "\033[34m【前置步骤】配置全维度国内加速源...\033[0m"

OS_TYPE=$(grep -Ei 'debian|ubuntu' /etc/os-release | grep 'ID=' | cut -d= -f2 | tr -d '"' | head -1)
OS_VERSION=$(grep -Ei 'VERSION_CODENAME' /etc/os-release | cut -d= -f2 | tr -d '"')

echo "检测到系统: $OS_TYPE $OS_VERSION ($WSL_FLAG)"

# 配置APT阿里云源
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

sudo apt clean
sudo apt update -y
echo ""

# ===================== 步骤1：安装基础工具 =====================
echo -e "\033[34m【步骤1/10】安装基础工具...\033[0m"

if [ "$OS_TYPE" = "ubuntu" ]; then
    sudo apt install -y git curl wget ca-certificates software-properties-common apt-transport-https gnupg lsb-release
else
    sudo apt install -y git curl wget ca-certificates apt-transport-https gnupg lsb-release
fi
echo ""

# ===================== 步骤2：配置Git国内加速 =====================
echo -e "\033[34m【步骤2/10】配置Git国内加速...\033[0m"
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

# ===================== 步骤3：安装Node.js 22.x LTS =====================
echo -e "\033[34m【步骤3/10】安装Node.js 22.x LTS...\033[0m"

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

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
    local pnpm_url="https://github.com/pnpm/pnpm/releases/download/v10.6.2/pnpm-linux-x64"
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
sudo apt update -y
sudo apt upgrade -y
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
    
    if sudo apt install -y ${py_pkg} ${py_pkg}-venv ${py_pkg}-dev 2>/dev/null; then
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
            add_deadsnakes_ppa "jammy" && sudo apt update -y
            install_python "3.11" || install_python "3.10" || install_python "3.8"
            ;;
        focal)
            echo "Ubuntu 20.04 尝试安装Python 3.10..."
            add_deadsnakes_ppa "focal" && sudo apt update -y
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
    sudo apt install -y python3 python3-venv python3-dev python3-pip
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

sudo apt install -y python-is-python3 2>/dev/null || {
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
        if sudo apt install -y python3-pip 2>/dev/null; then
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
sudo apt-get install --reinstall ca-certificates -y 2>/dev/null || true
sudo update-ca-certificates --fresh 2>/dev/null || true

# WSL特定：安装必要的构建工具
if [ "$WSL_FLAG" = "WSL" ]; then
    echo "WSL环境：安装额外构建依赖..."
    sudo apt install -y build-essential python3-dev libsqlite3-dev pkg-config
fi
echo ""

# ===================== 步骤10：部署青龙面板（关键修复）====================
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
export npm_config_build_from_source=false  # 先尝试下载预编译
export npm_config_unsafe_perm=true
export npm_config_user=root

# 配置pnpm
pnpm config set registry https://registry.npmmirror.com/
pnpm config set store-dir /tmp/pnpm-store
pnpm config set unsafe-perm true  # WSL关键修复

# 安装系统依赖
echo "安装系统编译依赖..."
sudo apt-get install -y build-essential libsqlite3-dev python3-dev pkg-config 2>/dev/null || true

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
        "https://github.com/whyour/node-sqlite3/releases/download/v1.0.3/napi-v6-linux-x64-glibc.tar.gz"
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
echo -e "   -
