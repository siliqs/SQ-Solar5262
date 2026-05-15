# Pinout 比對：HT-N5262M vs Meshtastic 官方 nRF52840 variants

研究日期：2026-05-15
參考 commit：Meshtastic firmware `main` (2026-05-15 shallow clone)

## 結論先講

**HT-N5262M 的 SX1262 接腳和 Heltec Mesh Node T114 / Heltec Mesh Solar 幾乎完全一樣，只差 RESET 一隻**。這代表 port 難度很低，主要是抄 T114/Solar 的 variant，改 RESET pin、砍掉 GPS / TFT / 按鍵的程式碼。

## SX1262 接腳（核心）

| 訊號 | HT-N5262M（Heltec lib `board-config.h`） | HT-N5262M（sketch `lora_tx.ino`） | T114（Meshtastic） | Solar（Meshtastic） |
|---|---|---|---|---|
| NSS / CS  | P0.24 | P0.24 | P0.24 | P0.24 |
| DIO1      | P0.20 | P0.20 | P0.20 | P0.20 |
| BUSY      | P0.17 | P0.17 | P0.17 | P0.17 |
| RESET     | **P0.18** | **P0.25** | P0.25 | P0.25 |
| MISO      | P0.23 | — | P0.23 | P0.23 |
| MOSI      | P0.22 | — | P0.22 | P0.22 |
| SCK       | P0.19 | — | P0.19 | P0.19 |
| DIO2      | (用作內建 RF switch，不接 MCU) | — | 同左 (`SX126X_DIO2_AS_RF_SWITCH`) | 同左 |
| DIO3      | (TCXO 1.8 V 電源，不接 MCU) | — | 同左 (`SX126X_DIO3_TCXO_VOLTAGE 1.8`) | 同左 |

**RESET pin 衝突**：
- Heltec library 內部寫 `RADIO_RESET = 18`
- 本 repo 的 lora_tx.ino sketch 內 `#define SX126X_RESET (0+25)` — 但這個 define 是寫給 RadioLib / Meshtastic 風格的 driver 用的，**Heltec lorawan library 不認**，所以實際燒進去 SX1262 RESET 應該還是接到 P0.18

下一步：拿 [`SCH_Schematic1_2026-05-14.pdf`](https://github.com/livinghuang/25_HT5262M_test/blob/main/assets/SCH_Schematic1_2026-05-14.pdf)（在 `25_HT5262M_test` repo）確認 SX1262 RESET 真實接哪一隻 nRF52840 GPIO。這是 port 第一個要釘下來的數字。

## 周邊差異（這片 vs T114 / Solar）

| 周邊 | HT-N5262M | T114 | Solar | port 影響 |
|---|---|---|---|---|
| TFT 1.14" 顯示器 (ST7789) | ❌ 沒有 | ✓ 有，CS=P0.11, RST=P0.2, DC=P0.12 | ❌ 沒有 | 砍掉 |
| GPS (L76K, UART) | ❌ 沒有 | ✓ TX=P1.07, RX=P1.05, STANDBY=P1.02, PPS=P1.04 | ❌ 沒有（同 HT-N5262M） | 砍掉 / 不啟用 GPS subsystem |
| 按鍵 | 模組本身沒拉出來 | BUTTON1=P1.10 | 同 T114 (BUTTON1=P1.10) | 需決定：不放按鍵、或用 GPIO 拉一顆出來 |
| LED | PIN_LED1=P0.35（HT-N5262M variant 自己定義） | P1.03 (green) | P1.15 (green) | 改 variant.h 對應實際 LED 接腳 |
| VEXT 控制 | ❌ HT-N5262M 沒拉這條 | VEXT_ENABLE=P0.21 | VEXT_ENABLE=P0.21 | 砍掉 VEXT 控制 |
| VBAT ADC | PIN_BAT_ADC=P0.4, CTL=P0.6, 分壓比 4.9 | — | — | 沿用本 repo `ble_advertise.ino` 已驗證的電路與分壓比 |
| QSPI Flash | ✓ MX25R1635F | ✓ | ✓ | 同 |
| TCXO | ✓ (DIO3 控 1.8 V) | ✓ | ✓ | 同 |

## 推薦的起點：fork `heltec_mesh_solar`

理由：
1. Solar variant **沒有 TFT、沒有 GPS**，剛好和 HT-N5262M 純通訊模組對齊
2. 名字 `heltec_mesh_solar` 和未來量產目標 `silic_solar_panel_5262M` 概念一致（都是太陽能 LoRa node）
3. SX1262 部分一行不用改（除了 RESET pin）
4. Solar 用的 `nicheGraphics.h` 也比較簡單

**T114 不適合直接用**，因為它有 TFT + GPS，會 link 進一堆 HT-N5262M 沒有的硬體 driver，要砍的東西多。

## Port checklist 草稿

- [ ] 用 schematic 確認 SX1262 RESET 真實 pin（P0.18 還是 P0.25）
- [ ] 在 fork 的 firmware repo 新增 `variants/nrf52840/ht_n5262m/`
  - [ ] 複製 `heltec_mesh_solar/variant.h` 改 LED / RESET / 砍掉 VEXT
  - [ ] 複製 `platformio.ini` 改 `custom_meshtastic_hw_model_slug = HT_N5262M`、`build_flags -DHT_N5262M`
  - [ ] 改 `variant.cpp`（pin description 陣列）
- [ ] 註冊新的 `meshtastic_HardwareModel` enum（要看 firmware 怎麼配 hw_model 編號 — T114 是 69，Solar 是？需要查）
- [ ] `pio run -e ht_n5262m` 編譯通過
- [ ] SWD 燒到板子（USB DFU **不能用**，Meshtastic 不走 UF2 bootloader）
- [ ] 在 console 看到 boot log、能 BLE pair、和現有 Meshtastic 節點收得到對方
