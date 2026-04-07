#!/bin/bash
set -euo pipefail

# ========== 彩色输出配置 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========== 全局变量 ==========
QL_DATA_DIR="$HOME/ql/data"
QL_LOG_DIR="$HOME/ql/log"
QL_PORT=5700
NODE_VERSION=20

# ========== 环境预检 ==========
echo -e "${GREEN}[1/10] 开始环境预检（强制WSL1）${NC}"
if [[ $(uname -r) =~ WSL2 ]]; then
  echo -e "${RED}错误：当前是WSL2！天翼云无VT无法运行，请切回WSL1！${NC}"
  exit 1
fi

# 检测旧青龙进程并杀掉
if pgrep -f "qinglong" >/dev/null 2>&1; then
  echo -e "${YELLOW}检测到旧青龙进程，自动终止...${NC}"
  pkill -f qinglong || true
fi

# ========== 换阿里源加速 ==========
echo -e "${GREEN}[2/10] 替换阿里云软件源${NC}"
sudo sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
sudo sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# ========== 更新系统+安装基础依赖 ==========
echo -e "${GREEN}[3/10] 更新系统&安装必备依赖${NC}"
sudo apt clean
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y git curl wget python3 python3-pip make build-essential libssl-dev

# ========== 安装指定LTS Node.js ==========
echo -e "${GREEN}[4/10] 安装Node.js ${NODE_VERSION}.x LTS${NC}"
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
sudo apt install -y nodejs

# 校验版本
NODE_V=$(node -v)
NPM_V=$(npm -v)
echo -e "${GREEN}Node版本：$NODE_V | NPM版本：$NPM_V${NC}"

# ========== 加固NPM镜像+权限 ==========
echo -e "${GREEN}[5/10] 切换NPM国内镜像&修复权限${NC}"
npm config set registry https://registry.npmmirror.com/
sudo chown -R $USER:$USER ~/.npm
sudo chmod -R 755 ~/.npm

# ========== 原生NPM全局安装青龙 ==========
echo -e "${GREEN}[6/10] NPM原生全局安装青龙（WSL1唯一方案）${NC}"
sudo npm install -g --unsafe-perm @whyour/qinglong

# ========== 创建持久化目录 ==========
echo -e "${GREEN}[7/10] 初始化青龙数据&日志目录${NC}"
mkdir -p $QL_DATA_DIR
mkdir -p $QL_LOG_DIR
chmod -R 777 $HOME/ql

# ========== 端口检测+放行 ==========
echo -e "${GREEN}[8/10] 检测端口&放行防火墙${NC}"
if sudo lsof -i :$QL_PORT >/dev/null 2>&1; then
  echo -e "${RED}端口${QL_PORT}被占用，请手动释放后重试！${NC}"
  exit 1
fi
# 天翼云WSL1无UFW，跳过端口放行（Windows端单独放行）
echo -e "${YELLOW}天翼云WSL1无UFW，端口放行请在Windows管理员CMD执行${NC}"


# ========== 后台常驻启动+日志持久化 ==========
echo -e "${GREEN}[9/10] 后台守护启动青龙${NC}"
sudo chmod -R 777 $HOME/ql && sudo chown -R $USER:$USER $HOME/ql
nohup qinglong start -p $QL_PORT -d $QL_DATA_DIR > $QL_LOG_DIR/ql_main.log 2>&1 &
sleep 5

# ========== 输出全部关键信息 ==========
echo -e "\n${GREEN}==================== 部署完成 ====================${NC}"
WSL_IP=$(hostname -I | awk '{print $1}')
echo -e "✅ WSL内网IP：${YELLOW}$WSL_IP${NC}"
echo -e "✅ 访问地址：${YELLOW}http://$WSL_IP:$QL_PORT${NC}"
echo -e "✅ 查看账号密码命令：${YELLOW}cat $QL_DATA_DIR/config/auth.json${NC}"
echo -e "✅ 青龙日志查看：${YELLOW}tail -f $QL_LOG_DIR/ql_main.log${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "${RED}禁止操作：切勿升级WSL2、切勿安装Docker、切勿开启Hyper-V${NC}"
