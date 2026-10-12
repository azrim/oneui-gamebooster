#!/usr/bin/env bash
# Download an APK from an APKMirror "...-android-apk-download" variant page.
#
#   apkmirror.sh <variant-download-page-url> <outfile>
#
# APKMirror gates the file behind two hops and a browser check:
#   variant page  ->  download/?key=...  ->  download.php?id=...&key=...  ->  CDN (.apk)
# Plain curl gets 403 unless a full desktop User-Agent is sent.
set -euo pipefail

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
HDRS=(-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      -H "Accept-Language: en-US,en;q=0.9")

VURL="${1:?usage: apkmirror.sh <variant-download-page-url> <outfile>}"
OUT="${2:?usage: apkmirror.sh <variant-download-page-url> <outfile>}"

page="$(mktemp)"; keyed="$(mktemp)"
trap 'rm -f "$page" "$keyed"' EXIT

curl -fsSL --max-time 60 -A "$UA" "${HDRS[@]}" "$VURL" -o "$page"

keyurl="$(grep -o -E 'href="[^"]*download/\?key=[a-f0-9]+"' "$page" | head -1 | sed 's/^href="//;s/"$//')"
if [ -z "$keyurl" ]; then
    echo "apkmirror: no download key found on $VURL" >&2
    exit 1
fi
case "$keyurl" in http*) ;; *) keyurl="https://www.apkmirror.com${keyurl}" ;; esac

curl -fsSL --max-time 60 -A "$UA" "${HDRS[@]}" -e "$VURL" "$keyurl" -o "$keyed"

dl="$(grep -o -E 'href="[^"]*download\.php\?id=[0-9]+&(amp;)?key=[a-f0-9]+"' "$keyed" | head -1 \
      | sed 's/^href="//;s/"$//;s/&amp;/\&/g')"
if [ -z "$dl" ]; then
    echo "apkmirror: no download.php link found" >&2
    exit 1
fi
case "$dl" in http*) ;; *) dl="https://www.apkmirror.com${dl}" ;; esac

curl -fsSL --max-time 300 -A "$UA" "${HDRS[@]}" -e "$keyurl" -o "$OUT" "$dl"

if ! file "$OUT" | grep -qiE 'zip|java archive|android'; then
    echo "apkmirror: $OUT is not an APK" >&2
    exit 1
fi
echo "apkmirror: $(basename "$OUT") ($(du -h "$OUT" | cut -f1))"
