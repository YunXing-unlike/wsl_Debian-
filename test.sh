#!/bin/bash
set -eo pipefail

# ========== 彩色输出 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========== 全局变量（日志真实值） ==========
QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
QL_DATA_DIR="/ql/data"
NODE_VERSION=20
GIT_MIRROR="https://fastgit.cc"
NPM_MIRROR="https://registry.npmmirror.com"

# ==========================
# 工具函数：系统环境检测
# ==========================
env_check() {
  echo -e "${GREEN}[环境预检] 正在检测系统信息...${NC}"
  . /etc/os-release
  ARCH=$(dpkg --print-architecture)
  echo -e "${BLUE}  OS:        $PRETTY_NAME${NC}"
  echo -e "${BLUE}  Arch:      $ARCH${NC}"

  if uname -r | grep -qiw "wsl2"; then
    echo -e "${RED}❌ 错误：当前为WSL2，脚本仅支持WSL1！${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ WSL1 环境校验通过${NC}"
}

# ==========================
# 清理旧环境（日志操作）
# ==========================
clean_old_env() {
  echo -e "\n${GREEN}[清理] 清空旧环境与缓存${NC}"
  pkill -f qinglong || true
  pkill -f pm2 || true
  pm2 stop all 2>/dev/null || true
  pm2 delete all 2>/dev/null || true

  npm cache clean --force 2>/dev/null || true
  rm -rf ~/.npm /root/.pm2 /ql 2>/dev/null || true

  npm uninstall -g @whyour/qinglong node-pre-gyp pnpm pm2 2>/dev/null || true
  mkdir -p ${QL_DATA_DIR}
  echo -e "${GREEN}✅ 旧环境清理完成${NC}"
}

# ==========================
# 安装系统依赖（日志原版）
# ==========================
install_deps() {
  echo -e "\n${GREEN}[1/8] 更新系统&安装必备依赖${NC}"
  apt update -y
  apt upgrade -y
  apt install -y iproute2 make python-is-python3 python3 build-essential curl git jq libsqlite3-dev libssl-dev lsof wget python3-pip ccache gcc g++ --no-install-recommends
  apt autoremove -y
  echo -e "${GREEN}✅ 系统依赖安装完成${NC}"
}

# ==========================
# 安装Node.js（日志原版：nodesource源）
# ==========================
install_node() {
  echo -e "\n${GREEN}[2/8] 安装Node.js ${NODE_VERSION}.x LTS${NC}"
  curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash
  apt install -y nodejs

  NODE_V=$(node -v)
  NPM_V=$(npm -v)
  echo -e "${GREEN}✅ Node版本：$NODE_V | NPM版本：$NPM_V${NC}"
}

# ==========================
# 配置国内镜像（日志原版）
# ==========================
set_mirrors() {
  echo -e "\n${GREEN}[3/8] 配置国内镜像（Git/NPM/PIP）${NC}"
  # PIP阿里源（日志原版）
  mkdir -p ~/.pip
  tee ~/.pip/pip.conf <<EOF >/dev/null
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF
  # Git加速镜像（日志原版）
  git config --global url."${GIT_MIRROR}/".insteadOf "https://github.com/"
  # NPM镜像
  npm config set registry ${NPM_MIRROR}
  echo -e "${GREEN}✅ 镜像配置完成${NC}"
}

# ==========================
# 安装编译工具（日志原版：仅node-pre-gyp pnpm）
# ==========================
install_build_tools() {
  echo -e "\n${GREEN}[4/8] 安装编译工具${NC}"
  # 严格按日志：仅安装node-pre-gyp pnpm，无其他额外包
  npm install -g node-pre-gyp pnpm
  echo -e "${GREEN}✅ 编译工具安装完成${NC}"
}

# ==========================
# 安装青龙面板（日志原版操作）
# ==========================
install_qinglong() {
  echo -e "\n${GREEN}[5/8] 清理NPM缓存并安装青龙面板${NC}"
  # 日志关键操作：清理缓存
  npm cache clean --force
  # 日志原版安装命令，无多余参数
  npm install -g @whyour/qinglong

  # 配置环境变量（日志原版）
  echo "export QL_DIR=${QL_DIR}" | tee -a /etc/profile >/dev/null
  echo "export QL_DATA_DIR=${QL_DATA_DIR}" | tee -a /etc/profile >/dev/null
  source /etc/profile
  echo -e "${GREEN}✅ 环境变量配置完成${NC}"
}

# ==========================
# 启动青龙（日志原版：直接执行qinglong）
# ==========================
start_qinglong() {
  echo -e "\n${GREEN}[6/8] 启动青龙面板${NC}"
  # 日志无qinglong start，直接执行qinglong
  qinglong
  sleep 20
  if pgrep -f "qinglong" >/dev/null; then
    echo -e "${GREEN}🎉 青龙面板启动成功！${NC}"
  else
    echo -e "${RED}❌ 启动失败！${NC}"
    exit 1
  fi
}

# ==========================
# 开机自启（日志原版）
# ==========================
set_autostart() {
  echo -e "\n${GREEN}[7/8] 配置开机自启${NC}"
  pm2 startup systemd
  pm2 save
  echo -e "${GREEN}✅ 自启配置完成${NC}"
}

# ==========================
# 输出信息
# ==========================
show_info() {
  echo -e "\n${GREEN}==================================================${NC}"
  WSL_IP=$(hostname -I | awk '{print $1}')
  echo -e "${GREEN}✅ 访问地址：${YELLOW}http://${WSL_IP}:5700${NC}"
  echo -e "${GREEN}✅ 查看账号密码：${YELLOW}cat ${QL_DATA_DIR}/config/auth.json${NC}"
  echo -e "${GREEN}==================================================${NC}"
}

# ==========================
# 主流程
# ==========================
clear
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}      青龙面板 WSL1 专用部署脚本（日志还原版）      ${NC}"
echo -e "${GREEN}           适配Ubuntu20.04 | Node20.x           ${NC}"
echo -e "${GREEN}==================================================${NC}"

env_check
clean_old_env
install_deps
install_node
set_mirrors
install_build_tools
install_qinglong
start_qinglong
set_autostart
show_info
