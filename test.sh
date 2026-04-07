#!/bin/bash
set -eo pipefail

# ========== 彩色输出 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========== 全局变量（固定适配WSL1） ==========
QL_DIR="/usr/lib/node_modules/@whyour/qinglong"
QL_DATA_DIR="/ql/data"
QL_PORT=5700
NODE_VERSION=20
GITHUB_MIRROR="https://gh.xx9527.cn"
NPM_MIRROR="https://registry.npmmirror.com"

# ==========================
# 工具函数：环境预检
# ==========================
env_check() {
  echo -e "${GREEN}[环境预检] 正在检测系统信息...${NC}"

  # 系统识别
  . /etc/os-release
  ARCH=$(dpkg --print-architecture)
  echo -e "${BLUE}  OS:        $PRETTY_NAME${NC}"
  echo -e "${BLUE}  Arch:      $ARCH${NC}"

  # WSL1强制校验（禁止WSL2）
  if uname -r | grep -qiw "wsl2"; then
    echo -e "${RED}❌ 错误：当前为WSL2，脚本仅支持WSL1！请切换WSL1后重试${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ WSL1 环境校验通过${NC}"

  # 网络检测
  if curl -s --connect-timeout 3 https://www.baidu.com >/dev/null; then
    echo -e "${BLUE}  网络:      直连正常${NC}"
  else
    echo -e "${RED}❌ 错误：网络异常，请检查网络后重试${NC}"
    exit 1
  fi
}

# ==========================
# 全链路加速配置
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

  # Git全局镜像（解决GitHub下载失败）
  git config --global url."${GITHUB_MIRROR}/".insteadOf "https://github.com/"
  git config --global url."${GITHUB_MIRROR}/".insteadOf "https://raw.githubusercontent.com/"
  git config --global http.sslVerify false

  # NPM镜像
  npm config set registry ${NPM_MIRROR}
  npm config set unsafe-perm true
}

# ==========================
# 清理旧环境/缓存/进程
# ==========================
clean_old_env() {
  echo -e "\n${GREEN}[清理] 彻底清空旧环境/缓存/进程${NC}"
  
  # 停止青龙/pm2进程
  pkill -f qinglong || true
  pkill -f pm2 || true
  pm2 stop all 2>/dev/null || true
  pm2 delete all 2>/dev/null || true

  # 清理npm缓存
  npm cache clean --force 2>/dev/null || true
  rm -rf ~/.npm /root/.npm 2>/dev/null || true

  # 卸载旧青龙
  npm uninstall -g @whyour/qinglong 2>/dev/null || true

  # 创建数据目录
  mkdir -p ${QL_DATA_DIR}
  chmod -R 777 /ql
}

# ==========================
# 安装系统必备依赖
# ==========================
install_deps() {
  echo -e "\n${GREEN}[3/10] 更新系统&安装编译依赖${NC}"
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt install -y \
    git curl wget make build-essential libssl-dev libsqlite3-dev \
    python3 python3-pip python-is-python3 iproute2 jq lsof nginx \
    ccache gcc g++ --no-install-recommends

  # 清理无用依赖
  sudo apt autoremove -y
}

# ==========================
# 安装Node.js
# ==========================
install_node() {
  echo -e "\n${GREEN}[4/10] 安装Node.js ${NODE_VERSION}.x LTS${NC}"
  curl -fsSL https://cdn.npmmirror.com/binaries/nodesource/setup_${NODE_VERSION}.x | sudo -E bash -
  sudo apt install -y nodejs

  # 验证版本
  NODE_V=$(node -v)
  NPM_V=$(npm -v)
  echo -e "${GREEN}✅ Node版本：$NODE_V | NPM版本：$NPM_V${NC}"
}

# ==========================
# 安装青龙编译必备工具（修复核心报错）
# ==========================
install_build_tools() {
  echo -e "\n${GREEN}[5/10] 安装编译工具（修复node-gyp报错）${NC}"
  npm install -g node-gyp @mapbox/node-pre-gyp node-addon-api pnpm pm2 ts-node
}

# ==========================
# 全局安装青龙面板
# ==========================
install_qinglong() {
  echo -e "\n${GREEN}[6/10] 全局安装青龙面板${NC}"
  npm install -g --unsafe-perm @whyour/qinglong

  # 自动配置环境变量（无需手动export）
  echo "export QL_DIR=${QL_DIR}" | sudo tee -a /etc/profile >/dev/null
  echo "export QL_DATA_DIR=${QL_DATA_DIR}" | sudo tee -a /etc/profile >/dev/null
  source /etc/profile
  echo -e "${GREEN}✅ 环境变量自动配置完成${NC}"
}

# ==========================
# 启动青龙（官方标准方式）
# ==========================
start_qinglong() {
  echo -e "\n${GREEN}[7/10] 启动青龙面板${NC}"
  
  # 关闭WSL1冲突服务
  sudo systemctl stop nginx 2>/dev/null || true
  sudo systemctl disable nginx 2>/dev/null || true

  # 后台启动
  qinglong &
  sleep 10

  # 校验启动状态
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
  echo -e "${YELLOW}💡 提示：首次打开面板会自动初始化，等待10秒即可${NC}"
}

# ==========================
# 主流程
# ==========================
clear
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}      青龙面板 WSL1 专用部署脚本（优化无错版）      ${NC}"
echo -e "${GREEN}           自动修复编译报错 · 一键部署完成           ${NC}"
echo -e "${GREEN}==================================================${NC}"

# 执行部署
env_check
set_mirrors
clean_old_env
install_deps
install_node
install_build_tools
install_qinglong
start_qinglong
show_info
