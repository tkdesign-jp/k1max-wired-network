#!/bin/sh
#
# verify_network.sh - Post-boot verification for k1max-wired-network
# Reports the actual state of the printer's network and key services.
#
# Part of k1max-wired-network
# https://github.com/tkdesign-jp/k1max-wired-network
#
# Run after rebooting the printer:
#   sh /usr/data/printer_data/config/verify_network.sh
#
# Each check prints [OK] or [FAIL]. If any line is [FAIL], see
# docs/troubleshooting.md.
#

OK="[OK]  "
FAIL="[FAIL]"
INFO="[INFO]"

echo "============================================"
echo "  K1 MAX Wired Network Verification"
echo "============================================"
echo

# 1. eth0 has an IP
eth0_ip=$(ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
if [ -n "$eth0_ip" ]; then
    echo "$OK eth0 has $eth0_ip"
else
    echo "$FAIL eth0 has no IPv4 address"
fi

# 2. wlan0 is DOWN
wlan0_state=$(ip link show wlan0 2>/dev/null | awk 'NR==1 {gsub(/[<>,]/," "); for(i=1;i<=NF;i++) if($i=="UP") {print "UP"; exit} ; print "DOWN"}')
if [ "$wlan0_state" = "DOWN" ]; then
    echo "$OK wlan0 is DOWN (no IP)"
else
    echo "$FAIL wlan0 is $wlan0_state"
fi

# 3. Default route is via eth0
default_iface=$(ip route show default 2>/dev/null | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
if [ "$default_iface" = "eth0" ]; then
    echo "$OK default route is via eth0"
else
    echo "$FAIL default route is via '$default_iface' (expected eth0)"
fi

# 4. WiFi radio is blocked by rfkill
if rfkill list 2>/dev/null | grep -A2 "Wireless LAN" | grep -q "Soft blocked: yes"; then
    echo "$OK wifi radio is blocked (rfkill)"
else
    echo "$FAIL wifi radio is not blocked (rfkill)"
fi

# 5. wpa_supplicant state (informational)
#    wifi-server starts wpa_supplicant and udhcpc on wlan0 regardless of
#    S43/S44 being disabled and wifi_sw=0. This project does not stop
#    those daemons - it takes the radio away from them. Seeing them
#    running is expected and is not a failure.
if pgrep wpa_supplicant > /dev/null 2>&1; then
    echo "$INFO wpa_supplicant is running (expected; radio is blocked)"
else
    echo "$INFO wpa_supplicant is not running"
fi

# 6. mjpg_streamer state (informational)
#    This project does not touch the camera. wifi-server contains no
#    reference to mjpg_streamer or cam_app, so disabling WiFi has no
#    effect on the camera path either way.
if pgrep mjpg_streamer > /dev/null 2>&1; then
    echo "$INFO mjpg_streamer is running (camera untouched by this project)"
else
    echo "$INFO mjpg_streamer is not running"
fi

# 7. Klipper / Moonraker / nginx / Dropbear all running
all_services_ok=1
for svc in klipper moonraker nginx dropbear; do
    if pgrep -f "$svc" > /dev/null 2>&1; then
        :
    else
        echo "$FAIL $svc is not running"
        all_services_ok=0
    fi
done
if [ "$all_services_ok" = "1" ]; then
    echo "$OK Klipper / Moonraker / nginx / Dropbear all running"
fi

# 8. Mainsail reachable on port 4409
if [ -n "$eth0_ip" ]; then
    # NOTE: /dev/tcp is a bash-ism and does not work in BusyBox ash
    # (the /bin/sh on stock K1 firmware), so we check the listening
    # socket via netstat instead.
    if netstat -ln 2>/dev/null | grep -q ":4409 "; then
        echo "$OK Mainsail listening on port 4409"
    else
        echo "$FAIL nothing listening on port 4409"
    fi
fi

echo
echo "============================================"
echo "  If any [FAIL], see docs/troubleshooting.md"
echo "============================================"
