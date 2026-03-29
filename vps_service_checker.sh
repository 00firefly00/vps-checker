#!/bin/bash

# ============================================
#   🎮 ULTRA IP & STREAMING CHECKER v4.7 🎮
#   - Исправленный speedtest (latency)
#   - GEOIP: таблица при mismatch
#   - META module (Facebook/Instagram/WhatsApp/Threads)
#   - Проверка покупки подписки стримингов
#   - Формат S3 (фиксированные строки)
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

OK="✔✔✔"
BAD="✖✖✖"

TMP="/tmp/.netcheck.$$"

spinner() {
    local pid=$1
    local msg="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    tput civis 2>/dev/null

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r[%s] %s" "${spin:i:1}" "$msg"
        sleep 0.1
        ((i=(i+1)%${#spin}))
    done

    printf "\r[✔] %s\n" "$msg"
    tput cnorm 2>/dev/null
}

# ===== Базовые функции =====

get_ip() { curl -4 -s ipinfo.io/ip; }
get_asn() { curl -4 -s ipinfo.io/org; }

get_region() {
    for url in \
        "ipinfo.io/country" \
        "http://ip-api.com/line/?fields=countryCode" \
        "ifconfig.co/country-iso"
    do
        R=$(curl -4 -s --max-time 5 "$url")
        [[ -n "$R" ]] && { echo "$R"; return; }
    done
    echo "?"
}

get_ip_type() {
    local ASN="$1"
    if [[ "$ASN" =~ (Mobile|LTE|Wireless|T-Mobile|Verizon|AT&T|Vodafone|Tele2|MTS|Beeline|Megafon) ]]; then
        echo "Mobile"
    elif [[ "$ASN" =~ (Residential|Home|ISP|Telecom) ]]; then
        echo "Residential"
    elif [[ "$ASN" =~ (OVH|Hetzner|DigitalOcean|Linode|AWS|Google|Azure|Contabo|Vultr|Leaseweb|M247|Choopa|Online|Scaleway|Netcup) ]]; then
        echo "Datacenter"
    else
        echo "Unknown"
    fi
}

classify_ip() {
    local type="$1"
    local geo="$2"
    local asn="$3"

    if [[ "$type" == "Residential" ]]; then
        echo "Residential (home ISP)"
    elif [[ "$type" == "Mobile" ]]; then
        echo "Mobile (cellular network)"
    elif [[ "$type" == "Datacenter" ]]; then
        [[ "$geo" == "mismatch" ]] && echo "VPN/Proxy (datacenter, GEO mismatch)" || echo "Hosting / Datacenter"
    else
        if [[ "$asn" =~ (VPN|Proxy|Hosting|Cloud|Server) ]]; then
            echo "VPN/Proxy (hosting ASN)"
        elif [[ "$geo" == "mismatch" ]]; then
            echo "Suspicious / Mixed (GEO mismatch)"
        else
            echo "Unknown / Mixed"
        fi
    fi
}

check_service() {
    curl -4 -s --max-time 10 "$1" > /dev/null
    [[ $? -eq 0 ]] && echo "$OK" || echo "$BAD"
}

get_youtube_info() {
    PAGE=$(curl -4 -s --max-time 10 "https://www.youtube.com/premium?hl=en")
    REGION=$(echo "$PAGE" | grep -o '"GL":"[A-Z][A-Z]"' | head -1 | cut -d '"' -f4)
    [[ -z "$REGION" ]] && REGION=$(get_region)

    if echo "$PAGE" | grep -q "yt-premium-header-renderer"; then
        PREMIUM="FULL ACCESS"
    elif echo "$PAGE" | grep -q "Premium is not available"; then
        PREMIUM="NOT AVAILABLE"
    elif echo "$PAGE" | grep -q "Try it free"; then
        PREMIUM="FULL ACCESS"
    else
        PREMIUM="UNKNOWN"
    fi

    echo "$REGION|$PREMIUM"
}

check_youtube_main() {
    curl -4 -s --max-time 10 https://www.youtube.com > /dev/null
    [[ $? -eq 0 ]] && echo "AVAILABLE" || echo "BLOCKED"
}

geoip_check() {
    G1=$(curl -4 -s ipinfo.io/country)
    G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode)
    G3=$(curl -4 -s ifconfig.co/country-iso)

    [[ -z "$G1" ]] && G1="N/A"
    [[ -z "$G2" ]] && G2="N/A"
    [[ -z "$G3" ]] && G3="N/A"

    UNIQUE=$(printf "%s\n%s\n%s\n" "$G1" "$G2" "$G3" | sort -u | wc -l)
    [[ "$UNIQUE" -eq 1 ]] && STATUS="clean" || STATUS="mismatch"

    echo "$G1|$G2|$G3|$STATUS"
}

check_blacklist() {
    IP=$(get_ip)
    REV=$(echo "$IP" | awk -F. '{print $4"."$3"."$2"."$1}')

    SPAM=$(dig +short ${REV}.zen.spamhaus.org)
    SORBS=$(dig +short ${REV}.dnsbl.sorbs.net)

    [[ -z "$SPAM" ]] && SPAM="CLEAN" || SPAM="LISTED"
    [[ -z "$SORBS" ]] && SORBS="CLEAN" || SORBS="LISTED"

    echo "$SPAM|$SORBS|$IP"
}

check_subscription() {
    local url="$1"
    local page
    page=$(curl -4 -s --max-time 10 "$url")

    if [[ -z "$page" ]]; then
        echo "UNKNOWN"
        return
    fi

    if echo "$page" | grep -qiE "not available|unavailable in your region|not available in your country|unsupported location|service is not available"; then
        echo "BLOCKED"
    else
        echo "AVAILABLE"
    fi
}

# ===== Speedtest =====

run_speedtest_only() {
    clear
    echo -e "${MAGENTA}💎 SPEEDTEST MODULE 💎${NC}"
    echo "════════════════════════════════════"

    RESULT=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - 2>/dev/null)

    DL=$(echo "$RESULT" | grep "Download" | awk '{print $2" "$3}')
    UL=$(echo "$RESULT" | grep "Upload" | awk '{print $2" "$3}')
    PING=$(echo "$RESULT" | grep -oE '[0-9]+(\.[0-9]+)? ms' | head -1)

    echo "⚡ DOWNLOAD:     🚀 $DL"
    echo "⚡ UPLOAD:       🔥 $UL"
    echo "⚡ LATENCY:      🎯 $PING"
    echo
}

# ===== GEOIP вывод =====

print_geoip() {
    local G1="$1"
    local G2="$2"
    local G3="$3"
    local STATUS="$4"

    if [[ "$STATUS" == "clean" ]]; then
        echo "🛰 GEOIP:        $G1"
    else
        echo "🛰 GEOIP mismatch:"
        echo
        printf "%-15s %-10s\n" "Service" "Region"
        printf "%-15s %-10s\n" "ipinfo.io" "$G1"
        printf "%-15s %-10s\n" "ip-api.com" "$G2"
        printf "%-15s %-10s\n" "ifconfig.co" "$G3"
        echo
    fi
}

# ===== YouTube Only =====

run_youtube_only() {
    clear
    echo -e "${MAGENTA}💠 YOUTUBE MODULE 💠${NC}"
    echo "════════════════════════════════════"

    MAIN=$(check_youtube_main)
    YT_DATA=$(get_youtube_info)
    REGION=$(echo "$YT_DATA" | cut -d '|' -f1)
    PREMIUM=$(echo "$YT_DATA" | cut -d '|' -f2)

    echo "🟢 Доступность:  $MAIN"
    echo "🌍 Регион:       $REGION"
    echo "💎 Premium:      $PREMIUM"
    echo
}

# ===== Основная проверка (S3) =====

run_checks_core() {

    # IP
    echo "[IP]" > "$TMP"
    echo "$(get_ip)" >> "$TMP"
    echo "$(get_asn)" >> "$TMP"
    echo "$(get_region)" >> "$TMP"

    GEO=$(geoip_check)
    G1=$(echo "$GEO" | cut -d '|' -f1)
    G2=$(echo "$GEO" | cut -d '|' -f2)
    G3=$(echo "$GEO" | cut -d '|' -f3)
    GEO_STATUS=$(echo "$GEO" | cut -d '|' -f4)

    TYPE=$(get_ip_type "$(get_asn)")
    CLASS=$(classify_ip "$TYPE" "$GEO_STATUS" "$(get_asn)")

    echo "$TYPE" >> "$TMP"
    echo "$CLASS" >> "$TMP"
    echo "$GEO_STATUS" >> "$TMP"
    echo "$G1" >> "$TMP"
    echo "$G2" >> "$TMP"
    echo "$G3" >> "$TMP"

    # YouTube
    echo "[YOUTUBE]" >> "$TMP"
    echo "$(check_youtube_main)" >> "$TMP"
    YT_DATA=$(get_youtube_info)
    echo "$(echo "$YT_DATA" | cut -d '|' -f1)" >> "$TMP"
    echo "$(echo "$YT_DATA" | cut -d '|' -f2)" >> "$TMP"

    # Streaming
    echo "[STREAMING]" >> "$TMP"
    echo "$(check_service https://www.netflix.com)" >> "$TMP"
    echo "$(check_service https://www.hbomax.com)" >> "$TMP"
    echo "$(check_service https://www.hulu.com)" >> "$TMP"
    echo "$(check_service https://www.primevideo.com)" >> "$TMP"
    echo "$(check_service https://www.paramountplus.com)" >> "$TMP"
    echo "$(check_service https://tv.apple.com)" >> "$TMP"
    echo "$(check_service https://www.crunchyroll.com)" >> "$TMP"

    # Streaming subscriptions
    echo "[STREAMING_SUB]" >> "$TMP"
    echo "$(check_subscription https://www.netflix.com/signup)" >> "$TMP"
    echo "$(check_subscription https://www.hbomax.com/subscribe)" >> "$TMP"
    echo "$(check_subscription https://signup.hulu.com/plans)" >> "$TMP"
    echo "$(check_subscription https://www.primevideo.com/signup)" >> "$TMP"
    echo "$(check_subscription https://www.paramountplus.com/account/signup/)" >> "$TMP"
    echo "$(check_subscription https://tv.apple.com/subscribe)" >> "$TMP"
    echo "$(check_subscription https://www.crunchyroll.com/premium)" >> "$TMP"

    # Gaming
    echo "[GAMING]" >> "$TMP"
    echo "$(check_service https://store.steampowered.com)" >> "$TMP"
    echo "$(check_service https://store.epicgames.com)" >> "$TMP"
    echo "$(check_service https://store.playstation.com)" >> "$TMP"
    echo "$(check_service https://www.xbox.com)" >> "$TMP"
    echo "$(check_service https://battle.net)" >> "$TMP"
    echo "$(check_service https://socialclub.rockstargames.com)" >> "$TMP"

    # Social (META + others)
    echo "[SOCIAL]" >> "$TMP"
    echo "$(check_service https://www.facebook.com)" >> "$TMP"
    echo "$(check_service https://www.messenger.com)" >> "$TMP"
    echo "$(check_service https://www.instagram.com)" >> "$TMP"
    echo "$(check_service https://www.threads.net)" >> "$TMP"
    echo "$(check_service https://web.whatsapp.com)" >> "$TMP"
    echo "$(check_service https://business.facebook.com)" >> "$TMP"
    echo "$(check_service https://x.com)" >> "$TMP"
    echo "$(check_service https://www.reddit.com)" >> "$TMP"
    echo "$(check_service https://web.telegram.org)" >> "$TMP"

    # Stores
    echo "[STORES]" >> "$TMP"
    echo "$(check_service https://www.amazon.com)" >> "$TMP"
    echo "$(check_service https://www.ebay.com)" >> "$TMP"
    echo "$(check_service https://www.aliexpress.com)" >> "$TMP"

    # Blacklist
    echo "[BLACKLIST]" >> "$TMP"
    BL=$(check_blacklist)
    echo "$(echo "$BL" | cut -d '|' -f1)" >> "$TMP"
    echo "$(echo "$BL" | cut -d '|' -f2)" >> "$TMP"
    echo "$(echo "$BL" | cut -d '|' -f3)" >> "$TMP"
}

# ===== Обёртка с анимацией =====

run_checks() {
    run_checks_core &
    pid=$!

    steps=(
        "Проверка IP..."
        "Проверка YouTube..."
        "Проверка стримингов..."
        "Проверка подписок..."
        "Проверка игровых сервисов..."
        "Проверка соцсетей..."
        "Проверка магазинов..."
        "Проверка blacklist..."
    )

    i=0
    while kill -0 "$pid" 2>/dev/null; do
        spinner "$pid" "${steps[i]}"
        ((i=(i+1)%${#steps[@]}))
    done

    wait "$pid"
    clear

    # Чтение IP блока
    IP=$(sed -n '2p' "$TMP")
    ASN=$(sed -n '3p' "$TMP")
    REGION=$(sed -n '4p' "$TMP")
    TYPE=$(sed -n '5p' "$TMP")
    CLASS=$(sed -n '6p' "$TMP")
    GEO_STATUS=$(sed -n '7p' "$TMP")
    G1=$(sed -n '8p' "$TMP")
    G2=$(sed -n '9p' "$TMP")
    G3=$(sed -n '10p' "$TMP")

    # YouTube
    YT_MAIN=$(sed -n '12p' "$TMP")
    YT_REGION=$(sed -n '13p' "$TMP")
    YT_PREMIUM=$(sed -n '14p' "$TMP")

    # Streaming
    STREAM=($(sed -n '16,22p' "$TMP"))

    # Streaming subscriptions
    STREAM_SUB=($(sed -n '24,30p' "$TMP"))

    # Gaming
    GAME=($(sed -n '32,37p' "$TMP"))

    # Social
    SOCIAL=($(sed -n '39,47p' "$TMP"))

    # Stores
    STORES=($(sed -n '49,51p' "$TMP"))

    # Blacklist
    BL_SPAM=$(sed -n '53p' "$TMP")
    BL_SORBS=$(sed -n '54p' "$TMP")
    BL_IP=$(sed -n '55p' "$TMP")

    rm -f "$TMP"

    echo -e "${MAGENTA}✧✧ SYSTEM SCAN COMPLETE ✧✧${NC}"
    echo

    echo -e "${CYAN}✧ IP INFORMATION ✧${NC}"
    echo "Тип IP:          $TYPE"
    echo "Класс IP:        $CLASS"
    echo "ASN:             $ASN"
    echo "Регион:          $REGION"
    print_geoip "$G1" "$G2" "$G3" "$GEO_STATUS"

    echo -e "${MAGENTA}✧ YOUTUBE MODULE ✧${NC}"
    echo "Доступность:     $YT_MAIN"
    echo "Регион:          $YT_REGION"
    echo "Premium:         $YT_PREMIUM"
    echo

    echo -e "${CYAN}✧ STREAMING MODULE ✧${NC}"
    echo "🎬 Netflix:      ${STREAM[0]}"
    echo "📺 HBO Max:      ${STREAM[1]}"
    echo "📺 Hulu:         ${STREAM[2]}"
    echo "🎥 Prime Video:  ${STREAM[3]}"
    echo "📺 Paramount+:   ${STREAM[4]}"
    echo "🍏 Apple TV+:    ${STREAM[5]}"
    echo "🌀 Crunchyroll:  ${STREAM[6]}"
    echo

    echo -e "${CYAN}✧ STREAMING SUBSCRIPTIONS ✧${NC}"
    echo "🎬 Netflix:      ${STREAM_SUB[0]}"
    echo "📺 HBO Max:      ${STREAM_SUB[1]}"
    echo "📺 Hulu:         ${STREAM_SUB[2]}"
    echo "🎥 Prime Video:  ${STREAM_SUB[3]}"
    echo "📺 Paramount+:   ${STREAM_SUB[4]}"
    echo "🍏 Apple TV+:    ${STREAM_SUB[5]}"
    echo "🌀 Crunchyroll:  ${STREAM_SUB[6]}"
    echo

    echo -e "${CYAN}✧ META MODULE ✧${NC}"
    echo "📘 Facebook:     ${SOCIAL[0]}"
    echo "💬 Messenger:    ${SOCIAL[1]}"
    echo "📸 Instagram:    ${SOCIAL[2]}"
    echo "🧵 Threads:      ${SOCIAL[3]}"
    echo "📱 WhatsApp Web: ${SOCIAL[4]}"
    echo "📊 Meta Business:${SOCIAL[5]}"
    echo

    echo -e "${CYAN}✧ SOCIAL MODULE ✧${NC}"
    echo "🐦 Twitter/X:    ${SOCIAL[6]}"
    echo "👽 Reddit:       ${SOCIAL[7]}"
    echo "✈ Telegram:     ${SOCIAL[8]}"
    echo

    echo -e "${CYAN}✧ STORES MODULE ✧${NC}"
    echo "🛒 Amazon:       ${STORES[0]}"
    echo "🛒 eBay:         ${STORES[1]}"
    echo "🛒 AliExpress:   ${STORES[2]}"
    echo

    echo -e "${CYAN}✧ BLACKLIST STATUS ✧${NC}"
    echo "🛡 Spamhaus:     $BL_SPAM"
    echo "🛡 SORBS:        $BL_SORBS"
    echo "🌐 IP:           $BL_IP"
    echo
}

# ===== Меню =====

while true; do
    echo -e "${YELLOW}Выберите действие:${NC}"
    echo "1) Запустить полную проверку"
    echo "2) Запустить тест скорости"
    echo "3) Проверить только YouTube"
    echo "4) Выход"
    read -p "> " CH

    case $CH in
        1) run_checks ;;
        2) run_speedtest_only ;;
        3) run_youtube_only ;;
        4) exit 0 ;;
        *) echo "Неверный выбор" ;;
    esac
done
