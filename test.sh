#!/bin/bash

# 青龙面板一键安装脚本 for WSL1 Ubuntu 20.04
# 修复npm配置问题版本
# 日期：2026-04-09

set -e

echo "========================================="
echo "青龙面板一键安装脚本（修复npm配置问题）"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本：sudo bash $0"
    exit 1
fi

# 0. 清理旧的npm配置
echo "步骤0/12：清理旧的npm配置..."
# 移除不兼容的npm配置项
npm config delete disturl 2>/dev/null || true
npm config delete sass_binary_site 2>/dev/null || true
npm config delete phantomjs_cdnurl 2>/dev/null || true
npm config delete chromedriver_cdnurl 2>/dev/null || true
npm config delete operadriver_cdnurl 2>/dev/null || true
npm config delete electron_mirror 2>/dev/null || true
npm config delete fse_binary_host_mirror 2>/dev/null || true
npm config delete node_sqlite3_binary_host_mirror 2>/dev/null || true
npm config delete sqlite3_binary_host_mirror 2>/dev/null || true
npm config delete sharp_binary_host 2>/dev/null || true
npm config delete sharp_libvips_binary_host 2>/dev/null || true
npm config delete canvas_binary_host_mirror 2>/dev/null || true
npm config delete nodejieba_binary_host_mirror 2>/dev/null || true

# 1. 备份并配置阿里云源
echo "步骤1/12：配置阿里云软件源..."
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
echo "步骤2/12：更新系统包..."
apt update && apt upgrade -y

# 3. 安装基础工具
echo "步骤3/12：安装基础工具..."
apt install -y git wget curl vim net-tools build-essential ca-certificates \
  gnupg libxml2-dev libxslt1-dev python3-dev gcc libffi-dev libssl-dev \
  libjpeg-dev libpng-dev libfreetype6-dev libsqlite3-dev pkg-config

# 4. 配置Git使用国内镜像
echo "步骤4/12：配置Git镜像加速..."
git config --global url."https://".insteadOf git://
git config --global url."https://github.com/".insteadOf git@github.com:

# 5. 安装Node.js 20.x
echo "步骤5/12：安装Node.js 20.x..."
# 清理旧的Node.js版本
apt remove -y nodejs npm 2>/dev/null || true
apt autoremove -y

# 安装Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"

# 6. 安装Python3和pip
echo "步骤6/12：安装Python3和pip..."
apt install -y python3 python3-pip python3-venv python3-dev

# 验证Python安装
python3 --version
pip3 --version

# 7. 配置国内镜像源（仅保留有效的配置）
echo "步骤7/12：配置国内镜像源..."

# 只配置registry，这是唯一必须且有效的配置
npm config set registry https://registry.npmmirror.com/

# 配置pip使用清华镜像
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip3 config set global.extra-index-url https://mirrors.aliyun.com/pypi/simple/
pip3 config set global.trusted-host "pypi.tuna.tsinghua.edu.cn mirrors.aliyun.com"

# 8. 安装pnpm
echo "步骤8/12：安装pnpm..."
# 根据【链接内容】，官方推荐使用pnpm@8.3.1
npm install -g pnpm@8.3.1
echo "pnpm版本: $(pnpm --version)"

# 9. 安装青龙面板
echo "步骤9/12：安装青龙面板..."

# 创建安装目录
INSTALL_DIR="/opt/qinglong"
if [ -d "$INSTALL_DIR" ]; then
    echo "备份现有青龙面板..."
    BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
    echo "已备份到: $BACKUP_DIR"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "从Gitee镜像克隆青龙面板..."
# 使用Gitee镜像（国内访问更快）
if git clone https://gitee.com/whyour/qinglong.git .; then
    echo "✓ 从Gitee克隆成功！"
    MIRROR_SOURCE="gitee"
else
    echo "Gitee克隆失败，尝试从GitHub克隆..."
    if git clone https://github.com/whyour/qinglong.git .; then
        echo "✓ 从GitHub克隆成功！"
        MIRROR_SOURCE="github"
    else
        echo "✗ 克隆失败！"
        echo "请检查网络连接或尝试以下方法："
        echo "1. 手动下载: wget https://github.com/whyour/qinglong/archive/refs/heads/master.zip"
        echo "2. 解压: unzip master.zip"
        echo "3. 移动: mv qinglong-master $INSTALL_DIR"
        exit 1
    fi
fi

# 检查当前版本
if [ -f "version.yaml" ]; then
    QL_VERSION=$(grep "version" version.yaml | head -1 | awk '{print $2}')
    echo "青龙面板版本: $QL_VERSION"
fi

# 10. 安装依赖
echo "步骤10/12：安装依赖..."

# 设置环境变量使用国内镜像
export MIRROR="gitee"

echo "使用pnpm安装依赖..."
if pnpm install; then
    echo "✓ pnpm安装成功！"
else
    echo "pnpm安装失败，尝试npm安装..."
    
    # 使用npm安装，忽略peer依赖冲突
    if npm install --legacy-peer-deps; then
        echo "✓ npm安装成功！"
    else
        echo "npm安装失败，尝试清理后重新安装..."
        
        # 清理node_modules后重试
        rm -rf node_modules
        npm cache clean --force
        
        if npm install --legacy-peer-deps --force; then
            echo "✓ 清理后安装成功！"
        else
            echo "⚠ 依赖安装遇到问题，但继续安装过程..."
        fi
    fi
fi

# 11. 创建目录结构和配置文件
echo "步骤11/12：创建目录结构和配置文件..."

# 创建数据目录
mkdir -p data/{config,scripts,log,db,upload,repo,raw,deps,env}
chmod -R 755 data

# 复制环境变量文件
if [ -f ".env.example" ]; then
    cp .env.example .env
    echo "✓ 已创建.env配置文件"
    
    # 更新.env文件中的镜像配置
    if ! grep -q "^MIRROR=" .env; then
        echo "MIRROR=gitee" >> .env
    fi
fi

# 创建启动脚本
cat > /usr/local/bin/ql << 'EOF'
#!/bin/bash
QL_DIR="/opt/qinglong"
QL_DATA_DIR="$QL_DIR/data"

# 设置国内镜像环境变量
export MIRROR="gitee"
export TZ="Asia/Shanghai"
export PORT=5700

case "$1" in
    start)
        echo "启动青龙面板..."
        cd "$QL_DIR"
        nohup node src/main.js > "$QL_DATA_DIR/log/qinglong.log" 2>&1 &
        QL_PID=$!
        echo "青龙面板已启动，PID: $QL_PID"
        echo "日志文件: $QL_DATA_DIR/log/qinglong.log"
        echo "访问地址: http://localhost:5700"
        ;;
    stop)
        echo "停止青龙面板..."
        QL_PID=$(pgrep -f "node.*qinglong" | head -1)
        if [ -n "$QL_PID" ]; then
            kill $QL_PID
            echo "已停止进程: $QL_PID"
        else
            echo "青龙面板未运行"
        fi
        ;;
    restart)
        echo "重启青龙面板..."
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
        if [ -f "$QL_DATA_DIR/log/qinglong.log" ]; then
            tail -f "$QL_DATA_DIR/log/qinglong.log"
        else
            echo "日志文件不存在: $QL_DATA_DIR/log/qinglong.log"
        fi
        ;;
    update)
        echo "更新青龙面板..."
        cd "$QL_DIR"
        git pull
        pnpm install
        $0 restart
        ;;
    *)
        echo "青龙面板管理工具"
        echo "用法: ql {start|stop|restart|status|log|update}"
        echo ""
        echo "命令说明:"
        echo "  start    - 启动青龙面板"
        echo "  stop     - 停止青龙面板"
        echo "  restart  - 重启青龙面板"
        echo "  status   - 查看运行状态"
        echo "  log      - 查看实时日志"
        echo "  update   - 更新青龙面板"
        echo ""
        echo "手动启动:"
        echo "  cd /opt/qinglong && node src/main.js"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/ql

# 12. 安装完成
echo "步骤12/12：安装完成！"

echo ""
echo "========================================="
echo "青龙面板安装完成！"
echo "========================================="
echo ""
echo "安装摘要："
echo "1. 已清理旧的npm配置"
echo "2. Node.js 20.x: 已安装"
echo "3. Python3: 已安装"
echo "4. pnpm 8.3.1: 已安装（官方推荐版本）"
echo "5. 青龙面板: 已从 $MIRROR_SOURCE 安装"
echo "6. 镜像源: 已配置国内镜像加速"
echo ""
echo "重要信息："
echo "访问地址: http://localhost:5700"
echo "安装目录: /opt/qinglong"
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
echo "初始化步骤："
echo "1. 启动青龙面板: ql start"
echo "2. 访问 http://localhost:5700"
echo "3. 按照页面提示完成初始化"
echo "4. 在青龙面板的【依赖管理】中安装所需依赖"
echo ""
echo "常见问题解决："
echo "1. 如果端口5700被占用，请修改/opt/qinglong/.env中的PORT"
echo "2. 如果启动失败，查看日志: ql log"
echo "3. 如果需要重新安装，先删除目录: rm -rf /opt/qinglong"
echo "========================================="
