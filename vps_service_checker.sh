#!/bin/bash
# Скрипт проверки сервисов, GeoIP, Blacklist и тест скорости
# Автор: Селена (адаптировано для GitHub)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
OK="${GREEN}✔${NC}"; FAIL="${RED}✖${NC}"

# ====== Регион ======
get_generic_region() { curl -4 -s ipinfo.io/country || echo "?" ; }
get_youtube_region() { curl -4 -sI https://www.youtube.com | grep -i "x-country-code" | awk '{print $2}' | tr -d '\r' || echo "?" ; }

# ====== Проверка сервисов ======
check_netflix() { curl -4 -s --max-time 10 https://www.netflix.com > /dev/null && NETFLIX_STATUS=$OK || NETFLIX_STATUS=$FAIL; NETFLIX_REGION=$(get_generic_region); }
check_youtube() { curl -4 -s --max-time 10 https://www.youtube.com > /dev/null && YT_STATUS=$OK || YT_STATUS=$FAIL; YT_REGION=$(get_youtube_region); }
check_disney() { curl -4 -s --max-time 10 https://www.disneyplus.com > /dev/null && DS_STATUS=$OK || DS_STATUS=$FAIL; DS_REGION=$(get_generic_region); }
check_tiktok() { curl -4 -s --max-time 10 https://www.tiktok.com > /dev/null && TT_STATUS=$OK || TT_STATUS=$FAIL; TT_REGION=$(get_generic_region); }
check_spotify() { curl -4 -s --max-time 10 https://www.spotify.com > /dev/null && SP_STATUS=$OK || SP_STATUS=$FAIL; SP_REGION=$(get_generic_region); }
check_chatgpt() { curl -4 -s --max-time 10 https://chat.openai.com > /dev/null && CG_STATUS=$OK || CG_STATUS=$FAIL; CG_REGION=$(get_generic_region); }

# ====== GeoIP ======
geoip_check_inline() {
    IP=$(curl -4 -s ipinfo.io/ip)
    G1=$(curl -4 -s ipinfo.io/country); G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode)
    G3=$(curl -4 -s https://ipwho.is/ | grep '"country_code"' | cut -d '"' -f4); G4=$(curl -4 -s https://ipapi.co/country/)
    G5=$(curl -4 -s ifconfig.co/country-iso)
    G1=${G1:-"-"}; G2=${G2:-"-"}; G3=${G3:-"-"}; G4=${G4:-"-"}; G5=${G5:-"-"}
    UNIQUE=$(printf "%s\n" "$G1" "$G2" "$G3" "$G4" "$G5" | sort -u | wc -l)
    [[ "$UNIQUE" -gt 1 ]] && GEO_COLOR="${RED}"; GEO_NOTE="расхождение" || GEO_COLOR="${GREEN}"; GEO_NOTE="Чистый"
    echo -e "\n${YELLOW}==== GEOIP ====${NC}"
    echo -e "ipinfo ip-api ipwhois ipapi ifcfg"
    echo -e "${GEO_COLOR}$G1     $G2     $G3      $G4     $G5${NC}"
    echo -e "Итог: ${GEO_COLOR}$GEO_NOTE${NC}"
}

# ====== Blacklist ======
check_blacklist() {
    echo -e "\n${YELLOW}==== BLACKLIST ====${NC}"
    IP=$(curl -4 -s ipinfo.io/ip)
    REV_IP=$(echo $IP | awk -F. '{print $4"."$3"."$2"."$1}')
    SPAMHAUS=$(dig +short ${REV_IP}.zen.spamhaus.org)
    [[ -z "$SPAMHAUS" ]] && echo -e "${GREEN}Spamhaus: Чистый${NC}" || echo -e "${RED}Spamhaus: Плохой${NC}"
    SORBS=$(dig +short ${REV_IP}.dnsbl.sorbs.net)
    [[ -z "$SORBS" ]] && echo -e "${GREEN}SORBS: Чистый${NC}" || echo -e "${RED}SORBS: Плохой${NC}"
    echo -e "${YELLOW}AbuseIPDB: Неизвестно${NC}"
    echo -e "IP: $IP"
}

# ====== Вывод таблицы ======
print_results() {
    echo -e "\n${YELLOW}========== РЕЗУЛЬТАТ ПРОВЕРКИ ==========${NC}"
    printf "| %-10s | %-10s | %-6s |\n" "Сервис" "Статус" "Регион"
    printf "+------------+------------+--------+\n"
    printf "| %-10s | %-10s | %-6s |\n" "Netflix" "$NETFLIX_STATUS" "$NETFLIX_REGION"
    printf "| %-10s | %-10s | %-6s |\n" "YouTube" "$YT_STATUS" "$YT_REGION"
    printf "| %-10s | %-10s | %-6s |\n" "Disney+" "$DS_STATUS" "$DS_REGION"
    printf "| %-10s | %-10s | %-6s |\n" "TikTok" "$TT_STATUS" "$TT_REGION"
    printf "| %-10s | %-10s | %-6s |\n" "Spotify" "$SP_STATUS" "$SP_REGION"
    printf "| %-10s | %-10s | %-6s |\n" "ChatGPT" "$CG_STATUS" "$CG_REGION"
    geoip_check_inline
    check_blacklist
}

# ====== Тест скорости ======
speed_test() {
    echo -e "\n${CYAN}==== ТЕСТ СКОРОСТИ ====${NC}"
    if ! command -v speedtest-cli &> /dev/null; then
        echo "Устанавливаем speedtest-cli..."
        sudo apt update && sudo apt install -y speedtest-cli
    fi
    speedtest-cli
}

# ====== Меню ======
while true; do
    echo -e "\n${YELLOW}Выберите действие:${NC}"
    echo "1) Проверка сервисов + GeoIP + Blacklist"
    echo "2) Тест скорости"
    echo "3) Выход"
    read -p "Введите номер: " choice
    case $choice in
        1)
            check_netflix; check_youtube; check_disney; check_tiktok; check_spotify; check_chatgpt
            print_results
            ;;
        2)
            speed_test
            ;;
        3)
            echo "Выход..."
            exit 0
            ;;
        *)
            echo "Неверный выбор, попробуйте снова."
            ;;
    esac
done
