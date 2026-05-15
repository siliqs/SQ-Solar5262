# Status

## 目的
這份文件用來提供固定格式的狀態更新，讓人類與 AI agents 都能快速掌握專案目前進度、風險與下一步。

## 最新狀態

- 日期：2026-05-15
- 整體狀態：`green`
- 本期摘要：v0 minimal port 完成。Meshtastic 韌體 build → SWD 燒錄 → boot 成功。SX1262 init 成功（pin: cs=24, irq=20, rst=25, busy=17，TCXO @ 1.8V），BLE advertising 起來（pairing PIN: `123456`）。
- 目前階段：v0 bring-up 完成，準備進入 v1（region 設成 TW/AS923、battery ADC 校正、手機 app 配對驗證）

## 已完成
- SX1262 RESET pin 確認為 P0.25（從 schematic + 相容硬體 + 經驗證據三方驗證）
- Meshtastic variant `ht_n5262m` 建立（`src/variant/ht_n5262m/` + `src/boards/ht_n5262m.json`）
- PIO build 成功：RAM 39.1%、Flash 64.4%
- SWD 燒錄成功（保留 bootloader 與 SoftDevice 區）
- Boot log 確認所有子系統 init OK：FS、NodeDB、SX1262、Power FSM、BLE
- 燒錄與監看腳本：[scripts/flash_meshtastic_swd.sh](../scripts/flash_meshtastic_swd.sh)、[scripts/monitor.sh](../scripts/monitor.sh)

## 進行中
- 文件收尾、commit

## 開放 / 阻塞 issue
詳見 [open_issues.md](open_issues.md)：
- Region 是 UNSET（預設掉到 US 902-928 MHz），TW 應走 AS923（923 MHz） — 法規問題，不能直接拿出去戶外發送
- Battery ADC 讀數錯（16.47V），ADC_CTRL (P0.06) 沒驅動 high，divider 沒生效
- 手機 app BLE pairing 還沒實測
- 沒有第二台 Meshtastic node 可以對測 RF link

## 風險與注意事項
- ⚠️ 在設好 region 之前不要把天線拉到戶外發送 — 預設 US band 在台灣不合法
- 板子目前不能再透過 Arduino sketch 燒錄（USB DFU bootloader 還在但 BSP variant 已不同），要回 Arduino 必須走 `restore_bootloader.sh`（DAPLink + mass_erase）
- 上游 meshtastic clone 在 `external/meshtastic-firmware/`，已 gitignore，換機器要重 clone

## 下一步
1. 用 Meshtastic Android app 試 BLE pairing，看是否能配對成功、能設 region 與 channel
2. 透過 BLE config 把 region 設成 TW/AS923（或在 build flag 加 `-DAS923_DEFAULT=1`，待研究）
3. 修 Battery ADC：variant.cpp `initVariant()` 加 `pinMode(P0.06, OUTPUT); digitalWrite(P0.06, HIGH);` 驅動 ADC_CTRL
4. 找第二台 Meshtastic 對測，驗證 mesh 通訊
5. 後續再開 GNSS / TFT / DWM3000 子系統（分次 PR）
