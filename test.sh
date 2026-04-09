#!/bin/bash
set -e  # 脚本出错自动退出
clear

echo "============================================="
echo "      青龙面板 一键部署脚本（全自动）"
echo "  适配：Ubuntu/Debian/WSL Linux子系统"
echo "============================================="
echo ""

# ===================== 1. 系统基础更新 =====================
echo "【1/12】更新系统软件源..."
sudo apt update -y && sudo apt upgrade -y

# ===================== 2. 安装基础工具 =====================
echo "【2/12】安装 Git、依赖管理工具..."
sudo apt install git software-properties-common -y

# ===================== 3. 安装 Node.js 18 + pnpm =====================
echo "【3/12】安装 Node.js 18.x 和 pnpm 8.3.1..."
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y
npm install -g pnpm@8.3.1
pnpm setup  # 初始化pnpm环境

# ===================== 4. 添加Python高版本源 =====================
echo "【4/12】添加 Python 3.12 安装源..."
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update -y

# ===================== 5. 安装Python编译依赖 =====================
echo "【5/12】安装 Python 编译依赖包..."
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev -y

# ===================== 6. 安装 Python 3.12 =====================
echo "【6/12】安装 Python 3.12 及相关组件..."
sudo apt install python3.12 python3.12-venv python3.12-dev -y

# ===================== 7. 配置系统默认Python版本 =====================
echo "【7/12】设置 Python 3.12 为默认版本..."
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
sudo update-alternatives --set python3 /usr/bin/python3.12

# ===================== 8. 安装&升级pip（指定版本+清华源） =====================
echo "【8/12】安装并升级 pip 到 25.0.1..."
sudo apt install python3-pip -y
python3 -m ensurepip --upgrade
# 配置pip清华源
mkdir -p ~/.pip
echo -e "[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple" > ~/.pip/pip.conf
# 升级pip
python3 -m pip install --upgrade pip==25.0.1

# ===================== 9. 修复SSL证书+网络依赖 =====================
echo "【9/12】修复系统SSL证书、升级网络依赖..."
sudo apt-get install --reinstall ca-certificates -y
sudo update-ca-certificates --fresh
pip install certifi urllib3 requests --upgrade

# ===================== 10. 配置pnpm国内镜像 =====================
echo "【10/12】配置 pnpm 国内加速源..."
pnpm config set registry https://registry.npmmirror.com/

# ===================== 11. 部署青龙面板 =====================
echo "【11/12】克隆青龙面板源码并配置..."
cd ~
git clone https://github.com/whyour/qinglong.git
cd qinglong
cp .env.example .env

# 安装最后一批系统依赖
sudo apt-get install python-is-python3 libsqlite3-dev -y

# 安装面板依赖
echo "【12/12】安装青龙面板依赖并启动..."
pnpm install

# ===================== 部署完成 =====================
echo ""
echo "============================================="
echo "              部署完成！"
echo "============================================="
echo "面板启动命令：pnpm start"
echo "访问地址：http://localhost:5700"
echo "默认端口：5700"
echo "============================================="

# 自动启动面板
pnpm start
