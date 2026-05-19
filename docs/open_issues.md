# Open Issues Register

## 目的
這份文件用來集中整理「必要但尚未確認」的事項，以及已在 GitHub 建立的對應 open issues。

原則很簡單：只要這個未知事項會影響專案方向、交付、風險、時程或品質，就不能只放著不管，必須進入追蹤。

## 使用規則
1. AI agents 可主動在 GitHub 建立或更新 issue，再把連結寫回這份文件。
2. 如果 issue 尚未建立，狀態不得標示為完成。
3. 每一列都要有 owner。
4. blocking 類 issue 要在每日或每週狀態更新中追蹤。
5. 問題解決後，關閉 GitHub issue，並同步更新這份文件。
6. 若人類要求 correction / rollback，對應 issue 應補記錄原因與後續處理。

## 追蹤表
| 類別 | 項目 | 為何重要 | GitHub Issue | Owner | 目標日期 | 狀態 | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| blocking | 專案主資訊完整性檢查 | 確認專案目標、範圍、owner、里程碑與必要 unknowns 是否缺漏 | [#1](https://github.com/livinghuang/26_meshtastic_on_ht_n5262m/issues/1) | AI agents | 2026-05-15 | open | 自動建立的第一張 bootstrap review issue |
| blocking | SX1262 RESET 真實 GPIO 確認 | 影響 variant pin 定義；錯了 radio init 必失敗 | — | livinghuang | 2026-05-15 | **closed** | 2026-05-15 結論 P0.25，三方證據一致（[decision_log.md](decision_log.md)），Meshtastic boot log 顯示 `SX1262 init success` 驗證 |
| decision-needed | Meshtastic region 設為 TW/AS923（923 MHz） | v0 預設掉到 US 902-928 MHz，在台灣不合法，不能拉天線到戶外發送 | — | livinghuang | TBD | open | 兩條路徑：(a) 透過 Meshtastic Android/iOS app 設定，(b) build flag 直接 hardcode（待查 `-DAS923_DEFAULT=1` 或 `userPrefs.jsonc`） |
| follow-up | 手機 app BLE pairing 實測 | boot log 顯示 BLE advertise 起來、PIN=123456，但還沒實際拿手機配對 | — | livinghuang | TBD | open | Meshtastic Android app + 板子 USB 接電 → 應能掃到 |
| correction | v0 firmware I2C bus hang | 第一次燒完 firmware 看似 boot OK、能讀 console log，但約幾十秒後完全沒新 log 出來、meshtastic CLI 連不上。SWD halt 確認卡在 `TwoWire::endTransmission()`，因 carrier I2C 線浮空 + 無 pull-up + max17048 retry 撞上 nRF52 TWIM stuck-SCL errata | — | AI agent | 2026-05-15 | **closed** | 修法：`variant.cpp::initVariant()` 開內建 pull-up（[decision_log.md](decision_log.md)）。重燒後 meshtastic CLI 能正常 `--info`、firmware 不再 hang |
| correction | I2C / LED pin map 跟 25_HT5262M_test schematic-verified 不一致 | I2C 原寫 P0.27/P0.26 — 但 P0.27 是 carrier 上 DWM3000 MISO；LED 原寫 P1.15 — 但 P1.15 是 RS485 RX；上一條的 internal pull-up "修復" 其實只是 hack 蓋住 pin 選錯的症狀 | — | AI agent | 2026-05-19 | **closed** | 改 SDA=P1.00、SCL=P1.01、LED=P1.11；I2C 內建 pull-up 移除（carrier 有外部 5.1k）。見 [decision_log 2026-05-19](decision_log.md) |
| correction | SWD `program ... verify` 燒完 app 永遠不執行 | openocd verify OK 但 chip 卡在 SoftDevice 區、HW BP 在 Reset_Handler/main/setup 都沒打到；USBD ENABLE=0；root cause = SWD program 不更新 0xFF000 BL settings page，Heltec bootloader 看不到 valid app marker | — | AI agent + livinghuang | 2026-05-19 | **closed** | 用 `25_HT5262M_test/scripts/restore_bootloader.sh` 重燒 BL + S140，之後改走 UF2 drag-drop（[scripts/flash_meshtastic_dfu.sh](../scripts/flash_meshtastic_dfu.sh)） |
| follow-up | Battery ADC 讀數校正 | boot log 顯示 `voltage=16.469999`，明顯錯。原因：ADC_CTRL (P0.06) 沒驅動 high，BAT 經 390k/100k divider 的路徑沒 enable | — | AI agent | 2026-05-19 | **closed** | 修法：在 [variant.h](../src/variant/ht_n5262m/variant.h) 用 Meshtastic `ADC_CTRL`/`ADC_CTRL_ENABLED` macro convention（不放 `initVariant()` — 那會被 Meshtastic 後面 init 重置），由 [`battery_adcEnable()`](https://github.com/meshtastic/firmware/blob/main/src/Power.cpp) 量測前後 toggle。`meshtastic --info` 現在回 `voltage: 4.228 V` ✓ |
| follow-up | LoRa link 實測 | 還沒第二台 Meshtastic node 對測，無法確認 TX path、天線、實際距離 | — | livinghuang | TBD | open | 找另一台 Heltec / RAK / T-Beam 對測 |
| follow-up | 開周邊：GNSS / TFT / DWM3000 / RS485 | v0 全關了。載板有這些介面，後續分階段啟用 | — | TBD | TBD | open | 分次 PR：先 GNSS、再 TFT、最後 DWM3000 / RS485 |
| follow-up | scripts/setup.sh 自動 clone + symlink | 換新機器或新 contributor 需要重複手動步驟，可以自動化 | — | AI agent | TBD | open | clone meshtastic-firmware → 建 symlink → 第一次 build |

## 建議的 issue 內容模板
```markdown
Title: [Unknown] <要確認的事項>

## 背景
這個資訊目前缺失，但會影響專案執行。

## 為什麼需要確認
- 

## 若不處理的風險
- 

## 預期輸出
- 

## Owner
- 

## 目標日期
- 
```
