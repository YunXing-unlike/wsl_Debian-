#!/bin/bash

# 青龙面板一键安装脚本 for WSL1 Ubuntu 20.04
# 基于官方文档修复版本
# 日期：2026-04-09

set -e

echo "========================================="
echo "青龙面板一键安装脚本 for WSL1 Ubuntu 20.04"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本：sudo bash $0"
    exit 1
fi

# 检查是否已安装青龙面板
if [ -d "/opt/qinglong" ] && [ -d "/opt/qinglong/data" ]; then
    echo "检测到已安装青龙面板，将尝试修复安装..."
fi

# 1. 备份并配置阿里云源
echo "步骤1/10：配置软件源..."
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)
fi

cat > /etc/apt/sources.list << 'EOF'
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# 2. 更新系统包
echo "步骤2/10：更新系统包..."
apt update && apt upgrade -y

# 3. 安装基础工具
echo "步骤3/10：安装基础工具..."
apt install -y git wget curl vim net-tools build-essential ca-certificates \
  gnupg libxml2-dev libxslt1-dev python3-dev gcc libffi-dev libssl-dev \
  libjpeg-dev libpng-dev libfreetype6-dev libsqlite3-dev pkg-config

# 4. 安装Node.js 20.x
echo "步骤4/10：安装Node.js 20.x..."
# 清理旧的Node.js版本
apt remove -y nodejs npm 2>/dev/null || true
apt autoremove -y

# 安装Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"

# 5. 安装Python3和pip
echo "步骤5/10：安装Python3和pip..."
apt install -y python3 python3-pip python3-venv python3-dev

# 验证Python安装
python3 --version
pip3 --version

# 6. 配置镜像源
echo "步骤6/10：配置镜像源..."
# 配置npm镜像
npm config set registry https://registry.npmmirror.com/

# 配置pip镜像
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip3 config set global.extra-index-url https://mirrors.aliyun.com/pypi/simple/

# 7. 安装pnpm（根据官方文档推荐版本）
echo "步骤7/10：安装pnpm..."
# 根据【链接内容】，官方推荐使用pnpm@8.3.1
npm install -g pnpm@8.3.1
echo "pnpm版本: $(pnpm --version)"

# 8. 安装青龙面板
echo "步骤8/10：安装青龙面板..."

# 方法1：从GitHub克隆最新版本
cd /opt
if [ -d "qinglong" ]; then
    echo "备份现有青龙面板..."
    mv qinglong qinglong.backup.$(date +%Y%m%d%H%M%S)
fi

echo "克隆青龙面板仓库..."
git clone https://github.com/whyour/qinglong.git
cd qinglong

# 检查当前版本
if [ -f "version.yaml" ]; then
    echo "青龙面板版本: $(grep "version" version.yaml | head -1)"
fi

# 根据【链接内容】，青龙面板使用pnpm进行依赖管理
echo "使用pnpm安装依赖..."
pnpm install

# 如果pnpm安装失败，尝试使用npm
if [ $? -ne 0 ]; then
    echo "pnpm安装失败，尝试使用npm安装..."
    npm install --legacy-peer-deps
fi

# 9. 创建必要的目录结构
echo "步骤9/10：创建目录结构..."
mkdir -p /opt/qinglong/data/{config,scripts,log,db,upload,repo,raw,deps,env}
chmod -R 755 /opt/qinglong/data

# 复制环境变量文件
if [ -f ".env.example" ]; then
    cp .env.example .env
    echo "已创建.env配置文件，请根据需要修改"
fi

# 10. 创建启动脚本
echo "步骤10/10：创建启动脚本..."

# 创建启动脚本
cat > /usr/local/bin/start-qinglong << 'EOF'
#!/bin/bash
cd /opt/qinglong
export PORT=5700
export TZ=Asia/Shanghai
node src/main.js
EOF

chmod +x /usr/local/bin/start-qinglong

# 创建管理脚本
cat > /usr/local/bin/ql << 'EOF'
#!/bin/bash
case "$1" in
    start)
        echo "启动青龙面板..."
        cd /opt/qinglong
        export PORT=5700
        export TZ=Asia/Shanghai
        nohup node src/main.js > /opt/qinglong/data/log/qinglong.log 2>&1 &
        echo "青龙面板已启动，PID: $!"
        echo "日志: /opt/qinglong/data/log/qinglong.log"
        ;;
    stop)
        echo "停止青龙面板..."
        PID=$(pgrep -f "node.*qinglong" | head -1)
        if [ -n "$PID" ]; then
            kill $PID
            echo "已停止进程: $PID"
        else
            echo "青龙面板未运行"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if pgrep -f "node.*qinglong" > /dev/null; then
            echo "青龙面板正在运行"
            ps aux | grep -E "node.*qinglong" | grep -v grep
        else
            echo "青龙面板未运行"
        fi
        ;;
    log)
        tail -f /opt/qinglong/data/log/qinglong.log
        ;;
    update)
        echo "更新青龙面板..."
        cd /opt/qinglong
        git pull
        pnpm install
        $0 restart
        ;;
    *)
        echo "青龙面板管理工具"
        echo "用法: ql {start|stop|restart|status|log|update}"
        echo ""
        echo "常用命令:"
        echo "  start    - 启动青龙面板"
        echo "  stop     - 停止青龙面板"
        echo "  restart  - 重启青龙面板"
        echo "  status   - 查看状态"
        echo "  log      - 查看实时日志"
        echo "  update   - 更新青龙面板"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/ql

# 输出安装完成信息
echo ""
echo "========================================="
echo "青龙面板安装完成！"
echo "========================================="
echo ""
echo "安装摘要："
echo "1. 系统工具: 已安装"
echo "2. Node.js 20.x: 已安装"
echo "3. Python3: 已安装"
echo "4. pnpm 8.3.1: 已安装（官方推荐版本）"
echo "5. 青龙面板: 已从GitHub克隆最新版本"
echo "6. 依赖: 已通过pnpm安装"
echo ""
echo "重要信息："
echo "访问地址: http://localhost:5700"
echo "数据目录: /opt/qinglong/data"
echo "配置文件: /opt/qinglong/.env"
echo ""
echo "管理命令："
echo "启动: ql start"
echo "停止: ql stop"
echo "重启: ql restart"
echo "状态: ql status"
echo "日志: ql log"
echo "更新: ql update"
echo ""
echo "手动启动: cd /opt/qinglong && node src/main.js"
echo ""
echo "初始化步骤："
echo "1. 启动青龙面板: ql start"
echo "2. 访问 http://localhost:5700"
echo "3. 按照页面提示完成初始化"
echo "4. 在青龙面板的【依赖管理】中安装所需依赖"
echo ""
echo "注意："
echo "1. 如果端口5700被占用，请修改/opt/qinglong/.env中的PORT设置"
echo "2. 建议定期更新青龙面板: ql update"
echo "========================================="
