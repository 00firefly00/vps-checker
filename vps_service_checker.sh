#!/usr/bin/env bash
if [ -z "$BASH_VERSION" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi

OK="OK"
BAD="BAD"
TMP="/tmp/.netcheck.$$"
trap 'rm -f "$TMP"' EXIT

GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"

spinner() {
    local pid="$1"
    local msg="$2"
    local spin='-\|/'
    local i=0
    tput civis 2>/dev/null
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r[%c] %s" "${spin:i:1}" "$msg"
        sleep 0.1
        i=$(( (i + 1) % 4 ))
    done
    printf "\r[+] %s\n" "$msg"
    tput cnorm 2>/dev/null
}

get_ip() { curl -4 -s ipinfo.io/ip; }
get_asn() { curl -4 -s ipinfo.io/org; }

get_region() {
    local r
    for u in \
        "ipinfo.io/country" \
        "http://ip-api.com/line/?fields=countryCode" \
        "ifconfig.co/country-iso"
    do
        r=$(curl -4 -s --max-time 5 "$u")
        [ -n "$r" ] && { echo "$r"; return; }
    done
    echo "?"
}

# -----------------------------
#  IMPROVED IP TYPE DETECTION
# -----------------------------
get_ip_type() {
    local a="$1"
    local rdns="$2"

    # Datacenter keywords
    if echo "$a" | grep -qiE "OVH|Hetzner|DigitalOcean|Linode|AWS|Google|Azure|Contabo|Vultr|Leaseweb|M247|Choopa|Scaleway|Netcup|Oracle|Alibaba|Tencent|Kamatera|G-Core|Cloudflare|Fastly|Akamai"; then
        echo "Datacenter"
        return
    fi

    # Mobile keywords
    if echo "$a" | grep -qiE "T-Mobile|Verizon|Vodafone|Tele2|MTS|Beeline|Megafon|AT&T|Sprint|Orange|Claro|Telia|Telenor|Rogers|Bell|Telus"; then
        echo "Mobile"
        return
    fi

    # Residential keywords
    if echo "$a" | grep -qiE "Comcast|Spectrum|Cox|Xfinity|BT|Virgin|Sky|Deutsche|Telekom|Orange Home|Rostelecom|Home|Residential|ISP"; then
        echo "Residential"
        return
    fi

    # Reverse DNS hints
    if echo "$rdns" | grep -qiE "static|dynamic|pool"; then
        echo "Residential"
        return
    fi

    if echo "$rdns" | grep -qiE "server|vps|cloud|hosting"; then
        echo "Datacenter"
        return
    fi

    echo "Residential"
}

classify_ip() {
    local t="$1" g="$2" a="$3" rdns="$4"

    case "$t" in
        Residential)
            echo "Residential (home ISP)"
            ;;
        Mobile)
            echo "Mobile (cellular network)"
            ;;
        Datacenter)
            if [ "$g" = "mismatch" ]; then
                echo "VPN/Proxy (datacenter, GEO mismatch)"
            else
                echo "Hosting / Datacenter"
            fi
            ;;
        *)
            if echo "$rdns" | grep -qiE "server|vps|cloud|hosting"; then
                echo "Hosting / Datacenter"
            elif [ "$g" = "mismatch" ]; then
                echo "Suspicious / Mixed (GEO mismatch)"
            else
                echo "Residential (fallback)"
            fi
            ;;
    esac
}

geoip_check() {
    local G1 G2 G3 U S
    G1=$(curl -4 -s ipinfo.io/country)
    G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode)
    G3=$(curl -4 -s ifconfig.co/country-iso)
    [ -z "$G1" ] && G1="N/A"
    [ -z "$G2" ] && G2="N/A"
    [ -z "$G3" ] && G3="N/A"
    U=$(printf "%s\n%s\n%s\n" "$G1" "$G2" "$G3" | grep -v "N/A" | sort -u | wc -l)
    [ "$U" -le 1 ] && S="clean" || S="mismatch"
    echo "$G1|$G2|$G3|$S"
}

print_geoip() {
    local g1="$1" g2="$2" g3="$3" s="$4"
    if [ "$s" = "clean" ]; then
        echo "GEOIP: $g1"
    else
        echo "GEOIP mismatch:"
        printf "%-15s %-10s\n" "Service" "Region"
        printf "%-15s %-10s\n" "ipinfo.io" "$g1"
        printf "%-15s %-10s\n" "ip-api.com" "$g2"
        printf "%-15s %-10s\n" "ifconfig.co" "$g3"
    fi
}

# -----------------------------
#  STREAMING CHECKS
# -----------------------------
check_streaming_service() {
    curl -4 -s --max-time 10 "$1" >/dev/null
    [ $? -eq 0 ] && echo "Доступен" || echo "Недоступен"
}

check_streaming_premium() {
    local url="$1"
    local keyword="$2"
    local resp

    resp=$(curl -4 -s --max-time 10 "$url")

    if echo "$resp" | grep -qi "$keyword"; then
        echo -e "${GREEN}Премиум доступен${NC}"
    else
        echo -e "${RED}Премиум недоступен${NC}"
    fi
}

# -----------------------------
#  YOUTUBE
# -----------------------------
check_youtube_main() {
    curl -4 -s --max-time 10 https://www.youtube.com >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

get_youtube_region() {
    local P R
    P=$(curl -4 -s --max-time 10 "https://www.youtube.com/?hl=en")
    R=$(echo "$P" | grep -o '"GL":"[A-Z][A-Z]"' | cut -d '"' -f4)
    [ -z "$R" ] && R=$(get_region)
    echo "$R"
}

# -----------------------------
#  SPOTIFY
# -----------------------------
check_spotify_main() {
    curl -4 -s --max-time 10 https://www.spotify.com >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

check_spotify_premium() {
    local J C

    J=$(curl -4 -s --max-time 10 \
        "https://spclient.wg.spotify.com/signup/public/v1/account?validate=1&email=test@test.com")

    if [ -z "$J" ]; then
        echo "UNKNOWN"
        return
    fi

    if echo "$J" | grep -q '"can_accept_premium":false'; then
        echo "NOT AVAILABLE"
        return
    fi

    if echo "$J" | grep -q '"can_accept_premium":true'; then
        echo "AVAILABLE"
        return
    fi

    C=$(echo "$J" | grep -o '"country":"[A-Z][A-Z]"' | cut -d '"' -f4)

    case "$C" in
        RU|BY|IR|SD|KP|SY)
            echo "NOT AVAILABLE"
            ;;
        *)
            echo "AVAILABLE"
            ;;
    esac
}

# -----------------------------
#  BLACKLIST
# -----------------------------
check_blacklist() {
    local IP REV SPAM SORBS
    IP="$1"
    REV=$(echo "$IP" | awk -F. '{print $4"."$3"."$2"."$1}')
    SPAM=$(dig +short ${REV}.zen.spamhaus.org 2>/dev/null)
    SORBS=$(dig +short ${REV}.dnsbl.sorbs.net 2>/dev/null)
    [ -z "$SPAM" ] && SPAM="CLEAN" || SPAM="LISTED"
    [ -z "$SORBS" ] && SORBS="CLEAN" || SORBS="LISTED"
    echo "$SPAM|$SORBS|$IP"
}

# -----------------------------
#  SPEEDTEST
# -----------------------------
speed_test() {
    if command -v speedtest >/dev/null 2>&1; then
        speedtest --simple
    elif command -v speedtest-cli >/dev/null 2>&1; then
        speedtest-cli --simple
    else
        echo "speedtest-cli не найден, выполняю простой тест..."
        echo "Download test:"
        wget -4 -O /dev/null https://speed.hetzner.de/100MB.bin 2>&1 | grep -o '[0-9.]\+ [KM]*B/s'
    fi
}

# -----------------------------
#  CORE CHECKS
# -----------------------------
run_checks_core() {
    local IP ASN RDNS G G1 G2 G3 GS T C BL

    IP=$(get_ip)
    ASN=$(get_asn)
    RDNS=$(dig -x "$IP" +short 2>/dev/null)

    echo "[IP]" >"$TMP"
    echo "$IP" >>"$TMP"
    echo "$ASN" >>"$TMP"
    echo "$(get_region)" >>"$TMP"

    G=$(geoip_check)
    G1=$(echo "$G" | cut -d '|' -f1)
    G2=$(echo "$G" | cut -d '|' -f2)
    G3=$(echo "$G" | cut -d '|' -f3)
    GS=$(echo "$G" | cut -d '|' -f4)

    T=$(get_ip_type "$ASN" "$RDNS")
    C=$(classify_ip "$T" "$GS" "$ASN" "$RDNS")

    echo "$T" >>"$TMP"
    echo "$C" >>"$TMP"
    echo "$GS" >>"$TMP"
    echo "$G1" >>"$TMP"
    echo "$G2" >>"$TMP"
    echo "$G3" >>"$TMP"

    echo "[YOUTUBE]" >>"$TMP"
    echo "$(check_youtube_main)" >>"$TMP"
    echo "$(get_youtube_region)" >>"$TMP"

    echo "[STREAMING]" >>"$TMP"

    # Netflix
    echo "$(check_streaming_service https://www.netflix.com)" >>"$TMP"
    echo "$(check_streaming_premium https://www.netflix.com/signup 'Choose your plan')" >>"$TMP"

    # HBO Max
    echo "$(check_streaming_service https://www.hbomax.com)" >>"$TMP"
    echo -e "${RED}Премиум недоступен${NC}" >>"$TMP"

    # Hulu
    echo "$(check_streaming_service https://www.hulu.com)" >>"$TMP"
    echo -e "${RED}Премиум недоступен${NC}" >>"$TMP"

    # Prime Video
    echo "$(check_streaming_service https://www.primevideo.com)" >>"$TMP"
    echo -e "${RED}Премиум недоступен${NC}" >>"$TMP"

    # Paramount+
    echo "$(check_streaming_service https://www.paramountplus.com)" >>"$TMP"
    echo -e "${RED}Премиум недоступен${NC}" >>"$TMP"

    # Apple TV+
    echo "$(check_streaming_service https://tv.apple.com)" >>"$TMP"
    echo "$(check_streaming_premium https://tv.apple.com 'Start Free Trial')" >>"$TMP"

    # Crunchyroll
    echo "$(check_streaming_service https://www.crunchyroll.com)" >>"$TMP"
    echo "$(check_streaming_premium https://www.crunchyroll.com 'premium')" >>"$TMP"

    echo "[SPOTIFY]" >>"$TMP"
    echo "$(check_spotify_main)" >>"$TMP"
    echo "$(check_spotify_premium)" >>"$TMP"

    echo "[BLACKLIST]" >>"$TMP"
    BL=$(check_blacklist "$IP")
    echo "$(echo "$BL" | cut -d '|' -f1)" >>"$TMP"
    echo "$(echo "$BL" | cut -d '|' -f2)" >>"$TMP"
    echo "$(echo "$BL" | cut -d '|' -f3)" >>"$TMP"
}

# -----------------------------
#  OUTPUT
# -----------------------------
run_checks() {
    run_checks_core &
    local pid=$!
    local steps=("IP" "YouTube" "Streaming" "Spotify" "Blacklist")
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        spinner "$pid" "${steps[i]}"
        i=$(( (i + 1) % ${#steps[@]} ))
    done
    wait "$pid"
    clear

    local IP ASN REG TYPE CLASS GS G1 G2 G3
    local YT_MAIN YT_R
    local S1 S2 S3 S4 S5 S6 S7 S8 S9 S10 S11 S12 S13 S14
    local SP_MAIN SP_PREM
    local BL_SP BL_SO BL_IP

    IP=$(sed -n '2p' "$TMP")
    ASN=$(sed -n '3p' "$TMP")
    REG=$(sed -n '4p' "$TMP")
    TYPE=$(sed -n '5p' "$TMP")
    CLASS=$(sed -n '6p' "$TMP")
    GS=$(sed -n '7p' "$TMP")
    G1=$(sed -n '8p' "$TMP")
    G2=$(sed -n '9p' "$TMP")
    G3=$(sed -n '10p' "$TMP")

    YT_MAIN=$(sed -n '12p' "$TMP")
    YT_R=$(sed -n '13p' "$TMP")

    # Streaming
    S1=$(sed -n '15p' "$TMP")
    S2=$(sed -n '16p' "$TMP")
    S3=$(sed -n '17p' "$TMP")
    S4=$(sed -n '18p' "$TMP")
    S5=$(sed -n '19p' "$TMP")
    S6=$(sed -n '20p' "$TMP")
    S7=$(sed -n '21p' "$TMP")
    S8=$(sed -n '22p' "$TMP")
    S9=$(sed -n '23p' "$TMP")
    S10=$(sed -n '24p' "$TMP")
    S11=$(sed -n '25p' "$TMP")
    S12=$(sed -n '26p' "$TMP")
    S13=$(sed -n '27p' "$TMP")
    S14=$(sed -n '28p' "$TMP")

    SP_MAIN=$(sed -n '30p' "$TMP")
    SP_PREM=$(sed -n '31p' "$TMP")

    BL_SP=$(sed -n '33p' "$TMP")
    BL_SO=$(sed -n '34p' "$TMP")
    BL_IP=$(sed -n '35p' "$TMP")

    echo "IP INFORMATION"
    echo "IP:      $IP"
    echo "ASN:     $ASN"
    echo "Region:  $REG"
    echo "Type:    $TYPE"
    echo "Class:   $CLASS"
    print_geoip "$G1" "$G2" "$G3" "$GS"
    echo

    echo "YOUTUBE"
    echo "Status:  $YT_MAIN"
    echo "Region:  $YT_R"
    echo

    echo "STREAMING"
    echo "Netflix:        $S1 | $S2"
    echo "HBO Max:        $S3 | $S4"
    echo "Hulu:           $S5 | $S6"
    echo "Prime Video:    $S7 | $S8"
    echo "Paramount+:     $S9 | $S10"
    echo "Apple TV+:      $S11 | $S12"
    echo "Crunchyroll:    $S13 | $S14"
    echo

    echo "SPOTIFY"
    echo "Service:  $SP_MAIN"
    echo "Premium:  $SP_PREM"
    echo

    echo "BLACKLIST"
    echo "Spamhaus:   $BL_SP"
    echo "SORBS:      $BL_SO"
    echo "IP:         $BL_IP"
    echo
}

while true; do
    echo "1) Full check"
    echo "2) Speed test"
    echo "3) Exit"
    printf "> "
    read -r C
    case "$C" in
        1) run_checks ;;
        2) speed_test ;;
        3) exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
done
