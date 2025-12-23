#!/bin/bash

#############################################
#  SmartDNS - Скрипт автоматической установки
#  Для Ubuntu 22.04 / Debian 12
#  
#  Поддерживаемые сервисы:
#  - Brawl Stars, Clash of Clans, Clash Royale
#  - Instagram, Facebook, Twitter/X, Threads
#  - Discord, LinkedIn
#  - Spotify, Netflix, Twitch, SoundCloud
#  - ChatGPT, Notion, Medium, Patreon
#  - BBC, Archive.org, ProtonMail, PayPal
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║             SmartDNS - Автоустановка v2.0                     ║"
echo "║   Обход блокировок: игры, соцсети, стриминг и сервисы         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ошибка: Запустите скрипт от root (sudo)${NC}"
    exit 1
fi

# Получение IP адреса сервера
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ipinfo.io/ip)

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Ошибка: Не удалось определить IP адрес сервера${NC}"
    echo "Введите IP адрес вручную:"
    read SERVER_IP
fi

echo -e "${GREEN}✓ IP адрес сервера: ${SERVER_IP}${NC}"
echo ""

# ===== ШАГ 1: Обновление системы =====
echo -e "${YELLOW}[1/6] Обновление системы...${NC}"
apt update && apt upgrade -y
echo -e "${GREEN}✓ Система обновлена${NC}"

# ===== ШАГ 2: Установка Docker =====
echo -e "${YELLOW}[2/6] Установка Docker...${NC}"

if ! command -v docker &> /dev/null; then
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Определяем дистрибутив
    OS="debian"
    if grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        OS="ubuntu"
    fi
    
    # Добавление репозитория Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${OS}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
    
    echo -e "${GREEN}✓ Docker установлен${NC}"
else
    echo -e "${GREEN}✓ Docker уже установлен${NC}"
fi

# ===== ШАГ 3: Отключение systemd-resolved =====
echo -e "${YELLOW}[3/6] Освобождение порта 53...${NC}"

if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    
    rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    
    echo -e "${GREEN}✓ systemd-resolved отключен${NC}"
else
    echo -e "${GREEN}✓ Порт 53 свободен${NC}"
fi

# ===== ШАГ 4: Настройка файрвола =====
echo -e "${YELLOW}[4/6] Настройка файрвола...${NC}"

apt install -y ufw

ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53/tcp > /dev/null 2>&1
ufw allow 53/udp > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1

ufw --force enable > /dev/null 2>&1

echo -e "${GREEN}✓ Файрвол настроен (порты: 22, 53, 80, 443)${NC}"

# ===== ШАГ 5: Создание конфигураций =====
echo -e "${YELLOW}[5/6] Создание конфигураций...${NC}"

# Создание директории
mkdir -p /opt/smartdns/coredns
mkdir -p /opt/smartdns/sniproxy

# Docker Compose
cat > /opt/smartdns/docker-compose.yml << 'DOCKER_EOF'
version: '3.8'

services:
  coredns:
    image: coredns/coredns:latest
    container_name: smartdns-coredns
    restart: always
    ports:
      - "53:53/udp"
      - "53:53/tcp"
    volumes:
      - ./coredns:/etc/coredns:ro
    command: -conf /etc/coredns/Corefile
    networks:
      - smartdns

  sniproxy:
    image: vimagick/sniproxy
    container_name: smartdns-sniproxy
    restart: always
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./sniproxy/sniproxy.conf:/etc/sniproxy.conf:ro
    networks:
      - smartdns

networks:
  smartdns:
    driver: bridge
DOCKER_EOF

# CoreDNS Corefile
cat > /opt/smartdns/coredns/Corefile << COREFILE_EOF
. {
    cache 3600
    errors
    
    # 🎮 ИГРЫ (Supercell)
    template IN A game.brawlstars.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A event.brawlstars.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A brawlstars.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A supercell.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A id.supercell.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A game.supercellid.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A csv.game.supercellid.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A prod.gamesconfiguration.supercell.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A api-assets.supercell.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A clashofclans.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A clashroyale.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # 📱 Instagram
    template IN A instagram.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A i.instagram.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A graph.instagram.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Facebook
    template IN A facebook.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A fb.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A connect.facebook.net {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Twitter / X
    template IN A twitter.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A x.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A api.twitter.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A api.x.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A abs.twimg.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A pbs.twimg.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A t.co {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Threads
    template IN A threads.net {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # 💬 Discord
    template IN A discord.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A discordapp.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A discord.gg {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A cdn.discordapp.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A gateway.discord.gg {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A media.discordapp.net {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # LinkedIn
    template IN A linkedin.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # 🎬 Spotify
    template IN A spotify.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A spclient.wg.spotify.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A apresolve.spotify.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # SoundCloud
    template IN A soundcloud.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Netflix
    template IN A netflix.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Twitch
    template IN A twitch.tv {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # 🔧 OpenAI / ChatGPT
    template IN A openai.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A chat.openai.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A api.openai.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Notion
    template IN A notion.so {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A notion.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Medium
    template IN A medium.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Patreon
    template IN A patreon.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # BBC
    template IN A bbc.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A bbc.co.uk {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Archive.org
    template IN A archive.org {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A web.archive.org {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # ProtonMail
    template IN A protonmail.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    template IN A proton.me {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # PayPal
    template IN A paypal.com {
        answer "{{ .Name }} 60 IN A ${SERVER_IP}"
    }
    
    # Все остальные → Google/Cloudflare DNS
    forward . 8.8.8.8 8.8.4.4 1.1.1.1 {
        prefer_udp
        health_check 5s
    }
}
COREFILE_EOF

# SNI Proxy config
cat > /opt/smartdns/sniproxy/sniproxy.conf << 'SNIPROXY_EOF'
user daemon
pidfile /var/run/sniproxy.pid

resolver {
    nameserver 8.8.8.8
    nameserver 1.1.1.1
    mode ipv4_only
}

listener 0.0.0.0:80 {
    proto http
    table http_hosts
}

listener 0.0.0.0:443 {
    proto tls
    table https_hosts
}

table http_hosts {
    .*\.brawlstars\.com$ *
    brawlstars\.com$ *
    .*\.supercell\.com$ *
    supercell\.com$ *
    .*\.supercell\.net$ *
    supercell\.net$ *
    .*\.clashofclans\.com$ *
    clashofclans\.com$ *
    .*\.clashroyale\.com$ *
    clashroyale\.com$ *
    .*\.instagram\.com$ *
    instagram\.com$ *
    .*\.cdninstagram\.com$ *
    .*\.facebook\.com$ *
    facebook\.com$ *
    .*\.fbcdn\.net$ *
    .*\.facebook\.net$ *
    .*\.fb\.com$ *
    fb\.com$ *
    .*\.twitter\.com$ *
    twitter\.com$ *
    .*\.x\.com$ *
    x\.com$ *
    .*\.twimg\.com$ *
    t\.co$ *
    .*\.threads\.net$ *
    threads\.net$ *
    .*\.discord\.com$ *
    discord\.com$ *
    .*\.discordapp\.com$ *
    discordapp\.com$ *
    .*\.discord\.gg$ *
    discord\.gg$ *
    .*\.discordapp\.net$ *
    .*\.linkedin\.com$ *
    linkedin\.com$ *
    .*\.licdn\.com$ *
    .*\.spotify\.com$ *
    spotify\.com$ *
    .*\.spotifycdn\.com$ *
    .*\.scdn\.co$ *
    .*\.soundcloud\.com$ *
    soundcloud\.com$ *
    .*\.sndcdn\.com$ *
    .*\.netflix\.com$ *
    netflix\.com$ *
    .*\.nflxvideo\.net$ *
    .*\.nflximg\.net$ *
    .*\.twitch\.tv$ *
    twitch\.tv$ *
    .*\.ttvnw\.net$ *
    .*\.openai\.com$ *
    openai\.com$ *
    .*\.notion\.so$ *
    notion\.so$ *
    .*\.notion\.com$ *
    notion\.com$ *
    .*\.medium\.com$ *
    medium\.com$ *
    .*\.patreon\.com$ *
    patreon\.com$ *
    .*\.bbc\.com$ *
    bbc\.com$ *
    .*\.bbc\.co\.uk$ *
    bbc\.co\.uk$ *
    .*\.archive\.org$ *
    archive\.org$ *
    .*\.protonmail\.com$ *
    protonmail\.com$ *
    .*\.proton\.me$ *
    proton\.me$ *
    .*\.paypal\.com$ *
    paypal\.com$ *
}

table https_hosts {
    .*\.brawlstars\.com$ *
    brawlstars\.com$ *
    .*\.supercell\.com$ *
    supercell\.com$ *
    .*\.supercell\.net$ *
    supercell\.net$ *
    .*\.clashofclans\.com$ *
    clashofclans\.com$ *
    .*\.clashroyale\.com$ *
    clashroyale\.com$ *
    .*\.instagram\.com$ *
    instagram\.com$ *
    .*\.cdninstagram\.com$ *
    .*\.facebook\.com$ *
    facebook\.com$ *
    .*\.fbcdn\.net$ *
    .*\.facebook\.net$ *
    .*\.fb\.com$ *
    fb\.com$ *
    .*\.twitter\.com$ *
    twitter\.com$ *
    .*\.x\.com$ *
    x\.com$ *
    .*\.twimg\.com$ *
    t\.co$ *
    .*\.threads\.net$ *
    threads\.net$ *
    .*\.discord\.com$ *
    discord\.com$ *
    .*\.discordapp\.com$ *
    discordapp\.com$ *
    .*\.discord\.gg$ *
    discord\.gg$ *
    .*\.discordapp\.net$ *
    .*\.linkedin\.com$ *
    linkedin\.com$ *
    .*\.licdn\.com$ *
    .*\.spotify\.com$ *
    spotify\.com$ *
    .*\.spotifycdn\.com$ *
    .*\.scdn\.co$ *
    .*\.soundcloud\.com$ *
    soundcloud\.com$ *
    .*\.sndcdn\.com$ *
    .*\.netflix\.com$ *
    netflix\.com$ *
    .*\.nflxvideo\.net$ *
    .*\.nflximg\.net$ *
    .*\.twitch\.tv$ *
    twitch\.tv$ *
    .*\.ttvnw\.net$ *
    .*\.openai\.com$ *
    openai\.com$ *
    .*\.notion\.so$ *
    notion\.so$ *
    .*\.notion\.com$ *
    notion\.com$ *
    .*\.medium\.com$ *
    medium\.com$ *
    .*\.patreon\.com$ *
    patreon\.com$ *
    .*\.bbc\.com$ *
    bbc\.com$ *
    .*\.bbc\.co\.uk$ *
    bbc\.co\.uk$ *
    .*\.archive\.org$ *
    archive\.org$ *
    .*\.protonmail\.com$ *
    protonmail\.com$ *
    .*\.proton\.me$ *
    proton\.me$ *
    .*\.paypal\.com$ *
    paypal\.com$ *
}
SNIPROXY_EOF

echo -e "${GREEN}✓ Конфигурации созданы${NC}"

# ===== ШАГ 6: Запуск SmartDNS =====
echo -e "${YELLOW}[6/6] Запуск SmartDNS...${NC}"

cd /opt/smartdns
docker compose pull
docker compose up -d

# Ждём запуска
sleep 5

# Проверка статуса
if docker ps | grep -q smartdns-coredns && docker ps | grep -q smartdns-sniproxy; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           SmartDNS успешно установлен! 🎉                     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Твой DNS сервер: ${SERVER_IP}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Поддерживаемые сервисы:${NC}"
    echo "  🎮 Игры:      Brawl Stars, Clash of Clans, Clash Royale"
    echo "  📱 Соцсети:   Instagram, Facebook, Twitter/X, Threads"
    echo "  💬 Общение:   Discord, LinkedIn"
    echo "  🎬 Стриминг:  Spotify, Netflix, Twitch, SoundCloud"
    echo "  🔧 Сервисы:   ChatGPT, Notion, Medium, Patreon, PayPal"
    echo "  📰 Медиа:     BBC, Archive.org, ProtonMail"
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Настройка устройств:${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "📱 ${BLUE}Android:${NC}"
    echo "   1. Скачай приложение 'DNS Changer' из Play Store"
    echo "   2. Укажи DNS: ${SERVER_IP}"
    echo "   3. Активируй и пользуйся!"
    echo ""
    echo "🍎 ${BLUE}iOS:${NC}"
    echo "   Wi-Fi:  Настройки → Wi-Fi → (i) → DNS → Вручную → ${SERVER_IP}"
    echo "   LTE/5G: Скачай 'DNSCloak' и добавь свой сервер"
    echo ""
else
    echo -e "${RED}Ошибка при запуске! Проверь логи:${NC}"
    docker compose logs
    exit 1
fi
