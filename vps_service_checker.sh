#!/usr/bin/env bash
if [ -z "$BASH_VERSION" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi

TMP="/tmp/.netcheck.$$"
trap 'rm -f "$TMP"' EXIT

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

# -----------------------------
#  IP FUNCTIONS
# -----------------------------
get_ip4() { curl -4 -s ipinfo.io/ip; }
get_asn4() { curl -4 -s ipinfo.io/org; }
get_region4() { curl -4 -s ipinfo.io/country; }

get_ip6() { curl -6 -s ipinfo.io/ip; }
get_asn6() { curl -6 -s ipinfo.io/org; }
get_region6() { curl -6 -s ipinfo.io/country; }

check_ipv6() {
    curl -6 -s --max-time 5 https://ifconfig.co >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "NOT_AVAILABLE"
}

# -----------------------------
#  GEOIP
# -----------------------------
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

# -----------------------------
#  SERVICE CHECKS
# -----------------------------
check_service() {
    curl -4 -s --max-time 10 "$1" >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

check_openai() {
    curl -4 -s --max-time 10 https://api.openai.com/v1/models >/dev/null
    [ $? -eq 0 ] && echo "API_AVAILABLE" || echo "API_BLOCKED"
}

check_chatgpt() {
    curl -4 -s --max-time 10 https://chat.openai.com >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

check_warp() {
    local resp
    resp=$(curl -4 -s --max-time 10 https://www.cloudflare.com/cdn-cgi/trace)
    if echo "$resp" | grep -q "warp=on"; then
        echo "WARP_ON"
    elif echo "$resp" | grep -q "warp=off"; then
        echo "WARP_OFF"
    else
        echo "UNKNOWN"
    fi
}

check_cloudflare_zero_trust() {
    curl -4 -s --max-time 10 https://one.one.one.one >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

# -----------------------------
#  CORE CHECKS
# -----------------------------
run_checks_core() {

    # IPv4
    echo "[IPV4]" >>"$TMP"
    echo "ip=$(get_ip4)" >>"$TMP"
    echo "asn=$(get_asn4)" >>"$TMP"
    echo "region=$(get_region4)" >>"$TMP"

    # IPv6
    echo "[IPV6]" >>"$TMP"
    echo "ip=$(get_ip6)" >>"$TMP"
    echo "asn=$(get_asn6)" >>"$TMP"
    echo "region=$(get_region6)" >>"$TMP"
    echo "status=$(check_ipv6)" >>"$TMP"

    # GEOIP
    local G G1 G2 G3 GS
    G=$(geoip_check)
    G1=$(echo "$G" | cut -d '|' -f1)
    G2=$(echo "$G" | cut -d '|' -f2)
    G3=$(echo "$G" | cut -d '|' -f3)
    GS=$(echo "$G" | cut -d '|' -f4)

    echo "[GEOIP]" >>"$TMP"
    echo "ipinfo=$G1" >>"$TMP"
    echo "ipapi=$G2" >>"$TMP"
    echo "ifconfig=$G3" >>"$TMP"
    echo "status=$GS" >>"$TMP"

    # YouTube
    echo "[YOUTUBE]" >>"$TMP"
    echo "main=$(check_service https://www.youtube.com)" >>"$TMP"

    # Streaming
    echo "[STREAMING]" >>"$TMP"
    echo "netflix=$(check_service https://www.netflix.com)" >>"$TMP"
    echo "disney=$(check_service https://www.disneyplus.com)" >>"$TMP"
    echo "prime=$(check_service https://www.primevideo.com)" >>"$TMP"
    echo "hulu=$(check_service https://www.hulu.com)" >>"$TMP"
    echo "hbomax=$(check_service https://www.hbomax.com)" >>"$TMP"
    echo "apple=$(check_service https://tv.apple.com)" >>"$TMP"
    echo "crunchyroll=$(check_service https://www.crunchyroll.com)" >>"$TMP"

    # OpenAI
    echo "[OPENAI]" >>"$TMP"
    echo "api=$(check_openai)" >>"$TMP"
    echo "chatgpt=$(check_chatgpt)" >>"$TMP"

    # Steam
    echo "[STEAM]" >>"$TMP"
    echo "store=$(check_service https://store.steampowered.com)" >>"$TMP"
    echo "community=$(check_service https://steamcommunity.com)" >>"$TMP"

    # TikTok
    echo "[TIKTOK]" >>"$TMP"
    echo "main=$(check_service https://www.tiktok.com)" >>"$TMP"

    # Telegram
    echo "[TELEGRAM]" >>"$TMP"
    echo "main=$(check_service https://core.telegram.org)" >>"$TMP"

    # Reddit
    echo "[REDDIT]" >>"$TMP"
    echo "main=$(check_service https://www.reddit.com)" >>"$TMP"

    # GitHub
    echo "[GITHUB]" >>"$TMP"
    echo "main=$(check_service https://github.com)" >>"$TMP"

    # Cloudflare Warp
    echo "[WARP]" >>"$TMP"
    echo "warp=$(check_warp)" >>"$TMP"
    echo "zero_trust=$(check_cloudflare_zero_trust)" >>"$TMP"
}

# -----------------------------
#  PARSER (устойчивый, без ошибок awk)
# -----------------------------
get_val() {
    local section="$1"
    local key="$2"
    local val

    val=$(awk -v s="[$section]" -v k="$key" '
        $0==s {f=1; next}
        /^

\[/ {f=0}
        f && $0 ~ "^"k"=" {
            sub("^[^=]*=", "", $0)
            print $0
        }
    ' "$TMP")

    [ -z "$val" ] && echo "N/A" || echo "$val"
}

# -----------------------------
#  OUTPUT
# -----------------------------
run_checks() {
    run_checks_core &
    local pid=$!
    local steps=("IP" "GEO" "Streaming" "OpenAI" "Steam" "Warp")
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        spinner "$pid" "${steps[i]}"
        i=$(( (i + 1) % ${#steps[@]} ))
    done

    wait "$pid"
    sleep 0.1
    sync "$TMP"
    clear

    echo "IPV4:"
    echo "  IP:      $(get_val IPV4 ip)"
    echo "  ASN:     $(get_val IPV4 asn)"
    echo "  Region:  $(get_val IPV4 region)"
    echo

    echo "IPV6:"
    echo "  IP:      $(get_val IPV6 ip)"
    echo "  ASN:     $(get_val IPV6 asn)"
    echo "  Region:  $(get_val IPV6 region)"
    echo "  Status:  $(get_val IPV6 status)"
    echo

    echo "GEOIP:"
    echo "  ipinfo:   $(get_val GEOIP ipinfo)"
    echo "  ip-api:   $(get_val GEOIP ipapi)"
    echo "  ifconfig: $(get_val GEOIP ifconfig)"
    echo "  Status:   $(get_val GEOIP status)"
    echo

    echo "YOUTUBE:"
    echo "  Main: $(get_val YOUTUBE main)"
    echo

    echo "STREAMING:"
    echo "  Netflix:      $(get_val STREAMING netflix)"
    echo "  Disney+:      $(get_val STREAMING disney)"
    echo "  Prime Video:  $(get_val STREAMING prime)"
    echo "  Hulu:         $(get_val STREAMING hulu)"
    echo "  HBO Max:      $(get_val STREAMING hbomax)"
    echo "  Apple TV+:    $(get_val STREAMING apple)"
    echo "  Crunchyroll:  $(get_val STREAMING crunchyroll)"
    echo

    echo "OPENAI:"
    echo "  API:     $(get_val OPENAI api)"
    echo "  ChatGPT: $(get_val OPENAI chatgpt)"
    echo

    echo "STEAM:"
    echo "  Store:      $(get_val STEAM store)"
    echo "  Community:  $(get_val STEAM community)"
    echo

    echo "TIKTOK:"
    echo "  Main: $(get_val TIKTOK main)"
    echo

    echo "TELEGRAM:"
    echo "  Main: $(get_val TELEGRAM main)"
    echo

    echo "REDDIT:"
    echo "  Main: $(get_val REDDIT main)"
    echo

    echo "GITHUB:"
    echo "  Main: $(get_val GITHUB main)"
    echo

    echo "WARP:"
    echo "  Warp:        $(get_val WARP warp)"
    echo "  Zero Trust:  $(get_val WARP zero_trust)"
    echo
}

while true; do
    echo "1) Full check"
    echo "2) Exit"
    printf "> "
    read -r C
    case "$C" in
        1) run_checks ;;
        2) exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
done
