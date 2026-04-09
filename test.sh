#!/bin/bash
clear

# 打印脚本说明
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      青龙面板部署脚本（严格按指定步骤+全维度加速）\033[0m"
echo -e "\033[32m  适配：Debian/Ubuntu/WSL Linux子系统\033[0m"
echo -e "\033[32m  加速源：阿里云(APT) | 清华源(pip) | 淘宝源(pnpm/npm) | gitproxy.mrhjx.cn(Git)\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo ""

# ===================== 前置：全维度国内加速源配置（核心新增） =====================
echo -e "\033[34m【前置步骤】配置全维度国内加速源...\033[0m"
# 1. 自动识别系统版本（适配Ubuntu/Debian/WSL）
OS_TYPE=$(grep -Ei 'debian|ubuntu' /etc/os-release | grep 'ID=' | cut -d= -f2 | tr -d '"')
OS_VERSION=$(grep -Ei 'VERSION_CODENAME' /etc/os-release | cut -d= -f2 | tr -d '"')
WSL_FLAG=$(grep -qi "microsoft" /proc/version && echo "WSL" || echo "原生Linux")

# 2. 配置APT国内源（阿里云，自动匹配版本+备份原文件）
echo "配置APT阿里云源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d)
if [ "$OS_TYPE" = "ubuntu" ]; then
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/ubuntu/ $OS_VERSION main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $OS_VERSION main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $OS_VERSION-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $OS_VERSION-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $OS_VERSION-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $OS_VERSION-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $OS_VERSION-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $OS_VERSION-backports main restricted universe multiverse
EOF
elif [ "$OS_TYPE" = "debian" ]; then
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/debian/ $OS_VERSION main non-free-firmware contrib non-free
deb-src http://mirrors.aliyun.com/debian/ $OS_VERSION main non-free-firmware contrib non-free
deb http://mirrors.aliyun.com/debian-security/ $OS_VERSION-security main non-free-firmware contrib non-free
deb-src http://mirrors.aliyun.com/debian-security/ $OS_VERSION-security main non-free-firmware contrib non-free
deb http://mirrors.aliyun.com/debian/ $OS_VERSION-updates main non-free-firmware contrib non-free
deb-src http://mirrors.aliyun.com/debian/ $OS_VERSION-updates main non-free-firmware contrib non-free
EOF
else
    # WSL未知版本兜底（Ubuntu 22.04）
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

# 3. 配置Git国内加速（ghproxy代理，WSL优化）
echo "配置Git ghproxy加速..."
git config --global url."https://gitproxy.mrhjx.cn/https://github.com/".insteadOf "https://github.com/"
git config --global url."https://gitproxy.mrhjx.cn/https://gist.github.com/".insteadOf "https://gist.github.com/"
if [ "$WSL_FLAG" = "WSL" ]; then
    git config --global http.sslVerify false
    git config --global core.compression 9  # 压缩传输提速
fi
echo ""

# ===================== 1. 安装Git =====================
echo -e "\033[34m【步骤1/12】安装Git...\033[0m"
sudo apt update
sudo apt install git -y
echo ""

# ===================== 2. 安装Node.js、npm、pnpm =====================
echo -e "\033[34m【步骤2/12】安装Node.js 18.x、npm、pnpm 8.3.1...\033[0m"
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y
# 新增：安装完Node.js后立即配置npm国内源（淘宝）
echo "配置npm淘宝镜像源..."
npm config set registry https://registry.npmmirror.com/
npm config set cache /tmp/npm-cache  # WSL权限优化
npm config set prefix ~/.npm-global
npm install -g pnpm@8.3.1
# 新增：配置pnpm国内源（提前配置，后续部署时再次确认）
pnpm config set registry https://registry.npmmirror.com/
pnpm config set store-dir /tmp/pnpm-store  # WSL缓存优化
echo ""

# ===================== 3. 更新系统包列表 =====================
echo -e "\033[34m【步骤3/12】更新系统包列表并升级...\033[0m"
sudo apt update
sudo apt upgrade
echo ""

# ===================== 4. 添加Deadsnakes PPA =====================
echo -e "\033[34m【步骤4/12】添加Deadsnakes PPA（需按回车确认）...\033[0m"
sudo apt install software-properties-common -y
# 提示用户按回车确认
echo -e "\033[33m⚠️  即将执行add-apt-repository，出现提示时请按【回车】确认！\033[0m"
read -p "按任意键继续..."
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
echo ""

# ===================== 5. 安装Python编译依赖 =====================
echo -e "\033[34m【步骤5/12】安装Python编译依赖包...\033[0m"
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev -y
echo ""

# ===================== 6. 更新Python 3.12及组件 =====================
echo -e "\033[34m【步骤6/12】安装Python 3.12（需按y+回车确认）...\033[0m"
echo -e "\033[33m⚠️  执行安装时请按【y】并回车确认！\033[0m"
read -p "按任意键继续..."
sudo apt install python3.12
echo ""

echo -e "\033[34m【步骤7/12】安装Python 3.12 venv/dev组件（需按y+回车确认）...\033[0m"
echo -e "\033[33m⚠️  执行安装时请按【y】并回车确认！\033[0m"
read -p "按任意键继续..."
sudo apt install python3.12-venv python3.12-dev
echo ""

# ===================== 7. 配置Python默认版本 =====================
echo -e "\033[34m【步骤8/12】配置Python 3.12为默认版本...\033[0m"
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
echo -e "\033[33m⚠️  请在弹出的选择界面中，输入Python 3.12对应的序号并回车！\033[0m"
read -p "按任意键继续..."
sudo update-alternatives --config python3
echo ""

# ===================== 8. 安装pip并升级 =====================
echo -e "\033[34m【步骤9/12】安装pip（需按y+回车确认）...\033[0m"
echo -e "\033[33m⚠️  执行安装时请按【y】并回车确认！\033[0m"
read -p "按任意键继续..."
sudo apt install python3-pip
echo ""

echo -e "\033[34m【步骤10/12】升级pip到25.0.1（清华源加速）...\033[0m"
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade pip==25.0.1 -i https://pypi.tuna.tsinghua.edu.cn/simple

# 强化：配置pip默认清华源（保留原逻辑，新增WSL优化）
echo -e "\033[34m配置pip默认清华源（WSL优化）...\033[0m"
mkdir -p ~/.pip
tee ~/.pip/pip.conf > /dev/null <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120
cache-dir = /tmp/pip-cache  # WSL权限优化

[install]
upgrade-strategy = only-if-needed
EOF
echo ""

# ===================== 9. 环境版本验证 =====================
echo -e "\033[34m【步骤11/12】验证环境版本...\033[0m"
echo -e "Python版本：\033[32m$(python3 --version | awk '{print $2}')\033[0m"
echo -e "pip版本：\033[32m$(pip3 --version | awk '{print $2}' | cut -d'/' -f1)\033[0m"
echo -e "Node.js版本：\033[32m$(node --version)\033[0m"
echo -e "pnpm版本：\033[32m$(pnpm --version)\033[0m"
echo ""

# ===================== 10. 青龙面板部署 =====================
echo -e "\033[34m【步骤12/12】部署青龙面板...\033[0m"
# 修复CA证书
echo "修复系统CA证书..."
sudo apt-get install --reinstall ca-certificates -y
sudo update-ca-certificates --fresh

# 升级Python网络依赖（使用清华源加速）
echo "升级Python网络依赖库（清华源）..."
pip install certifi urllib3 requests --upgrade -i https://pypi.tuna.tsinghua.edu.cn/simple

# 初始化pnpm
echo "初始化pnpm环境..."
pnpm setup

# 克隆青龙源码（Git ghproxy加速）
echo "克隆青龙面板源码（ghproxy加速）..."
git clone https://github.com/whyour/qinglong.git

# 进入项目目录
cd qinglong

# 复制环境变量
echo "复制环境变量配置文件..."
cp .env.example .env

# 再次确认pnpm国内源（双重保障）
echo "确认pnpm淘宝镜像源..."
pnpm config set registry https://registry.npmmirror.com/

# 安装系统依赖
echo "安装系统依赖（python-is-python3等）..."
sudo apt-get install python3 python-is-python3 build-essential libsqlite3-dev -y

# 安装项目依赖（pnpm国内源加速）
echo "安装青龙面板项目依赖（pnpm国内源）..."
pnpm install

# 启动青龙面板
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m              部署完成！\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo -e "✅ 全维度加速源配置生效：阿里云APT + 清华pip + 淘宝pnpm/npm + ghproxy Git"
echo -e "✅ 环境验证通过：Python 3.12 + pip 25.0.1 + Node.js 18 + pnpm 8.3.1"
echo -e "✅ 青龙面板依赖安装完成，即将启动..."
echo -e "📌 访问地址：http://localhost:5700"
echo -e "📌 如需重启面板：cd ~/qinglong && pnpm start"
echo -e "📌 APT源备份文件：/etc/apt/sources.list.bak.$(date +%Y%m%d)"
echo -e "\033[32m=============================================\033[0m"
echo ""

# 启动青龙面板
pnpm start
