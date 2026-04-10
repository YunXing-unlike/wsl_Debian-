#!/bin/bash
# ==============================================================
# QingLong Panel Backend One-Click Deploy Script
# Environment: WSL1 + Ubuntu 20.04 (No Docker, No Systemd)
# Function: Auto deploy qinglong backend, fix node20 npm error
# Author: Professional Script
# ==============================================================

# 脚本严格模式：遇到错误立即退出，未定义变量报错，管道失败终止
set -euo pipefail

# ===================== 基础配置（可自定义） =====================
# 青龙安装目录
QL_DIR="/opt/qinglong"
# 青龙数据目录
QL_DATA_DIR="/opt/qinglong/data"
# 青龙端口
QL_PORT=5700
# 国内镜像源配置
APT_MIRROR="mirrors.aliyun.com"
PIP_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
NPM_MIRROR="https://registry.npmmirror.com"
# =================================================================

# ===================== 权限检查 =====================
check_root() {
    if [ $(id -u) -ne 0 ]; then
        echo -e "\033[31m错误：请使用 root 用户运行此脚本！\033[0m"
        exit 1
    fi
}

# ===================== 更换APT国内源 =====================
change_apt_source() {
    echo -e "\033[32m[1/7] 更换Ubuntu APT国内镜像源...\033[0m"
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    cat > /etc/apt/sources.list << EOF
deb http://${APT_MIRROR}/ubuntu/ focal main restricted universe multiverse
deb http://${APT_MIRROR}/ubuntu/ focal-updates main restricted universe multiverse
deb http://${APT_MIRROR}/ubuntu/ focal-backports main restricted universe multiverse
deb http://${APT_MIRROR}/ubuntu/ focal-security main restricted universe multiverse
EOF
    apt update -y && apt upgrade -y
}

# ===================== 安装系统基础依赖 =====================
install_base_deps() {
    echo -e "\033[32m[2/7] 安装系统基础依赖...\033[0m"
    apt install -y \
        git curl wget build-essential libssl-dev \
        python3 python3-pip python3-dev \
        screen unzip zip net-tools
}

# ===================== 更换PIP国内源 =====================
change_pip_source() {
    echo -e "\033[32m[3/7] 配置PIP国内镜像源...\033[0m"
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << EOF
[global]
index-url = ${PIP_MIRROR}
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
    pip3 install --upgrade pip
}

# ===================== 安装Node.js 20.x + 修复NPM报错 =====================
install_node() {
    echo -e "\033[32m[4/7] 安装Node.js 20.x + 修复NPM disturl错误...\033[0m"
    # 安装Node20官方源
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
    apt update -y && apt install -y nodejs

    # 核心修复：解决 Node20 npm error: disturl is not a valid npm option
    echo -e "\033[32m修复NPM不兼容的disturl配置...\033[0m"
    npm config delete disturl || true
    npm config set registry ${NPM_MIRROR}
    npm install -g npm@latest
}

# ===================== 全局安装青龙面板 =====================
install_qinglong() {
    echo -e "\033[32m[5/7] 全局安装青龙面板后端...\033[0m"
    # 创建工作目录
    mkdir -p ${QL_DIR} ${QL_DATA_DIR}
    # 全局安装青龙
    npm install -g @whyour/qinglong
    # 永久配置青龙环境变量
    echo "export QL_DIR=${QL_DIR}" >> /etc/profile
    echo "export QL_DATA_DIR=${QL_DATA_DIR}" >> /etc/profile
    echo "export QL_PORT=${QL_PORT}" >> /etc/profile
    source /etc/profile
}

# ===================== 安装PM2进程守护（替代systemd） =====================
install_pm2() {
    echo -e "\033[32m[6/7] 安装PM2进程守护（WSL1无systemd）...\033[0m"
    npm install -g pm2
    # 设置PM2开机自启（WSL1兼容方案）
    pm2 startup
}

# ===================== 启动青龙服务 =====================
start_qinglong() {
    echo -e "\033[32m[7/7] 启动青龙面板后端服务...\033[0m"
    # 停止可能存在的旧进程
    pkill -f qinglong || true
    pm2 delete qinglong || true
    # 后台启动青龙
    cd ${QL_DIR}
    nohup qinglong > /var/log/qinglong.log 2>&1 &
    # PM2守护进程
    pm2 start "qinglong" --name qinglong
    pm2 save
    sleep 3
}

# ===================== 预留自定义步骤入口（用户可自行添加） =====================
custom_step() {
    echo -e "\033[33m=============================================\033[0m"
    echo -e "\033[33m【自定义步骤入口】可在此处添加个性化配置\033[0m"
    echo -e "\033[33m示例：安装额外依赖、配置代理、拉取自定义脚本\033[0m"
    echo -e "\033[33m=============================================\033[0m"
    # 👇👇👇 在此处添加你的自定义命令 👇👇👇

    # 👆👆👆 自定义命令结束 👆👆👆
}

# ===================== 部署完成提示 =====================
finish_info() {
    echo -e "\033[36m=============================================\033[0m"
    echo -e "\033[36m🎉 青龙面板后端部署完成！\033[0m"
    echo -e "\033[36m访问地址：http://localhost:${QL_PORT}\033[0m"
    echo -e "\033[36mWSL访问：http://$(hostname -I | awk '{print $1}'):${QL_PORT}\033[0m"
    echo -e "\033[36m初始账号：admin / 初始密码查看：cat ${QL_DATA_DIR}/config/auth.json\033[0m"
    echo -e "\033[36m服务管理：pm2 start/stop/restart qinglong\033[0m"
    echo -e "\033[36m日志查看：tail -f /var/log/qinglong.log\033[0m"
    echo -e "\033[36m=============================================\033[0m"
}

# ===================== 主执行流程 =====================
main() {
    clear
    echo -e "\033[36m=============================================\033[0m"
    echo -e "\033[36m青龙面板后端 WSL1 一键部署脚本\033[0m"
    echo -e "\033[36m环境：Ubuntu 20.04 | 无Docker | 无Systemd\033[0m"
    echo -e "\033[36m=============================================\033[0m"

    check_root
    change_apt_source
    install_base_deps
    change_pip_source
    install_node
    install_qinglong
    install_pm2
    custom_step
    start_qinglong
    finish_info
}

# 执行主程序
main
