# Debug: 「裝置持續 reboot / 螢幕一直閃」調查記錄

## 目的
留給下一位接手的 AI agent / 工程師。這份是 **未完成** 的調查筆記，不是結論。重點在記下 **已驗證的事實**、**已排除的假設**、和 **接下來最應該做的事**，避免下一個人重走我走過的路。

- 日期：2026-05-20
- 投入時間：~1 session
- 整體狀態：`yellow` — root cause 未確定，已知 NVS 曾被弄亂、目前 config 落回 defaults。
- 接手：把 [external/meshtastic-firmware](../external/meshtastic-firmware) 視為 read-only 上游，本 repo 改動以 variant + scripts + docs 為主。

---

## 1. 使用者回報的症狀演進

回報順序（每一行都是一次澄清，前面的描述被後面修正）：

1. 「the device look contiounly reboot」
2. 詢問下進一步說明：`APP disconnect`（Meshtastic 手機 APP 一直斷線）
3. APP 透過 **BLE** 連，斷線節奏「連上後幾十秒到幾分鐘才斷」
4. 再下一輪：「could I make the LCM is contiounsely on? currently it becom dark, while and return as flash」 — **真正觀察到的是 TFT 變暗、過一陣子又閃亮**
5. 把 `display.screen_on_secs` 從 600 改成 31536000（1 年）後 → 「now it contiouns ly filash again and again」 → 症狀變嚴重

也就是說 user 一開始用「reboot」描述的，**其實是 TFT 在閃**。

---

## 2. 已驗證的事實（用 DAPLink + meshtastic CLI 量過）

### 2.1 CPU 沒有 reboot
SWD halt 三次間隔 200ms（[scripts/flash_meshtastic_swd.sh:18-20](../scripts/flash_meshtastic_swd.sh#L18-L20) 那組 openocd），三次都停在同一點：

```
halt #1  pc=0x0009280c  lr=0x00092779  xPSR=0x61000000  RESETREAS=0
halt #2  pc=0x0009280c  lr=0x00092779
halt #3  pc=0x0009280c  lr=0x00092779
```

- 同樣 PC 連三次 → CPU 待在 WFE/idle loop，沒在 boot path
- `RESETREAS = 0` → 上次 reset 之後 firmware 已清掉所有 sticky bits（Adafruit BSP 開機會做），或只發生過 power-on reset
- `GPREGRET = 0`、`GPREGRET2 = 0` → 沒有 DFU 觸發
- `meshtastic --info` 回應正常，`rebootCount: 0`

**結論：CPU 不是 boot loop。「閃」是 display-level 的現象。**

### 2.2 TFT GPIO 真的在被 toggle
P0.OUT @ `0x50000504`，採樣 20 次 × 400ms：

```
sample 1-17  : 0xffb77fb7   bit3=0, bit15=0  → VTFT_CTRL & VTFT_LEDA 都 LOW → 面板+背光 ON
sample 18-20 : 0xffffffff   bit3=1, bit15=1  → 都 HIGH → 面板+背光 OFF
```

P-MOSFET active LOW，所以 bit=0 是 ON、bit=1 是 OFF（[variant.h:60-62](../src/variant/ht_n5262m/variant.h#L60-L62)）。

實際 firmware 寫這兩條的位置：[Screen.cpp:595-602](../external/meshtastic-firmware/src/graphics/Screen.cpp#L595-L602)（OFF path）、[Screen.cpp:527-533](../external/meshtastic-firmware/src/graphics/Screen.cpp#L527-L533)、[Screen.cpp:552-560](../external/meshtastic-firmware/src/graphics/Screen.cpp#L552-L560)（ON path）。OFF/ON 觸發點都來自 `Screen::handleSetOn(bool)`。

### 2.3 PowerFSM 路徑（程式碼閱讀）
[PowerFSM.cpp:309](../external/meshtastic-firmware/src/PowerFSM.cpp#L309)：boot 3 秒後 → POWER（USB 在）或 ON。
[PowerFSM.cpp:402-407](../external/meshtastic-firmware/src/PowerFSM.cpp#L402-L407)：ON 與 POWER 都會在 `screen_on_secs` 秒後 timed_transition 到 stateDARK。
[PowerFSM.cpp:209-217](../external/meshtastic-firmware/src/PowerFSM.cpp#L209-L217)：`darkEnter()` call `screen->setOn(false)` → 觸發 2.2 看到的 GPIO 變化。

### 2.4 NVS 在我們調 config 期間被弄亂
對照三次 `meshtastic --info` 的 owner / node 身分：

| 時間點 | myNodeNum | nodedbCount | owner | rebootCount |
|---|---|---|---|---|
| 一開始 | `12191505` (`!00ba0711`) | 2（看得到 peer `!d47d10f0`） | `Meshtastic 0711` | 0 |
| 設 `screen_on_secs=31536000` 之後 | **`224740446`** | **1** | (消失) | 0 |
| 設回 `86400` 之後再 `--get display` | — | — | — | — |
| 最終確認 | — | — | — | `display.screen_on_secs: 600`（**也不是我們設的 86400**） |

也就是說：
- 設 31536000 之後 node 身分 **整個被換掉**、peer DB 清空
- 設回 86400 沒有生效（落地後又被覆寫成預設 600）
- 我們的 config 寫入會無聲被 wipe，**這是目前最大未解的謎**

可能原因（尚未驗證）：
- a. 31536000 不會 uint32 overflow（[Default.cpp:6-10](../external/meshtastic-firmware/src/mesh/Default.cpp#L6-L10) 有 24.86 天 clamp），但可能觸發 NodeDB 的合法性檢查 → factory reset
- b. LittleFS 寫入失敗 → fallback 到 defaults
- c. PKC / device key 重生 → 連帶 myNodeNum 改變

### 2.5 沒有確認、但很可疑：OpenOCD init 可能在 nRESET pulse
`scripts/flash_meshtastic_swd.sh` 用的 [daplink_nrf52.cfg](~/Library/Arduino15/packages/Heltec_nRF52/hardware/Heltec_nRF52/1.7.0/scripts/openocd/daplink_nrf52.cfg) 只 source `target/nrf52.cfg`，預設可能會在 `init` 時 pulse nRESET。如果為真，我們的 SWD 採樣每次都讓裝置重啟一次 — 那「7 秒從 ON 到 OFF」其實就是「reset 後 3 秒 BOOT timeout + 4 秒到 DARK 的轉換」，並不是真實穩態。

**下一個 agent 第一步要驗證的就是這個。** 用 `openocd ... -c "init" -c "echo done"` 之後，立刻看 `meshtastic --info` 的 `rebootCount` 有沒有 +1。如果有，後面所有 SWD 採樣結論都要重看。

---

## 3. 已排除的假設

- ❌ **CPU boot loop**：SWD halt 三連發證偽（§2.1）
- ❌ **BLE supervision timeout 太短**：[NRF52Bluetooth.cpp:321](../external/meshtastic-firmware/src/platform/nrf52/NRF52Bluetooth.cpp#L321) 沒設 supervision timeout 是真的，但 user 後來說 symptom 是 TFT 閃，不是 APP 斷線，所以這個假設先擱著。**未來如果 user 真的回報 APP 在 LoRa TX 期間斷線，再回來處理。**
- ❌ **uint32 overflow on `screen_on_secs * 1000`**：[Default.cpp:6-10](../external/meshtastic-firmware/src/mesh/Default.cpp#L6-L10) 有 `INT32_MAX` clamp，不會 overflow
- ❌ **TFT 硬體閃**：GPIO 直接被 toggle（§2.2），是 firmware 主動關，不是電源 sag / 硬體 glitch

---

## 4. 我們對 NVS 動過什麼（重要：尚未復原）

| 動作 | 結果 |
|---|---|
| `--set display.screen_on_secs 31536000` | NVS 被 wipe，myNodeNum 從 `12191505` 換成 `224740446`，peer DB 清空 |
| `--set display.screen_on_secs 86400` | 看似成功（`Writing display configuration to device`）但後來 `--get` 回 600，沒生效 |
| 最後狀態 | `display.screen_on_secs: 600`（default）；其他 config 是否仍 default 化未驗證 |

**沒做的事：沒重 build、沒重 flash、沒改 source code。** 只有 CLI config 改動，且都已被 NVS 回滾。

---

## 5. 接手後建議的順序

1. **先確認 OpenOCD init 會不會 reset 裝置**
   - `meshtastic --info` 拿 `rebootCount` (A)
   - 跑 `openocd -c init -c exit`
   - 再 `--info` 拿 `rebootCount` (B)
   - 如果 B > A → SWD 觀察值全部要打折，§2.2 那個 7 秒週期不是真實穩態
   - 對應的話，要改 `daplink_nrf52.cfg` 加 `reset_config srst_only srst_nogate connect_assert_srst` 或乾脆改用 `init; halt` 不 reset 的方式

2. **重新 verify TFT 行為，不靠 SWD**
   - 用 monitor.sh 看 serial（如果 firmware log 還有出來）
   - 或直接眼睛盯 TFT，記下從上電到第一次變暗的秒數
   - 期望：~600 秒（default `screen_on_secs`），不是 7 秒

3. **NVS 為什麼被 wipe — 復現一次看看**
   - 重 flash 一次乾淨 firmware（DFU 流程，[scripts/flash_meshtastic_dfu.sh](../scripts/flash_meshtastic_dfu.sh)）
   - `--info` 記下 `myNodeNum`、`nodedbCount`
   - 再 `--set display.screen_on_secs 31536000`
   - 再 `--info`，看 myNodeNum 是否再次改變
   - 如果會復現，issue 在 Meshtastic upstream 對極大 `screen_on_secs` 值的處理，要往 NodeDB save / load 路徑追

4. **永遠 always-on 的合法做法**
   - 不要再用很大的 `screen_on_secs`（可能觸發 §2.4 的問題）
   - 可選方案：
     - a. 用 `86400`（1 天）— 已驗證會被 NVS 拒絕（沒生效），原因待查
     - b. 改 firmware：在 variant 加 `#define DEFAULT_SCREEN_ON_SECS 0xFFFFFFFF` 之類 + clamp 處理；或直接在 PowerFSM_setup 把那兩條 timed_transition 砍掉
     - c. 註解掉 [Screen.cpp:586](../external/meshtastic-firmware/src/graphics/Screen.cpp#L586) 那段 `dispdev->displayOff()` 與 [Screen.cpp:595-602](../external/meshtastic-firmware/src/graphics/Screen.cpp#L595-L602) — 但要評估對其他 power state 的副作用

5. **如果 user 後來又抱怨 BLE 斷線（§3 第二項）**
   - 把 [NRF52Bluetooth.cpp:321](../external/meshtastic-firmware/src/platform/nrf52/NRF52Bluetooth.cpp#L321) 補上 `Bluefruit.Periph.setConnSupervisionTimeout(600);`（6 秒）
   - rebuild + reflash + 觀察

---

## 6. 工具與環境快照

- USB CDC（app）：`/dev/cu.usbmodem213101`（**注意**：python `dtr=True` open 之後，斷掉再 open 可能會 stuck — ioreg 會顯示 `!registered, !matched, inactive, busy`。解法：拔插 USB。可參考 [reference_nimble_setvalue_notify_race](../docs/) 沒寫但是這個 mac 上的記憶）
- DAPLink CMSIS-DAP：`/dev/cu.usbmodem8302`
- OpenOCD：`~/Library/Arduino15/packages/arduino/tools/openocd/0.11.0-arduino2/bin/openocd`
- DAPLink cfg：`~/Library/Arduino15/packages/Heltec_nRF52/hardware/Heltec_nRF52/1.7.0/scripts/openocd/daplink_nrf52.cfg`
- 可用 `mdw 0x50000504` 讀 P0.OUT 來看 TFT enable 狀態（bit 3 = VTFT_CTRL，bit 15 = VTFT_LEDA，0 = ON）
- meshtastic CLI 已裝在 `~/.local/bin/meshtastic`

## 7. firmware 版本與身分（最後一次 --info）

```
firmwareVersion : 2.8.0.4827498
pioEnv          : ht_n5262m
hwModel         : NRF52_UNKNOWN
role            : CLIENT
myNodeNum       : 224740446    ← 不是原本的 12191505，已被覆寫
rebootCount     : 0
display.screen_on_secs : 600
```

---

## 8. 給 successor agent：協作模型對齊

這個 repo（[siliqs/SQ-Solar5262](https://github.com/siliqs/SQ-Solar5262)）由 **多個 AI agent 並行協作**。接手前先讀懂以下幾點，避免踩到別人的 work-in-progress。

### 8.1 同時在動的 agent
- **我**（Opus 4.7 on `living@mac`）：本次調查的執行者；負責 hand-off 文件、scripts、整體偵錯，**不主動改 variant source**。
- **另一個 agent**（Sonnet 4.6 on `julianoccross-2026` 上的 macOS user）：也對這個 repo commit。memory 上的記錄只說「也會 commit」，沒明指範圍 — 從 `git log --author` 可以看出他寫過的部分（推測是 build/flash 跟 Zephyr/upstream toolchain 整合，但 **不要假設**，請實際看 commit 內容確認）。

### 8.2 變更範圍 ownership（**待 Living 確認**）

下面是預設假設，**接手第一步請先 push 前在 chat 問 Living 確認**：

| 區域 | 預設假設 | 不確定點 |
|---|---|---|
| `src/variant/ht_n5262m/variant.{h,cpp}` | 任一 agent 都可動，但動之前要在 commit message 寫清楚 why | 是否另一個 agent 視為「他的」？需問 |
| `src/variant/ht_n5262m/platformio.ini` | 同上 | 同上 |
| `src/boards/ht_n5262m.json` | 同上 | 同上 |
| `scripts/` | flash/monitor 由我建立、可共用維護 | — |
| `patches/` | 上游 Meshtastic patch，誰加都行但要記在 README | — |
| `external/meshtastic-firmware/` | **read-only**，跟 upstream sync 由人類做 | — |
| `docs/` | 任一 agent 可寫，但 status.md 是「正式狀態」、debug-*.md 是「調查記錄」，請分開 | — |

### 8.3 Branch 策略
- 兩個 agent **都 commit 到 `main`**。沒有 feature branch convention。
- **PULL/REBASE**，不要 force-push。memory 明確記載這條。
- Push 前一律 `git pull --rebase origin main` 一次，跑通 build（如果改了 source）再 push。

### 8.4 與 Living（人類）的通訊協議
- **push 完一定回報**。Living 在 chat 上會看到 push 通知後立刻 `git pull`，所以 push 失敗時也要明說。
- 不要積太多 local commit 不 push — 另一個 agent 可能也在改，越晚 push rebase 越痛。
- 主要互動工作站：`living@mac`（這台）。`julianoccross-2026` 那邊是另一個 agent 跑的 worker，不是 Living 本人主用。

### 8.5 對 successor 的第一個 action（建議）
1. `cd /Users/living/Projects/26_meshtastic_on_ht_n5262m && git pull --rebase`
2. 讀完本文件全部
3. 跑 §5 的第 1 步（驗證 OpenOCD 是否 reset 裝置），這是後續所有結論的前提
4. 跑 §5 的第 3 步（NVS wipe 復現實驗）
5. 任何 source 改動前，**先在 chat 問 Living「我要動 variant.h，OK 嗎」** — 避免跟另一個 agent 撞到

### 8.6 此次調查產出的 deliverable
- 本文件（[docs/debug-screen-flash.md](debug-screen-flash.md)）
- **沒有 source code 改動**、**沒有 NVS 修復**、**沒有重新 flash**
- NVS 目前狀態是被弄亂後的 default，不是健康狀態 — 接手可以選擇 reflash 重來 or 帶著這個狀態繼續查

