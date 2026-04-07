#!/bin/bash
set -eo pipefail

# ========== 彩色输出 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========== 全局变量 ==========
QL_DATA_DIR="$HOME/ql/data"
QL_LOG_DIR="$HOME/ql/log"
QL_PORT=5700
NODE_VERSION=20
SPEED_TEST_URL="https://nodesource.com"
GITHUB_API_URL="https://xiake.pro/static/node.json"

# ==========================
# 工具函数：系统环境检测
# ==========================
env_check() {
  echo -e "${GREEN}[环境预检] 正在检测系统信息...${NC}"

  # 1. 检测发行版
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    CODENAME=$VERSION_CODENAME
  else
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
    CODENAME=$(lsb_release -sc)
  fi

  # 2. 检测架构
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64) ARCH="arm64" ;;
    *) ARCH="unknown" ;;
  esac

  # 3. 检测网络连通性
  echo -e "${BLUE}  OS:        $OS $VER ($CODENAME)${NC}"
  echo -e "${BLUE}  Arch:      $ARCH${NC}"

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 $SPEED_TEST_URL || true)
  if [ "$HTTP_CODE" = "200" ]; then
    NET_STATUS="直连正常"
    NEED_MIRROR=0
  else
    NET_STATUS="国外源访问异常，将自动全速加速"
    NEED_MIRROR=1
  fi
  echo -e "${BLUE}  网络:      $NET_STATUS${NC}"
}

# ==========================
# 智能 APT 源加速
# ==========================
apt_mirror_smart() {
  echo -e "\n${GREEN}[2/10] 智能切换系统镜像源（阿里/清华）${NC}"
  sudo cp -a /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d)

  if [[ "$OS" =~ Ubuntu ]]; then
    sudo tee /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ $CODENAME main restricted universe multiverse
EOF
  elif [[ "$OS" =~ Debian ]]; then
    sudo tee /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/debian/ $CODENAME main non-free contrib
deb http://mirrors.aliyun.com/debian-security $CODENAME-security main
deb http://mirrors.aliyun.com/debian/ $CODENAME-updates main non-free contrib
deb http://mirrors.aliyun.com/debian/ $CODENAME-backports main non-free contrib
EOF
  fi

  echo "nameserver 223.5.5.5" | sudo tee /etc/resolv.conf >/dev/null
  echo "nameserver 114.114.114.114" | sudo tee -a /etc/resolv.conf >/dev/null
}

# ==========================
# PIP 加速
# ==========================
pip_mirror() {
  echo -e "${GREEN}[附加加速] 配置 PIP 阿里源${NC}"
  mkdir -p ~/.pip
  tee ~/.pip/pip.conf <<EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF
}

# ==========================
# 自动获取最快 GitHub 镜像（xiake.pro 测速接口）
# ==========================
get_fastest_gh_mirror() {
  # 临时关闭严格退出，防止接口波动导致脚本退出
  set +e

  echo -e "\n${GREEN}[Git加速] 正在获取最优 GitHub 镜像...${NC}"

  # 请求测速接口，取速度最快、speed>0 的镜像
  BEST_MIRROR=$(curl -s --connect-timeout 8 --max-time 12 "$GITHUB_API_URL" 2>/dev/null | \
    jq -r '.data | map(select(.speed > 0)) | sort_by(.speed) | reverse | .[0].url' 2>/dev/null || true)

  # 兜底备用镜像
  if [ -z "$BEST_MIRROR" ] || [ "$BEST_MIRROR" = "null" ]; then
    BEST_MIRROR="https://fastgit.cc"
    echo -e "${YELLOW}镜像接口请求失败，使用备用镜像：$BEST_MIRROR${NC}"
  else
    echo -e "${GREEN}已自动选择最快镜像：$BEST_MIRROR${NC}"
  fi

  # 恢复严格模式
  set -e
}

# ==========================
# 应用 Git 全局加速
# ==========================
git_mirror_smart() {
  get_fastest_gh_mirror
  
  echo -e "${GREEN}[Git加速] 应用全局代理加速${NC}"
  git config --global url."${BEST_MIRROR}/".insteadOf "https://github.com/"
  git config --global url."${BEST_MIRROR}/".insteadOf "https://raw.githubusercontent.com/"
  git config --global http.sslVerify false
  git config --global core.compression 9
}

# ==========================
# 主流程开始
# ==========================
clear
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}      青龙面板 WSL1 专用部署脚本（智能加速版）      ${NC}"
echo -e "${GREEN}           自动测速·自动选最快GitHub镜像           ${NC}"
echo -e "${GREEN}==================================================${NC}"

# 1. 环境检测 + WSL1 强制校验
echo -e "${GREEN}[1/10] 开始环境预检（强制WSL1 + 系统识别）${NC}"
if [[ $(uname -r) =~ WSL2 ]]; then
  echo -e "${RED}错误：当前是WSL2！天翼云无VT无法运行，请切回WSL1！${NC}"
  exit 1
fi
env_check

# 2. 智能加速
if [ $NEED_MIRROR -eq 1 ]; then
  apt_mirror_smart
  pip_mirror
  git_mirror_smart
else
  echo -e "${YELLOW}网络直连良好，仅加速 Node/Pip/Git${NC}"
  pip_mirror
  git_mirror_smart
fi

# 3. 清理旧青龙进程
if pgrep -f "ql" >/dev/null 2>&1; then
  echo -e "${YELLOW}检测到旧青龙进程，自动终止...${NC}"
  pkill -f ql || true
fi

# 4. 安装系统依赖（提前安装 jq，避免中途安装报错退出）
echo -e "${GREEN}[3/10] 更新系统&安装必备依赖${NC}"
sudo apt clean
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y git curl wget python3 python3-pip make build-essential \
  libssl-dev lsof python-is-python3 libsqlite3-dev iproute2 jq

# 5. 安装 Node.js
echo -e "${GREEN}[4/10] 安装Node.js ${NODE_VERSION}.x LTS${NC}"
if [ $NEED_MIRROR -eq 1 ]; then
  curl -fsSL https://cdn.npmmirror.com/binaries/nodesource/setup_${NODE_VERSION}.x | sudo -E bash -
else
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
fi
sudo apt install -y nodejs

NODE_V=$(node -v)
NPM_V=$(npm -v)
echo -e "${GREEN}Node版本：$NODE_V | NPM版本：$NPM_V${NC}"

# 6. NPM 加速
echo -e "${GREEN}[5/10] 切换NPM国内镜像&修复权限${NC}"
npm config set registry https://registry.npmmirror.com/
npm config set disturl https://npmmirror.com/dist
sudo chown -R $USER:$USER ~/.npm
sudo chmod -R 755 ~/.npm

# 7. 安装青龙
echo -e "${GREEN}[6/10] NPM 全局安装青龙面板${NC}"
sudo npm install -g --unsafe-perm @whyour/qinglong

# 8. 数据目录初始化
echo -e "${GREEN}[7/10] 初始化数据目录${NC}"
mkdir -p $QL_DATA_DIR
mkdir -p $QL_LOG_DIR
chmod -R 755 $HOME/ql
chown -R $USER:$USER $HOME/ql

# 9. 端口检测
echo -e "${GREEN}[8/10] 检测端口 ${QL_PORT}${NC}"
if sudo lsof -i :$QL_PORT >/dev/null 2>&1; then
  echo -e "${RED}端口被占用，请释放后重试${NC}"
  exit 1
fi
echo -e "${YELLOW}WSL1 端口放行请在 Windows 防火墙设置${NC}"

# 10. 后台启动青龙
echo -e "${GREEN}[9/10] 后台启动青龙${NC}"
nohup ql start -p $QL_PORT -d $QL_DATA_DIR > $QL_LOG_DIR/ql_main.log 2>&1 &
sleep 8

# 11. 启动校验
if pgrep -f "ql" >/dev/null; then
  echo -e "${GREEN}✅ 青龙启动成功${NC}"
else
  echo -e "${RED}❌ 启动失败，日志：tail -f $QL_LOG_DIR/ql_main.log${NC}"
  exit 1
fi

# 12. 输出信息
echo -e "\n${GREEN}==================================================${NC}"
WSL_IP=$(hostname -I | awk '{print $1}')
echo -e "访问面板：${YELLOW}http://$WSL_IP:$QL_PORT${NC}"
echo -e "查看账号：${YELLOW}cat $QL_DATA_DIR/config/auth.json${NC}"
echo -e "实时日志：${YELLOW}tail -f $QL_LOG_DIR/ql_main.log${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "${RED}⚠  禁止：WSL2 / Docker / Hyper-V ⚠${NC}"
