# Troubleshooting & Development History

This document explains, in chronological order, what was tried during the development of `k1max-wired-network`, what broke, and why the final approach is what it is.

Read this if:

- Something failed after `apply.sh` and you need to understand what happened.
- You want to apply the changes manually instead of via `apply.sh`.
- You are adapting this to a different K1-series printer.

---

## 0. The starting situation

A K1 MAX connected to the LAN via Ethernet was losing all network access whenever WiFi was turned off in the Mainsail UI. Diagnostics:

- `ip route` showed the default route via `wlan0`, with `eth0` only present as a secondary route.
- Turning WiFi off in the UI was a soft toggle: the WiFi driver remained loaded and `wlan0` stayed up.
- The whole system seemed to assume WiFi was the canonical interface.

Goal: make `eth0` the only network path and get the WiFi radio out of the picture. The camera is out of scope.

---

## 1. First attempt — disable S43/S44 only

K1 MAX's init.d boots `S43wifi_bcm_init_config` and `S44wifi_bcm_up` to bring up the WiFi BCM driver and interface. The first attempt was to disable these via `chmod -x` and reboot.

```sh
chmod -x /etc/init.d/S43wifi_bcm_init_config
chmod -x /etc/init.d/S44wifi_bcm_up
reboot
```

**Result: WiFi came back after reboot.**

Investigation showed that `S99start_app` launches `wifi-server`, and `wifi-server` itself initializes the WiFi driver via `wpa_supplicant`, independent of S43/S44. Disabling the init.d scripts was bypassed at the application layer.

---

## 2. Second attempt — set `wifi_sw` to 0

Looking at `/usr/data/creality/userdata/config/system_config.json`, the field `user_info.wifi_sw` looked like the application-layer "WiFi enabled" flag. Setting it to 0:

```json
{
  "user_info": {
    "wifi_sw": 0,
    ...
  }
}
```

This stops `wifi-server` from launching `wpa_supplicant`, so no association attempt happens.

**Result: closer, but `wlan0` was still being brought UP by something earlier in boot.** The default route still occasionally landed on `wlan0` depending on timing.

---

## 3. Third attempt — `S41eth0_primary` to force wlan0 down

The fix that finally stuck: install an init.d script that runs *before* the WiFi scripts (S41 < S43/S44 < S99) and explicitly sets `wlan0` down.

```sh
# /etc/init.d/S41eth0_primary
#!/bin/sh
sleep 3
ip link set wlan0 down 2>/dev/null || true
```

Plus `chmod 755`. Combined with the changes from steps 1 and 2:

- `S43`/`S44` chmod-x'd → driver doesn't init via init.d.
- `wifi_sw: 0` → wifi-server doesn't try to associate.
- `S41eth0_primary` → wlan0 is forced down at boot, before anything else gets a chance.

**Result: works. eth0 stays as the default route across reboots.**

---

## 4. The expensive mistake — delayed killall

An earlier version of `S41eth0_primary` tried to also kill `wifi-server` after it had a chance to start, like this:

```sh
# DO NOT USE
sleep 10
killall wifi-server
ip link set wlan0 down
```

**This bricked the printer until SSH-rescue.** Specifically:

The K1 MAX runs a Monitor watchdog that watches the application stack. When it noticed `wifi-server` had been killed, it reacted by restarting the *entire* application layer — which killed and restarted Klipper and Moonraker, but then failed to bring them back up cleanly because the system was in a half-state. Mainsail became unreachable. The printer LCD got stuck.

Recovery required SSH (still alive at boot because Dropbear is started by an earlier init script), manually deleting the killall line from `S41eth0_primary`, and rebooting.

**Lesson:** do not call `killall` on Creality's application processes from an init script. The watchdog will retaliate.

The final `S41eth0_primary` is the minimal version: bring `wlan0` down and stop. Let `wifi_sw: 0` handle the application layer.

---

## 5. mjpg_streamer

`mjpg_streamer` is the camera frame server, launched by the Creality app stack. On a default K1 MAX it runs even when nothing is consuming the stream. This project leaves it alone.

Note: an earlier version of this document claimed `mjpg_streamer` stops because `wifi-server` no longer starts it. That is wrong on both counts. `wifi-server` is **not** disabled by this project (it is started by `S99start_app` and comes up ~16s after boot even with S43/S44 disabled and `wifi_sw=0`), and its binary contains **zero** references to `mjpg_streamer` or `cam_app`. The camera keeps running exactly as on stock firmware.

Verify after reboot:

```sh
ps | grep mjpg
```

Seeing `mjpg_streamer` running is the expected, normal state.

---

## 6. The soc_fan / PB2 dead end

Separate from the network changes, a `[temperature_fan soc_fan]` block was tried in `printer.cfg` to keep the mainboard cool. It used `pin: PB2` because that was guessed from internet sources.

```
[temperature_fan soc_fan]
pin: PB2
...
```

Klipper refused to load:

```
pin PB2 used multiple times in config
```

PB2 was already used by an `enable_pin` and inside a `heater_fans multi_pin` block elsewhere in the config. The correct MCU fan pin on K1 MAX is not documented publicly and was not identified during this work. The `temperature_fan soc_fan` block was removed.

This isn't tracked in this repo because it isn't network-related. It's recorded here as a "do not assume PB2" note.

---

## 7. Reverting

To return the printer to factory behavior:

```sh
chmod +x /etc/init.d/S43wifi_bcm_init_config
chmod +x /etc/init.d/S44wifi_bcm_up
rm /etc/init.d/S41eth0_primary
# Edit /usr/data/creality/userdata/config/system_config.json:
#   set "wifi_sw": 1
reboot
```

If you used `apply.sh`, the originals are also under `/usr/data/k1max-wired-network-backup-<timestamp>/`.

---

## 8. After a Creality firmware update

Creality firmware updates regularly:

- Re-enable S43/S44 (the files are restored to executable).
- Reset `system_config.json` (`wifi_sw` is set back to 1).
- May or may not remove `/etc/init.d/S41eth0_primary` depending on the update.

After any Creality firmware update, re-run `apply.sh`.
