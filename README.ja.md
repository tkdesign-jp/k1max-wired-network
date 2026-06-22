# K1 MAX 有線ネットワーク固定化

Creality K1 MAX を**有線LANのみで安定動作**させる。WiFi を完全に無効化し、カメラプロセスも停止する。

> 🇬🇧 English version: [README.md](README.md)
> ⚠️ 適用前に [DISCLAIMER.md](DISCLAIMER.md) を読むこと。

---

## 解決する問題

純正の K1 MAX では、Ethernet ケーブルを挿しただけでは不十分。デフォルトルートが `wlan0` 経由になっており、`S99start_app` が `wifi-server` を起動して WiFi ドライバを再初期化し続ける。UI で WiFi を「OFF」にしてもデバイスにアクセスできなくなる。

このリポジトリには、以下を実現するための boot 時スクリプトと手順が含まれる:

- `eth0` を唯一のアクティブなネットワークインターフェースにする
- 起動のたびに `wlan0` を強制 down
- `wifi-server` による WiFi 再有効化を阻止
- `mjpg_streamer`(カメラ)を停止(不要な場合)
- 再起動後の状態を検証

最終結果: K1 MAX が起動直後から有線 Ethernet で動作し、WiFi は一切触らず、カメラフレームも送らず、無線ルートに静かにフォールバックすることもない。

---

## これは何で、何ではないか

- これは**init.d スクリプト一式と設定ファイル1箇所の編集**で、適用と検証のフローが明確化されている
- **ファームウェアの mod ではなく**、フラッシュは行わない。すべて可逆
- **純正 Creality ファームウェア**スタック対象: Klipper + Moonraker + Mainsail / Buildroot 2020.02.1 / MIPS SoC / port 4409
- root化・置換ファームウェア(Kamp, Helper Script, fluidd-only 等)では**未テスト**。動く可能性は高いが、ファイルパスが異なるかもしれない

---

## ⚠️ 先に読むこと

プリンタの init.d を変更すると、モーションコントローラや Web UI が起動できなくなる可能性がある。開発中に実際に起きた問題は [docs/troubleshooting.md](docs/troubleshooting.md) に記録してあるので必ず読むこと。

**自己責任で適用すること。** [DISCLAIMER.md](DISCLAIMER.md) 参照。

---

## 動作環境

- Creality K1 MAX(このモデル限定 — K1 / K1C は調整が必要かもしれない)
- 純正ファームウェア(Klipper + Moonraker + Mainsail)
- SSH アクセス有効、root パスワード既知
- プリンタが LAN 上で到達可能、IP 既知(例: `192.168.1.19`)
- 同じ LAN 上に別デバイス(ラップトップ)があり、SSH で復旧できる

---

## 何が変更されるか

| 対象 | 操作 | 効果 |
|---|---|---|
| `/etc/init.d/S43wifi_bcm_init_config` | `chmod -x` | WiFi ドライバ初期化を無効化(ファイルは保持) |
| `/etc/init.d/S44wifi_bcm_up` | `chmod -x` | WiFi 起動を無効化(ファイルは保持) |
| `/usr/data/creality/userdata/config/system_config.json` | 編集 | `user_info.wifi_sw` → `0` |
| `/etc/init.d/S41eth0_primary` | 新規作成 | S43/S44 / S99 より前に `wlan0` を down |
| `/usr/data/printer_data/config/verify_network.sh` | 新規作成 | 再起動後の自己検証 |

すべて**可逆**: S43/S44 を `chmod +x` で戻し、`wifi_sw` を `1` に戻し、`S41eth0_primary` を削除すれば、次回起動で工場出荷状態に戻る。

---

## このリポジトリのファイル

```
scripts/
├── S41eth0_primary       wlan0 を強制 down する boot スクリプト
├── verify_network.sh     再起動後のネットワーク状態確認
└── apply.sh              一発適用スクリプト(プリンタ上で SSH 経由実行)

docs/
└── troubleshooting.md    開発中に壊れた経緯と原因
```

---

## インストール

### 方法1: 同梱スクリプトで適用

root として SSH ログイン、リポジトリを取得し `apply.sh` を実行:

```bash
# プリンタ上(root で SSH ログイン)
cd /tmp
wget https://github.com/tkdesign-jp/k1max-wired-network/archive/refs/heads/main.tar.gz
tar xzf main.tar.gz
cd k1max-wired-network-main
sh scripts/apply.sh
```

`apply.sh` の動作:

1. 影響を受けるファイルを `/tmp/k1max-wired-network-backup-<timestamp>/` にバックアップ
2. S43/S44 を `chmod -x` で無効化
3. `system_config.json` にパッチを当て `wifi_sw: 0` に
4. `S41eth0_primary` を `/etc/init.d/` に正しい権限で配置
5. `verify_network.sh` を `/usr/data/printer_data/config/` に配置

その後プリンタを再起動:

```bash
reboot
```

復帰後、Mainsail のコンソール(または SSH)から検証スクリプトを実行:

```bash
sh /usr/data/printer_data/config/verify_network.sh
```

すべて `[OK]` 行が出るはず。下記の「期待される出力」参照。

### 方法2: 手動で実行

[docs/troubleshooting.md](docs/troubleshooting.md) に各変更を正確なコマンドで記述してある。各ステップを理解してから実行したい場合はこちらが安全。

---

## `verify_network.sh` の期待される出力

```
[OK]  eth0 has 192.168.1.19 (または相応の有線 IP)
[OK]  wlan0 is DOWN (IP なし)
[OK]  default route is via eth0
[OK]  wpa_supplicant is not running
[OK]  mjpg_streamer is not running
[OK]  Klipper / Moonraker / nginx / Dropbear all running
[OK]  Mainsail reachable on port 4409
```

`[FAIL]` 行があれば [docs/troubleshooting.md](docs/troubleshooting.md) を参照。

---

## 元に戻す

純正動作に戻すには:

```bash
# プリンタ上(root で SSH ログイン)
chmod +x /etc/init.d/S43wifi_bcm_init_config
chmod +x /etc/init.d/S44wifi_bcm_up
rm /etc/init.d/S41eth0_primary
# system_config.json を編集し wifi_sw を 1 に戻す
reboot
```

`apply.sh` が作成したバックアップ(`/tmp/k1max-wired-network-backup-<timestamp>/`)に元のファイルが入っている。

---

## 既知の制限

- `mjpg_streamer` は `wifi-server` が起動しなくなったために結果として停止しているだけ。何か別の方法でカメラ経路を再有効化すれば復活する。このセットには単独の「カメラ無効化」トグルはない
- Creality のファームウェアアップデートで WiFi スクリプトが再有効化される可能性がある。Creality アップデート後は `apply.sh` を再実行すること
- `/usr/data/creality/userdata/config/system_config.json` のパスは純正 K1 MAX ファームウェア。改造ファームウェアでは異なる場所かもしれない

---

## ライセンス

[MIT](LICENSE) — 自由に使ってよい、無保証。[DISCLAIMER.md](DISCLAIMER.md) も参照。
