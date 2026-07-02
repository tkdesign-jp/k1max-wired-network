# K1 MAX Wired Network Hardening

Make Creality K1 MAX run reliably on **wired Ethernet only**, with WiFi fully disabled and the camera process stopped.

> 🇯🇵 日本語版は [README.ja.md](README.ja.md) を参照してください。
> ⚠️ Before applying anything, read [DISCLAIMER.md](DISCLAIMER.md).

---

## The problem this solves

On a stock K1 MAX, plugging in an Ethernet cable is not enough. The default route is set via `wlan0`, and `S99start_app` keeps re-initializing the WiFi driver through `wifi-server` regardless of what the menu says. Turning WiFi "off" in the UI leaves the device unreachable.

This repository contains the boot-time scripts and the procedure needed to:

- Make `eth0` the only active network interface.
- Force `wlan0` down on every boot.
- Stop `wifi-server` from re-enabling WiFi.
- Stop `mjpg_streamer` (camera) if you don't use it.
- Verify the resulting state after every reboot.

The end result: a K1 MAX that boots straight onto wired Ethernet, never touches WiFi, never streams camera frames, and never silently falls back to a wireless route.

---

## What this is (and isn't)

- This is a **set of init.d scripts and one config edit** that ship with a clear apply/verify flow.
- It is **not a firmware mod** and does not flash anything. All changes are reversible.
- It targets the **stock Creality firmware** stack: Klipper + Moonraker + Mainsail on Buildroot 2020.02.1, MIPS SoC, port 4409.
- It is **not** specifically tested on rooted-and-replaced firmware variants (Kamp, Helper Script, fluidd-only builds). It will probably work but the file paths may differ.

---

## ⚠️ Read this first

Modifying init.d on a printer can leave it unable to start its motion controller or web UI. Things that have actually happened during development of this script are documented in [docs/troubleshooting.md](docs/troubleshooting.md) — read it.

**You apply this at your own risk.** See [DISCLAIMER.md](DISCLAIMER.md).

---

## Requirements

- Creality K1 MAX (this exact model — K1 / K1C may need adjustment).
- Stock firmware with Klipper + Moonraker + Mainsail.
- SSH access enabled, root password known.
- The printer is reachable on your network and you know its IP (e.g. `192.168.1.19`).
- A second device (laptop) on the same LAN to recover via SSH if something goes wrong.

---

## What gets changed

| Target | Action | Effect |
|---|---|---|
| `/etc/init.d/S43wifi_bcm_init_config` | `chmod -x` | WiFi driver init disabled (file kept) |
| `/etc/init.d/S44wifi_bcm_up` | `chmod -x` | WiFi bring-up disabled (file kept) |
| `/usr/data/creality/userdata/config/system_config.json` | edit | `user_info.wifi_sw` → `0` |
| `/etc/init.d/S41eth0_primary` | new file | Forces `wlan0` down before S43/S44 / S99 |
| `/usr/data/printer_data/config/verify_network.sh` | new file | Post-reboot self-check |

Everything is **reversible**: restoring `chmod +x` on S43/S44, setting `wifi_sw` back to `1`, and removing `S41eth0_primary` returns the printer to factory behavior on next reboot.

---

## Files in this repository

```
scripts/
├── S41eth0_primary       Boot script that forces wlan0 down
├── verify_network.sh     Reports actual network state after reboot
└── apply.sh              One-shot applier (run via SSH on the printer)

docs/
└── troubleshooting.md    History of what broke during development, and why
```

---

## Installation

### Option 1: Apply via the included script

SSH into the printer as root, fetch this repo, and run `apply.sh`:

```bash
# On the printer (SSH'd in as root)
cd /tmp
wget https://github.com/tkdesign-jp/k1max-wired-network/archive/refs/heads/main.tar.gz
tar xzf main.tar.gz
cd k1max-wired-network-main
sh scripts/apply.sh
```

`apply.sh` will:

1. Back up the affected files into `/usr/data/k1max-wired-network-backup-<timestamp>/`.
2. Disable S43/S44 via `chmod -x`.
3. Patch `system_config.json` to set `wifi_sw: 0`.
4. Install `S41eth0_primary` into `/etc/init.d/` with the correct permissions.
5. Install `verify_network.sh` into `/usr/data/printer_data/config/`.

Then reboot the printer:

```bash
reboot
```

After it comes back up, run the verifier from Mainsail's console (or SSH):

```bash
sh /usr/data/printer_data/config/verify_network.sh
```

You should see all `[OK]` lines. See "Expected output" below.

### Option 2: Do it manually

Follow the steps in [docs/troubleshooting.md](docs/troubleshooting.md) which describes every change with the exact command. This is the safer path if you want to understand each step before running it.

---

## Expected output of `verify_network.sh`

```
[OK]  eth0 has 192.168.1.19 (or similar wired IP)
[OK]  wlan0 is DOWN (no IP)
[OK]  default route is via eth0
[OK]  wpa_supplicant is not running
[OK]  mjpg_streamer is not running
[OK]  Klipper / Moonraker / nginx / Dropbear all running
[OK]  Mainsail reachable on port 4409
```

If any line is `[FAIL]`, see [docs/troubleshooting.md](docs/troubleshooting.md).

---

## Reverting

To return to stock behavior:

```bash
# On the printer (SSH'd in as root)
chmod +x /etc/init.d/S43wifi_bcm_init_config
chmod +x /etc/init.d/S44wifi_bcm_up
rm /etc/init.d/S41eth0_primary
# Edit system_config.json and set wifi_sw back to 1
reboot
```

The backup created by `apply.sh` (under `/usr/data/k1max-wired-network-backup-<timestamp>/`) contains the original copies.

---

## Known limitations

- `mjpg_streamer` is stopped only because `wifi-server` no longer starts it. If you re-enable the camera path some other way, it will come back. There is no separate "camera disable" toggle in this set.
- Creality firmware updates may re-enable the WiFi scripts. After any Creality update, re-run `apply.sh`.
- The path `/usr/data/creality/userdata/config/system_config.json` is stock K1 MAX firmware. Modified firmware builds may use a different location.

---

## License

[MIT](LICENSE) — do what you like, no warranty. See also [DISCLAIMER.md](DISCLAIMER.md).
