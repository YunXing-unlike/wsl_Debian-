#!/bin/bash
# ============================================
# 青龙面板 task 命令 - 完整修复版
# 支持：scripts目录、子目录、swap临时文件
# ============================================

# 青龙目录
QL_DIR="/root/qinglong"
SCRIPTS_DIR="$QL_DIR/scripts"
LOGS_DIR="$QL_DIR/log"

# 参数解析
MODE="normal"  # normal, now, conc, desi
FILE_PATH=""
ENV_NAME=""
ACCOUNT_NUM=""
MAX_TIME=""
PARAMS=""

# 解析选项
while [[ $# -gt 0 ]]; do
    case "$1" in
        now)
            MODE="now"
            shift
            ;;
        conc)
            MODE="conc"
            shift
            if [[ $# -gt 0 ]]; then
                ENV_NAME="$1"
                shift
            fi
            if [[ $# -gt 0 ]] && [[ "$1" != -* ]]; then
                ACCOUNT_NUM="$1"
                shift
            fi
            ;;
        desi)
            MODE="desi"
            shift
            if [[ $# -gt 0 ]]; then
                ENV_NAME="$1"
                shift
            fi
            if [[ $# -gt 0 ]]; then
                ACCOUNT_NUM="$1"
                shift
            fi
            ;;
        -m|--max-time)
            shift
            MAX_TIME="$1"
            shift
            ;;
        -l|--log)
            MODE="log"
            shift
            ;;
        --)
            shift
            PARAMS="$@"
            break
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$FILE_PATH" ]; then
                FILE_PATH="$1"
            else
                PARAMS="$PARAMS $1"
            fi
            shift
            ;;
    esac
done

# 如果没有提供文件路径，显示帮助
if [ -z "$FILE_PATH" ]; then
    echo "Usage: task <file_path> [now|conc|desi] [options]"
    echo ""
    echo "Options:"
    echo "  now              立即运行（忽略随机延迟）"
    echo "  conc <env> [num] 并发执行"
    echo "  desi <env> [num] 指定账号执行"
    echo "  -m <seconds>     设置超时时间"
    echo "  -l               实时打印日志"
    exit 1
fi

# ============================================
# 关键修复：查找脚本的完整逻辑
# ============================================

find_script() {
    local target="$1"
    local found=""
    
    # 1. 直接路径检查（绝对路径）
    if [ -f "$target" ]; then
        echo "$target"
        return 0
    fi
    
    # 2. 在scripts目录下查找
    if [ -f "$SCRIPTS_DIR/$target" ]; then
        echo "$SCRIPTS_DIR/$target"
        return 0
    fi
    
    # 3. 处理 swap 文件（关键修复！）
    # 青龙会生成类似 notify.swap.py 的临时文件，实际对应 notify.py
    if [[ "$target" == *.swap.* ]]; then
        local base_name="${target%.swap.*}"
        local ext="${target##*.}"
        
        # 查找原始文件
        if [ -f "$SCRIPTS_DIR/$base_name.$ext" ]; then
            echo "$SCRIPTS_DIR/$base_name.$ext"
            return 0
        fi
        
        # 递归查找子目录
        found=$(find "$SCRIPTS_DIR" -name "$base_name.$ext" -type f 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
    fi
    
    # 4. 递归查找子目录（处理路径包含目录的情况）
    if [[ "$target" == */* ]]; then
        local dir_part=$(dirname "$target")
        local file_part=$(basename "$target")
        
        if [ -f "$SCRIPTS_DIR/$target" ]; then
            echo "$SCRIPTS_DIR/$target"
            return 0
        fi
        
        # 在子目录中查找
        found=$(find "$SCRIPTS_DIR/$dir_part" -name "$file_part" -type f 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
    fi
    
    # 5. 全局搜索（最后手段）
    found=$(find "$SCRIPTS_DIR" -name "$(basename "$target")" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# 查找脚本
SCRIPT_FULL_PATH=$(find_script "$FILE_PATH")

if [ -z "$SCRIPT_FULL_PATH" ]; then
    echo "Error: Script not found: $FILE_PATH"
    echo "Searched in: $SCRIPTS_DIR"
    echo ""
    echo "Available scripts in $SCRIPTS_DIR:"
    ls -la "$SCRIPTS_DIR/" 2>/dev/null || echo "  (directory not accessible)"
    exit 1
fi

# 获取脚本信息
SCRIPT_NAME=$(basename "$SCRIPT_FULL_PATH")
SCRIPT_DIR=$(dirname "$SCRIPT_FULL_PATH")
RELATIVE_PATH="${SCRIPT_FULL_PATH#$SCRIPTS_DIR/}"

# 创建日志目录
TASK_LOG_DIR="$LOGS_DIR/$SCRIPT_NAME"
mkdir -p "$TASK_LOG_DIR"

# 生成日志文件名
LOG_DATE=$(date +"%Y-%m-%d-%H-%M-%S-%3N")
LOG_FILE="$TASK_LOG_DIR/$LOG_DATE.log"

# ============================================
# 设置环境变量
# ============================================
export QL_DIR="$QL_DIR"
export QL_SCRIPTS_DIR="$SCRIPTS_DIR"
export QL_LOGS_DIR="$LOGS_DIR"

# 加载青龙环境（如果存在）
[ -f "$QL_DIR/config/env.sh" ] && source "$QL_DIR/config/env.sh"
[ -f "$QL_DIR/config/config.sh" ] && source "$QL_DIR/config/config.sh"

# 切换到脚本所在目录
cd "$SCRIPT_DIR" || cd "$QL_DIR"

# ============================================
# 执行脚本
# ============================================

echo "========================================"
echo "任务开始: $SCRIPT_NAME"
echo "模式: $MODE"
echo "脚本路径: $SCRIPT_FULL_PATH"
echo "日志文件: $LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# 构建执行命令
case "${SCRIPT_FULL_PATH##*.}" in
    js)
        CMD="node \"$SCRIPT_FULL_PATH\""
        ;;
    py)
        CMD="python3 \"$SCRIPT_FULL_PATH\""
        ;;
    sh)
        CMD="bash \"$SCRIPT_FULL_PATH\""
        ;;
    ts)
        CMD="ts-node \"$SCRIPT_FULL_PATH\""
        ;;
    *)
        CMD="bash \"$SCRIPT_FULL_PATH\""
        ;;
esac

# 添加参数
if [ -n "$PARAMS" ]; then
    CMD="$CMD $PARAMS"
fi

# 执行并记录日志
if [ "$MODE" = "log" ]; then
    # 实时输出模式
    eval "$CMD" 2>&1 | tee "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
else
    # 后台/标准模式
    eval "$CMD" > "$LOG_FILE" 2>&1
    EXIT_CODE=$?
fi

# 记录结束信息
echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "任务结束: $SCRIPT_NAME" >> "$LOG_FILE"
echo "退出码: $EXIT_CODE" >> "$LOG_FILE"
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# 输出结果
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ 任务执行成功: $SCRIPT_NAME"
else
    echo "❌ 任务执行失败: $SCRIPT_NAME (退出码: $EXIT_CODE)"
    echo "日志: $LOG_FILE"
fi

exit $EXIT_CODE
