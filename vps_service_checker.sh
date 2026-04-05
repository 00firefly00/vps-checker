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
get_ipv6() { curl -6 -s --max-time 5 ipinfo.io/ip; }
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
#  NEW SERVICE CHECKS
# -----------------------------
check_simple() {
    curl -4 -s --max-time 8 "$1" >/dev/null
    [ $? -eq 0 ] && echo "Доступен" || echo "Недоступен"
}

check_openai() {
    curl -4 -s --max-time 8 https://api.openai.com >/dev/null
    [ $? -eq 0 ] && echo "Доступен" || echo "Недоступен"
}

check_youtube_premium() {
    local r
    r=$(curl -4 -s --max-time 8 https://www.youtube.com/premium)
    echo "$r" | grep -qi "YouTube Premium" && echo "Есть" || echo "Неизвестно"
}

# -----------------------------
#  IMPROVED IP TYPE DETECTION
# -----------------------------
get_ip_type() {
    local a="$1"
    local rdns="$2"

    if echo "$a" | grep -qiE "OVH|Hetzner|DigitalOcean|Linode|AWS|Google|Azure|Contabo|Vultr|Leaseweb|M247|Choopa|Scaleway|Netcup|Oracle|Alibaba|Tencent|Kamatera|G-Core|Cloudflare|Fastly|Akamai"; then
        echo "Datacenter"
        return
    fi

    if echo "$a" | grep -qiE "T-Mobile|Verizon|Vodafone|Tele2|MTS|Beeline|Megafon|AT&T|Sprint|Orange|Claro|Telia|Telenor|Rogers|Bell|Telus"; then
        echo "Mobile"
        return
    fi

    if echo "$a" | grep -qiE "Comcast|Spectrum|Cox|Xfinity|BT|Virgin|Sky|Deutsche|Telekom|Orange Home|Rostelecom|Home|Residential|ISP"; then
        echo "Residential"
        return
    fi

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
#  STREAMING CHECKS (OLD + NEW)
# -----------------------------
check_streaming_service() {
    curl -4 -s --max-time 10 "$1" >/dev/null
    [ $? -eq 0 ] && echo "Доступен" || echo "Недоступен"
}

# -----------------------------
#  CORE CHECKS
# -----------------------------
run_checks_core() {
    local IP IPV6 ASN RDNS G G1 G2 G3 GS T C

    IP=$(get_ip)
    IPV6=$(get_ipv6)
    ASN=$(get_asn)
    RDNS=$(dig -x "$IP" +short 2>/dev/null)

    echo "[IP]" >"$TMP"
    echo "$IP" >>"$TMP"
    echo "$IPV6" >>"$TMP"
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

    echo "[SERVICES]" >>"$TMP"

    echo "$(check_streaming_service https://www.netflix.com)" >>"$TMP"
    echo "$(check_youtube_premium)" >>"$TMP"
    echo "$(check_simple https://www.disneyplus.com)" >>"$TMP"

    echo "$(check_openai)" >>"$TMP"
    echo "$(check_simple https://store.steampowered.com)" >>"$TMP"
    echo "$(check_simple https://www.tiktok.com)" >>"$TMP"
    echo "$(check_simple https://web.telegram.org)" >>"$TMP"
    echo "$(check_simple https://www.reddit.com)" >>"$TMP"
    echo "$(check_simple https://github.com)" >>"$TMP"
    echo "$(check_simple https://www.cloudflare.com)" >>"$TMP"
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
    echo "Type:   $(sed -n '6p' "$TMP")"
    echo "Class:  $(sed -n '7p' "$TMP")"
    print_geoip "$(sed -n '9p' "$TMP")" "$(sed -n '10p' "$TMP")" "$(sed -n '11p' "$TMP")" "$(sed -n '8p' "$TMP")"
    echo

    echo "SERVICES"
    echo "Netflix:        $(sed -n '13p' "$TMP")"
    echo "YouTube Prem:   $(sed -n '14p' "$TMP")"
    echo "Disney+:        $(sed -n '15p' "$TMP")"
    echo "OpenAI:         $(sed -n '16p' "$TMP")"
    echo "Steam:          $(sed -n '17p' "$TMP")"
    echo "TikTok:         $(sed -n '18p' "$TMP")"
    echo "Telegram:       $(sed -n '19p' "$TMP")"
    echo "Reddit:         $(sed -n '20p' "$TMP")"
    echo "GitHub:         $(sed -n '21p' "$TMP")"
    echo "Cloudflare:     $(sed -n '22p' "$TMP")"
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
