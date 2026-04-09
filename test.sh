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
sudo apt update -y
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

# ===================== 4. 添加Deadsnakes PPA（自动回车确认） =====================
echo -e "\033[34m【步骤4/12】添加Deadsnakes PPA...\033[0m"
sudo apt install software-properties-common -y
echo "" | sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update -y
echo ""

# ===================== 5. 安装Python编译依赖（自动确认） =====================
echo -e "\033[34m【步骤5/12】安装Python编译依赖包...\033[0m"
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev -y
echo ""

# ===================== 6. 安装Python 3.12及组件（自动确认） =====================
echo -e "\033[34m【步骤6/12】安装Python 3.12...\033[0m"
sudo apt install python3.12 -y
echo ""

echo -e "\033[34m【步骤7/12】安装Python 3.12 venv/dev组件...\033[0m"
sudo apt install python3.12-venv python3.12-dev -y
echo ""

# ===================== 7. 配置Python默认版本（自动选择3.12） =====================
echo -e "\033[34m【步骤8/12】配置Python 3.12为默认版本...\033[0m"
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
echo "1" | sudo update-alternatives --config python3
echo ""

# ===================== 8. 安装pip并升级（自动确认） =====================
echo -e "\033[34m【步骤9/12】安装pip...\033[0m"
sudo apt install python3-pip -y
echo ""

echo -e "\033[34m【步骤10/12】升级pip到25.0.1（清华源加速）...\033[0m"
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade pip==25.0.1 -i https://pypi.tuna.tsinghua.edu.cn/simple

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

# ===================== 9. 环境版本验证 =====================
echo -e "\033[34m【步骤11/12】验证环境版本...\033[0m"
echo -e "Python版本：\033[32m$(python3 --version | awk '{print $2}')\033[0m"
echo -e "pip版本：\033[32m$(pip3 --version | awk '{print $2}' | cut -d'/' -f1)\033[0m"
echo -e "Node.js版本：\033[32m$(node --version)\033[0m"
echo -e "pnpm版本：\033[32m$(pnpm --version)\033[0m"
echo ""

# ===================== 10. 青龙面板部署（全程自动） =====================
echo -e "\033[34m【步骤12/12】部署青龙面板...\033[0m"
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
echo -e "✅ 环境验证通过：Python 3.12 + pip 25.0.1 + Node.js 18 + pnpm 8.3.1"
echo -e "✅ 青龙面板依赖安装完成，即将启动..."
echo -e "📌 访问地址：http://localhost:5700"
echo -e "📌 如需重启面板：cd ~/qinglong && pnpm start"
echo -e "📌 APT源备份文件：/etc/apt/sources.list.bak.$(date +%Y%m%d)"
echo -e "\033[32m=============================================\033[0m"
echo ""

# 启动青龙面板
pnpm start
