#!/bin/bash

# ============================================
#   🎮 ULTRA IP & STREAMING CHECKER v3.1 🎮
#  
#   
# ============================================

# ===== Цвета =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

OK="✔✔✔"
BAD="✖✖✖"

# ===== Кэш =====
IP_CACHE=""
ASN_CACHE=""
REGION_CACHE=""

# ===== БАЗА =====
get_ip() {
    [[ -n "$IP_CACHE" ]] && { echo "$IP_CACHE"; return; }
    IP_CACHE=$(curl -4 -s ipinfo.io/ip)
    echo "$IP_CACHE"
}

get_asn() {
    [[ -n "$ASN_CACHE" ]] && { echo "$ASN_CACHE"; return; }
    ASN_CACHE=$(curl -4 -s ipinfo.io/org)
    echo "$ASN_CACHE"
}

get_region() {
    [[ -n "$REGION_CACHE" ]] && { echo "$REGION_CACHE"; return; }

    for url in \
        "ipinfo.io/country" \
        "http://ip-api.com/line/?fields=countryCode" \
        "ifconfig.co/country-iso"
    do
        R=$(curl -4 -s --max-time 5 "$url")
        [[ -n "$R" ]] && { REGION_CACHE="$R"; echo "$R"; return; }
    done

    REGION_CACHE="?"
    echo "?"
}

# ===== Тип IP =====
get_ip_type() {
    ASN=$(get_asn)

    if [[ "$ASN" =~ (Mobile|LTE|Wireless|T-Mobile|Verizon|AT&T|Vodafone|Tele2|MTS|Beeline|Megafon) ]]; then
        echo "Mobile"
    elif [[ "$ASN" =~ (Residential|Home|ISP|Telecom) ]]; then
        echo "Residential"
    elif [[ "$ASN" =~ (OVH|Hetzner|DigitalOcean|Linode|AWS|Google|Azure|Contabo|Vultr) ]]; then
        echo "Datacenter"
    else
        echo "Unknown"
    fi
}

# ===== Проверка доступности =====
check_service() {
    curl -4 -s --max-time 10 "$1" > /dev/null
    [[ $? -eq 0 ]] && echo "$OK" || echo "$BAD"
}

# ===== YouTube Premium =====
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

# ===== GEOIP =====
geoip_check() {
    G1=$(curl -4 -s ipinfo.io/country)
    G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode)
    G3=$(curl -4 -s ifconfig.co/country-iso)

    [[ -z "$G1" ]] && G1="N/A"
    [[ -z "$G2" ]] && G2="N/A"
    [[ -z "$G3" ]] && G3="N/A"

    UNIQUE=$(printf "%s\n%s\n%s\n" "$G1" "$G2" "$G3" | sort -u | wc -l)

    if [[ "$UNIQUE" -eq 1 ]]; then
        GEO_STATUS="clean"
    else
        GEO_STATUS="mismatch"
    fi

    echo "$G1|$G2|$G3|$GEO_STATUS"
}

# ===== Blacklist =====
check_blacklist() {
    IP=$(get_ip)
    REV=$(echo "$IP" | awk -F. '{print $4"."$3"."$2"."$1}')

    SPAM=$(dig +short ${REV}.zen.spamhaus.org)
    SORBS=$(dig +short ${REV}.dnsbl.sorbs.net)

    [[ -z "$SPAM" ]] && SPAM="CLEAN" || SPAM="LISTED"
    [[ -z "$SORBS" ]] && SORBS="CLEAN" || SORBS="LISTED"

    echo "$SPAM|$SORBS|$IP"
}

# ===== Speedtest =====
run_speedtest() {
    RESULT=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - 2>/dev/null)
    DL=$(echo "$RESULT" | grep "Download" | awk '{print $2" "$3}')
    UL=$(echo "$RESULT" | grep "Upload" | awk '{print $2" "$3}')
    PING=$(echo "$RESULT" | grep "Hosted" | awk '{print $6" ms"}')
    echo "$DL|$UL|$PING"
}

run_speedtest_only() {
    SPEED=$(run_speedtest)
    DL=$(echo "$SPEED" | cut -d '|' -f1)
    UL=$(echo "$SPEED" | cut -d '|' -f2)
    PING=$(echo "$SPEED" | cut -d '|' -f3)

    clear
    echo -e "${MAGENTA}💎 NETWORK PERFORMANCE 💎${NC}"
    echo "════════════════════════════════════"
    echo "⚡ DOWNLOAD:     🚀 $DL"
    echo "⚡ UPLOAD:       🔥 $UL"
    echo "⚡ LATENCY:      🎯 $PING"
    echo
}

# ===== YouTube Only =====
run_youtube_only() {
    YT_MAIN=$(check_youtube_main)
    YT_DATA=$(get_youtube_info)
    YT_REGION=$(echo "$YT_DATA" | cut -d '|' -f1)
    YT_PREMIUM=$(echo "$YT_DATA" | cut -d '|' -f2)

    clear
    echo -e "${MAGENTA}💠 YOUTUBE MODULE 💠${NC}"
    echo "════════════════════════════════════"
    echo "🟢 Доступность:  $YT_MAIN"
    echo "🌍 Регион:       $YT_REGION"
    echo "💎 Premium:      $YT_PREMIUM"
    echo
}

# ===== Основная проверка =====
run_checks() {

    # STREAMING
    NF_STATUS=$(check_service "https://www.netflix.com")
    HBO_STATUS=$(check_service "https://www.hbomax.com")
    HULU_STATUS=$(check_service "https://www.hulu.com")
    PRIME_STATUS=$(check_service "https://www.primevideo.com")
    PARAMOUNT_STATUS=$(check_service "https://www.paramountplus.com")
    APPLE_STATUS=$(check_service "https://tv.apple.com")
    CRUNCH_STATUS=$(check_service "https://www.crunchyroll.com")

    # GAMING
    STEAM_STATUS=$(check_service "https://store.steampowered.com")
    EPIC_STATUS=$(check_service "https://store.epicgames.com")
    PSN_STATUS=$(check_service "https://store.playstation.com")
    XBOX_STATUS=$(check_service "https://www.xbox.com")
    BLIZZ_STATUS=$(check_service "https://battle.net")
    ROCKSTAR_STATUS=$(check_service "https://socialclub.rockstargames.com")

    # SOCIAL
    IG_STATUS=$(check_service "https://www.instagram.com")
    X_STATUS=$(check_service "https://x.com")
    WA_STATUS=$(check_service "https://web.whatsapp.com")
    REDDIT_STATUS=$(check_service "https://www.reddit.com")
    TG_STATUS=$(check_service "https://web.telegram.org")

    # STORES
    AMAZON_STATUS=$(check_service "https://www.amazon.com")
    EBAY_STATUS=$(check_service "https://www.ebay.com")
    ALI_STATUS=$(check_service "https://www.aliexpress.com")

    # YouTube
    YT_MAIN=$(check_youtube_main)
    YT_DATA=$(get_youtube_info)
    YT_REGION=$(echo "$YT_DATA" | cut -d '|' -f1)
    YT_PREMIUM=$(echo "$YT_DATA" | cut -d '|' -f2)

    # GEOIP
    GEO=$(geoip_check)
    GEO_STATUS=$(echo "$GEO" | cut -d '|' -f4)

    # Blacklist
    BL=$(check_blacklist)
    BL_SPAM=$(echo "$BL" | cut -d '|' -f1)
    BL_SORBS=$(echo "$BL" | cut -d '|' -f2)
    BL_IP=$(echo "$BL" | cut -d '|' -f3)

    # Speedtest
    SPEED=$(run_speedtest)
    DL=$(echo "$SPEED" | cut -d '|' -f1)
    UL=$(echo "$SPEED" | cut -d '|' -f2)
    PING=$(echo "$SPEED" | cut -d '|' -f3)

    IP_TYPE=$(get_ip_type)
    ASN=$(get_asn)
    MAIN_REGION=$(get_region)

    clear

    echo -e "${MAGENTA}💠💠💠 SYSTEM SCAN COMPLETE 💠💠💠${NC}"
    echo "════════════════════════════════════"
    echo

    echo -e "${CYAN}💠 IP INFORMATION 💠${NC}"
    echo "════════════════════════════════════"
    echo "🌐 Тип IP:       $IP_TYPE"
    echo "🏢 ASN:          $ASN"
    echo "📌 Регион:       $MAIN_REGION"
    echo "🛰 GEOIP:        $GEO_STATUS"
    echo

    echo -e "${MAGENTA}💠 YOUTUBE MODULE 💠${NC}"
    echo "════════════════════════════════════"
    echo "🟢 Доступность:  $YT_MAIN"
    echo "🌍 Регион:       $YT_REGION"
    echo "💎 Premium:      $YT_PREMIUM"
    echo

    echo -e "${MAGENTA}💎 NETWORK PERFORMANCE 💎${NC}"
    echo "════════════════════════════════════"
    echo "⚡ DOWNLOAD:     🚀 $DL"
    echo "⚡ UPLOAD:       🔥 $UL"
    echo "⚡ LATENCY:      🎯 $PING"
    echo

    echo -e "${CYAN}💠 STREAMING MODULE 💠${NC}"
    echo "════════════════════════════════════"
    echo "🎬 Netflix:      $NF_STATUS"
    echo "📺 HBO Max:      $HBO_STATUS"
    echo "📺 Hulu:         $HULU_STATUS"
    echo "🎥 Prime Video:  $PRIME_STATUS"
    echo "📺 Paramount+:   $PARAMOUNT_STATUS"
    echo "🍏 Apple TV+:    $APPLE_STATUS"
    echo "🌀 Crunchyroll:  $CRUNCH_STATUS"
    echo

    echo -e "${CYAN}💠 GAMING MODULE 💠${NC}"
    echo "════════════════════════════════════"
    echo "🎮 Steam:        $STEAM_STATUS"
    echo "🎮 Epic Games:   $EPIC_STATUS"
    echo "🎮 PSN:          $PSN_STATUS"
    echo "🎮 Xbox:         $XBOX_STATUS"
    echo "🎮 Battle.net:   $BLIZZ_STATUS"
    echo "🎮 Rockstar:     $ROCKSTAR_STATUS"
    echo

    echo -e "${CYAN}💠 SOCIAL MODULE 💠${NC}"
    echo "════════════════════════════════════"
    echo "📸 Instagram:    $IG_STATUS"
    echo "🐦 Twitter/X:    $X_STATUS"
    echo "📱 WhatsApp:     $WA_STATUS"
    echo "👽 Reddit:       $REDDIT_STATUS"
    echo "✈ Telegram:     $TG_STATUS"
    echo

    echo -e "${CYAN}💠 STORES MODULE 💠${NC}"
    echo "════════════════════════════════════"
    echo "🛒 Amazon:       $AMAZON_STATUS"
    echo "🛒 eBay:         $EBAY_STATUS"
    echo "🛒 AliExpress:   $ALI_STATUS"
    echo

    echo -e "${CYAN}💠 BLACKLIST STATUS 💠${NC}"
    echo "════════════════════════════════════"
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
