#!/bin/bash
# 青龙面板一键安装脚本 | 无视报错 | 自定义步骤启动 | 强制步骤显示
# 适用系统：Ubuntu 20.04 (focal)
set +e                      # 核心：关闭报错退出，无视所有命令错误
export LC_ALL=C              # 固定语言，避免输出乱码

# ====================== 配置区域 ======================
# 高亮颜色定义（强制步骤显示，不被输出掩盖）
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'
total_steps=25               # 总步骤数
# ======================================================

# ====================== 核心函数 ======================
# 强制打印步骤信息（永不被掩盖）
print_step() {
    local step_num=$1
    local step_desc=$2
    # 强制清空终端行，高亮输出步骤
    echo -e "\n\033[K${BLUE}=============================================================${NC}"
    echo -e "\033[K${GREEN}✅  当前执行步骤：${step_num}/${total_steps}  |  ${step_desc}${NC}"
    echo -e "\033[K${BLUE}=============================================================${NC}\n"
}

# ====================== 分步执行函数 ======================
# 步骤1：备份并替换阿里云Ubuntu源
step1() {
    print_step 1 "备份原软件源并写入阿里云源"
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak || true
    sudo sh -c 'cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF' || true
}

# 步骤2：更新软件源并升级系统
step2() {
    print_step 2 "更新软件包列表并升级系统"
    sudo apt update && sudo apt upgrade -y || true
}

# 步骤3：安装基础依赖工具
step3() {
    print_step 3 "安装curl/git/net-tools等基础依赖"
    sudo apt install -y curl git build-essential net-tools iproute2 || true
}

# 步骤4：配置DNS加速
step4() {
    print_step 4 "配置114DNS加速外网访问"
    sudo sh -c 'rm /etc/resolv.conf && echo "nameserver 114.114.114.114" > /etc/resolv.conf' || true
}

# 步骤5：添加Node.js20.x官方源
step5() {
    print_step 5 "添加Node.js20.x安装源"
    curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash - || true
}

# 步骤6：安装nodejs和npm
step6() {
    print_step 6 "安装nodejs和npm"
    sudo apt install -y nodejs || true
}

# 步骤7：配置npm淘宝镜像源
step7() {
    print_step 7 "配置npm永久淘宝镜像"
    npm config set registry https://registry.npmmirror.com || true
}

# 步骤8：全局安装青龙基础npm依赖
step8() {
    print_step 8 "全局安装node-pre-gyp/pnpm"
    sudo npm install -g node-pre-gyp pnpm || true
}

# 步骤9：全局安装青龙面板核心包
step9() {
    print_step 9 "安装青龙面板核心包"
    sudo npm install -g @whyour/qinglong || true
}

# 步骤10：安装python3和pip3
step10() {
    print_step 10 "安装python3和pip3"
    sudo apt install -y python3 python3-pip || true
}

# 步骤11：配置pip阿里云源
step11() {
    print_step 11 "配置pip阿里云镜像源"
    mkdir -p ~/.pip || true
    sh -c 'cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple
EOF' || true
}

# 步骤12：创建青龙数据目录
step12() {
    print_step 12 "创建青龙面板数据目录"
    mkdir -p /root/qinglong /root/qinglong/data || true
}

# 步骤13：配置青龙环境变量
step13() {
    print_step 13 "配置青龙永久环境变量"
    export QL_DIR=/root/qinglong && export QL_DATA_DIR=/root/qinglong/data || true
    echo "export QL_DIR=/root/qinglong" >> ~/.bashrc || true
    echo "export QL_DATA_DIR=/root/qinglong/data" >> ~/.bashrc || true
}

# 步骤14：加载环境变量
step14() {
    print_step 14 "加载环境变量配置"
    source ~/.bashrc || true
}

# 步骤15：尝试启动青龙（旧命令）
step15() {
    print_step 15 "尝试启动青龙面板（旧命令）"
    Qinglong || true
}

# 步骤16：停止残留进程+清理错误安装
step16() {
    print_step 16 "停止残留进程并清理错误环境"
    pm2 stop all && pm2 delete all && rm -rf /root/qinglong || true
}

# 步骤17：克隆青龙源码（第一次）
step17() {
    print_step 17 "克隆青龙面板源码（第一次）"
    git clone https://gitee.com/whyour/qinglong.git /root/qinglong || true
}

# 步骤18：进入目录并复制配置文件
step18() {
    print_step 18 "复制青龙配置文件"
    cd /root/qinglong || true
    cp -f .env.example .env || true
}

# 步骤19：安装依赖（第一次）
step19() {
    print_step 19 "安装青龙依赖（第一次）"
    npm config set registry https://registry.npmmirror.com && npm install -g pnpm@8.3.1 pm2 ts-node && pnpm install --prod || true
}

# 步骤20：彻底清理错误环境
step20() {
    print_step 20 "清理残留目录，重置环境"
    cd /root || true
    rm -rf qinglong || true
}

# 步骤21：重新克隆纯净源码
step21() {
    print_step 21 "重新克隆纯净青龙源码"
    git clone https://gitee.com/whyour/qinglong.git || true
    cd qinglong || true
}

# 步骤22：复制配置文件
step22() {
    print_step 22 "重新复制配置文件"
    cp .env.example .env || true
}

# 步骤23：安装完整依赖
step23() {
    print_step 23 "安装青龙完整依赖"
    npm config set registry https://registry.npmmirror.com || true
    npm install -g pnpm pm2 || true
    pnpm install || true
}

# 步骤24：pm2启动青龙面板
step24() {
    print_step 24 "PM2守护启动青龙面板"
    pm2 start "pnpm start" --name "qinglong" || true
}

# 步骤25：保存pm2配置
step25() {
    print_step 25 "保存PM2自启配置"
    pm2 save || true
}

# ====================== 启动交互逻辑 ======================
clear
echo -e "${YELLOW}🚀 青龙面板一键安装脚本（无视报错/自定义步骤）${NC}"
echo -e "${YELLOW}=============================================================${NC}"
echo -e "${GREEN}1. 重新开始安装（从步骤1开始执行）${NC}"
echo -e "${GREEN}2. 指定步骤开始安装（输入步骤序号）${NC}"
echo -e "${YELLOW}=============================================================${NC}"

# 获取用户选择
read -p "请输入选择 [1/2]：" user_choice
if [ "$user_choice" = "1" ]; then
    start_step=1
elif [ "$user_choice" = "2" ]; then
    read -p "请输入开始的步骤序号 [1-${total_steps}]：" start_step
    # 校验步骤号合法性
    if ! [[ "$start_step" =~ ^[0-9]+$ ]] || [ "$start_step" -lt 1 ] || [ "$start_step" -gt "$total_steps" ]; then
        echo -e "${RED}❌ 输入无效！默认从步骤1开始${NC}"
        start_step=1
    fi
else
    echo -e "${RED}❌ 输入错误！默认从步骤1开始${NC}"
    start_step=1
fi

# 确认启动
echo -e "\n${GREEN}🎉 确认从 步骤${start_step} 开始执行，总步骤：${total_steps}${NC}"
sleep 2

# ====================== 执行主逻辑 ======================
for ((i=start_step; i<=total_steps; i++)); do
    step$i
    echo -e "\033[K${YELLOW}🔚 步骤 ${i} 执行完成（无视报错，继续下一步）${NC}\n"
    sleep 0.5
done

# 安装完成提示
echo -e "\n${GREEN}🎉 所有步骤执行完毕！青龙面板安装完成${NC}"
echo -e "${BLUE}📌 访问地址：http://127.0.0.1:8000${NC}"
echo -e "${BLUE}📌 查看状态：pm2 status qinglong${NC}"
echo -e "${BLUE}📌 重启面板：pm2 restart qinglong${NC}\n"
