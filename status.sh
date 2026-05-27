#!/bin/bash
# status.sh - Cek status VPS setelah rebuild

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${GREEN}"
echo "==================== STATUS VPS ===================="
echo -e "${NC}"

echo -e "${BLUE}📊 Penggunaan RAM:${NC}"
free -h
echo ""

echo -e "${BLUE}💾 Penggunaan Disk:${NC}"
df -h /
echo ""

echo -e "${BLUE}🔥 Firewall Status:${NC}"
ufw status
echo ""

echo -e "${BLUE}🔄 Service yang Berjalan:${NC}"
systemctl list-units --type=service --state=running | grep -E "(ssh|fail2ban|nginx|mysql)" | head -5
echo ""

echo -e "${BLUE}📈 System Load:${NC}"
uptime
echo ""

echo -e "${GREEN}===================================================${NC}"
