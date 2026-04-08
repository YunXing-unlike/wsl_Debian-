#!/bin/bash

# ==================================================
# 脚本名称: QingLong Panel 部署脚本 (WSL1专用版)
# 适用环境: Windows WSL1 (Ubuntu 20.04 LTS)
# 部署方式: 源码编译部署 (非Docker/非虚拟机)
# 更新时间: 2026-04-08
# ==================================================

# --- 全局配置 ---
# 设置遇到错误即退出，防止错误蔓延
set -e 

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 定义安装路径 (建议放在用户目录下)
QL_DIR="/opt/ql"
QL_BRANCH="master" # 青龙面板主分支

# GitHub 加速代理 (根据要求6配置)
GH_PROXY="https://fastgit.cc/"

echo -e "${GREEN}=== 环境检查与初始化 ===${NC}"
# 确保在 WSL1 环境中
if [ -z "$(grep -i microsoft /proc/version)" ]; then
    echo -e "${RED}警告: 当前可能不在 WSL 环境中，请确认环境正确。${NC}"
fi

# --- 步骤 1: 更换国内加速源 (要求5) ---
echo -e "${GREEN}>>> [1/6] 正在配置阿里云 Ubuntu 20.04 加速源...${NC}"
# 备份原有源
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
# 写入阿里云源 (针对 Ubuntu 20.04 focal)
sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# --- 步骤 2: 安装系统依赖 ---
echo -e "${GREEN}>>> [2/6] 更新软件包列表并安装核心依赖...${NC}"
sudo apt-get update
# 安装构建工具、Python3、Node.js 环境依赖
# 说明：脱离Docker必须手动解决 git, curl, wget, gcc, make 等编译依赖
sudo apt-get install -y git curl wget unzip tar gcc g++ make python3 python3-pip

# --- 步骤 3: 安装 Node.js 环境 (使用 nvm 管理) [Gitee镜像修正版] ---
echo -e "${GREEN}>>> [3/6] 安装 Node.js 环境 (使用 Gitee 国内镜像加速)...${NC}"

export NVM_DIR="$HOME/.nvm"

# [核心修补] 放弃失效的 gh.llkk.cc 代理，改用 Gitee 官方镜像源
# 备注信息：Gitee 是国内稳定的代码托管平台，同步了 NVM 官方仓库，速度极快且稳定
if [ ! -d "$NVM_DIR/.git" ]; then
    echo "正在通过 Gitee 克隆 NVM 仓库..."
    # 使用 Gitee 镜像源，解决 403 和连接超时问题
    git clone https://gitee.com/mirrors/nvm.git "$NVM_DIR"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: Git 克隆失败。请检查网络连接。${NC}"
        exit 1
    fi
else
    echo "NVM 仓库已存在，跳过下载。"
fi

# [核心修补] 强制加载 nvm 环境
# 备注信息：必须手动执行 source，否则当前 shell 会话无法识别 nvm 命令
if [ -s "$NVM_DIR/nvm.sh" ]; then
    echo "正在加载 NVM 环境..."
    . "$NVM_DIR/nvm.sh"  # 这里的 . 等同于 source 命令
else
    echo -e "${RED}致命错误: nvm.sh 文件未找到，Git 克隆可能不完整。${NC}"
    exit 1
fi

# 设置 nvm 国内镜像源 (极大加速 Node 下载)
# 备注信息：配置淘宝镜像，加速 Node.js 二进制包下载
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node

# 安装 Node.js (青龙面板推荐 v18)
echo "正在安装 Node.js v18..."
nvm install 18
nvm use 18
nvm alias default 18

# 验证 Node 安装
echo -e "Node 版本: $(node -v)"
echo -e "NPM 版本: $(npm -v)"

# 配置 NPM 淘宝镜像源
npm config set registry https://registry.npmmirror.com

# 安装 pnpm (青龙依赖)
npm install -g pnpm
# 配置 pnpm 淘宝镜像源
pnpm config set registry https://registry.npmmirror.com

# --- 步骤 4: 安装 PM2 进程守护 ---
echo -e "${GREEN}>>> [4/6] 安装 PM2 进程管理工具...${NC}"
# 备注信息：脱离 Docker 容器化后，必须使用 PM2 来守护 Node 进程，保证面板开机自启和崩溃重启
npm install -g pm2

# --- 步骤 5: 拉取青龙面板源码 ---
echo -e "${GREEN}>>> [5/6] 拉取青龙面板源码...${NC}"
sudo mkdir -p $QL_DIR
# 赋予当前用户目录权限，避免后续权限问题
sudo chown -R $(whoami):$(whoami) $QL_DIR

cd $QL_DIR

# 使用 GitHub 加速代理拉取代码 (要求6)
# 备注信息：直接访问 GitHub 在国内极不稳定，必须使用 gh.llkk.cc 代理
if [ ! -d ".git" ]; then
    echo "正在克隆仓库..."
    git clone ${GH_PROXY}github.com/whyour/qinglong.git .
else
    echo "仓库已存在，正在更新..."
    git pull
fi

# --- 步骤 6: 安装依赖并构建启动 ---
echo -e "${GREEN}>>> [6/6] 安装项目依赖并构建...${NC}"
# 安装依赖
pnpm install

# 构建项目 (源码部署必须步骤)
pnpm build

# 创建必要的目录结构
mkdir -p $QL_DIR/log $QL_DIR/db $QL_DIR/scripts $QL_DIR/config

# 备份并更新 extra.sh (用于安装 python 依赖)
cp $QL_DIR/sample/extra.sh $QL_DIR/config/extra.sh

echo -e "${GREEN}>>> 部署完成！正在启动青龙面板...${NC}"
# 使用 PM2 启动
# 备注信息：使用 max-memory-restart 防止内存泄漏，name 指定应用名便于管理
pm2 start $QL_DIR/dist/index.js --name "qinglong" --max-memory-restart 500M

# 保存 PM2 进程列表
pm2 save

# 设置 PM2 开机自启 (WSL1 需额外配置 Windows 任务计划，此处仅做 Linux 层面设置)
pm2 startup

# 获取 IP 地址 (WSL1 通常为 eth0)
IP_ADDR=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
if [ -z "$IP_ADDR" ]; then
    IP_ADDR="127.0.0.1"
fi

echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}青龙面板部署成功！${NC}"
echo -e "访问地址: ${GREEN}http://${IP_ADDR}:5700${NC}"
echo -e "初始用户名: admin"
echo -e "初始密码: adminadmin"
echo -e "请在浏览器打开上述地址进行初始化设置。"
echo -e "${YELLOW}========================================${NC}"
echo -e "${RED}提示: 若无法访问，请检查 Windows 防火墙设置或 WSL 网络端口转发。${NC}"
