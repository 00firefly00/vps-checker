#!/usr/bin/env bash
if [ -z "$BASH_VERSION" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi

OK="OK"
BAD="BAD"
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

get_ip_type() {
    local a="$1"
    case "$a" in
        *Mobile*|*LTE*|*Wireless*|*T-Mobile*|*Verizon*|*Vodafone*|*Tele2*|*MTS*|*Beeline*|*Megafon*)
            echo "Mobile" ;;
        *Residential*|*Home*|*ISP*|*Telecom*)
            echo "Residential" ;;
        *OVH*|*Hetzner*|*DigitalOcean*|*Linode*|*AWS*|*Google*|*Azure*|*Contabo*|*Vultr*|*Leaseweb*|*M247*|*Choopa*|*Online*|*Scaleway*|*Netcup*)
            echo "Datacenter" ;;
        *)
            echo "Unknown" ;;
    esac
}

classify_ip() {
    local t="$1" g="$2" a="$3"
    if [ "$t" = "Residential" ]; then
        echo "Residential (home ISP)"
    elif [ "$t" = "Mobile" ]; then
        echo "Mobile (cellular network)"
    elif [ "$t" = "Datacenter" ]; then
        if [ "$g" = "mismatch" ]; then
            echo "VPN/Proxy (datacenter, GEO mismatch)"
        else
            echo "Hosting / Datacenter"
        fi
    else
        case "$a" in
            *VPN*|*Proxy*|*Hosting*|*Cloud*|*Server*)
                echo "VPN/Proxy (hosting ASN)" ;;
            *)
                if [ "$g" = "mismatch" ]; then
                    echo "Suspicious / Mixed (GEO mismatch)"
                else
                    echo "Unknown / Mixed"
                fi ;;
        esac
    fi
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

check_streaming() {
    local url="$1"
    local block_pattern="$2"

    local resp
    resp=$(curl -4 -s --max-time 10 "$url")

    if [ -z "$resp" ]; then
        echo "$BAD"
        return
    fi

    if echo "$resp" | grep -qiE "$block_pattern"; then
        echo "$BAD"
    else
        echo "$OK"
    fi
}

check_youtube_main() {
    curl -4 -s --max-time 10 https://www.youtube.com >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

get_youtube_info() {
    local P R S
    P=$(curl -4 -s --max-time 10 "https://www.youtube.com/premium?hl=en")
    R=$(echo "$P" | grep -o '"GL":"[A-Z][A-Z]"' | head -1 | cut -d '"' -f4)
    [ -z "$R" ] && R=$(get_region)

    if echo "$P" | grep -q "Premium is not available"; then
        S="NOT AVAILABLE"
    elif echo "$P" | grep -q "yt-premium-header-renderer"; then
        S="FULL ACCESS"
    elif echo "$P" | grep -q "Try it free"; then
        S="FULL ACCESS"
    else
        S="UNKNOWN"
    fi

    echo "$R|$S"
}

check_spotify_main() {
    curl -4 -s --max-time 10 https://www.spotify.com >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

check_spotify_premium() {
    local P
    P=$(curl -4 -s --max-time 10 "https://www.spotify.com/premium/")

    if [ -z "$P" ]; then
        echo "UNKNOWN"
        return
    fi

    if echo "$P" | grep -qi "not available in your country"; then
        echo "NOT AVAILABLE"
    elif echo "$P" | grep -qiE "Get Premium|Try Premium"; then
        echo "AVAILABLE"
    else
        echo "UNKNOWN"
    fi
}

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

run_checks_core() {
    local IP ASN G G1 G2 G3 GS T C D BL

    IP=$(get_ip)
    ASN=$(get_asn)

    echo "[IP]" >"$TMP"
    echo "$IP" >>"$TMP"
    echo "$ASN" >>"$TMP"
    echo "$(get_region)" >>"$TMP"

    G=$(geoip_check)
    G1=$(echo "$G" | cut -d '|' -f1)
    G2=$(echo "$G" | cut -d '|' -f2)
    G3=$(echo "$G" | cut -d '|' -f3)
    GS=$(echo "$G" | cut -d '|' -f4)

    T=$(get_ip_type "$ASN")
    C=$(classify_ip "$T" "$GS" "$ASN")

    echo "$T" >>"$TMP"
    echo "$C" >>"$TMP"
    echo "$GS" >>"$TMP"
    echo "$G1" >>"$TMP"
    echo "$G2" >>"$TMP"
    echo "$G3" >>"$TMP"

    echo "[YOUTUBE]" >>"$TMP"
    echo "$(check_youtube_main)" >>"$TMP"
    D=$(get_youtube_info)
    echo "$(echo "$D" | cut -d '|' -f1)" >>"$TMP"
    echo "$(echo "$D" | cut -d '|' -f2)" >>"$TMP"

    echo "[STREAMING]" >>"$TMP"
    echo "$(check_streaming https://www.netflix.com/title/70143836 'unblocker|proxy')" >>"$TMP"
    echo "$(check_streaming https://play.hbomax.com 'not in your region')" >>"$TMP"
    echo "$(check_streaming https://www.hulu.com 'not available in your region')" >>"$TMP"
    echo "$(check_streaming https://www.primevideo.com 'not available')" >>"$TMP"
    echo "$(check_streaming https://www.paramountplus.com 'not available')" >>"$TMP"
    echo "$(check_streaming https://tv.apple.com 'unsupported region')" >>"$TMP"
    echo "$(check_streaming https://www.crunchyroll.com 'not available')" >>"$TMP"

    echo "[SPOTIFY]" >>"$TMP"
    echo "$(check_spotify_main)" >>"$TMP"
    echo "$(check_spotify_premium)" >>"$TMP"

    echo "[BLACKLIST]" >>"$TMP"
    BL=$(check_blacklist "$IP")
    echo "$(echo "$BL" | cut -d '|' -f1)" >>"$TMP"
    echo "$(echo "$BL" | cut -d '|' -f2)" >>"$TMP"
    echo "$(echo "$BL" | cut -d '|' -f3)" >>"$TMP"
}

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
    local YT_MAIN YT_R YT_P
    local ST0 ST1 ST2 ST3 ST4 ST5 ST6
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
    YT_P=$(sed -n '14p' "$TMP")

    ST0=$(sed -n '16p' "$TMP")
    ST1=$(sed -n '17p' "$TMP")
    ST2=$(sed -n '18p' "$TMP")
    ST3=$(sed -n '19p' "$TMP")
    ST4=$(sed -n '20p' "$TMP")
    ST5=$(sed -n '21p' "$TMP")
    ST6=$(sed -n '22p' "$TMP")

    SP_MAIN=$(sed -n '24p' "$TMP")
    SP_PREM=$(sed -n '25p' "$TMP")

    BL_SP=$(sed -n '27p' "$TMP")
    BL_SO=$(sed -n '28p' "$TMP")
    BL_IP=$(sed -n '29p' "$TMP")

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
    echo "Premium: $YT_P"
    echo

    echo "STREAMING"
    echo "Netflix:      $ST0"
    echo "HBO Max:      $ST1"
    echo "Hulu:         $ST2"
    echo "Prime Video:  $ST3"
    echo "Paramount+:   $ST4"
    echo "Apple TV+:    $ST5"
    echo "Crunchyroll:  $ST6"
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
