#!/bin/sh
#
# apply.sh - One-shot applier for k1max-wired-network
#
# Run this ON THE PRINTER as root after extracting this repository to /tmp.
#
# Part of k1max-wired-network
# https://github.com/tkdesign-jp/k1max-wired-network
#
# This script:
#   1. Backs up the affected files
#   2. Disables /etc/init.d/S43wifi_bcm_init_config and S44wifi_bcm_up
#   3. Patches /usr/data/creality/userdata/config/system_config.json
#      to set user_info.wifi_sw to 0
#   4. Installs /etc/init.d/S41eth0_primary
#   5. Installs /usr/data/printer_data/config/verify_network.sh
#
# Reboot the printer after this completes, then run verify_network.sh.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Sanity check: are we on a K1 MAX?
if [ ! -f /usr/data/creality/userdata/config/system_config.json ]; then
    echo "ERROR: /usr/data/creality/userdata/config/system_config.json not found."
    echo "This script is intended for stock Creality K1 MAX firmware."
    echo "Aborting."
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: must be run as root."
    exit 1
fi

# Source files we need
SRC_S41="$SCRIPT_DIR/S41eth0_primary"
SRC_VERIFY="$SCRIPT_DIR/verify_network.sh"

if [ ! -f "$SRC_S41" ]; then
    echo "ERROR: $SRC_S41 not found. Run this from the repository's scripts/ directory."
    exit 1
fi
if [ ! -f "$SRC_VERIFY" ]; then
    echo "ERROR: $SRC_VERIFY not found. Run this from the repository's scripts/ directory."
    exit 1
fi

# Backup
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/k1max-wired-network-backup-$TS"
mkdir -p "$BACKUP_DIR"
echo "[1/5] Backing up to $BACKUP_DIR"
for f in /etc/init.d/S43wifi_bcm_init_config \
         /etc/init.d/S44wifi_bcm_up \
         /etc/init.d/S41eth0_primary \
         /usr/data/creality/userdata/config/system_config.json \
         /usr/data/printer_data/config/verify_network.sh; do
    if [ -e "$f" ]; then
        cp -p "$f" "$BACKUP_DIR/"
    fi
done

# Disable S43 / S44 (keep the files for Creality firmware-update reasons)
echo "[2/5] Disabling S43/S44 WiFi init scripts"
chmod -x /etc/init.d/S43wifi_bcm_init_config 2>/dev/null || true
chmod -x /etc/init.d/S44wifi_bcm_up 2>/dev/null || true

# Patch system_config.json
echo "[3/5] Setting wifi_sw to 0 in system_config.json"
CFG="/usr/data/creality/userdata/config/system_config.json"
# Inline edit using sed; tolerant of "wifi_sw":1 or "wifi_sw" : 1
if grep -q '"wifi_sw"' "$CFG"; then
    sed -i -E 's/("wifi_sw"[[:space:]]*:[[:space:]]*)[01]/\10/' "$CFG"
    # Verify the edit happened
    if grep -E '"wifi_sw"[[:space:]]*:[[:space:]]*0' "$CFG" > /dev/null; then
        echo "      wifi_sw is now 0"
    else
        echo "      WARNING: failed to set wifi_sw to 0. Check $CFG manually."
    fi
else
    echo "      WARNING: 'wifi_sw' key not found in $CFG."
    echo "      Skipping this patch. Check the file manually."
fi

# Install S41eth0_primary
echo "[4/5] Installing /etc/init.d/S41eth0_primary"
cp "$SRC_S41" /etc/init.d/S41eth0_primary
chmod 755 /etc/init.d/S41eth0_primary

# Install verify_network.sh
echo "[5/5] Installing /usr/data/printer_data/config/verify_network.sh"
mkdir -p /usr/data/printer_data/config
cp "$SRC_VERIFY" /usr/data/printer_data/config/verify_network.sh
chmod 755 /usr/data/printer_data/config/verify_network.sh

echo
echo "============================================"
echo "  All changes applied."
echo
echo "  Backup at: $BACKUP_DIR"
echo
echo "  Reboot the printer now:"
echo "    reboot"
echo
echo "  After it comes back, verify:"
echo "    sh /usr/data/printer_data/config/verify_network.sh"
echo "============================================"
