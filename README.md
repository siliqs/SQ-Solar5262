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

## 還沒確認的關鍵點

- [ ] SX1262 RESET 真實 GPIO（library 寫 P0.18，sketch 寫 P0.25，要用 [`SCH_Schematic1_2026-05-14.pdf`](https://github.com/livinghuang/25_HT5262M_test/blob/main/assets/SCH_Schematic1_2026-05-14.pdf)（在 `25_HT5262M_test` repo）釘下來）
- [ ] Meshtastic region table 怎麼設成 TW / AS923（923 MHz）
- [ ] Meshtastic 用 NimBLE 燒下去後，要回 Arduino 是否還能靠 `scripts/restore_bootloader.sh` 救回（理論可，待驗證）

## 下一步動作

1. 看 schematic 確認 RESET pin
2. Fork `meshtastic/firmware`，複製 `variants/nrf52840/heltec_mesh_solar` → `variants/nrf52840/ht_n5262m`
3. 改 pin、改 `[env]` 名稱、設 `-DHT_N5262M`、`hw_model = PRIVATE_HW (255)`
4. `pio run -e ht_n5262m` 編譯
5. 用 SWD（[`flash_swd.sh`](https://github.com/livinghuang/25_HT5262M_test/blob/main/scripts/flash_swd.sh) — 在 `25_HT5262M_test` repo）燒進去
6. 看 console boot log、試手機 app BLE pairing、和現有 Meshtastic 節點互測

完整步驟見 [`firmware_structure.md`](firmware_structure.md) 末尾的清單。
