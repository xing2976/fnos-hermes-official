#!/bin/bash
#
# Hermes Agent fpk 构建脚本
# 用法：
#   ./build-fpk.sh              # 自动递增 patch 版本
#   ./build-fpk.sh 0.22.0       # 指定版本号
#   ./build-fpk.sh --noinc      # 保持当前版本
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="${PROJECT_DIR}/dist"
VERSION_FILE="${PROJECT_DIR}/config/bootstrap/hermes-version.env"

# 读取当前版本
CURRENT_VERSION=$(grep '^HERMES_VERSION=' "$VERSION_FILE" 2>/dev/null | cut -d= -f2 || echo "0.21.0")

# 解析参数
INC_VERSION=true
for arg in "$@"; do
    case $arg in
        --noinc)
            INC_VERSION=false
            ;;
        *)
            if [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                CURRENT_VERSION="$arg"
            fi
            ;;
    esac
done

# 自动递增版本
if [ "$INC_VERSION" = true ] && [ -n "$CURRENT_VERSION" ]; then
    PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
    NEW_PATCH=$((PATCH + 1))
    MAJOR_MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f1,2)
    CURRENT_VERSION="${MAJOR_MINOR}.${NEW_PATCH}"
fi

# 设置环境变量
export HERMES_VERSION="$CURRENT_VERSION"

echo ">>> 构建版本: $CURRENT_VERSION"

# 确保 dist 目录存在
mkdir -p "$DIST_DIR"

# 检查必要的源文件
if [ ! -f "${PROJECT_DIR}/manifest" ]; then
    echo "ERROR: manifest 文件不存在"
    exit 1
fi

# 检查 app.tgz（如果存在则使用，否则提示需要解压源码）
APP_TGZ="${PROJECT_DIR}/app.tgz"
if [ ! -f "$APP_TGZ" ]; then
    echo "WARNING: app.tgz 不存在，将尝试从上游下载 Hermes Agent 源码"
    
    # 下载 Hermes Agent 源码
    HERMES_SRC_URL="https://github.com/NousResearch/hermes-agent/releases/download/v${CURRENT_VERSION}/hermes-agent-${CURRENT_VERSION}.tar.gz"
    echo ">>> 下载: $HERMES_SRC_URL"
    
    if command -v curl >/dev/null 2>&1; then
        curl -LsSf "$HERMES_SRC_URL" -o /tmp/hermes-src.tar.gz 2>/dev/null || {
            # 尝试备用镜像
            curl -LsSf "https://ghproxy.com/$HERMES_SRC_URL" -o /tmp/hermes-src.tar.gz 2>/dev/null || {
                echo "ERROR: 无法下载 Hermes Agent 源码"
                exit 1
            }
        }
        
        # 解压到临时目录
        TMPDIR=$(mktemp -d)
        tar xzf /tmp/hermes-src.tar.gz -C "$TMPDIR" 2>/dev/null || true
        
        # 移动到项目目录
        mkdir -p "${PROJECT_DIR}/app"
        mv "$TMPDIR"/*/* "${PROJECT_DIR}/app/" 2>/dev/null || mv "$TMPDIR"/* "${PROJECT_DIR}/app/" 2>/dev/null || true
        
        rm -rf "$TMPDIR"
        rm -f /tmp/hermes-src.tar.gz
        
        # 创建 app.tgz
        (cd "${PROJECT_DIR}" && tar czf app.tgz app/)
    else
        echo "ERROR: 需要 curl 来下载源码"
        exit 1
    fi
fi

# 构建 fpk
echo ">>> 开始构建 fpk..."

# 计算 checksum
PACKAGE_NAME="fnos-hermes-agent-v${CURRENT_VERSION}.fpk"
cd "$PROJECT_DIR"

# 使用 tar 构建（模拟官方 fnpack）
tar czf "$PACKAGE_NAME" manifest config/ cmd/ wizard/ ICON.PNG ICON_256.PNG LICENSE app/ app.tgz 2>/dev/null || {
    # 如果失败，尝试只打包必要文件
    tar czf "$PACKAGE_NAME" manifest config/bootstrap/ cmd/ wizard/ app/ui/config 2>/dev/null || {
        echo "ERROR: 构建失败"
        exit 1
    }
}

# 更新 manifest checksum
SHA=$(sha256sum "$PACKAGE_NAME" 2>/dev/null | cut -c1-64 || shasum -a 256 "$PACKAGE_NAME" 2>/dev/null | cut -c1-64)
sed -i "s/^checksum.*/checksum              = ${SHA}/" manifest

# 移动产物
mkdir -p "$DIST_DIR"
mv "$PACKAGE_NAME" "$DIST_DIR/"

echo ">>> 构建完成: ${DIST_DIR}/${PACKAGE_NAME}"
echo ">>> Checksum: ${SHA}"
