#!/bin/bash
set -e  # 脚本出错自动退出
clear

# ===================== 全局配置 & 版本识别 =====================
# 自动识别系统/版本（适配Ubuntu/Debian/WSL）
OS_TYPE=$(grep -Ei 'debian|ubuntu' /etc/os-release | grep 'ID=' | cut -d= -f2 | tr -d '"')
OS_VERSION=$(grep -Ei 'VERSION_CODENAME' /etc/os-release | cut -d= -f2 | tr -d '"')
WSL_FLAG=$(grep -qi "microsoft" /proc/version && echo "WSL" || echo "Native")

echo "============================================="
echo "      青龙面板 一键部署脚本（终极加速版）"
echo "  系统适配：$OS_TYPE $OS_VERSION ($WSL_FLAG)"
echo "  加速源：阿里云(APT)、清华源(pip)、淘宝源(pnpm/npm)、ghproxy(Git)"
echo "============================================="
echo ""

# ===================== 第一步：全维度国内加速源配置（核心） =====================
echo "【1/14】配置全维度国内加速源（自动适配系统版本）..."

# 1. APT源配置（自动匹配Ubuntu/Debian版本，备份原文件）
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

# 2. pip源配置（清华源，WSL缓存优化）
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

# 3. npm/pnpm源配置（淘宝源，WSL缓存优化）
npm config set registry https://registry.npmmirror.com/
npm config set cache /tmp/npm-cache
npm config set prefix ~/.npm-global  # WSL权限优化

# 4. Git加速配置（ghproxy代理，WSL SSL优化）
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"
git config --global url."https://ghproxy.com/https://gist.github.com/".insteadOf "https://gist.github.com/"
if [ "$WSL_FLAG" = "WSL" ]; then
    git config --global http.sslVerify false
    git config --global core.compression 9  # 压缩传输提速
fi

# ===================== 第二步：系统基础更新 =====================
echo "【2/14】系统基础更新（加速版）..."
sudo apt upgrade -y

# ===================== 第三步：安装基础工具 =====================
echo "【3/14】安装Git、依赖管理工具..."
sudo apt install git software-properties-common -y

# ===================== 第四步：安装Node.js 18 + pnpm =====================
echo "【4/14】安装Node.js 18.x + pnpm 8.3.1..."
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y
npm install -g pnpm@8.3.1
pnpm setup
pnpm config set registry https://registry.npmmirror.com/  # 二次确认pnpm源

# ===================== 第五步：添加Python高版本源 =====================
echo "【5/14】添加Python 3.12安装源..."
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update -y

# ===================== 第六步：安装Python编译依赖 =====================
echo "【6/14】安装Python编译依赖包..."
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev -y

# ===================== 第七步：安装Python 3.12 =====================
echo "【7/14】安装Python 3.12及组件..."
sudo apt install python3.12 python3.12-venv python3.12-dev -y

# ===================== 第八步：配置默认Python版本 =====================
echo "【8/14】设置Python 3.12为默认版本..."
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
sudo update-alternatives --set python3 /usr/bin/python3.12

# ===================== 第九步：安装&升级pip =====================
echo "【9/14】安装并升级pip到25.0.1..."
sudo apt install python3-pip -y
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade pip==25.0.1

# ===================== 第十步：修复SSL证书+网络依赖 =====================
echo "【10/14】修复SSL证书、升级网络依赖..."
sudo apt-get install --reinstall ca-certificates -y
sudo update-ca-certificates --fresh
pip install certifi urllib3 requests --upgrade

# ===================== 第十一步：克隆青龙面板（加速版） =====================
echo "【11/14】克隆青龙面板源码（ghproxy加速）..."
cd ~
git clone https://github.com/whyour/qinglong.git
cd qinglong
cp .env.example .env

# ===================== 第十二步：安装青龙系统依赖 =====================
echo "【12/14】安装青龙面板系统依赖..."
sudo apt-get install python-is-python3 libsqlite3-dev -y

# ===================== 第十三步：安装青龙项目依赖（加速版） =====================
echo "【13/14】安装青龙面板依赖（pnpm国内源）..."
pnpm install

# ===================== 第十四步：环境验证 =====================
echo "【14/14】验证核心环境版本..."
echo "Python版本：$(python3 --version | awk '{print $2}')"
echo "pip版本：$(pip3 --version | awk '{print $2}' | cut -d'/' -f1)"
echo "Node.js版本：$(node --version)"
echo "pnpm版本：$(pnpm --version)"

# ===================== 部署完成 =====================
echo ""
echo "============================================="
echo "              部署完成！🎉"
echo "============================================="
echo "✅ 全维度国内加速源已配置生效"
echo "✅ Python 3.12 + pip 25.0.1 环境就绪"
echo "✅ Node.js 18 + pnpm 8.3.1 环境就绪"
echo "✅ 青龙面板依赖安装完成"
echo "---------------------------------------------"
echo "📌 面板启动命令：cd ~/qinglong && pnpm start"
echo "📌 访问地址：http://localhost:5700"
echo "📌 默认端口：5700"
echo "📌 加速源备份：/etc/apt/sources.list.bak.$(date +%Y%m%d)"
echo "============================================="

# 自动启动青龙面板
pnpm start
