#!/bin/bash
# زنجیر⛓️ - اسکریپت تولید کلید Matrix
# این اسکریپت کلید امضای Dendrite را تولید می‌کند

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEY_FILE="$PROJECT_DIR/dendrite/matrix_key.pem"

echo "🔐 تولید کلید امضای Matrix..."

# Check if key already exists
if [ -f "$KEY_FILE" ]; then
    echo "⚠️  کلید قبلاً وجود دارد: $KEY_FILE"
    read -p "آیا می‌خواهید کلید جدید تولید کنید؟ (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "❌ لغو شد."
        exit 0
    fi
    echo "🗑️  حذف کلید قدیمی..."
    rm -f "$KEY_FILE"
fi

# Generate key using Docker
echo "⏳ در حال تولید کلید با Dendrite..."

docker run --rm \
    -v "$PROJECT_DIR/dendrite:/etc/dendrite" \
    matrixdotorg/dendrite-monolith:latest \
    /usr/bin/generate-keys \
    --private-key /etc/dendrite/matrix_key.pem

# Verify key was created
if [ -f "$KEY_FILE" ]; then
    echo "✅ کلید با موفقیت تولید شد: $KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo "🔒 مجوزهای فایل تنظیم شد."
else
    echo "❌ خطا در تولید کلید!"
    exit 1
fi
