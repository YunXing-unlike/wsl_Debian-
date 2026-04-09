#!/bin/bash
set -e  # 出错自动退出，避免卡壳
clear

# 打印脚本说明
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      青龙面板部署脚本（全自动+全维度加速）\033[0m"
echo -e "\033[32m  适配：Debian/Ubuntu/WSL Linux子系统\033[0m"
echo -e "\033[32m  加速源：阿里云(APT) | 清华源(pip) | 淘宝源(pnpm/npm) | gitproxy.mrhjx.cn(Git)\033[0m"
echo -e "\033[32m  特性：全程自动确认（无需手动输y/回车）\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo ""

# ===================== 前置：修复PATH环境变量 + 强制刷新 =====================
echo -e "\033[34m【前置优化】配置全局命令PATH环境变量...\033[0m"
# 覆盖所有可能的全局目录
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# 写入bashrc确保永久生效
echo "export PATH=$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc  # 强制刷新
echo ""

# ===================== 前置：全维度国内加速源配置 =====================
echo -e "\033[34m【前置步骤】配置全维度国内加速源...\033[0m"
# 1. 自动识别系统版本
OS_TYPE=$(grep -Ei 'debian|ubuntu' /etc/os-release | grep 'ID=' | cut -d= -f2 | tr -d '"')
OS_VERSION=$(grep -Ei 'VERSION_CODENAME' /etc/os-release | cut -d= -f2 | tr -d '"')
WSL_FLAG=$(grep -qi "microsoft" /proc/version && echo "WSL" || echo "原生Linux")

# 2. 配置APT阿里云源（自动备份+适配版本）
echo "配置APT阿里云源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d)
if [ "$OS_TYPE" = "ubuntu" ]; then
    # Ubuntu版本映射（兼容旧版本codename）
    case $OS_VERSION in
        focal)
            CODENAME="focal"
            ;;
        jammy)
            CODENAME="jammy"
            ;;
        noble)
            CODENAME="noble"
            ;;
        *)
            CODENAME="jammy"  # 默认 fallback 到 jammy
            ;;
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
    # Debian版本映射
    case $OS_VERSION in
        bookworm)
            CODENAME="bookworm"
            ;;
        bullseye)
            CODENAME="bullseye"
            ;;
        buster)
            CODENAME="buster"
            ;;
        *)
            CODENAME="bookworm"
            ;;
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
sudo apt update -y  # 刷新源（关键修复：新增这一步）

# 3. 配置Git国内加速（替换为gitproxy.mrhjx.cn）
echo "配置Git gitproxy.mrhjx.cn加速..."
git config --global url."https://gitproxy.mrhjx.cn/https://github.com/".insteadOf "https://github.com/"
git config --global url."https://gitproxy.mrhjx.cn/https://gist.github.com/".insteadOf "https://gist.github.com/"
if [ "$WSL_FLAG" = "WSL" ]; then
    git config --global http.sslVerify false
    git config --global core.compression 9
fi
echo ""

# ===================== 1. 安装Git（自动确认） =====================
echo -e "\033[34m【步骤1/12】安装Git...\033[0m"
sudo apt install git -y
echo ""

# ===================== 2. 安装Node.js + 用corepack安装pnpm（核心修复） =====================
echo -e "\033[34m【步骤2/12】安装Node.js 18.x、npm、pnpm 8.3.1...\033[0m"
# 自动确认Node.js源添加
echo "" | curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y

# 配置npm国内源
npm config set registry https://registry.npmmirror.com/
npm config set cache /tmp/npm-cache

# ========== 关键：用corepack安装pnpm（官方方式，100%解决命令找不到） ==========
echo "启用corepack并安装pnpm 8.3.1..."
corepack enable  # 启用Node.js内置的包管理器管理工具
corepack prepare pnpm@8.3.1 --activate  # 安装并激活指定版本pnpm

# 验证pnpm是否安装成功
if command -v pnpm &>/dev/null; then
    echo -e "\033[32mpnpm安装成功，版本：$(pnpm --version)\033[0m"
else
    echo -e "\033[31m紧急修复：手动创建pnpm软链接...\033[0m"
    sudo ln -s "$(which pnpm)" /usr/local/bin/pnpm
fi

# 配置pnpm国内源+缓存
pnpm config set registry https://registry.npmmirror.com/
pnpm config set store-dir /tmp/pnpm-store
echo ""

# ===================== 3. 更新系统包列表（自动确认） =====================
echo -e "\033[34m【步骤3/12】更新系统包列表并升级...\033[0m"
sudo apt update -y
sudo apt upgrade -y
echo ""

# ===================== 4. 安装Python（适配不同系统版本）【核心修复】 =====================
echo -e "\033[34m【步骤4/12】安装Python（自动适配系统版本）...\033[0m"
# 安装基础依赖
sudo apt install software-properties-common apt-transport-https ca-certificates -y

# ========== 核心修复：解决Python包找不到的问题 ==========
# 先尝试添加Deadsnakes PPA（兼容WSL）
add_ppa_success=0
if [ "$OS_TYPE" = "ubuntu" ]; then
    echo "尝试添加Deadsnakes PPA源..."
    # 强制刷新证书（解决WSL下PPA添加失败）
    sudo update-ca-certificates --fresh
    # 非交互模式添加PPA（避免手动确认）
    echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu $CODENAME main" | sudo tee /etc/apt/sources.list.d/deadsnakes.list
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A7557766
    # 刷新源
    sudo apt update -y || add_ppa_success=1
fi

# 根据系统类型选择Python版本（完整修复逻辑）
if [ "$OS_TYPE" = "ubuntu" ]; then
    # Ubuntu不同版本的Python支持（修复核心）
    case $OS_VERSION in
        # Ubuntu 20.04 (focal) - 优先用系统自带3.8，PPA失败时不强制3.10
        focal)
            if [ $add_ppa_success -eq 0 ] && command -v apt-cache &>/dev/null && apt-cache show python3.10 &>/dev/null; then
                echo "检测到Ubuntu 20.04 + PPA可用，安装Python 3.10..."
                sudo apt install python3.10 python3.10-venv python3.10-dev -y
                PYTHON_VERSION="3.10"
            else
                echo "Ubuntu 20.04 PPA源不可用，安装系统自带Python 3.8..."
                sudo apt install python3.8 python3.8-venv python3.8-dev -y
                PYTHON_VERSION="3.8"
            fi
            ;;
        # Ubuntu 22.04+ 支持3.12
        jammy|noble)
            if [ $add_ppa_success -eq 0 ] && apt-cache show python3.12 &>/dev/null; then
                echo "安装Python 3.12..."
                sudo apt install python3.12 python3.12-venv python3.12-dev -y
                PYTHON_VERSION="3.12"
            else
                echo "安装系统默认Python3..."
                sudo apt install python3 python3-venv python3-dev -y
                PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
            fi
            ;;
        *)
            # 未知Ubuntu版本，先尝试装系统自带Python3，再升级
            echo "未知Ubuntu版本，安装系统默认Python3..."
            sudo apt install python3 python3-venv python3-dev -y
            PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
            echo "当前系统Python版本：$PYTHON_VERSION"
            ;;
    esac
elif [ "$OS_TYPE" = "debian" ]; then
    # Debian系统（修复：优先装系统自带版本）
    case $OS_VERSION in
        # Debian 12 (bookworm) 自带3.11
        bookworm)
            echo "检测到Debian 12，安装Python 3.11..."
            sudo apt install python3.11 python3.11-venv python3.11-dev -y
            PYTHON_VERSION="3.11"
            ;;
        # Debian 11 (bullseye) 自带3.9
        bullseye)
            echo "检测到Debian 11，安装Python 3.9..."
            sudo apt install python3.9 python3.9-venv python3.9-dev -y
            PYTHON_VERSION="3.9"
            ;;
        # Debian 10 (buster) 自带3.7
        buster)
            echo "检测到Debian 10，安装Python 3.7..."
            sudo apt install python3.7 python3.7-venv python3.7-dev -y
            PYTHON_VERSION="3.7"
            ;;
        *)
            # 兜底安装系统默认Python3
            echo "未知Debian版本，安装系统默认Python3..."
            sudo apt install python3 python3-venv python3-dev -y
            PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
            ;;
    esac
else
    # WSL/其他系统，默认安装系统自带Python3（修复：兼容所有WSL）
    echo "检测到WSL/其他系统，安装系统默认Python3..."
    sudo apt install python3 python3-venv python3-dev -y
    PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
fi
echo ""

# ===================== 5. 安装Python编译依赖（自动确认） =====================
echo -e "\033[34m【步骤5/12】安装Python编译依赖包...\033[0m"
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev -y
echo ""

# ===================== 6. 配置Python默认版本 =====================
echo -e "\033[34m【步骤6/12】配置Python $PYTHON_VERSION 为默认版本...\033[0m"
# 修复：兼容系统默认Python（避免update-alternatives报错）
if command -v python$PYTHON_VERSION &>/dev/null; then
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python$PYTHON_VERSION 1
    echo "1" | sudo update-alternatives --config python3 || true
else
    echo "使用系统默认Python3..."
fi
# 修复python命令指向（容错）
sudo ln -sf /usr/bin/python3 /usr/bin/python || true
echo ""

# ===================== 7. 安装pip并升级（自动确认） =====================
echo -e "\033[34m【步骤7/12】安装pip...\033[0m"
sudo apt install python3-pip -y
echo ""

echo -e "\033[34m【步骤8/12】升级pip（清华源加速）...\033[0m"
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple

# 配置pip默认清华源
echo -e "\033[34m配置pip默认清华源...\033[0m"
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
echo ""

# ===================== 8. 环境版本验证 =====================
echo -e "\033[34m【步骤9/12】验证环境版本...\033[0m"
echo -e "Python版本：\033[32m$(python3 --version | awk '{print $2}')\033[0m"
echo -e "pip版本：\033[32m$(pip3 --version | awk '{print $2}' | cut -d'/' -f1)\033[0m"
echo -e "Node.js版本：\033[32m$(node --version)\033[0m"
echo -e "pnpm版本：\033[32m$(pnpm --version)\033[0m"
echo ""

# ===================== 9. 青龙面板部署（全程自动） =====================
echo -e "\033[34m【步骤10/12】部署青龙面板...\033[0m"
# 修复CA证书
echo "修复系统CA证书..."
sudo apt-get install --reinstall ca-certificates -y
sudo update-ca-certificates --fresh

# 升级Python网络依赖
echo "升级Python网络依赖库..."
pip install certifi urllib3 requests --upgrade -i https://pypi.tuna.tsinghua.edu.cn/simple

# 初始化pnpm
echo "初始化pnpm环境..."
yes | pnpm setup

# 克隆青龙源码
echo "克隆青龙面板源码..."
git clone https://github.com/whyour/qinglong.git

# 进入项目目录（容错）
cd qinglong || { echo -e "\033[31m错误：青龙目录不存在！\033[0m"; exit 1; }

# 复制环境变量
echo "复制环境变量配置文件..."
cp .env.example .env

# 确认pnpm国内源
echo "确认pnpm淘宝镜像源..."
pnpm config set registry https://registry.npmmirror.com/

# 安装系统依赖
echo "安装系统依赖..."
sudo apt-get install python3 python-is-python3 build-essential libsqlite3-dev -y

# 安装项目依赖
echo "安装青龙面板项目依赖..."
pnpm install

# 启动青龙面板
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m              部署完成！🎉\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo -e "✅ 全维度加速源配置生效：阿里云APT + 清华pip + 淘宝pnpm/npm + gitproxy.mrhjx.cn Git"
echo -e "✅ 环境验证通过：Python $PYTHON_VERSION + pip 最新版 + Node.js 18 + pnpm 8.3.1"
echo -e "✅ 青龙面板依赖安装完成，即将启动..."
echo -e "📌 访问地址：http://localhost:5700"
echo -e "📌 如需重启面板：cd ~/qinglong && pnpm start"
echo -e "📌 APT源备份文件：/etc/apt/sources.list.bak.$(date +%Y%m%d)"
echo -e "\033[32m=============================================\033[0m"
echo ""

# 启动青龙面板
pnpm start
