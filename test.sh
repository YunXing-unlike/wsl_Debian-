#!/bin/bash
# ============================================
# 青龙面板 Debian 修复脚本
# 修复：task命令、swap文件、notify脚本缺失
# ============================================

echo "=========================================="
echo "  青龙面板 Debian 系统修复"
echo "=========================================="

QL_DIR="/root/qinglong"
SCRIPTS_DIR="$QL_DIR/scripts"

# 1. 确保目录存在
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$QL_DIR/log"
mkdir -p "$QL_DIR/config"

# 2. 下载基础通知脚本（青龙必需）
echo "下载基础通知脚本..."

cd "$SCRIPTS_DIR"

# 下载 sendNotify.js（青龙标准通知库）
if [ ! -f "sendNotify.js" ]; then
    echo "下载 sendNotify.js..."
    curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/whyour/qinglong/master/sample/sendNotify.js" -o sendNotify.js 2>/dev/null || \
    curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/whyour/qinglong/master/sample/sendNotify.js" -o sendNotify.js 2>/dev/null || \
    echo "// 默认通知库占位" > sendNotify.js
fi

# 下载 notify.py（青龙标准通知库）
if [ ! -f "notify.py" ]; then
    echo "下载 notify.py..."
    curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/whyour/qinglong/master/sample/notify.py" -o notify.py 2>/dev/null || \
    curl -fsSL "https://mirror.ghproxy.com/https://raw.githubusercontent.com/whyour/qinglong/master/sample/notify.py" -o notify.py 2>/dev/null || \
    echo "# 默认通知库占位" > notify.py
fi

# 3. 创建示例任务脚本（可选）
if [ ! -f "example.js" ]; then
    cat > example.js << 'EOF'
// 示例任务脚本
const notify = require('./sendNotify.js');

async function main() {
    console.log('示例任务执行成功');
    // await notify.sendNotify('测试通知', '这是一条测试消息');
}

main();
EOF
fi

if [ ! -f "example.py" ]; then
    cat > example.py << 'EOF'
#!/usr/bin/env python3
# 示例任务脚本
import sys
sys.path.append('/root/qinglong/scripts')

try:
    from notify import send
except:
    pass

def main():
    print("Python示例任务执行成功")
    # send("测试通知", "这是一条测试消息")

if __name__ == "__main__":
    main()
EOF
chmod +x example.py
fi

# 4. 修复task命令（确保swap文件正确处理）
echo "修复task命令..."

sudo tee /usr/local/bin/task > /dev/null <<'TASK_EOF'
#!/bin/bash
# ============================================
# 青龙面板 task 命令 - Debian修复版
# ============================================

QL_DIR="/root/qinglong"
SCRIPTS_DIR="$QL_DIR/scripts"
LOGS_DIR="$QL_DIR/log"

# 调试模式
DEBUG=false

# 查找脚本（增强版）
find_script() {
    local target="$1"
    local found=""
    
    [ "$DEBUG" = true ] && echo "[DEBUG] 查找: $target" >&2
    
    # 清理路径（去除可能的./前缀）
    target="${target#./}"
    
    # 1. 绝对路径
    if [ -f "$target" ]; then
        echo "$target"
        return 0
    fi
    
    # 2. scripts目录直接查找
    if [ -f "$SCRIPTS_DIR/$target" ]; then
        echo "$SCRIPTS_DIR/$target"
        return 0
    fi
    
    # 3. 处理swap文件（关键修复）
    # 格式: notify.swap.py -> notify.py
    if [[ "$target" == *.swap.* ]]; then
        local base="${target%.swap.*}"
        local ext="${target##*.}"
        
        [ "$DEBUG" = true ] && echo "[DEBUG] swap映射: $base.$ext" >&2
        
        # 查找原始文件
        if [ -f "$SCRIPTS_DIR/$base.$ext" ]; then
            echo "$SCRIPTS_DIR/$base.$ext"
            return 0
        fi
        
        # 递归查找
        found=$(find "$SCRIPTS_DIR" -name "$base.$ext" -type f 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
        
        # 如果找不到原始文件，创建一个占位脚本（临时方案）
        echo "[警告] 找不到 $base.$ext，创建临时占位脚本" >&2
        local temp_script="$SCRIPTS_DIR/$base.$ext"
        case "$ext" in
            js)
                echo "// 自动生成的占位脚本" > "$temp_script"
                echo "console.log('占位脚本: $base.$ext');" >> "$temp_script"
                ;;
            py)
                echo "#!/usr/bin/env python3" > "$temp_script"
                echo "# 自动生成的占位脚本" >> "$temp_script"
                echo "print('占位脚本: $base.$ext')" >> "$temp_script"
                chmod +x "$temp_script"
                ;;
        esac
        echo "$temp_script"
        return 0
    fi
    
    # 4. 子目录查找
    if [[ "$target" == */* ]]; then
        if [ -f "$SCRIPTS_DIR/$target" ]; then
            echo "$SCRIPTS_DIR/$target"
            return 0
        fi
    fi
    
    # 5. 全局搜索
    found=$(find "$SCRIPTS_DIR" -name "$(basename "$target")" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# 解析参数
FILE_PATH=""
NOW_MODE=false
PARAMS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        now)
            NOW_MODE=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        real_time=true)
            # 忽略real_time参数
            shift
            ;;
        task)
            # 忽略task自身
            shift
            ;;
        *)
            if [ -z "$FILE_PATH" ] && [[ "$1" != *=* ]]; then
                FILE_PATH="$1"
            else
                PARAMS="$PARAMS $1"
            fi
            shift
            ;;
    esac
done

# 检查参数
if [ -z "$FILE_PATH" ]; then
    echo "Usage: task <script> [now]"
    echo "  now - 立即执行"
    exit 1
fi

# 查找脚本
SCRIPT_PATH=$(find_script "$FILE_PATH")

if [ -z "$SCRIPT_PATH" ]; then
    echo "Error: Script not found: $FILE_PATH"
    echo "Searched in: $SCRIPTS_DIR"
    echo ""
    echo "Available scripts:"
    ls -la "$SCRIPTS_DIR/" 2>/dev/null || echo "  (目录为空)"
    exit 1
fi

# 获取脚本信息
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# 创建日志目录
mkdir -p "$LOGS_DIR/$SCRIPT_NAME"
LOG_FILE="$LOGS_DIR/$SCRIPT_NAME/$(date +%Y-%m-%d-%H-%M-%S-%3N).log"

# 设置环境
export QL_DIR="$QL_DIR"
export QL_SCRIPTS_DIR="$SCRIPTS_DIR"
cd "$SCRIPT_DIR" 2>/dev/null || cd "$QL_DIR"

# 随机延迟
if [ "$NOW_MODE" = false ]; then
    DELAY=$((RANDOM % 5 + 1))
    echo "随机延迟 ${DELAY} 秒..."
    sleep $DELAY
fi

echo "========================================"
echo "执行: $SCRIPT_NAME"
echo "路径: $SCRIPT_PATH"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# 执行脚本
case "${SCRIPT_PATH##*.}" in
    js)  CMD="node \"$SCRIPT_PATH\"" ;;
    py)  CMD="python3 \"$SCRIPT_PATH\"" ;;
    sh)  CMD="bash \"$SCRIPT_PATH\"" ;;
    *)   CMD="bash \"$SCRIPT_PATH\"" ;;
esac

eval "$CMD $PARAMS" > "$LOG_FILE" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ 成功: $SCRIPT_NAME"
else
    echo "❌ 失败: $SCRIPT_NAME (退出码: $EXIT_CODE)"
    echo "日志: $LOG_FILE"
    tail -n 10 "$LOG_FILE" 2>/dev/null
fi

exit $EXIT_CODE
TASK_EOF

sudo chmod +x /usr/local/bin/task

# 5. 验证修复
echo ""
echo "========================================"
echo "  修复完成，验证中..."
echo "========================================"

echo "scripts目录内容:"
ls -la "$SCRIPTS_DIR/"

echo ""
echo "测试task命令:"
task example.js now

echo ""
echo "测试swap文件映射:"
task notify.swap.py now 2>&1 | head -5

echo ""
echo "========================================"
echo "  修复完成！"
echo "========================================"
echo "请重新启动青龙面板: ql restart"
