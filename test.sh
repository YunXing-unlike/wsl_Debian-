#!/bin/bash
# ==============================================
# 青龙面板 WSL1-Ubuntu20.04 原生部署脚本
# 环境：WSL1 + Ubuntu20.04 | 无Docker | 无虚拟化
# 加速源：APT阿里源 + NPM淘宝源 + GitHub指定加速(gh.llkk.cc)
# 作者：自动化部署脚本
# ==============================================

# ===================== 配置项（固定，不可修改）=====================
# 系统版本要求
REQUIRE_UBUNTU="20.04"
# GitHub加速地址（你指定的固定地址）
GH_PROXY="https://gh.llkk.cc"
# 青龙面板官方仓库
QL_REPO="https://github.com/whyour/qinglong.git"
# 青龙安装目录
QL_DIR="$HOME/qinglong"
# 青龙端口
QL_PORT=5700
# NPM国内加速源
NPM_MIRROR="https://registry.npmmirror.com"

# ===================== 步骤1：环境校验（必须WSL1+Ubuntu20.04）=====================
echo -e "\033[32m[1/8] 校验运行环境...\033[0m"
# 检查是否为Ubuntu20.04
SYSTEM_VERSION=$(lsb_release -rs 2>/dev/null)
if [ "$SYSTEM_VERSION" != "$REQUIRE_UBUNTU" ]; then
    echo -e "\033[31m错误：仅支持Ubuntu 20.04，当前系统版本：$SYSTEM_VERSION\033[0m"
    exit 1
fi

# 检查是否为WSL1
if ! grep -qi "wsl1" /proc/version; then
    echo -e "\033[31m错误：仅支持WSL1，请勿使用WSL2/虚拟机/Docker\033[0m"
    exit 1
fi
echo -e "\033[32m环境校验通过：WSL1 + Ubuntu20.04\033[0m"

# ===================== 步骤2：替换APT国内阿里源（加速系统安装）=====================
echo -e "\033[32m[2/8] 替换Ubuntu20.04国内APT加速源...\033[0m"
# 备份原始源
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
# 写入阿里官方源（Ubuntu20.04专用）
sudo cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
EOF
# 更新软件源缓存
sudo apt update -y
echo -e "\033[32mAPT国内源替换完成\033[0m"

# ===================== 步骤3：安装系统基础依赖（青龙必备）=====================
echo -e "\033[32m[3/8] 安装系统依赖（git/python3/gcc等）...\033[0m"
sudo apt install -y \
git wget curl \
python3 python3-pip \
gcc g++ make \
libssl-dev zlib1g-dev
# 配置PIP国内源
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
echo -e "\033[32m系统依赖安装完成\033[0m"

# ===================== 步骤4：安装Node.js16（青龙强制要求版本）=====================
echo -e "\033[32m[4/8] 安装Node.js16（国内源）...\033[0m"
# 安装NodeSource国内加速源（Ubuntu20.04专用）
curl -fsSL https://mirrors.aliyun.com/nodesource/node_16.x | sudo -E bash -
sudo apt install -y nodejs
# 配置NPM国内加速源
npm config set registry $NPM_MIRROR
# 验证安装
node -v && npm -v
echo -e "\033[32mNode.js16安装完成\033[0m"

# ===================== 步骤5：克隆青龙源码（你指定的GitHub加速）=====================
echo -e "\033[32m[5/8] 克隆青龙面板源码（加速地址：$GH_PROXY）...\033[0m"
# 删除旧目录（如果存在）
rm -rf $QL_DIR
# 带加速克隆源码
git clone $GH_PROXY/$QL_REPO $QL_DIR
echo -e "\033[32m青龙源码克隆完成\033[0m"

# ===================== 步骤6：安装青龙项目依赖=====================
echo -e "\033[32m[6/8] 安装青龙面板依赖包...\033[0m"
cd $QL_DIR
# 国内源安装依赖
npm install --registry=$NPM_MIRROR
echo -e "\033[32m青龙依赖安装完成\033[0m"

# ===================== 步骤7：初始化青龙配置=====================
echo -e "\033[32m[7/8] 初始化青龙面板...\033[0m"
npm run setup
echo -e "\033[32m青龙初始化完成\033[0m"

# ===================== 步骤8：启动青龙面板 + 输出访问信息=====================
echo -e "\033[32m[8/8] 启动青龙面板...\033[0m"
# 后台启动青龙
nohup npm run start > ql.log 2>&1 &
sleep 3
echo -e "\033[32m==============================================\033[0m"
echo -e "\033[32m青龙面板部署成功！\033[0m"
echo -e "\033[32m访问地址：http://localhost:$QL_PORT\033[0m"
echo -e "\033[32m账号密码：在部署日志中查看（首次初始化自动生成）\033[0m"
echo -e "\033[32m==============================================\033[0m"
