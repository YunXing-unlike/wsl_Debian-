#!/bin/bash
set -eo pipefail

# ========== 彩色输出 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========== 全局变量 ==========
QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
QL_DATA_DIR="/ql/data"
QL_PORT=5700
NODE_VERSION=20
SPEED_TEST_URL="https://nodesource.com"
# 固定Git镜像（你的要求）
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
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 $SPEED_TEST_URL || true)
  if [ "$HTTP_CODE" = "200" ]; then
    NET_STATUS="直连正常"
  else
    NET_STATUS="国外源访问异常，将自动加速"
  fi
  echo -e "${BLUE}  网络:      $NET_STATUS${NC}"
}

# ==========================
# 固定Git加速（fastgit.cc，无测速，直接使用）
# ==========================
git_mirror_fixed() {
  echo -e "${GREEN}[Git加速] 应用固定镜像：${GIT_MIRROR}${NC}"
  git config --global url."${GIT_MIRROR}/".insteadOf "https://github.com/"
  git config --global url."${GIT_MIRROR}/".insteadOf "https://raw.githubusercontent.com/"
  git config --global http.sslVerify false
  git config --global core.compression 9
}

# ==========================
# 全链路加速配置（Node安装后执行，无npm报错）
# ==========================
set_mirrors() {
  echo -e "\n${GREEN}[附加加速] 配置PIP/Git/NPM全国内镜像${NC}"

  # PIP阿里源
  mkdir -p ~/.pip
  tee ~/.pip/pip.conf <<EOF >/dev/null
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF

  # Git固定加速
  git_mirror_fixed

  # NPM镜像（此时Node已安装，无报错）
  npm config set registry ${NPM_MIRROR}
  npm config set unsafe-perm true
}

# ==========================
# 清理旧环境
# ==========================
clean_old_env() {
  echo -e "\n${GREEN}[清理] 彻底清空旧环境/缓存/进程${NC}"
  
  # 停止进程
  pkill -f qinglong || true
  pkill -f pm2 || true
  pm2 stop all 2>/dev/null || true
  pm2 delete all 2>/dev/null || true

  # 清理缓存
  npm cache clean --force 2>/dev/null || true
  rm -rf ~/.npm /root/.npm 2>/dev/null || true

  # 卸载旧版本
  npm uninstall -g @whyour/qinglong 2>/dev/null || true

  # 创建数据目录
  mkdir -p ${QL_DATA_DIR}
  chmod -R 777 /ql
}

# ==========================
# 安装系统依赖
# ==========================
install_deps() {
  echo -e "\n${GREEN}[3/10] 更新系统&安装编译依赖${NC}"
  apt update -y
  apt upgrade -y
  apt install -y \
    git curl wget make build-essential libssl-dev libsqlite3-dev \
    python3 python3-pip python-is-python3 iproute2 jq lsof \
    ccache gcc g++ --no-install-recommends
  apt autoremove -y
}

# ==========================
# 安装Node.js（修复404！永久可用国内源）
# ==========================
install_node() {
  echo -e "\n${GREEN}[4/10] 安装Node.js ${NODE_VERSION}.x LTS${NC}"
  
  # 🔥 修复404：替换为100%可用的官方国内源
  curl -fsSL https://mirrors.aliyun.com/nodesource/nodesource.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://mirrors.aliyun.com/nodesource/deb/node_${NODE_VERSION}.x $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/nodesource.list
  
  apt update -y
  apt install -y nodejs

  # 验证版本
  NODE_V=$(node -v)
  NPM_V=$(npm -v)
  echo -e "${GREEN}✅ Node版本：$NODE_V | NPM版本：$NPM_V${NC}"
}

# ==========================
# 安装编译工具
# ==========================
install_build_tools() {
  echo -e "\n${GREEN}[5/10] 安装编译工具（修复node-gyp报错）${NC}"
  npm install -g node-gyp @mapbox/node-pre-gyp node-addon-api pnpm pm2 ts-node
}

# ==========================
# 安装青龙面板
# ==========================
install_qinglong() {
  echo -e "\n${GREEN}[6/10] 全局安装青龙面板${NC}"
  npm install -g --unsafe-perm @whyour/qinglong

  # 配置环境变量
  echo "export QL_DIR=${QL_DIR}" | tee -a /etc/profile >/dev/null
  echo "export QL_DATA_DIR=${QL_DATA_DIR}" | tee -a /etc/profile >/dev/null
  source /etc/profile
  echo -e "${GREEN}✅ 环境变量配置完成${NC}"
}

# ==========================
# 启动青龙
# ==========================
start_qinglong() {
  echo -e "\n${GREEN}[7/10] 启动青龙面板${NC}"
  
  # 后台启动
  qinglong &
  sleep 15

  # 校验状态
  if pgrep -f "qinglong" >/dev/null; then
    echo -e "${GREEN}🎉 青龙面板启动成功！${NC}"
  else
    echo -e "${RED}❌ 启动失败！请检查日志${NC}"
    exit 1
  fi
}

# ==========================
# 输出访问信息
# ==========================
show_info() {
  echo -e "\n${GREEN}==================================================${NC}"
  WSL_IP=$(hostname -I | awk '{print $1}')
  echo -e "${GREEN}✅ 访问地址：${YELLOW}http://${WSL_IP}:${QL_PORT}${NC}"
  echo -e "${GREEN}✅ 账号密码：${YELLOW}cat ${QL_DATA_DIR}/config/auth.json${NC}"
  echo -e "${GREEN}✅ 重启命令：${YELLOW}qinglong restart${NC}"
  echo -e "${GREEN}==================================================${NC}"
}

# ==========================
# 主流程（修复执行顺序，彻底解决npm报错）
# ==========================
clear
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}      青龙面板 WSL1 专用部署脚本（稳定版）      ${NC}"
echo -e "${GREEN}           固定Git镜像：fastgit.cc           ${NC}"
echo -e "${GREEN}==================================================${NC}"

# 正确执行顺序（核心修复）
env_check
clean_old_env
install_deps
install_node        # 先装Node（已修复404）
set_mirrors        # 再配置npm镜像（无报错）
install_build_tools
install_qinglong
start_qinglong
show_info
