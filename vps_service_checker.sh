#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m';MAGENTA='\033[0;35m';NC='\033[0m'
OK="✔✔✔";BAD="✖✖✖";TMP="/tmp/.netcheck.$$"

spinner(){local pid=$1 msg="$2" s='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0;tput civis 2>/dev/null;while kill -0 "$pid" 2>/dev/null;do printf "\r[%s] %s" "${s:i:1}" "$msg";sleep 0.1;((i=(i+1)%${#s}));done;printf "\r[✔] %s\n" "$msg";tput cnorm 2>/dev/null;}

get_ip(){curl -4 -s ipinfo.io/ip;}
get_asn(){curl -4 -s ipinfo.io/org;}
get_region(){for u in ipinfo.io/country "http://ip-api.com/line/?fields=countryCode" ifconfig.co/country-iso;do r=$(curl -4 -s --max-time 5 "$u");[[ -n "$r" ]]&&echo "$r"&&return;done;echo "?";}
get_ip_type(){local a="$1";[[ "$a" =~ Mobile|LTE|Wireless|T-Mobile|Verizon|AT&T|Vodafone|Tele2|MTS|Beeline|Megafon ]]&&echo Mobile&&return;[[ "$a" =~ Residential|Home|ISP|Telecom ]]&&echo Residential&&return;[[ "$a" =~ OVH|Hetzner|DigitalOcean|Linode|AWS|Google|Azure|Contabo|Vultr|Leaseweb|M247|Choopa|Online|Scaleway|Netcup ]]&&echo Datacenter&&return;echo Unknown;}
classify_ip(){local t="$1" g="$2" a="$3";[[ "$t"=="Residential" ]]&&echo "Residential (home ISP)"&&return;[[ "$t"=="Mobile" ]]&&echo "Mobile (cellular network)"&&return;[[ "$t"=="Datacenter" ]]&&([[ "$g"=="mismatch" ]]&&echo "VPN/Proxy (datacenter, GEO mismatch)"||echo "Hosting / Datacenter")&&return;[[ "$a" =~ VPN|Proxy|Hosting|Cloud|Server ]]&&echo "VPN/Proxy (hosting ASN)"&&return;[[ "$g"=="mismatch" ]]&&echo "Suspicious / Mixed (GEO mismatch)"&&return;echo "Unknown / Mixed";}
check_service(){curl -4 -s --max-time 10 "$1" >/dev/null;[[ $? -eq 0 ]]&&echo "$OK"||echo "$BAD";}
check_subscription(){local p=$(curl -4 -s --max-time 10 "$1");[[ -z "$p" ]]&&echo UNKNOWN&&return;echo "$p"|grep -qiE "not available|unavailable|unsupported|region|country"&&echo BLOCKED||echo AVAILABLE;}

get_youtube_info(){local P=$(curl -4 -s --max-time 10 "https://www.youtube.com/premium?hl=en");local R=$(echo "$P"|grep -o '"GL":"[A-Z][A-Z]"'|head -1|cut -d '"' -f4);[[ -z "$R" ]]&&R=$(get_region);local S;echo "$P"|grep -q "yt-premium-header-renderer"&&S="FULL ACCESS"||echo "$P"|grep -q "Premium is not available"&&S="NOT AVAILABLE"||echo "$P"|grep -q "Try it free"&&S="FULL ACCESS"||S="UNKNOWN";echo "$R|$S";}
check_youtube_main(){curl -4 -s --max-time 10 https://www.youtube.com >/dev/null;[[ $? -eq 0 ]]&&echo AVAILABLE||echo BLOCKED;}

geoip_check(){G1=$(curl -4 -s ipinfo.io/country);G2=$(curl -4 -s http://ip-api.com/line/?fields=countryCode);G3=$(curl -4 -s ifconfig.co/country-iso);[[ -z "$G1" ]]&&G1="N/A";[[ -z "$G2" ]]&&G2="N/A";[[ -z "$G3" ]]&&G3="N/A";U=$(printf "%s\n%s\n%s\n" "$G1" "$G2" "$G3"|sort -u|wc -l);[[ "$U" -eq 1 ]]&&S=clean||S=mismatch;echo "$G1|$G2|$G3|$S";}

print_geoip(){local g1="$1" g2="$2" g3="$3" s="$4";[[ "$s"=="clean" ]]&&echo "GEOIP: $g1"&&return;echo "GEOIP mismatch:";printf "%-15s %-10s\n" Service Region;printf "%-15s %-10s\n" ipinfo.io "$g1";printf "%-15s %-10s\n" ip-api.com "$g2";printf "%-15s %-10s\n" ifconfig.co "$g3";}

run_speedtest_only(){clear;echo "SPEEDTEST";R=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py|python3 - 2>/dev/null);DL=$(echo "$R"|grep Download|awk '{print $2" "$3}');UL=$(echo "$R"|grep Upload|awk '{print $2" "$3}');PING=$(echo "$R"|grep -oE '[0-9]+(\.[0-9]+)? ms'|head -1);echo "DL: $DL";echo "UL: $UL";echo "PING: $PING";}

run_youtube_only(){clear;M=$(check_youtube_main);D=$(get_youtube_info);R=$(echo "$D"|cut -d '|' -f1);P=$(echo "$D"|cut -d '|' -f2);echo "YT: $M";echo "REGION: $R";echo "PREMIUM: $P";}

run_checks_core(){
echo "[IP]" >"$TMP"
echo "$(get_ip)" >>"$TMP"
echo "$(get_asn)" >>"$TMP"
echo "$(get_region)" >>"$TMP"
G=$(geoip_check);G1=$(echo "$G"|cut -d '|' -f1);G2=$(echo "$G"|cut -d '|' -f2);G3=$(echo "$G"|cut -d '|' -f3);GS=$(echo "$G"|cut -d '|' -f4)
T=$(get_ip_type "$(get_asn)");C=$(classify_ip "$T" "$GS" "$(get_asn)")
echo "$T" >>"$TMP";echo "$C" >>"$TMP";echo "$GS" >>"$TMP";echo "$G1" >>"$TMP";echo "$G2" >>"$TMP";echo "$G3" >>"$TMP"

echo "[YOUTUBE]" >>"$TMP"
echo "$(check_youtube_main)" >>"$TMP"
D=$(get_youtube_info)
echo "$(echo "$D"|cut -d '|' -f1)" >>"$TMP"
echo "$(echo "$D"|cut -d '|' -f2)" >>"$TMP"

echo "[STREAMING_SUB]" >>"$TMP"
echo "$(check_subscription https://www.netflix.com/signup)" >>"$TMP"
echo "$(check_subscription https://www.hbomax.com/subscribe)" >>"$TMP"
echo "$(check_subscription https://signup.hulu.com/plans)" >>"$TMP"
echo "$(check_subscription https://www.primevideo.com/signup)" >>"$TMP"
echo "$(check_subscription https://www.paramountplus.com/account/signup/)" >>"$TMP"
echo "$(check_subscription https://tv.apple.com/subscribe)" >>"$TMP"
echo "$(check_subscription https://www.crunchyroll.com/premium)" >>"$TMP"
echo "$(check_service https://www.spotify.com)" >>"$TMP"
echo "$(check_subscription https://www.spotify.com/premium)" >>"$TMP"

echo "[AI]" >>"$TMP"
echo "$(check_service https://chat.openai.com)" >>"$TMP"
echo "$(check_subscription https://chat.openai.com/auth/subscribe)" >>"$TMP"
echo "$(check_service https://claude.ai)" >>"$TMP"
echo "$(check_subscription https://claude.ai/subscribe)" >>"$TMP"
echo "$(check_service https://gemini.google.com)" >>"$TMP"
echo "$(check_subscription https://gemini.google.com/upgrade)" >>"$TMP"
echo "$(check_service https://copilot.microsoft.com)" >>"$TMP"
echo "$(check_subscription https://www.microsoft.com/store/b/copilotpro)" >>"$TMP"
echo "$(check_service https://www.perplexity.ai)" >>"$TMP"
echo "$(check_subscription https://www.perplexity.ai/pro)" >>"$TMP"
echo "$(check_service https://www.midjourney.com)" >>"$TMP"
echo "$(check_subscription https://www.midjourney.com/account)" >>"$TMP"
echo "$(check_service https://huggingface.co)" >>"$TMP"
echo "$(check_subscription https://huggingface.co/pricing)" >>"$TMP"
echo "$(check_service https://runwayml.com)" >>"$TMP"
echo "$(check_subscription https://runwayml.com/pricing)" >>"$TMP"
echo "$(check_service https://elevenlabs.io)" >>"$TMP"
echo "$(check_subscription https://elevenlabs.io/pricing)" >>"$TMP"

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
echo "$(echo "$BL"|cut -d '|' -f1)" >>"$TMP"
echo "$(echo "$BL"|cut -d '|' -f2)" >>"$TMP"
echo "$(echo "$BL"|cut -d '|' -f3)" >>"$TMP"
}

run_checks(){
run_checks_core & pid=$!
steps=("IP" "YouTube" "Subscriptions" "AI" "Social" "Stores" "Blacklist")
i=0;while kill -0 "$pid" 2>/dev/null;do spinner "$pid" "${steps[i]}";((i=(i+1)%${#steps[@]}));done;wait "$pid";clear

IP=$(sed -n '2p' "$TMP");ASN=$(sed -n '3p' "$TMP");REG=$(sed -n '4p' "$TMP")
TYPE=$(sed -n '5p' "$TMP");CLASS=$(sed -n '6p' "$TMP");GS=$(sed -n '7p' "$TMP")
G1=$(sed -n '8p' "$TMP");G2=$(sed -n '9p' "$TMP");G3=$(sed -n '10p' "$TMP")

YT_MAIN=$(sed -n '12p' "$TMP");YT_R=$(sed -n '13p' "$TMP");YT_P=$(sed -n '14p' "$TMP")

SUB=($(sed -n '16,24p' "$TMP"))
AI=($(sed -n '26,43p' "$TMP"))
SOC=($(sed -n '45,53p' "$TMP"))
ST=($(sed -n '55,57p' "$TMP"))
BL_SP=$(sed -n '59p' "$TMP");BL_SO=$(sed -n '60p' "$TMP");BL_IP=$(sed -n '61p' "$TMP")

rm -f "$TMP"

echo "IP: $IP"
echo "ASN: $ASN"
echo "REGION: $REG"
print_geoip "$G1" "$G2" "$G3" "$GS"
echo
echo "YOUTUBE: $YT_MAIN | $YT_R | $YT_P"
echo
echo "STREAMING SUBSCRIPTIONS:"
echo "Netflix: ${SUB[0]}"
echo "HBO Max: ${SUB[1]}"
echo "Hulu: ${SUB[2]}"
echo "Prime: ${SUB[3]}"
echo "Paramount: ${SUB[4]}"
echo "AppleTV: ${SUB[5]}"
echo "Crunchyroll: ${SUB[6]}"
echo "Spotify: ${SUB[7]}"
echo "Spotify Premium: ${SUB[8]}"
echo
echo "AI SERVICES:"
echo "OpenAI: ${AI[0]} | ${AI[1]}"
echo "Claude: ${AI[2]} | ${AI[3]}"
echo "Gemini: ${AI[4]} | ${AI[5]}"
echo "Copilot: ${AI[6]} | ${AI[7]}"
echo "Perplexity: ${AI[8]} | ${AI[9]}"
echo "Midjourney: ${AI[10]} | ${AI[11]}"
echo "HuggingFace: ${AI[12]} | ${AI[13]}"
echo "RunwayML: ${AI[14]} | ${AI[15]}"
echo "ElevenLabs: ${AI[16]} | ${AI[17]}"
echo
echo "SOCIAL:"
echo "FB: ${SOC[0]}"
echo "Messenger: ${SOC[1]}"
echo "Instagram: ${SOC[2]}"
echo "Threads: ${SOC[3]}"
echo "WhatsApp: ${SOC[4]}"
echo "MetaBiz: ${SOC[5]}"
echo "X: ${SOC[6]}"
echo "Reddit: ${SOC[7]}"
echo "Telegram: ${SOC[8]}"
echo
echo "STORES:"
echo "Amazon: ${ST[0]}"
echo "eBay: ${ST[1]}"
echo "AliExpress: ${ST[2]}"
echo
echo "BLACKLIST:"
echo "Spamhaus: $BL_SP"
echo "SORBS: $BL_SO"
echo "IP: $BL_IP"
}

while true;do
echo "1) Full check";echo "2) Speedtest";echo "3) YouTube";echo "4) Exit"
read -p "> " C
case $C in
1)run_checks;;
2)run_speedtest_only;;
3)run_youtube_only;;
4)exit 0;;
*)echo "Invalid";;
esac
done
