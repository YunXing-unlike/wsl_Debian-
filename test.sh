#!/bin/bash
set -e  # 脚本出错自动退出
clear

# ===================== 1. 系统信息自动识别（核心适配） =====================
# 识别系统类型（Ubuntu/Debian）、版本代号、是否为WSL
OS_TYPE=$(grep -Ei 'debian|ubuntu' /etc/os-release | grep 'ID=' | cut -d= -f2 | tr -d '"')
OS_VERSION=$(grep -Ei 'VERSION_CODENAME' /etc/os-release | cut -d= -f2 | tr -d '"')
WSL_FLAG=$(grep -qi "microsoft" /proc/version && echo "WSL" || echo "原生Linux")

# 打印部署信息
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      青龙面板 一键部署脚本（终极加速版）\033[0m"
echo -e "\033[32m  适配环境：$OS_TYPE $OS_VERSION ($WSL_FLAG)\033[0m"
echo -e "\033[32m  加速源：阿里云(APT) | 清华源(pip) | 淘宝源(pnpm/npm) | ghproxy(Git)\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo ""

# ===================== 2. 全维度国内加速源配置（核心提速） =====================
echo -e "\033[34m【1/14】配置全维度国内加速源（自动适配系统）...\033[0m"

# 2.1 APT源配置（自动匹配版本+备份原文件）
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
sudo apt clean && sudo apt update -y

# 2.2 pip源配置（清华源+WSL缓存优化）【仅配置文件，不执行pip命令】
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

# 2.3 Git加速配置（ghproxy代理+WSL SSL优化）【无依赖，可提前配置】
git config --global url."https://gitproxy.mrhjx.cn/https://github.com/".insteadOf "https://github.com/"
git config --global url."https://gitproxy.mrhjx.cn/https://gist.github.com/".insteadOf "https://gist.github.com/"
if [ "$WSL_FLAG" = "WSL" ]; then
    git config --global http.sslVerify false
    git config --global core.compression 9  # 压缩传输提速
fi

# ===================== 3. 系统基础环境搭建 =====================
echo -e "\033[34m【2/14】系统基础更新（加速版）...\033[0m"
sudo apt upgrade -y

echo -e "\033[34m【3/14】安装Git、系统依赖工具...\033[0m"
sudo apt install git software-properties-common curl -y  # 补充curl（Node.js安装依赖）

echo -e "\033[34m【4/14】安装Node.js 18.x + pnpm 8.3.1...\033[0m"
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y
# 安装Node.js后，再配置npm/pnpm源（核心修复点）
npm config set registry https://registry.npmmirror.com/
npm config set cache /tmp/npm-cache
npm config set prefix ~/.npm-global  # 避免WSL权限冲突
npm install -g pnpm@8.3.1
pnpm setup
pnpm config set registry https://registry.npmmirror.com/  # 二次确认pnpm源

echo -e "\033[34m【5/14】添加Python 3.12安装源...\033[0m"
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update -y

echo -e "\033[34m【6/14】安装Python编译依赖包...\033[0m"
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev -y

echo -e "\033[34m【7/14】安装Python 3.12及组件...\033[0m"
sudo apt install python3.12 python3.12-venv python3.12-dev -y

echo -e "\033[34m【8/14】设置Python 3.12为默认版本...\033[0m"
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
sudo update-alternatives --set python3 /usr/bin/python3.12

echo -e "\033[34m【9/14】安装并升级pip到25.0.1...\033[0m"
sudo apt install python3-pip -y
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade pip==25.0.1

# ===================== 4. 网络环境修复 =====================
echo -e "\033[34m【10/14】修复SSL证书、升级网络依赖...\033[0m"
sudo apt-get install --reinstall ca-certificates -y
sudo update-ca-certificates --fresh
pip install certifi urllib3 requests --upgrade

# ===================== 5. 青龙面板部署 =====================
echo -e "\033[34m【11/14】克隆青龙面板源码（ghproxy加速）...\033[0m"
cd ~
git clone https://github.com/whyour/qinglong.git
cd qinglong
cp .env.example .env

echo -e "\033[34m【12/14】安装青龙面板系统依赖...\033[0m"
sudo apt-get install python-is-python3 libsqlite3-dev -y

echo -e "\033[34m【13/14】安装青龙面板依赖（pnpm国内源）...\033[0m"
pnpm install

# ===================== 6. 环境验证 =====================
echo -e "\033[34m【14/14】验证核心环境版本...\033[0m"
echo -e "Python版本：\033[32m$(python3 --version | awk '{print $2}')\033[0m"
echo -e "pip版本：\033[32m$(pip3 --version | awk '{print $2}' | cut -d'/' -f1)\033[0m"
echo -e "Node.js版本：\033[32m$(node --version)\033[0m"
echo -e "pnpm版本：\033[32m$(pnpm --version)\033[0m"

# ===================== 部署完成 =====================
echo ""
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m              部署完成！🎉\033[0m"
echo -e "\033[32m=============================================\033[0m"
echo -e "✅ 全维度国内加速源已配置生效"
echo -e "✅ Python 3.12 + pip 25.0.1 环境就绪"
echo -e "✅ Node.js 18 + pnpm 8.3.1 环境就绪"
echo -e "✅ 青龙面板依赖安装完成"
echo -e "---------------------------------------------"
echo -e "📌 面板启动命令：cd ~/qinglong && pnpm start"
echo -e "📌 访问地址：http://localhost:5700"
echo -e "📌 默认端口：5700"
echo -e "📌 APT源备份：/etc/apt/sources.list.bak.$(date +%Y%m%d)"
echo -e "\033[32m=============================================\033[0m"

# 自动启动青龙面板
pnpm start
