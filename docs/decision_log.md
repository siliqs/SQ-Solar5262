# Decision Log

## 目的
這份文件用來記錄專案中的重要決策，避免團隊只知道結論，不知道脈絡。

若決策後續被校正或回滾，也應補記錄原因與影響。

## 記錄表
| 日期 | 決策 | 原因 | 決策者 | 對應 issue / commit | 影響 |
| --- | --- | --- | --- | --- | --- |
| 2026-05-15 | SX1262 RESET pin = P0.25（不是 Heltec library `board-config.h` 寫的 P0.18） | (1) Schematic 顯示 P0.18 是 nRF52840 系統 RESET（UICR.PSELRESET 預設配置），如果 SX1262 RESET 真接在 P0.18，pull low 會把 MCU 自己重開，邏輯上不可能；(2) sibling repo `25_HT5262M_test` 的 `lora_tx.ino` / `range_test_rx.ino` 都用 P0.25 並實測 RX 正常（RSSI -27 dBm 連續收）；(3) Meshtastic Solar / T114 都用 P0.25 — Heltec Mesh Solar 的核心模組就是 HT-N5262M（boards JSON 同 USB product `HT-n5262`、同 hwids），證據鏈一致 | livinghuang + AI agent | [open_issues.md#1](open_issues.md) → 已關閉 | Meshtastic ht_n5262m variant 直接抄 Solar 的 SX1262 pin 區塊，不需要改 |
| 2026-05-15 | v0 bring-up 全部關掉周邊（HAS_SCREEN=0, HAS_GPS=0, MESHTASTIC_EXCLUDE_INPUTBROKER=1） | 我們的載板「silic_solar_panel_5262M」schematic 顯示有 TFT、GNSS header、DWM3000 UWB、RS485、I2C sensor，但 v0 目標只是「LoRa + BLE + USB CDC 跑得起來」。先把 minimal port 確定可 boot，後續再分階段把周邊開起來，避免一開始就因為某個 driver init 失敗而看不到任何輸出 | livinghuang + AI agent | — | 後續開周邊功能時要分次 PR，不要一次全打開 |
| 2026-05-15 | 燒錄走 SWD via openocd + DAPLink，不走 USB DFU | (1) `program ... verify` 不做 `mass_erase`，bootloader 區與 S140 SoftDevice 區完全不動，最壞情況可以 `restore_bootloader.sh` 救回原 Arduino BSP；(2) USB DFU (`use_1200bps_touch`) 在 Meshtastic 已換成 NimBLE 之後相容性未驗證；(3) DAPLink 已連好且 host enumerate 到 (CMSIS-DAP HID + DAPLink CDC + MSC drive) | livinghuang | [scripts/flash_meshtastic_swd.sh](../scripts/flash_meshtastic_swd.sh) | 後續燒錄都走這條路徑 |
| 2026-05-15 | Variant 檔案放在我們 repo `src/variant/ht_n5262m/` + `src/boards/ht_n5262m.json`，用絕對路徑 symlink 到 `external/meshtastic-firmware/`（meshtastic clone 不版控） | (1) Variant 是專案核心產出，必須在我們 repo 內版控；(2) 上游 meshtastic/firmware 幾百 MB，gitignore 掉避免污染 repo；(3) 絕對路徑 symlink 解掉相對路徑層數算錯的 bug | AI agent | [src/variant/ht_n5262m/](../src/variant/ht_n5262m/) | 換新機器要先 `git clone meshtastic/firmware → external/` 再執行 symlink，未來可以加 `scripts/setup.sh` 自動化 |
| 2026-05-15 | I2C bus（P0.27/P0.26）改用 nRF52 內建 ~13 kΩ pull-up（在 `variant.cpp::initVariant()` 用 `pinMode(..., INPUT_PULLUP)` 啟用） | 第一次燒完 firmware 看似 boot OK、能讀 console log，但約幾十秒後就完全沒新 log 出來、meshtastic CLI `Timed out waiting for connection completion`。SWD halt 看 PC 卡在 `TwoWire::endTransmission()`（addr2line 解析 0x57e12 / 0x57e16）。原因：carrier 的 I2C sensor header 沒掛 device、也沒加外部 pull-up，SDA/SCL 浮空時，Meshtastic 週期 retry max17048 battery gauge probe 撞上 nRF52 TWIM stuck-SCL errata，busy wait 死循環。修復：開內建 pull-up 給 bus 一個確定 high 狀態，scan 直接 NACK 回來、不會 hang | AI agent | [src/variant/ht_n5262m/variant.cpp](../src/variant/ht_n5262m/variant.cpp) `initVariant()` | 之後若要接真實 I2C 周邊：(a) 內建 13kΩ 對 standard mode (100kHz) OK 但對 fast mode (400kHz) 太弱，會需要外部 pull-up；(b) 如果換 pin 也要記得改 `pinMode` 兩行 |
