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

# -----------------------------
#  IP INFO
# -----------------------------
get_ipv4() { curl -4 -s --max-time 5 ipinfo.io/ip; }
get_ipv6() { curl -6 -s --max-time 5 ipinfo.io/ip; }
get_asn()  { curl -4 -s --max-time 5 ipinfo.io/org; }

get_region() {
    curl -4 -s ipinfo.io/country
}

# -----------------------------
#  SIMPLE SERVICE CHECK
# -----------------------------
check_service() {
    curl -4 -s --max-time 8 "$1" >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

# -----------------------------
#  ADVANCED CHECKS
# -----------------------------
check_openai() {
    curl -4 -s --max-time 8 https://api.openai.com >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

check_youtube_premium() {
    local r
    r=$(curl -4 -s --max-time 8 https://www.youtube.com/premium)
    echo "$r" | grep -qi "YouTube Premium" && echo "AVAILABLE" || echo "UNKNOWN"
}

check_disney() {
    local r
    r=$(curl -4 -s --max-time 8 https://www.disneyplus.com)
    echo "$r" | grep -qi "Disney" && echo "AVAILABLE" || echo "BLOCKED"
}

# -----------------------------
#  CORE
# -----------------------------
run_checks_core() {

    echo "[IP]" >"$TMP"
    echo "$(get_ipv4)" >>"$TMP"
    echo "$(get_ipv6)" >>"$TMP"
    echo "$(get_asn)" >>"$TMP"
    echo "$(get_region)" >>"$TMP"

    echo "[SERVICES]" >>"$TMP"

    # Streaming / media
    echo "$(check_service https://www.netflix.com)" >>"$TMP"
    echo "$(check_youtube_premium)" >>"$TMP"
    echo "$(check_disney)" >>"$TMP"

    # Platforms
    echo "$(check_openai)" >>"$TMP"
    echo "$(check_service https://store.steampowered.com)" >>"$TMP"
    echo "$(check_service https://www.tiktok.com)" >>"$TMP"
    echo "$(check_service https://web.telegram.org)" >>"$TMP"
    echo "$(check_service https://www.reddit.com)" >>"$TMP"
    echo "$(check_service https://github.com)" >>"$TMP"

    # Cloudflare
    echo "$(check_service https://www.cloudflare.com)" >>"$TMP"
}

# -----------------------------
#  OUTPUT
# -----------------------------
run_checks() {
    run_checks_core &
    pid=$!

    steps=("IP" "Services")
    i=0

    while kill -0 "$pid" 2>/dev/null; do
        spinner "$pid" "${steps[i]}"
        i=$(( (i + 1) % ${#steps[@]} ))
    done

    wait "$pid"
    clear

    echo "IP INFORMATION"
    echo "IPv4:   $(sed -n '2p' "$TMP")"
    echo "IPv6:   $(sed -n '3p' "$TMP")"
    echo "ASN:    $(sed -n '4p' "$TMP")"
    echo "Region: $(sed -n '5p' "$TMP")"
    echo

    echo "SERVICES"

    echo "Netflix:           $(sed -n '7p' "$TMP")"
    echo "YouTube Premium:   $(sed -n '8p' "$TMP")"
    echo "Disney+:           $(sed -n '9p' "$TMP")"

    echo "OpenAI:            $(sed -n '10p' "$TMP")"
    echo "Steam:             $(sed -n '11p' "$TMP")"
    echo "TikTok:            $(sed -n '12p' "$TMP")"
    echo "Telegram:          $(sed -n '13p' "$TMP")"
    echo "Reddit:            $(sed -n '14p' "$TMP")"
    echo "GitHub:            $(sed -n '15p' "$TMP")"
    echo "Cloudflare:        $(sed -n '16p' "$TMP")"

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
