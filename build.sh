#!/bin/bash

CALC_URL='https://mirror.yandex.ru/calculate/release/'
GIT_URL='https://github.com/alesharik/calculate-learn'

CALC_DIST="cldx"
BUILD_ID="cldx"
PROFILE_NAME="CLDX"

function download_iso() {
    ## Find last available nightly data
    echo "[*] w3m -dump $CALC_URL | grep -v 'Index' | grep '/' | tail -1 | cut -d ' ' -f 1"
    LAST_DATE=$(w3m -dump ${CALC_URL} | grep -v 'Index' | grep '/' | tail -1 | cut -d ' ' -f 1)
    echo "[*] LAST DATE: ${LAST_DATE}"

    ## Last nigtly URL
    LAST_NIGHTLY=$CALC_URL$LAST_DATE
    echo "[*] LAST NIGHTLY: ${LAST_NIGHTLY}"

    ## Last nightly ISO URL
    echo "[*] w3m -dump $LAST_NIGHTLY | grep ${CALC_DIST}- | grep '.iso' | cut -d ' ' -f 1"
    ISO_NAME=$(w3m -dump $LAST_NIGHTLY | grep ${CALC_DIST}- | grep ".iso" | cut -d ' ' -f 1)
    echo "[*] ISO NAME: ${ISO_NAME}"

    curl ${LAST_NIGHTLY}${ISO_NAME} -o $ISO_NAME
    echo "[+] ISO is downloaded"
}


echo "Reading active build"
## Read active cl build id
IFS=' '
# shellcheck disable=SC2046
read -ra strarr <<< $(sudo cl-builder-update --id list | tail -n +2 | grep $BUILD_ID | xargs echo -n)

if [ ! -z "$strarr" ]; then
	echo "[?] Build with this ID exist! Breaking build..."
	sudo cl-builder-break --id "${BUILD_ID}" --clear ON --clear-pkg ON -f || true
fi

download_iso

echo "[+] Prepare new build"
sudo cl-builder-prepare --id "${BUILD_ID}" --iso "${ISO_NAME}" -f

echo "[+] First build update without update package, only portage tree and overlays"
sudo cl-builder-update --id "${BUILD_ID}" --scan ON -s -e -f

echo "[+] Change profile to necessary"
sudo cl-builder-profile --id "${BUILD_ID}" -u -f --url "${GIT_URL}" "${PROFILE_NAME}"

echo "[+] Second build update with new profile"
sudo cl-builder-update --id "${BUILD_ID}" --scan ON -e -f

echo "[+] Building image..."
sudo cl-builder-image --id "${BUILD_ID}" -f -V OFF --keep-tree OFF -c zstd --image "/var/calculate/linux/${BUILD_ID}-${LAST_DATE:: -1}-x86_64.iso"

exit 0