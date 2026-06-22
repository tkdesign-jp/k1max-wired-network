# Disclaimer

## English

This repository modifies init scripts and a config file on a **Creality K1 MAX 3D printer**. Read this before applying anything.

### Warranty

Applying these scripts may **void your manufacturer warranty**. Creality has not authorized these changes. If your printer is under warranty and you may need to claim it, do not apply these changes.

### Risk

Errors in init.d scripts can cause:

- The printer to fail to boot Klipper / Moonraker / Mainsail.
- The printer to become unreachable on the network (no SSH, no Web UI).
- In the worst case, an unbootable state requiring physical recovery (USB flashing, SD card reset, or RMA).

A real example of a script error causing the Monitor watchdog to kill all services — leaving Klipper unable to start — is documented in [docs/troubleshooting.md](docs/troubleshooting.md). It was recoverable, but only because SSH still worked at boot. **You may not be that lucky.**

### Responsibility

By using anything in this repository, you accept that:

- **You are solely responsible** for any damage to your printer, loss of warranty, loss of prints in progress, or any consequential damages.
- The author (**T.K DΞSIGN**) provides this material **as-is**, with **no warranty** of any kind, express or implied.
- The author has **no obligation** to provide support, fixes, or compensation if something goes wrong.
- This is a personal project shared as a reference, not a commercial product.

### Before applying

Recommended precautions:

1. Have SSH access ready on a second device on the same LAN, so you can recover.
2. Note the printer's current IP address.
3. Back up the original files (the included `apply.sh` does this automatically into `/tmp/k1max-wired-network-backup-<timestamp>/`).
4. Read [docs/troubleshooting.md](docs/troubleshooting.md) end-to-end.
5. Do not apply this on a printer in the middle of a long print.

### Firmware updates

After any Creality firmware update, the WiFi init scripts will likely be re-enabled and `system_config.json` may be reset. You will need to re-apply this. The author is not tracking Creality firmware releases and cannot guarantee future compatibility.

---

## 日本語

このリポジトリは **Creality K1 MAX 3Dプリンタ** の init スクリプトと設定ファイルを変更する。適用前に必ず読むこと。

### 保証

これらのスクリプトを適用すると、**メーカー保証が無効になる可能性**がある。Creality はこの変更を承認していない。保証期間中で保証を使う可能性があるなら、適用しないこと。

### リスク

init.d スクリプトのミスは以下を引き起こす可能性がある:

- プリンタが Klipper / Moonraker / Mainsail の起動に失敗
- プリンタがネットワーク上で到達不能になる(SSH 不可、Web UI 不可)
- 最悪の場合、物理的な復旧(USB フラッシュ、SD カードリセット、修理依頼)が必要な起動不能状態

スクリプトのミスで Monitor watchdog が全サービスを kill し Klipper が起動不能になった実例は [docs/troubleshooting.md](docs/troubleshooting.md) に記録してある。復旧できたのは起動時に SSH が生きていたから。**同じ運が来るとは限らない。**

### 責任

このリポジトリの内容を使うことで、以下に同意したものとする:

- プリンタの故障、保証喪失、進行中の印刷の損失、その他派生する損害について **すべて自己責任**
- 著者(**T.K DΞSIGN**)は本素材を **現状のまま** 提供し、明示・黙示問わず**いかなる保証もしない**
- 何か起きても著者にはサポート・修正・補償の**義務はない**
- これは商用製品ではなく、参考として共有された個人プロジェクト

### 適用前の推奨手順

1. 同じ LAN 上の別デバイスから SSH アクセスできる状態にしておく(復旧用)
2. プリンタの現在の IP アドレスをメモ
3. 元のファイルをバックアップ(同梱の `apply.sh` は `/tmp/k1max-wired-network-backup-<timestamp>/` に自動バックアップする)
4. [docs/troubleshooting.md](docs/troubleshooting.md) を最後まで読む
5. 長時間印刷の最中には適用しない

### ファームウェアアップデート後

Creality のファームウェアアップデート後は、WiFi init スクリプトが再有効化され、`system_config.json` がリセットされる可能性が高い。再適用が必要になる。著者は Creality のファームウェアリリースを追跡しておらず、将来の互換性は保証できない。
