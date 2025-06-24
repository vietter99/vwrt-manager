#!/bin/sh
echo "Content-Type: application/json"
echo ""

band="${QUERY_STRING#band=}"

phy=""
for p in $(ls /sys/class/ieee80211/); do
  iwinfo $p info 2>/dev/null | grep -qi "$band" && { phy=$p; break; }
done
[ -z "$phy" ] && phy=$(ls /sys/class/ieee80211/ | head -n1)

info="$(iwinfo $phy info 2>/dev/null)"
has_ax=0; has_ac=0; has_n=0; has_legacy=0

rawmodes=$(echo "$info" | grep "HW Mode(s):" | sed -E 's/.*HW Mode\(s\): //; s#/# #g' | tr -d '[],' | xargs)
for m in $rawmodes; do
  case "$m" in
    *ax*) has_ax=1 ;;
    *ac*) has_ac=1 ;;
    *n*) has_n=1 ;;
    *a*) has_legacy=1 ;;
    *g*) has_legacy=1 ;;
    *b*) has_legacy=1 ;;
  esac
done

# Nếu là 2.4G + ax thì luôn đủ ax/n/legacy, width 20/40
if echo "$band" | grep -qi '2\.4' && [ $has_ax -eq 1 ]; then
  modes='["ax","n","legacy"]'
  widths='["20","40"]'
# Nếu là 5G + ax thì đủ ax/ac/n, width 20/40/80/160
elif echo "$band" | grep -qi '5g' && [ $has_ax -eq 1 ]; then
  modes='["ax","ac","n"]'
  widths='["20","40","80","160"]'
# Nếu không phải ax, lấy động thực tế
else
  modes="["
  [ $has_ax -eq 1 ] && modes="$modes\"ax\","
  [ $has_ac -eq 1 ] && modes="$modes\"ac\","
  [ $has_n -eq 1 ] && modes="$modes\"n\","
  [ $has_legacy -eq 1 ] && modes="$modes\"legacy\","
  modes=$(echo "$modes" | sed 's/,$//')
  modes="$modes]"

  widths=""
  echo "$info" | grep -q "HE160" && widths="$widths\"160\","
  echo "$info" | grep -q "VHT160" && widths="$widths\"160\","
  echo "$info" | grep -q "HE80"  && widths="$widths\"80\","
  echo "$info" | grep -q "VHT80"  && widths="$widths\"80\","
  echo "$info" | grep -q "HE40"  && widths="$widths\"40\","
  echo "$info" | grep -q "VHT40"  && widths="$widths\"40\","
  echo "$info" | grep -q "HE20" && widths="$widths\"20\","
  echo "$info" | grep -q "VHT20" && widths="$widths\"20\","
  echo "$info" | grep -q "HT20"   && widths="$widths\"20\","
  [ -z "$widths" ] && widths="\"20\""
  widths=$(echo "$widths" | sed 's/,$//')
  widths="[$widths]"
fi

echo "{\"modes\":$modes,\"widths\":$widths}"
