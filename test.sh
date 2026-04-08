#!/bin/bash
# 青龙面板一键安装脚本 - 无视报错 | 断点续装 | 强制步骤显示
# 适用系统：Ubuntu 20.04 (focal)
set +e                      # 核心：无视所有命令报错，强制继续执行
set -o pipefail             # 忽略管道命令报错
clear                      # 清屏优化显示

# ====================== 配置区域 ======================
# 颜色定义（强制高亮步骤，不被输出掩盖）
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"
# 总步骤数（严格按你的命令拆分，无任何简化）
TOTAL_STEPS=51
# ======================================================

# ====================== 核心函数 ======================
# 强制打印当前步骤（置顶高亮，永不被掩盖）
print_step() {
    local step_num=$1
    local step_desc=$2
    echo -e "\n${GREEN}============================================================${RESET}"
    echo -e "${GREEN}📌  当前执行：第 ${step_num}/${TOTAL_STEPS} 步 | ${step_desc}${RESET}"
    echo -e "${GREEN}============================================================${RESET}\n"
}
# ======================================================

# ====================== 启动选择 ======================
echo -e "${YELLOW}============================================================${RESET}"
echo -e "${YELLOW}          青龙面板一键安装脚本（无Docker/纯原生）${RESET}"
echo -e "${YELLOW}============================================================${RESET}"
echo -e "${YELLOW}✅ 特性：无视所有报错 | 强制步骤显示 | 保留全部重复命令${RESET}"
echo -e "${YELLOW}✅ 模式：0=从头开始  | 输入数字=从指定步骤断点执行${RESET}"
echo -e "${YELLOW}============================================================${RESET}\n"

# 读取用户启动选择
read -p "$(echo -e ${YELLOW}请输入启动方式：${RESET})" START_STEP

# 输入合法性校验
if [[ ! $START_STEP =~ ^[0-9]+$ ]] || [[ $START_STEP -gt $TOTAL_STEPS ]]; then
    echo -e "${RED}⚠️  输入错误，自动切换为【从头开始】${RESET}"
    START_STEP=1
elif [[ $START_STEP -eq 0 ]]; then
    START_STEP=1
    echo -e "${GREEN}✅ 已选择：从头开始执行所有步骤${RESET}"
else
    echo -e "${GREEN}✅ 已选择：从第 ${START_STEP} 步断点执行${RESET}"
fi
sleep 1
echo -e "\n${YELLOW}🚀 开始执行脚本，请稍候...${RESET}\n"
sleep 1
# ======================================================

# ====================== 步骤执行 ======================
# 步骤1：写入阿里云软件源（替代交互式nano，适配脚本自动化）
if [[ $START_STEP -le 1 ]]; then
    print_step 1 "写入Ubuntu20.04阿里云官方软件源"
    sudo tee /etc/apt/sources.list > /dev/null << EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF
fi

# 步骤2：更新并升级系统
if [[ $START_STEP -le 2 ]]; then
    print_step 2 "更新软件包列表并升级系统"
    sudo apt update && sudo apt upgrade -y
fi

# 步骤3：安装基础依赖
if [[ $START_STEP -le 3 ]]; then
    print_step 3 "安装curl/git等基础依赖工具"
    sudo apt install -y curl git build-essential net-tools iproute2
fi

# 步骤4：配置DNS加速
if [[ $START_STEP -le 4 ]]; then
    print_step 4 "配置114DNS加速外网访问"
    sudo sh -c 'rm /etc/resolv.conf && echo "nameserver 114.114.114.114" > /etc/resolv.conf'
fi

# 步骤5：安装Node.js20.x源
if [[ $START_STEP -le 5 ]]; then
    print_step 5 "添加Node.js20.x官方安装源"
    curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -
fi

# 步骤6：安装nodejs/npm
if [[ $START_STEP -le 6 ]]; then
    print_step 6 "安装nodejs和npm环境"
    sudo apt install -y nodejs
fi

# 步骤7：配置npm淘宝源
if [[ $START_STEP -le 7 ]]; then
    print_step 7 "配置npm永久淘宝镜像加速"
    npm config set registry https://registry.npmmirror.com
fi

# 步骤8：全局安装青龙依赖包
if [[ $START_STEP -le 8 ]]; then
    print_step 8 "全局安装node-pre-gyp/pnpm依赖"
    sudo npm install -g node-pre-gyp pnpm
fi

# 步骤9：全局安装青龙核心包
if [[ $START_STEP -le 9 ]]; then
    print_step 9 "全局安装青龙面板核心包"
    sudo npm install -g @whyour/qinglong
fi

# 步骤10：安装python3/pip3
if [[ $START_STEP -le 10 ]]; then
    print_step 10 "安装python3和pip3"
    sudo apt install -y python3 python3-pip
fi

# 步骤11：创建pip配置目录
if [[ $START_STEP -le 11 ]]; then
    print_step 11 "创建pip3配置文件目录"
    mkdir -p ~/.pip
fi

# 步骤12：写入pip阿里云源
if [[ $START_STEP -le 12 ]]; then
    print_step 12 "写入pip阿里云加速源"
    tee ~/.pip/pip.conf > /dev/null << EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple
EOF
fi

# 步骤13：创建青龙数据目录
if [[ $START_STEP -le 13 ]]; then
    print_step 13 "创建青龙面板数据存储目录"
    mkdir -p /root/qinglong /root/qinglong/data
fi

# 步骤14：设置临时环境变量
if [[ $START_STEP -le 14 ]]; then
    print_step 14 "设置青龙临时环境变量"
    export QL_DIR=/root/qinglong && export QL_DATA_DIR=/root/qinglong/data
fi

# 步骤15：写入环境变量到bashrc
if [[ $START_STEP -le 15 ]]; then
    print_step 15 "将环境变量写入配置文件永久生效"
    echo "export QL_DIR=/root/qinglong" >> ~/.bashrc && echo "export QL_DATA_DIR=/root/qinglong/data" >> ~/.bashrc
fi

# 步骤16：加载环境变量
if [[ $START_STEP -le 16 ]]; then
    print_step 16 "加载系统环境变量配置"
    source ~/.bashrc
fi

# 步骤17：启动青龙面板
if [[ $START_STEP -le 17 ]]; then
    print_step 17 "执行青龙面板启动命令"
    Qinglong
fi

# 步骤18：清理残留进程/目录
if [[ $START_STEP -le 18 ]]; then
    print_step 18 "停止残留进程并清理错误安装文件"
    pm2 stop all && pm2 delete all && rm -rf /root/qinglong
fi

# 步骤19：克隆青龙源码
if [[ $START_STEP -le 19 ]]; then
    print_step 19 "克隆青龙Gitee官方源码"
    git clone https://gitee.com/whyour/qinglong.git /root/qinglong
fi

# 步骤20：进入青龙目录
if [[ $START_STEP -le 20 ]]; then
    print_step 20 "进入青龙安装目录"
    cd /root/qinglong
fi

# 步骤21：复制环境配置文件
if [[ $START_STEP -le 21 ]]; then
    print_step 21 "复制.env环境配置文件"
    cp -f .env.example .env
fi

# 步骤22：安装面板核心依赖
if [[ $START_STEP -le 22 ]]; then
    print_step 22 "安装青龙面板核心运行依赖"
    npm config set registry https://registry.npmmirror.com && npm install -g pnpm@8.3.1 pm2 ts-node && pnpm install --prod
fi

# 步骤23：强制删除青龙目录
if [[ $START_STEP -le 23 ]]; then
    print_step 23 "强制删除已存在的青龙目录"
    rm -rf /root/qinglong
fi

# 步骤24：重新克隆源码
if [[ $START_STEP -le 24 ]]; then
    print_step 24 "重新克隆青龙官方源码"
    git clone https://gitee.com/whyour/qinglong.git /root/qinglong
fi

# 步骤25：进入青龙目录
if [[ $START_STEP -le 25 ]]; then
    print_step 25 "进入青龙源码目录"
    cd /root/qinglong
fi

# 步骤26：复制配置文件
if [[ $START_STEP -le 26 ]]; then
    print_step 26 "重新复制环境配置文件"
    cp -f .env.example .env
fi

# 步骤27：安装依赖
if [[ $START_STEP -le 27 ]]; then
    print_step 27 "重新安装面板运行依赖"
    npm config set registry https://registry.npmmirror.com && npm install -g pnpm@8.3.1 pm2 ts-node && pnpm install --prod
fi

# 步骤28：清空残留目录
if [[ $START_STEP -le 28 ]]; then
    print_step 28 "强制清空青龙残留目录"
    rm -rf /root/qinglong
fi

# 步骤29：克隆原生源码
if [[ $START_STEP -le 29 ]]; then
    print_step 29 "克隆青龙纯原生源码"
    git clone https://gitee.com/whyour/qinglong.git /root/qinglong
fi

# 步骤30：进入目录
if [[ $START_STEP -le 30 ]]; then
    print_step 30 "进入青龙原生目录"
    cd /root/qinglong
fi

# 步骤31：复制核心配置
if [[ $START_STEP -le 31 ]]; then
    print_step 31 "复制核心环境配置文件"
    cp .env.example .env
fi

# 步骤32：配置加速+安装依赖
if [[ $START_STEP -le 32 ]]; then
    print_step 32 "配置npm加速并安装原生依赖"
    npm config set registry https://registry.npmmirror.com
    npm install -g pnpm@8.3.1
    pnpm install --prod
fi

# 步骤33：回到root目录
if [[ $START_STEP -le 33 ]]; then
    print_step 33 "返回系统root根目录"
    cd /root
fi

# 步骤34：删除残留目录
if [[ $START_STEP -le 34 ]]; then
    print_step 34 "删除错误残留的青龙目录"
    rm -rf qinglong
fi

# 步骤35：重新克隆源码
if [[ $START_STEP -le 35 ]]; then
    print_step 35 "重新克隆青龙加速源码"
    git clone https://gitee.com/whyour/qinglong.git
fi

# 步骤36：进入青龙目录
if [[ $START_STEP -le 36 ]]; then
    print_step 36 "进入青龙源码根目录"
    cd qinglong
fi

# 步骤37：复制配置文件
if [[ $START_STEP -le 37 ]]; then
    print_step 37 "复制.env配置文件"
    cp .env.example .env
fi

# 步骤38：安装纯原生依赖
if [[ $START_STEP -le 38 ]]; then
    print_step 38 "安装纯Node原生运行依赖"
    npm config set registry https://registry.npmmirror.com
    npm install -g pnpm@8.3.1
    pnpm install --prod
fi

# 步骤39：原生启动面板
if [[ $START_STEP -le 39 ]]; then
    print_step 39 "直接原生启动青龙面板"
    node server.js
fi

# 步骤40：清理所有残留
if [[ $START_STEP -le 40 ]]; then
    print_step 40 "强制清理所有错误残留文件"
    cd /root
    rm -rf qinglong
    mkdir -p qinglong
    cd qinglong
fi

# 步骤41：克隆纯净源码
if [[ $START_STEP -le 41 ]]; then
    print_step 41 "克隆纯净版青龙源码"
    git clone https://gitee.com/whyour/qinglong.git .
fi

# 步骤42：复制环境配置
if [[ $START_STEP -le 42 ]]; then
    print_step 42 "复制纯净版环境配置文件"
    cp .env.example .env
fi

# 步骤43：加速安装依赖
if [[ $START_STEP -le 43 ]]; then
    print_step 43 "加速安装纯原生依赖"
    npm config set registry https://registry.npmmirror.com
    npm install -g pnpm@8.3.1
    pnpm install --prod
fi

# 步骤44：官方原生启动
if [[ $START_STEP -le 44 ]]; then
    print_step 44 "执行青龙官方原生启动命令"
    pnpm start
fi

# 步骤45：彻底清理环境
if [[ $START_STEP -le 45 ]]; then
    print_step 45 "彻底清理错误安装环境"
    cd /root
    rm -rf qinglong
fi

# 步骤46：最终克隆源码
if [[ $START_STEP -le 46 ]]; then
    print_step 46 "最终克隆纯净青龙源码"
    git clone https://gitee.com/whyour/qinglong.git
    cd qinglong
fi

# 步骤47：复制配置
if [[ $START_STEP -le 47 ]]; then
    print_step 47 "最终复制环境配置文件"
    cp .env.example .env
fi

# 步骤48：安装完整依赖
if [[ $START_STEP -le 48 ]]; then
    print_step 48 "安装完整依赖（修复缺失组件）"
    npm config set registry https://registry.npmmirror.com
    npm install -g pnpm pm2
    pnpm install
fi

# 步骤49：最终无Docker启动
if [[ $START_STEP -le 49 ]]; then
    print_step 49 "最终无Docker模式启动青龙"
    pnpm start
fi

# 步骤50：pm2托管进程
if [[ $START_STEP -le 50 ]]; then
    print_step 50 "pm2后台托管青龙面板"
    pm2 start "pnpm start" --name "qinglong"
fi

# 步骤51：保存pm2配置
if [[ $START_STEP -le 51 ]]; then
    print_step 51 "保存pm2自启配置"
    pm2 save
fi
# ======================================================

# ====================== 完成提示 ======================
echo -e "\n${GREEN}============================================================${RESET}"
echo -e "${GREEN}🎉 脚本执行完毕！所有步骤已强制执行完成${RESET}"
echo -e "${YELLOW}ℹ️  青龙面板已通过pm2后台托管，支持开机自启${RESET}"
echo -e "${YELLOW}ℹ️  访问地址：服务器IP:8000（默认端口）${RESET}"
echo -e "${GREEN}============================================================${RESET}\n"
