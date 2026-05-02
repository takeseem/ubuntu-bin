#!/bin/bash -e

###############################################################################
# Description: AppImage Unpacker & System Integrator
# Usage: ./app-ext.sh <YourApp.AppImage>
#
# Features:
#   1. Unpacks AppImage to a local directory (persistent, avoids IO overhead).
#   2. Automatically extracts and fixes the .desktop file.
#   3. Updates the system menu (XDG) for easy launching and taskbar pinning.
#   4. Sets absolute paths for Exec and Icon to ensure portability.
###############################################################################

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[$(date +"%H:%M:%S")]${NC} $1"; }
error() { echo -e "${YELLOW}[ERROR]${NC} $1" && exit 1; }

# 参数检查
[[ -z "$1" ]] && error "Usage: $0 <AppImage_File>"
[[ ! -f "$1" ]] && error "File '$1' not found."

APP_IMG_PATH=$(readlink -f "$1")
BASE_DIR=$(pwd)
FILE_NAME=$(basename "$APP_IMG_PATH")
APP_NAME="${FILE_NAME%.AppImage}"

# 提取简化的应用名 (例如: QQMusic-1.2.3 -> qqmusic)
SHORT_NAME=$(echo "$APP_NAME" | sed -E 's/[-_][0-9].*//I' | tr '[:upper:]' '[:lower:]')

log "Processing ${GREEN}$FILE_NAME${NC} ..."

# 1. 解包 AppImage
TARGET_DIR="$BASE_DIR/$APP_NAME"
if [[ -d "$TARGET_DIR" ]]; then
    log "Target directory '$APP_NAME' already exists. Skipping extraction."
else
    mkdir -p "$TARGET_DIR"
    log "Extracting AppImage to $TARGET_DIR ..."
    (cd "$TARGET_DIR" && "$APP_IMG_PATH" --appimage-extract > /dev/null)
fi

SQUASH_DIR="$TARGET_DIR/squashfs-root"
[[ ! -d "$SQUASH_DIR" ]] && error "Extraction failed: $SQUASH_DIR not found."

# 2. 处理 Desktop 文件
ORIG_DESKTOP=$(ls "$SQUASH_DIR"/*.desktop | head -n 1)
[[ -z "$ORIG_DESKTOP" ]] && error "No .desktop file found in AppImage."

DESKTOP_FILE=$(basename "$ORIG_DESKTOP")
LOCAL_DESKTOP="$BASE_DIR/$DESKTOP_FILE"

log "Configuring desktop file: ${GREEN}$DESKTOP_FILE${NC}"

# 复制并修改
cp -p "$ORIG_DESKTOP" "$LOCAL_DESKTOP"

# 修正 Exec, Icon 和 Path
# 使用 env APPDIR 确保应用内部路径正确，设置 Path 为工作目录
sed -i "s|^Exec=.*|Exec=env APPDIR=$SQUASH_DIR $SQUASH_DIR/AppRun|" "$LOCAL_DESKTOP"
sed -i "s|^Icon=.*|Icon=$SQUASH_DIR/.DirIcon|" "$LOCAL_DESKTOP"

# 确保有 Path 字段，方便应用寻找相对资源
if grep -q "^Path=" "$LOCAL_DESKTOP"; then
    sed -i "s|^Path=.*|Path=$SQUASH_DIR|" "$LOCAL_DESKTOP"
else
    echo "Path=$SQUASH_DIR" >> "$LOCAL_DESKTOP"
fi

# 移除可能的冲突项
sed -i '/^Categories=/d' "$LOCAL_DESKTOP"
echo "Categories=Utility;Application;" >> "$LOCAL_DESKTOP"

# 3. 集成到系统
log "Integrating with system menu..."
DEST_APP_DIR="$HOME/.local/share/applications"
mkdir -p "$DEST_APP_DIR"

ln -sf "$LOCAL_DESKTOP" "$DEST_APP_DIR/$DESKTOP_FILE"

# 验证并更新数据库
if command -v desktop-file-validate >/dev/null; then
    desktop-file-validate "$LOCAL_DESKTOP" || log "${YELLOW}Warning: Desktop file validation failed.${NC}"
fi

update-desktop-database "$DEST_APP_DIR" 2>/dev/null || true

# 4. 创建便捷链接 (可选)
ln -sfT "$TARGET_DIR" "$BASE_DIR/$SHORT_NAME-ver"

log "${GREEN}Done!${NC} Application is now available in your system menu."
log "Unpacked directory: $TARGET_DIR"
log "Desktop file linked: $DEST_APP_DIR/$DESKTOP_FILE"
