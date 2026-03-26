#!/bin/bash

# ====== Цвета ======
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

OK="${GREEN}✔${NC}"
FAIL="${RED}✖${NC}"

# ====== Базовые функции ======
get_ip() { curl -4 -s ipinfo.io/ip; }
get_generic_region() { curl -4 -s ipinfo.io/country || echo "?"; }

# ====== YouTube регион (УЛУЧШЕННЫЙ) ======
get_youtube_region() {
    PAGE=$(curl -4 -s --max-time 10 https://www.youtube.com/premium)

    # ищем страну в HTML (ytcfg)
    REGION=$(echo "$PAGE" | grep -o '"GL":"[A-Z][A-Z]"' | head -1 | cut -d '"' -f4)

    # fallback через заголовок
    if [[ -z "$REGION" ]]; then
        REGION=$(curl -4 -sI https://www.youtube.com | grep -i "x-country-code" | awk '{print $2}' | tr -d '\r')
    fi

    # fallback через IP
    if [[ -z "$REGION" ]]; then
        REGION=$(get_generic_region)
    fi

    echo "${REGION:-?}"
}

# ====== Проверка сервисов ======
check_netflix() {
    curl -4 -s --max-time 10 https://www.netflix.com > /dev/null
    [[ $? -eq 0 ]] && NETFLIX_STATUS=$OK || NETFLIX_STATUS=$FAIL
    NETFLIX_REGION=$(get_generic_region)
}

check_youtube() {
    PAGE=$(curl -4 -s --max-time 10 https://www.youtube.com/premium)

    if [[ "$PAGE" == *"Premium is not available"* ]]; then
        YT_STATUS=$FAIL
    else
        YT_STATUS=$OK
    fi

    YT_REGION=$(get_youtube_region)
}

check_disney() {
    curl -4 -s --max-time 10 https://www.disneyplus.com > /dev/null
    [[ $? -eq 0 ]] && DS_STATUS=$OK || DS_STATUS=$FAIL
    DS_REGION=$(get_generic_region)
}

check_tiktok() {
    curl -4 -s --max-time 10 https://www.tiktok.com > /dev/null
    [[ $? -eq 0 ]] && TT_STATUS=$OK || TT_STATUS=$FAIL
    TT_REGION=$(get_generic_region)
}

check_spotify() {
    curl -4 -s --max-time 10 https://www.spotify.com > /dev/null
    [[ $? -eq 0 ]] && SP_STATUS=$OK || SP_STATUS=$FAIL
    SP_REGION=$(get_generic_region)
}

check_chatgpt() {
    curl -4 -s --max-time 10 https://chat.openai.com > /dev/null
    [[ $? -eq 0 ]] && CG_STATUS=$OK || CG_STATUS=$FAIL
    CG_REGION=$(get_generic_region)
}

# ====== GeoIP ======
geoip_check_inline() {
    IP=$(get_ip)

    G1=$(curl -4 -s ipinfo.io/country)
    G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode)
    G3=$(curl -4 -s https://ipwho.is/ | grep '"country_code":' | cut -d '"' -f4)
    G4=$(curl -4 -s https://ipapi.co/country/)
    G5=$(curl -4 -s ifconfig.co/country-iso)

    # защита от мусора
    [[ -z "$G3" || "$G3" == "null" ]] && G3="-"

    G1=${G1:-"-"}; G2=${G2:-"-"}; G4=${G4:-"-"}; G5=${G5:-"-"}

    UNIQUE=$(printf "%s\n" "$G1" "$G2" "$G3" "$G4" "$G5" | sort -u | wc -l)

    if [[ "$UNIQUE" -gt 1 ]]; then
        COLOR="$RED"; NOTE="расхождение"
    else
        COLOR="$GREEN"; NOTE="Чистый"
    fi

    echo -e "\n${YELLOW}==== GEOIP ====${NC}"
    printf "%-7s %-7s %-7s %-7s %-7s\n" "ipinfo" "ip-api" "whois2" "ipapi" "ifcfg"
    printf "${COLOR}%-7s %-7s %-7s %-7s %-7s${NC}\n" "$G1" "$G2" "$G3" "$G4" "$G5"
    echo -e "Итог: ${COLOR}${NOTE}${NC}"
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
    echo -e "\n${YELLOW}========== РЕЗУЛЬТАТ ПРОВЕРКИ ==========${NC}"
    printf "| %-10s | %-10s | %-6s |\n" "Сервис" "Статус" "Регион"
    printf "+------------+------------+--------+\n"

    printf "| %-10s | %b | %-6s |\n" "Netflix" "$NETFLIX_STATUS" "$NETFLIX_REGION"
    printf "| %-10s | %b | %-6s |\n" "YouTube" "$YT_STATUS" "$YT_REGION"
    printf "| %-10s | %b | %-6s |\n" "Disney+" "$DS_STATUS" "$DS_REGION"
    printf "| %-10s | %b | %-6s |\n" "TikTok" "$TT_STATUS" "$TT_REGION"
    printf "| %-10s | %b | %-6s |\n" "Spotify" "$SP_STATUS" "$SP_REGION"
    printf "| %-10s | %b | %-6s |\n" "ChatGPT" "$CG_STATUS" "$CG_REGION"

    geoip_check_inline
    check_blacklist
}

# ====== Speedtest ======
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
            check_netflix
            check_youtube
            check_disney
            check_tiktok
            check_spotify
            check_chatgpt
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
