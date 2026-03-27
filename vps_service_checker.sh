#!/bin/bash

# ====== Цвета ======
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

OK="${GREEN}✔${NC}"
FAIL="${RED}✖${NC}"

# ====== База ======
get_ip() { curl -4 -s ipinfo.io/ip; }
get_region() { curl -4 -s ipinfo.io/country || echo "?"; }
get_asn() { curl -4 -s ipinfo.io/org || echo "Unknown"; }

# ====== YouTube ======
get_youtube_info() {
    PAGE=$(curl -4 -s --max-time 10 https://www.youtube.com/premium)

    REGION=$(echo "$PAGE" | grep -o '"GL":"[A-Z][A-Z]"' | head -1 | cut -d '"' -f4)

    if [[ "$PAGE" == *"Premium is not available"* ]]; then
        PREMIUM="нет"
    else
        PREMIUM="да"
    fi

    [[ -z "$REGION" ]] && REGION=$(get_region)

    echo "$REGION|$PREMIUM"
}

# ====== Проверка ======
check_service() {
    curl -4 -s --max-time 10 "$1" > /dev/null
    [[ $? -eq 0 ]] && echo "$OK" || echo "$FAIL"
}

# ====== Сервисы ======
check_netflix() { NETFLIX_STATUS=$(check_service "https://www.netflix.com"); NETFLIX_REGION=$(get_region); }

check_youtube() {
    YT_STATUS=$(check_service "https://www.youtube.com")
    DATA=$(get_youtube_info)
    YT_REGION=$(echo $DATA | cut -d '|' -f1)
    YT_PREMIUM=$(echo $DATA | cut -d '|' -f2)
}

check_disney() { DS_STATUS=$(check_service "https://www.disneyplus.com"); DS_REGION=$(get_region); }
check_tiktok() { TT_STATUS=$(check_service "https://www.tiktok.com"); TT_REGION=$(get_region); }
check_spotify() { SP_STATUS=$(check_service "https://www.spotify.com"); SP_REGION=$(get_region); }
check_chatgpt() { CG_STATUS=$(check_service "https://chat.openai.com"); CG_REGION=$(get_region); }
check_meta() { META_STATUS=$(check_service "https://www.facebook.com"); META_REGION=$(get_region); }

# Microsoft только страна
check_microsoft() { MS_REGION=$(get_region); }

# ====== GeoIP ======
geoip_check_inline() {
    G1=$(curl -4 -s ipinfo.io/country)
    G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode)
    G3=$(curl -4 -s https://ipapi.co/country/)
    G4=$(curl -4 -s ifconfig.co/country-iso)
    G5=$(curl -4 -s https://api.2ip.io/geo.json | grep '"country_code"' | cut -d '"' -f4)

    [[ -z "$G5" || "$G5" == *"<"* ]] && G5="-"

    UNIQUE=$(printf "%s\n" "$G1" "$G2" "$G3" "$G4" "$G5" | sort -u | wc -l)

    if [[ "$UNIQUE" -gt 1 ]]; then
        COLOR="$RED"; NOTE="расхождение"
    else
        COLOR="$GREEN"; NOTE="Чистый"
    fi

    echo -e "\n${YELLOW}==== GEOIP ====${NC}"
    printf "%-6s %-6s %-6s %-6s %-6s\n" "ipinfo" "ip-api" "ipapi" "ifcfg" "2ip"
    printf "${COLOR}%-6s %-6s %-6s %-6s %-6s${NC}\n" "$G1" "$G2" "$G3" "$G4" "$G5"
    echo -e "Итог: ${COLOR}${NOTE}${NC}"

    MAIN_REGION="$G1"
}

# ====== Оценка IP ======
ip_summary() {
    echo -e "\n${CYAN}==== ОЦЕНКА IP ====${NC}"

    case "$MAIN_REGION" in
        RU|BY|IR|CN)
            echo -e "${RED}IP: $MAIN_REGION (ограниченный)${NC}"
            ;;
        *)
            echo -e "${GREEN}IP: $MAIN_REGION (хороший)${NC}"
            ;;
    esac
}

# ====== Blacklist ======
check_blacklist() {
    echo -e "\n${YELLOW}==== BLACKLIST ====${NC}"
    IP=$(get_ip)
    REV_IP=$(echo $IP | awk -F. '{print $4"."$3"."$2"."$1}')

    SPAMHAUS=$(dig +short ${REV_IP}.zen.spamhaus.org)
    [[ -z "$SPAMHAUS" ]] && echo -e "${GREEN}Spamhaus: Чистый${NC}" || echo -e "${RED}Spamhaus: Плохой${NC}"

    SORBS=$(dig +short ${REV_IP}.dnsbl.sorbs.net)
    [[ -z "$SORBS" ]] && echo -e "${GREEN}SORBS: Чистый${NC}" || echo -e "${RED}SORBS: Плохой${NC}"

    echo -e "${YELLOW}AbuseIPDB: Неизвестно${NC}"
    echo -e "IP: $IP"
}

# ====== Таблица ======
print_results() {
    echo -e "\n${YELLOW}========== РЕЗУЛЬТАТ ==========${NC}"
    printf "| %-10s | %-10s | %-8s |\n" "Сервис" "Статус" "Регион"
    printf "+------------+------------+----------+\n"

    printf "| %-10s | %b | %-8s |\n" "Netflix" "$NETFLIX_STATUS" "$NETFLIX_REGION"
    printf "| %-10s | %b | %-8s |\n" "YouTube" "$YT_STATUS" "$YT_REGION"
    printf "| %-10s | %-10s | %-8s |\n" "Premium" "$YT_PREMIUM" ""
    printf "| %-10s | %b | %-8s |\n" "Disney+" "$DS_STATUS" "$DS_REGION"
    printf "| %-10s | %b | %-8s |\n" "TikTok" "$TT_STATUS" "$TT_REGION"
    printf "| %-10s | %b | %-8s |\n" "Spotify" "$SP_STATUS" "$SP_REGION"
    printf "| %-10s | %b | %-8s |\n" "ChatGPT" "$CG_STATUS" "$CG_REGION"
    printf "| %-10s | %b | %-8s |\n" "Meta" "$META_STATUS" "$META_REGION"
    printf "| %-10s | %-10s | %-8s |\n" "Microsoft" "" "$MS_REGION"

    geoip_check_inline
    ip_summary

    echo -e "\n${CYAN}==== ASN ====${NC}"
    echo -e "${YELLOW}$(get_asn)${NC}"

    check_blacklist
}

# ====== Speedtest ======
speed_test() {
    echo -e "\n${CYAN}==== ТЕСТ СКОРОСТИ ====${NC}"

    if ! command -v speedtest-cli &> /dev/null; then
        sudo apt update && sudo apt install -y speedtest-cli
    fi

    echo "Проверка скорости..."

    RESULT=$(speedtest-cli --simple 2>/dev/null)

    PING=$(echo "$RESULT" | grep "Ping" | awk '{print $2" "$3}')
    DOWN=$(echo "$RESULT" | grep "Download" | awk '{print $2" "$3}')
    UP=$(echo "$RESULT" | grep "Upload" | awk '{print $2" "$3}')

    echo -e "\n${YELLOW}Ping: $PING${NC}"
    echo -e "${YELLOW}Download: $DOWN${NC}"
    echo -e "${YELLOW}Upload: $UP${NC}"
}

# ====== Меню ======
while true; do
    echo -e "\n${YELLOW}Выберите действие:${NC}"
    echo "1) Проверка сервисов"
    echo "2) Тест скорости"
    echo "3) Выход"

    read -p "Введите номер: " choice

    case $choice in
        1)
            check_netflix
            check_youtube
            check_disney
            check_tiktok
            check_spotify
            check_chatgpt
            check_meta
            check_microsoft
            print_results
            ;;
        2)
            speed_test
            ;;
        3)
            exit 0
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
done
