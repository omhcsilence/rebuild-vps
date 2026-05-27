#!/bin/bash


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


LOG_FILE="/var/log/rebuild-$(date +%Y%m%d-%H%M%S).log"


echo -e "${GREEN}"
echo "=============================================="
echo "     SIMPLE VPS REBUILD SCRIPT v2.0"
echo "     Menghapus Semua Paket & Konfigurasi"
echo "=============================================="
echo -e "${NC}"


echo -e "${RED}⚠️  PERINGATAN! Script ini akan:${NC}"
echo "  ❌ Menghapus Nginx, Apache, PHP, MySQL, MariaDB"
echo "  ❌ Menghapus Pterodactyl Panel & Wings"
echo "  ❌ Menghapus Docker, Redis, Supervisor"
echo "  ❌ Menghapus semua konfigurasi terkait"
echo "  ❌ Mereset firewall & system ke default"
echo ""
echo -e "${YELLOW}⚠️  Data di /var/www, /var/lib/mysql, /etc/nginx akan DIHAPUS!${NC}"
echo ""

read -p "Ketik 'YES' untuk melanjutkan: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo -e "${RED}Dibatalkan${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Memulai proses rebuild...${NC}"
echo ""


log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}


log "Menghentikan semua service..."

services="nginx apache2 mysql mariadb php8.1-fpm php8.2-fpm php8.3-fpm redis-server supervisor docker pterodactyl-wings wings cron"

for service in $services; do
    if systemctl list-unit-files | grep -q "^$service.service"; then
        systemctl stop $service 2>/dev/null
        systemctl disable $service 2>/dev/null
        log "  ✓ Stopped $service"
    fi
done


pkill -f "pterodactyl" 2>/dev/null
pkill -f "wings" 2>/dev/null
pkill -f "nginx" 2>/dev/null
pkill -f "mysql" 2>/dev/null


log "Menghapus user pterodactyl..."
if id "pterodactyl" &>/dev/null; then
    userdel -r pterodactyl 2>/dev/null
    log "  ✓ User pterodactyl dihapus"
fi


log "Menghapus semua paket..."


log "  Menghapus Nginx & Apache..."
apt purge --auto-remove -y nginx nginx-common nginx-core apache2 apache2-utils 2>/dev/null


log "  Menghapus PHP..."
apt purge --auto-remove -y php* php8.* php7.* libapache2-mod-php* 2>/dev/null


log "  Menghapus MySQL & MariaDB..."
apt purge --auto-remove -y mysql-server mysql-client mysql-common mariadb-server mariadb-client 2>/dev/null


log "  Menghapus Pterodactyl..."
apt purge --auto-remove -y pterodactyl* wings* 2>/dev/null


log "  Menghapus Docker..."
apt purge --auto-remove -y docker docker-engine docker.io containerd runc docker-compose 2>/dev/null


log "  Menghapus tools terkait..."
apt purge --auto-remove -y redis-server supervisor certbot nodejs npm composer redis-tools 2>/dev/null


log "  Menghapus snap packages..."
snap list --all 2>/dev/null | awk 'NR>1 {print $1}' | while read snap_name; do
    snap remove --purge "$snap_name" 2>/dev/null
done


apt purge --auto-remove -y snapd 2>/dev/null


log "Menghapus direktori dan file..."

directories=(
    "/var/www/pterodactyl"
    "/var/www/html"
    "/etc/nginx"
    "/etc/apache2"
    "/etc/php"
    "/var/lib/mysql"
    "/var/lib/mariadb"
    "/etc/mysql"
    "/etc/mariadb"
    "/var/lib/docker"
    "/etc/docker"
    "/etc/letsencrypt"
    "/etc/pterodactyl"
    "/var/lib/pterodactyl"
    "/srv/pterodactyl"
    "/opt/pterodactyl"
    "/var/log/pterodactyl"
    "/var/log/wings"
    "/etc/supervisor/conf.d/pterodactyl*"
    "/etc/cron.d/pterodactyl*"
    "/etc/nginx/sites-enabled/pterodactyl*"
    "/etc/nginx/sites-available/pterodactyl*"
    "/root/.pterodactyl"
    "/root/.config/pterodactyl"
)

for dir in "${directories[@]}"; do
    if [[ -e "$dir" ]]; then
        rm -rf "$dir" 2>/dev/null
        log "  ✓ Deleted $dir"
    fi
done


for user_home in /home/* /root; do
    if [[ -d "$user_home" ]]; then
        rm -rf "$user_home/.composer" 2>/dev/null
        rm -rf "$user_home/.npm" 2>/dev/null
        rm -rf "$user_home/.cache" 2>/dev/null
    fi
done


log "Membersihkan sistem..."


apt autoremove --purge -y
apt autoclean
apt clean


find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
journalctl --rotate
journalctl --vacuum-time=1s


rm -rf /tmp/*
rm -rf /var/tmp/*


swapoff -a 2>/dev/null
rm -f /swapfile 2>/dev/null
sed -i '/swapfile/d' /etc/fstab 2>/dev/null


log "Meriset konfigurasi ke default..."


ufw --force disable 2>/dev/null
ufw --force reset 2>/dev/null
ufw default deny incoming 2>/dev/null
ufw default allow outgoing 2>/dev/null
ufw allow 22/tcp 2>/dev/null
echo "y" | ufw enable 2>/dev/null
log "  ✓ Firewall reset (SSH port 22 open)"


cat > /etc/hosts << EOF
127.0.0.1 localhost
127.0.1.1 $(hostname)

::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
log "  ✓ Hosts file reset"


apt install --reinstall -y openssh-server 2>/dev/null
systemctl restart ssh
log "  ✓ SSH reset"


log "Menginstall paket dasar..."

apt update


apt install -y \
    curl \
    wget \
    git \
    htop \
    net-tools \
    ufw \
    fail2ban \
    nano \
    vim \
    unzip \
    tar \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    2>/dev/null

log "  ✓ Paket dasar terinstall"


systemctl enable fail2ban 2>/dev/null
systemctl start fail2ban 2>/dev/null


log "Verifikasi hasil cleanup..."

echo ""
echo -e "${GREEN}=============================================="
echo "           REBUILD COMPLETE!"
echo -e "==============================================${NC}"
echo ""

echo -e "${BLUE}📊 RAM Usage:${NC}"
free -h
echo ""

echo -e "${BLUE}💾 Disk Usage:${NC}"
df -h /
echo ""

echo -e "${BLUE}🔥 Firewall Status:${NC}"
ufw status | head -2
echo ""

echo -e "${BLUE}🔄 Running Services:${NC}"
systemctl list-units --type=service --state=running | grep -E "(ssh|fail2ban)" | wc -l
echo "  - SSH: active"
echo "  - Fail2ban: active"
echo ""

echo -e "${BLUE}🔍 Cek sisa instalasi:${NC}"
if [[ -d "/var/www/pterodactyl" ]] || [[ -d "/etc/nginx" ]]; then
    echo -e "${YELLOW}⚠️  Masih ada sisa direktori${NC}"
else
    echo -e "${GREEN}✓ Tidak ada sisa paket web server/database${NC}"
fi

echo ""
echo -e "${GREEN}=============================================="
echo "✅ VPS SEKARANG SUDAH SEPERTI BARU!"
echo -e "==============================================${NC}"
echo ""
echo -e "${YELLOW}📝 Log tersimpan di: $LOG_FILE${NC}"
echo ""
echo -e "${CYAN}Untuk menginstall Pterodactyl, jalankan:${NC}"
echo "  bash <(curl -s https://pterodactyl-installer.se)"
echo ""
echo -e "${CYAN}Atau gunakan installer resmi Pterodactyl:${NC}"
echo "  bash <(curl -s https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer/master/installer.sh)"
echo ""

read -p "Reboot VPS sekarang? (y/n): " reboot_confirm
if [[ "$reboot_confirm" == "y" ]] || [[ "$reboot_confirm" == "Y" ]]; then
    log "Rebooting system..."
    reboot
else
    log "Selesai. Silakan reboot nanti: sudo reboot"
fi
