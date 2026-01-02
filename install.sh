#!/bin/bash
# زنجیر⛓️ - اسکریپت نصب خودکار
# پیام‌رسان امن و غیرمتمرکز ایرانی‌شده بر پایه Matrix
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║           ⛓️  زنجیر - نصب‌کننده خودکار ⛓️            ║"
    echo "║      پیام‌رسان امن و غیرمتمرکز بر پایه Matrix      ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[اطلاعات]${NC} $1"; }
log_success() { echo -e "${GREEN}[موفق]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[هشدار]${NC} $1"; }
log_error() { echo -e "${RED}[خطا]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "لطفاً با دسترسی root اجرا کنید: sudo ./install.sh"
        exit 1
    fi
}

check_domain() {
    if [ -z "$1" ]; then
        echo ""
        log_error "دامنه مشخص نشده است!"
        echo -e "استفاده: ${YELLOW}sudo ./install.sh yourdomain.com${NC}"
        exit 1
    fi
    DOMAIN="$1"
    log_info "دامنه: $DOMAIN"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker قبلاً نصب شده است."
        return
    fi
    log_info "در حال نصب Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    log_success "Docker با موفقیت نصب شد."
}

install_docker_compose() {
    if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
        log_success "Docker Compose قبلاً نصب شده است."
        return
    fi
    log_info "در حال نصب Docker Compose..."
    apt-get update && apt-get install -y docker-compose-plugin
    log_success "Docker Compose با موفقیت نصب شد."
}

generate_secrets() {
    log_info "تولید رمزهای امنیتی..."
    POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')
    REGISTRATION_SECRET=$(openssl rand -base64 32 | tr -d '/+=')
    log_success "رمزها تولید شدند."
}

create_env_file() {
    log_info "ایجاد فایل .env..."
    cat > .env <<EOF
DOMAIN=${DOMAIN}
REGISTRATION_SHARED_SECRET=${REGISTRATION_SECRET}
POSTGRES_USER=dendrite
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=dendrite
LETSENCRYPT_EMAIL=admin@${DOMAIN}
EOF
    chmod 600 .env
    log_success "فایل .env ایجاد شد."
}

update_configs() {
    log_info "به‌روزرسانی فایل‌های تنظیمات..."
    
    # Update element-config.json
    sed -i "s/\${DOMAIN}/${DOMAIN}/g" config/element-config.json
    
    # Update dendrite.yaml
    sed -i "s/\${DOMAIN}/${DOMAIN}/g" dendrite/dendrite.yaml
    sed -i "s/\${POSTGRES_USER}/dendrite/g" dendrite/dendrite.yaml
    sed -i "s/\${POSTGRES_PASSWORD}/${POSTGRES_PASSWORD}/g" dendrite/dendrite.yaml
    sed -i "s/\${POSTGRES_DB}/dendrite/g" dendrite/dendrite.yaml
    sed -i "s/\${REGISTRATION_SHARED_SECRET}/${REGISTRATION_SECRET}/g" dendrite/dendrite.yaml
    
    log_success "تنظیمات به‌روز شدند."
}

generate_matrix_key() {
    log_info "تولید کلید امضای Matrix..."
    if [ ! -f "dendrite/matrix_key.pem" ]; then
        docker run --rm -v "$(pwd)/dendrite:/etc/dendrite" \
            matrixdotorg/dendrite-monolith:latest \
            /usr/bin/generate-keys --private-key /etc/dendrite/matrix_key.pem
        chmod 600 dendrite/matrix_key.pem
        log_success "کلید Matrix تولید شد."
    else
        log_warning "کلید Matrix قبلاً وجود دارد."
    fi
}

start_services() {
    log_info "راه‌اندازی سرویس‌ها..."
    
    # Run element-copy first to prepare files
    docker compose run --rm element-copy
    
    # Start all services
    docker compose up -d postgres dendrite element caddy
    
    log_success "سرویس‌ها راه‌اندازی شدند!"
}

print_success() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✅ نصب با موفقیت انجام شد! ✅            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "🌐 آدرس وب: ${BLUE}https://${DOMAIN}${NC}"
    echo ""
    echo -e "📝 برای ثبت‌نام کاربر جدید از دستور زیر استفاده کنید:"
    echo -e "${YELLOW}docker exec -it zanjir-dendrite /usr/bin/create-account \\
    --config /etc/dendrite/dendrite.yaml \\
    --username YOUR_USERNAME \\
    --admin${NC}"
    echo ""
    echo -e "🔑 رمز ثبت‌نام: ${YELLOW}${REGISTRATION_SECRET}${NC}"
    echo ""
    log_info "این اطلاعات در فایل .env ذخیره شده‌اند."
}

# Main
print_banner
check_root
check_domain "$1"
install_docker
install_docker_compose
generate_secrets
create_env_file
update_configs
generate_matrix_key
start_services
print_success
