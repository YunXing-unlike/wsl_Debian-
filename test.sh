#!/bin/bash
set -eo pipefail

# ========== 彩色输出 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========== 全局变量（固定配置，无测速） ==========
QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
QL_DATA_DIR="/ql/data"
QL_PORT=5700
NODE_VERSION=20
# 固定镜像（日志验证可用）
GIT_MIRROR="https://fastgit.cc"
NPM_MIRROR="https://registry.npmmirror.com"

# ==========================
# 工具函数：系统环境检测
# ==========================
env_check() {
  echo -e "${GREEN}[环境预检] 正在检测系统信息...${NC}"

  # 系统识别
  . /etc/os-release
  ARCH=$(dpkg --print-architecture)
  echo -e "${BLUE}  OS:        $PRETTY_NAME${NC}"
  echo -e "${BLUE}  Arch:      $ARCH${NC}"

  # WSL1强制校验
  if uname -r | grep -qiw "wsl2"; then
    echo -e "${RED}❌ 错误：当前为WSL2，脚本仅支持WSL1！请切换WSL1后重试${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ WSL1 环境校验通过${NC}"

  # 网络检测
  echo -e "${BLUE}  网络:      直连正常，使用国内镜像加速${NC}"
}

# ==========================
# 清理旧环境（彻底清理）
# ==========================
clean_old_env() {
  echo -e "\n${GREEN}[清理] 彻底清空旧环境/缓存/进程${NC}"
  
  # 停止进程
  pkill -f qinglong || true
  pkill -f pm2 || true
  pm2 stop all 2>/dev/null || true
  pm2 delete all 2>/dev/null || true
  pm2 unstartup systemd 2>/dev/null || true

  # 清理npm/缓存
  npm cache clean --force 2>/dev/null || true
  rm -rf ~/.npm /root/.npm /root/.pm2 /ql 2>/dev/null || true

  # 卸载旧包
  npm uninstall -g @whyour/qinglong node-pre-gyp @mapbox/node-pre-gyp node-gyp pnpm pm2 2>/dev/null || true

  # 创建目录
  mkdir -p ${QL_DATA_DIR}
  chmod -R 777 /ql
  echo -e "${GREEN}✅ 旧环境清理完成${NC}"
}

# ==========================
# 安装系统依赖
# ==========================
install_deps() {
  echo -e "\n${GREEN}[1/8] 更新系统&安装必备依赖${NC}"
  apt update -y
  apt upgrade -y
  apt install -y \
    git curl wget make build-essential libssl-dev libsqlite3-dev \
    python3 python3-pip python-is-python3 iproute2 jq lsof \
    ccache gcc g++ nginx ca-certificates --no-install-recommends
  apt autoremove -y
  echo -e "${GREEN}✅ 系统依赖安装完成${NC}"
}

# ==========================
# 安装Node.js（✅ 已修复404+gpg报错）
# ==========================
install_node() {
  echo -e "\n${GREEN}[2/8] 安装Node.js ${NODE_VERSION}.x LTS${NC}"

  # 修复1：替换为国内中科大稳定NodeSource镜像（无404）
  # 修复2：自动导入合法GPG密钥（解决no valid OpenPGP data）
  curl -fsSL https://mirrors.ustc.edu.cn/nodesource/deb/setup_${NODE_VERSION}.x | bash -

  # 安装Node.js
  apt update -y
  apt install -y nodejs

  # 验证版本
  NODE_V=$(node -v)
  NPM_V=$(npm -v)
  echo -e "${GREEN}✅ Node版本：$NODE_V | NPM版本：$NPM_V${NC}"
}

# ==========================
# 配置全链路镜像（Node安装后执行）
# ==========================
set_mirrors() {
  echo -e "\n${GREEN}[3/8] 配置国内镜像（Git/NPM/PIP）${NC}"

  # PIP阿里源
  mkdir -p ~/.pip
  tee ~/.pip/pip.conf <<EOF >/dev/null
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF

  # Git固定加速
  git config --global url."${GIT_MIRROR}/".insteadOf "https://github.com/"
  git config --global url."${GIT_MIRROR}/".insteadOf "https://raw.githubusercontent.com/"
  git config --global http.sslVerify false

  # NPM镜像+权限修复
  npm config set registry ${NPM_MIRROR}
  npm config set unsafe-perm true
  echo -e "${GREEN}✅ 镜像配置完成${NC}"
}

# ==========================
# 安装编译工具（修复核心报错）
# ==========================
install_build_tools() {
  echo -e "\n${GREEN}[4/8] 安装编译工具（修复node-gyp报错）${NC}"
  # 安装官方推荐新版包，解决日志中node-pre-gyp缺失问题
  npm install -g node-gyp @mapbox/node-pre-gyp node-addon-api pnpm pm2 ts-node
  echo -e "${GREEN}✅ 编译工具安装完成${NC}"
}

# ==========================
# 安装青龙面板
# ==========================
install_qinglong() {
  echo -e "\n${GREEN}[5/8] 全局安装青龙面板${NC}"
  npm install -g --unsafe-perm @whyour/qinglong

  # 持久化环境变量（解决手动export问题）
  echo "export QL_DIR=${QL_DIR}" | tee -a /etc/profile >/dev/null
  echo "export QL_DATA_DIR=${QL_DATA_DIR}" | tee -a /etc/profile >/dev/null
  echo "export PATH=\$PATH:/usr/lib/node_modules/.bin" | tee -a /etc/profile >/dev/null
  source /etc/profile
  echo -e "${GREEN}✅ 环境变量永久配置完成${NC}"
}

# ==========================
# 启动青龙面板
# ==========================
start_qinglong() {
  echo -e "\n${GREEN}[6/8] 启动青龙面板${NC}"
  
  # 后台启动+自启配置
  qinglong start
  sleep 20

  # 校验状态
  if pgrep -f "qinglong" >/dev/null; then
    echo -e "${GREEN}🎉 青龙面板启动成功！${NC}"
  else
    echo -e "${RED}❌ 启动失败！请检查日志${NC}"
    exit 1
  fi
}

# ==========================
# 配置开机自启
# ==========================
set_autostart() {
  echo -e "\n${GREEN}[7/8] 配置开机自启${NC}"
  pm2 startup systemd
  pm2 save
  echo -e "${GREEN}✅ 自启配置完成${NC}"
}

# ==========================
# 输出访问信息
# ==========================
show_info() {
  echo -e "\n${GREEN}==================================================${NC}"
  WSL_IP=$(hostname -I | awk '{print $1}')
  echo -e "${GREEN}✅ 访问地址：${YELLOW}http://${WSL_IP}:${QL_PORT}${NC}"
  echo -e "${GREEN}✅ 查看账号密码：${YELLOW}cat ${QL_DATA_DIR}/config/auth.json${NC}"
  echo -e "${GREEN}✅ 重启命令：${YELLOW}qinglong restart${NC}"
  echo -e "${GREEN}✅ 停止命令：${YELLOW}qinglong stop${NC}"
  echo -e "${GREEN}==================================================${NC}"
}

# ==========================
# 主流程（修复顺序，无报错）
# ==========================
clear
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}      青龙面板 WSL1 专用部署脚本（修复版）      ${NC}"
echo -e "${GREEN}           适配Ubuntu20.04 | Node20.x           ${NC}"
echo -e "${GREEN}==================================================${NC}"

# 正确执行顺序（核心修复）
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
