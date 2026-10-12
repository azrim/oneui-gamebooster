#!/usr/bin/env bash
# Galaxy Store APK download URL resolver.
#
# Replica of UN1CA's GET_GALAXY_STORE_DOWNLOAD_URL (GPL-3.0, salvogiangri/UN1CA):
#   1) stubUpdateCheck.as  -> <productId>
#   2) ods.as (SamsungProtocol request id=2303) -> <downLoadURI>
#
# The (device, sdkVer, oneUiVersion) tuple decides which app build Samsung serves,
# so we can ask for the Game Booster variant that matches a given Android baseline.

GS_DEVICES=(${GS_DEVICES:-SM-S938B SM-S901E SM-S938N})   # S25 Ultra EUR, S22 GBL, S25 Ultra KOR

# gs_download_url <package> <sdkVer> <oneUiVersion> -> prints a download URI
gs_download_url() {
    local pkg="$1" sdk="$2" oneui="$3"
    local systemid dev stub productid req out uri
    systemid="$(date +%s)"

    for dev in "${GS_DEVICES[@]}"; do
        stub="$(curl -fsSL --max-time 30 \
            "https://vas.samsungapps.com/stub/stubUpdateCheck.as?appId=${pkg}&versionCode=0&deviceId=${dev}&mcc=262&mnc=01&csc=EUX&sdkVer=${sdk}&oneUiVersion=${oneui}&systemId=${systemid}")" || continue

        productid="$(printf '%s' "$stub" | grep -o '<productId>[^<]*' | sed 's/.*>//')"
        [ -n "$productid" ] || continue

        req="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>"
        req+="<SamsungProtocol networkType=\"0\" openApiVersion=\"${sdk}\" deviceModel=\"${dev}\""
        req+=" mcc=\"262\" mnc=\"01\" csc=\"EUX\" version=\"7.7\" systemId=\"${systemid}\""
        req+=" deviceFeature=\"locale=en_GB||abi32=armeabi-v7a:armeabi||abi64=arm64-v8a||oneUiVersion=${oneui}\">"
        req+="<request id=\"2303\" numParam=\"2\">"
        req+="<param name=\"stduk\">0</param>"
        req+="<param name=\"productID\">${productid}</param>"
        req+="</request></SamsungProtocol>"

        out="$(curl -fsSL --max-time 30 "https://uk-odc.samsungapps.com/ods.as" \
            -H "Content-Type: text/plain" -d "$req")" || continue

        uri="$(printf '%s' "$out" | grep -o '<value name="downLoadURI">[^<]*' | sed 's/.*>//')"
        if [ -n "$uri" ]; then
            printf '%s\n' "${uri//amp;/}"
            return 0
        fi
    done

    echo "gs_download_url: no download URI for ${pkg} (sdk=${sdk} oneui=${oneui})" >&2
    return 1
}

# gs_version_name <package> <sdkVer> <oneUiVersion> -> prints the served versionName
gs_version_name() {
    local pkg="$1" sdk="$2" oneui="$3" dev stub
    for dev in "${GS_DEVICES[@]}"; do
        stub="$(curl -fsSL --max-time 30 \
            "https://vas.samsungapps.com/stub/stubUpdateCheck.as?appId=${pkg}&versionCode=0&deviceId=${dev}&mcc=262&mnc=01&csc=EUX&sdkVer=${sdk}&oneUiVersion=${oneui}&systemId=$(date +%s)")" || continue
        local v
        v="$(printf '%s' "$stub" | grep -o '<versionName>[^<]*' | sed 's/.*>//')"
        [ -n "$v" ] && { printf '%s\n' "$v"; return 0; }
    done
    return 1
}

# fetch_apk <package> <sdkVer> <oneUiVersion> <outfile>
fetch_apk() {
    local pkg="$1" sdk="$2" oneui="$3" out="$4" url
    url="$(gs_download_url "$pkg" "$sdk" "$oneui")" || return 1
    curl -fL --retry 3 --max-time 600 -o "$out" "$url"
}
