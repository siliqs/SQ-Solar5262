# Meshtastic on HT-N5262M

> Originated from `25_HT5262M_test/study/meshtastic/` (separated 2026-05-15). Cross-references prefixed `../../` were rewritten as absolute URLs into the `25_HT5262M_test` repo — those upstream files were untracked at extraction time and may 404 until they're committed there.

## 目標

讓這片 HT-N5262M 加入 [Meshtastic](https://meshtastic.org/) mesh 網路，能被其他 Meshtastic 節點 ping 到、能被手機 app pair。

## 現況評估

HT-N5262M 硬體 = nRF52840 + SX1262 + TCXO，和 Meshtastic 官方支援的 `heltec_mesh_solar` variant 結構幾乎一樣。SX1262 接腳對照 → [`pinout_comparison.md`](pinout_comparison.md)，重點：

- NSS / DIO1 / BUSY 三隻完全相同
- RESET 一隻可能不同（待 schematic 確認）
- 沒有 TFT、沒有 GPS、沒有按鍵 — 都要在 variant 裡關掉

## 硬體 baseline（切 Meshtastic 前）

2026-05-15 量測：板子掛在 `/dev/tty.usbmodem21101`（macOS 上看到的描述是 "Heltec"），目前燒著 [`range_test_rx`](https://github.com/livinghuang/25_HT5262M_test/blob/main/src/range_test_rx/range_test_rx.ino)（在 `25_HT5262M_test` repo），console 持續輸出：

```
RX pwr=14 seq=N/20  rssi=-27 dBm  snr=12 dB
```

意思是 **SX1262 RX path、USB CDC、電源、現有 Arduino sketch 都正常**。換句話說後面 Meshtastic 跑不起來的話，問題出在 firmware port，不會是硬體。

`screen /dev/tty.usbmodem21101 115200` 或：
```bash
python3 -c "import serial; s=serial.Serial('/dev/tty.usbmodem21101',115200,timeout=1)
while True:
    l=s.readline()
    if l: print(l.decode('utf-8',errors='replace'),end='')"
```

## 已研究

- [`pinout_comparison.md`](pinout_comparison.md) — HT-N5262M vs `heltec_mesh_solar` / `heltec_mesh_node_t114` pin 對照
- [`firmware_structure.md`](firmware_structure.md) — Meshtastic firmware 怎麼 build、怎麼加新 variant、`PRIVATE_HW = 255` 怎麼用

## v0 bring-up 結果（2026-05-15）

✅ **Meshtastic 跑起來了。** Boot log 摘錄：

```
S:B:36,2.8.0.4827498,ht_n5262m,meshtastic/firmware
SX126xInterface(cs=24, irq=20, rst=25, busy=17)
SX126X_DIO3_TCXO_VOLTAGE ... 1.800000 V
SX126x init result 0
Frequency set to 906.875000
SX1262 init success
Init NRF52 Bluetooth
Bluetooth pin set to '123456'
Advertise
```

memory：RAM 39.1%、Flash 64.4%。SX1262 RESET 結論為 P0.25（[decision_log.md](docs/decision_log.md)）。

## 怎麼從零再 build + 燒

```bash
# 1. clone 上游 (一次性, gitignore 掉)
mkdir -p external && cd external && git clone --depth 1 --recursive https://github.com/meshtastic/firmware.git meshtastic-firmware && cd ..

# 2. symlink 我們的 variant 與 board JSON 進 meshtastic clone
ln -sfn "$PWD/src/variant/ht_n5262m" external/meshtastic-firmware/variants/nrf52840/ht_n5262m
ln -sfn "$PWD/src/boards/ht_n5262m.json" external/meshtastic-firmware/boards/ht_n5262m.json

# 3. build
(cd external/meshtastic-firmware && pio run -e ht_n5262m)

# 4. 燒（DAPLink 接好；不動 bootloader 區）
./scripts/flash_meshtastic_swd.sh

# 5. 看 console
./scripts/monitor.sh
```

回 Arduino sketch 要走 `25_HT5262M_test/scripts/restore_bootloader.sh`（DAPLink + mass_erase）+ 重燒 sketch。

## 待辦

詳見 [docs/open_issues.md](docs/open_issues.md)：region 設 TW/AS923、battery ADC 校正、手機 app BLE pairing 實測、LoRa link 對測、開 GNSS/TFT/DWM3000/RS485 周邊。

⚠️ Region 預設掉到 US 902-928 MHz，**設好 region 之前不要拉天線到戶外發送**。
