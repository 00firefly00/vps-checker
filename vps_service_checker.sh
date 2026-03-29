#!/usr/bin/env bash
if [ -z "$BASH_VERSION" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi

OK="OK"
BAD="BAD"
TMP="/tmp/.netcheck.$$"

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

check_service() {
    curl -4 -s --max-time 10 "$1" >/dev/null
    [ $? -eq 0 ] && echo "$OK" || echo "$BAD"
}

get_youtube_info() {
    local P R S
    P=$(curl -4 -s --max-time 10 "https://www.youtube.com/premium?hl=en")
    R=$(echo "$P" | grep -o '"GL":"[A-Z][A-Z]"' | head -1 | cut -d '"' -f4)
    [ -z "$R" ] && R=$(get_region)
    if echo "$P" | grep -q "yt-premium-header-renderer"; then
        S="FULL ACCESS"
    elif echo "$P" | grep -q "Premium is not available"; then
        S="NOT AVAILABLE"
    elif echo "$P" | grep -q "Try it free"; then
        S="FULL ACCESS"
    else
        S="UNKNOWN"
    fi
    echo "$R|$S"
}

check_youtube_main() {
    curl -4 -s --max-time 10 https://www.youtube.com >/dev/null
    [ $? -eq 0 ] && echo "AVAILABLE" || echo "BLOCKED"
}

geoip_check() {
    local G1 G2 G3 U S
    G1=$(curl -4 -s ipinfo.io/country)
    G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode)
    G3=$(curl -4 -s ifconfig.co/country-iso)
    [ -z "$G1" ] && G1="N/A"
    [ -z "$G2" ] && G2="N/A"
    [ -z "$G3" ] && G3="N/A"
    U=$(printf "%s\n%s\n%s\n" "$G1" "$G2" "$G3" | sort -u | wc -l)
    [ "$U" -eq 1 ] && S="clean" || S="mismatch"
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

check_blacklist() {
    local IP REV SPAM SORBS
    IP=$(get_ip)
    REV=$(echo "$IP" | awk -F. '{print $4"."$3"."$2"."$1}')
    SPAM=$(dig +short ${REV}.zen.spamhaus.org 2>/dev/null)
    SORBS=$(dig +short ${REV}.dnsbl.sorbs.net 2>/dev/null)
    [ -z "$SPAM" ] && SPAM="CLEAN" || SPAM="LISTED"
    [ -z "$SORBS" ] && SORBS="CLEAN" || SORBS="LISTED"
    echo "$SPAM|$SORBS|$IP"
}

run_speedtest_only() {
    clear
    echo "SPEEDTEST"
    local R DL UL PING
    R=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - 2>/dev/null)
    DL=$(echo "$R" | grep "Download" | awk '{print $2" "$3}')
    UL=$(echo "$R" | grep "Upload" | awk '{print $2" "$3}')
    PING=$(echo "$R" | grep -oE '[0-9]+(\.[0-9]+)? ms' | head -1)
    echo "DOWNLOAD: $DL"
    echo "UPLOAD:   $UL"
    echo "LATENCY:  $PING"
    echo
}

run_youtube_only() {
    clear
    local M D R P
    M=$(check_youtube_main)
    D=$(get_youtube_info)
    R=$(echo "$D" | cut -d '|' -f1)
    P=$(echo "$D" | cut -d '|' -f2)
    echo "YOUTUBE: $M"
    echo "REGION:  $R"
    echo "PREMIUM: $P"
    echo
}

run_checks_core() {
    local G G1 G2 G3 GS T C D BL

    echo "[IP]" >"$TMP"
    echo "$(get_ip)" >>"$TMP"
    echo "$(get_asn)" >>"$TMP"
    echo "$(get_region)" >>"$TMP"

    G=$(geoip_check)
    G1=$(echo "$G" | cut -d '|' -f1)
    G2=$(echo "$G" | cut -d '|' -f2)
    G3=$(echo "$G" | cut -d '|' -f3)
    GS=$(echo "$G" | cut -d '|' -f4)

    T=$(get_ip_type "$(get_asn)")
    C=$(classify_ip "$T" "$GS" "$(get_asn)")

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
    echo "$(check_service https://www.netflix.com)" >>"$TMP"
    echo "$(check_service https://www.hbomax.com)" >>"$TMP"
    echo "$(check_service https://www.hulu.com)" >>"$TMP"
    echo "$(check_service https://www.primevideo.com)" >>"$TMP"
    echo "$(check_service https://www.paramountplus.com)" >>"$TMP"
    echo "$(check_service https://tv.apple.com)" >>"$TMP"
    echo "$(check_service https://www.crunchyroll.com)" >>"$TMP"

    echo "[GAMING]" >>"$TMP"
    echo "$(check_service https://store.steampowered.com)" >>"$TMP"
    echo "$(check_service https://store.epicgames.com)" >>"$TMP"
    echo "$(check_service https://store.playstation.com)" >>"$TMP"
    echo "$(check_service https://www.xbox.com)" >>"$TMP"
    echo "$(check_service https://battle.net)" >>"$TMP"
    echo "$(check_service https://socialclub.rockstargames.com)" >>"$TMP"

    echo "[SOCIAL]" >>"$TMP"
    echo "$(check_service https://www.facebook.com)" >>"$TMP"
    echo "$(check_service https://www.messenger.com)" >>"$TMP"
    echo "$(check_service https://www.instagram.com)" >>"$TMP"
    echo "$(check_service https://www.threads.net)" >>"$TMP"
    echo "$(check_service https://web.whatsapp.com)" >>"$TMP"
    echo "$(check_service https://business.facebook.com)" >>"$TMP"
    echo "$(check_service https://x.com)" >>"$TMP"
    echo "$(check_service https://www.reddit.com)" >>"$TMP"
    echo "$(check_service https://web.telegram.org)" >>"$TMP"

    echo "[STORES]" >>"$TMP"
    echo "$(check_service https://www.amazon.com)" >>"$TMP"
    echo "$(check_service https://www.ebay.com)" >>"$TMP"
    echo "$(check_service https://www.aliexpress.com)" >>"$TMP"

    echo "[BLACKLIST]" >>"$TMP"
    BL=$(check_blacklist)
    echo "$(echo "$BL" | cut -d '|' -f1)" >>"$TMP"
    echo "$(echo "$BL" | cut -d '|' -f2)" >>"$TMP"
    echo "$(echo "$BL" | cut -d '|' -f3)" >>"$TMP"
}

run_checks() {
    run_checks_core &
    local pid=$!
    local steps=("IP" "YouTube" "Streaming" "Gaming" "Social" "Stores" "Blacklist")
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        spinner "$pid" "${steps[i]}"
        i=$(( (i + 1) % ${#steps[@]} ))
    done
    wait "$pid"
    clear

    local IP ASN REG TYPE CLASS GS G1 G2 G3
    local YT_MAIN YT_R YT_P
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

    local ST0 ST1 ST2 ST3 ST4 ST5 ST6
    ST0=$(sed -n '16p' "$TMP")
    ST1=$(sed -n '17p' "$TMP")
    ST2=$(sed -n '18p' "$TMP")
    ST3=$(sed -n '19p' "$TMP")
    ST4=$(sed -n '20p' "$TMP")
    ST5=$(sed -n '21p' "$TMP")
    ST6=$(sed -n '22p' "$TMP")

    local GM0 GM1 GM2 GM3 GM4 GM5
    GM0=$(sed -n '24p' "$TMP")
    GM1=$(sed -n '25p' "$TMP")
    GM2=$(sed -n '26p' "$TMP")
    GM3=$(sed -n '27p' "$TMP")
    GM4=$(sed -n '28p' "$TMP")
    GM5=$(sed -n '29p' "$TMP")

    local S0 S1 S2 S3 S4 S5 S6 S7 S8
    S0=$(sed -n '31p' "$TMP")
    S1=$(sed -n '32p' "$TMP")
    S2=$(sed -n '33p' "$TMP")
    S3=$(sed -n '34p' "$TMP")
    S4=$(sed -n '35p' "$TMP")
    S5=$(sed -n '36p' "$TMP")
    S6=$(sed -n '37p' "$TMP")
    S7=$(sed -n '38p' "$TMP")
    S8=$(sed -n '39p' "$TMP")

    local STS0 STS1 STS2
    STS0=$(sed -n '41p' "$TMP")
    STS1=$(sed -n '42p' "$TMP")
    STS2=$(sed -n '43p' "$TMP")

    BL_SP=$(sed -n '45p' "$TMP")
    BL_SO=$(sed -n '46p' "$TMP")
    BL_IP=$(sed -n '47p' "$TMP")

    rm -f "$TMP"

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

    echo "GAMING"
    echo "Steam:        $GM0"
    echo "Epic Games:   $GM1"
    echo "PlayStation:  $GM2"
    echo "Xbox:         $GM3"
    echo "Battle.net:   $GM4"
    echo "Rockstar:     $GM5"
    echo

    echo "SOCIAL"
    echo "Facebook:   $S0"
    echo "Messenger:  $S1"
    echo "Instagram:  $S2"
    echo "Threads:    $S3"
    echo "WhatsApp:   $S4"
    echo "Meta Biz:   $S5"
    echo "X/Twitter:  $S6"
    echo "Reddit:     $S7"
    echo "Telegram:   $S8"
    echo

    echo "STORES"
    echo "Amazon:     $STS0"
    echo "eBay:       $STS1"
    echo "AliExpress: $STS2"
    echo

    echo "BLACKLIST"
    echo "Spamhaus:   $BL_SP"
    echo "SORBS:      $BL_SO"
    echo "IP:         $BL_IP"
    echo
}

while true; do
    echo "1) Full check"
    echo "2) Speedtest"
    echo "3) YouTube only"
    echo "4) Exit"
    printf "> "
    read -r C
    case "$C" in
        1) run_checks ;;
        2) run_speedtest_only ;;
        3) run_youtube_only ;;
        4) exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
done
