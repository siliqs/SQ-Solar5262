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

## v0 bring-up 結果（2026-05-15 → 2026-05-19 修正完）

✅ **Meshtastic 跑起來了。** `meshtastic --info` 摘錄：

```
Owner: Meshtastic 3cac (3cac)
firmwareVersion: 2.8.0.4827498
pioEnv: ht_n5262m
hasBluetooth: true
deviceMetrics: { batteryLevel: 101, voltage: 4.228, uptimeSeconds: 290 }
```

memory：RAM 39.1%、Flash 64.4%。

## Pin map（2026-05-19 cross-checked against 25_HT5262M_test）

Carrier 板（silic_solar_panel_5262M v1）的真實接腳，全部在 25_HT5262M_test Zephyr 端 schematic-verified 過。變更紀錄見 [decision_log](docs/decision_log.md)。

| 訊號 | Pin | 來源驗證 |
|---|---|---|
| SX1262 NSS / CS  | P0.24 | [lora_tx.ino](https://github.com/livinghuang/25_HT5262M_test/blob/main/src/lora_tx/lora_tx.ino) + Meshtastic boot |
| SX1262 DIO1      | P0.20 | 同上 |
| SX1262 BUSY      | P0.17 | 同上 |
| SX1262 RESET     | P0.25 | 同上（Meshtastic init OK；P0.18 是 nRESET 不能用） |
| SPI MISO/MOSI/SCK | P0.23 / P0.22 / P0.19 | Solar variant，已驗 |
| **I2C SDA / SCL**  | **P1.00 / P1.01** | [i2c_hdc1080_zephyr](https://github.com/livinghuang/25_HT5262M_test/blob/main/src/i2c_hdc1080_zephyr/boards/nrf52840dk_nrf52840.overlay) HDC1080 已讀通；外部 5.1k pull-up（R30/R31） |
| **LED1**           | **P1.11** | 載板無 user LED，挑一隻浮空 pin；**避開 P1.15（RS485 RX）** |
| **BAT ADC + CTRL** | P0.04 + P0.06 | divider 4.9x；CTRL 由 Meshtastic `battery_adcEnable()` 量測前後 toggle |

→ [pinout_comparison.md](pinout_comparison.md) 還有完整周邊（TFT / GNSS / RS485 / DWM3000）的 pin 對照給未來啟用周邊用。

## 怎麼從零再 build + 燒（建議流程）

```bash
# 1. clone 上游 (一次性, gitignore 掉)
mkdir -p external && cd external && \
  git clone --depth 1 --recursive https://github.com/meshtastic/firmware.git meshtastic-firmware && \
  cd ..

# 2. symlink 我們的 variant 與 board JSON 進 meshtastic clone
ln -sfn "$PWD/src/variant/ht_n5262m" external/meshtastic-firmware/variants/nrf52840/ht_n5262m
ln -sfn "$PWD/src/boards/ht_n5262m.json" external/meshtastic-firmware/boards/ht_n5262m.json

# 3. build
(cd external/meshtastic-firmware && pio run -e ht_n5262m)

# 4. 燒（DAPLink 接好 → 自動進 UF2 bootloader → drag-drop UF2）
./scripts/flash_meshtastic_dfu.sh

# 5. 驗
meshtastic --port /dev/cu.usbmodem???? --info
# 或：./scripts/monitor.sh /dev/cu.usbmodem????
```

**首次燒（或 bootloader 被弄壞）**：先跑一次 `../25_HT5262M_test/scripts/restore_bootloader.sh`（mass_erase + 重燒 Heltec BL + S140），再回來跑步驟 4。

回 Arduino sketch 也走 `restore_bootloader.sh` + 重燒 sketch。

## ⚠️ 不要用 `flash_meshtastic_swd.sh`

那條路 openocd 會 `Verify OK` 但 chip **永遠不會跑到 app**（bootloader 把 app slot 當無效）。詳見下面的「Bring-up history」。腳本還在 repo 裡只是給 SWD-debug 用，預設請走 `flash_meshtastic_dfu.sh`。

## Bring-up history（2026-05-19 踩過的坑）

按時間線：

1. **變了三個 pin（[variant.h](src/variant/ht_n5262m/variant.h)、[variant.cpp](src/variant/ht_n5262m/variant.cpp)）跟 25_HT5262M_test 已驗證對齊**：
   - I2C `P0.27/P0.26` → `P1.00/P1.01`（P0.27 其實是 DWM3000 MISO）
   - LED `P1.15` → `P1.11`（P1.15 是 RS485 RX）
   - BAT_CTL（P0.06）改用 Meshtastic 的 `ADC_CTRL`/`ADC_CTRL_ENABLED` macro convention，讓 [`battery_adcEnable()`](https://github.com/meshtastic/firmware/blob/main/src/Power.cpp) 自己 toggle；放 `initVariant()` 試過，會被 Meshtastic 後面 init 重置回 INPUT，所以白拉

2. **第一次燒 — SWD `program ... verify` 全部 OK，但 chip 像死了一樣**：
   - USB CDC enumerate 看得到 (HT-n5262 PID 0x4405) 但沒任何輸出
   - openocd halt + sample PC 12 次全部在 SoftDevice 區（0x4xxx–0x9xxx）、**app code (>=0x26000) 一次都沒摸到**
   - HW breakpoint 設在 Reset_Handler / main / setup 三個位址 — **10 秒內全部沒打到**
   - USBD ENABLE=0、NVIC USBD IRQ 沒在 ISER1 — USB 被軟體跳過
   - RESETREAS=0x4 (SREQ)、SHCSR=0x70000 (fault active flags) — 暗示 chip 經歷過 fault

3. **Root cause**：SWD `program ... verify` 寫了 0x26000+ 的 app 區，但**沒更新** 0xFF000 的 Adafruit bootloader settings page。Heltec bootloader（0xF4000+）開機讀 settings page 確認 app valid；看到 sentinel 0xff → 把 app slot 當成「沒安裝」→ 自己留在 OTA DFU 模式（透過 SD 跑 BLE 廣告，所以 PC 全在 SD 區）。Verify OK 騙了我們。

4. **解法 — 走 UF2 drag-drop**：
   - `25_HT5262M_test/scripts/restore_bootloader.sh` 把 BL+SD 重燒（順便清 settings page）
   - 進 UF2 bootloader：`/Volumes/HT-n5262` mount 出現
   - `cp firmware-*.uf2 /Volumes/HT-n5262/CURRENT.UF2` → bootloader 邊收邊寫，原子地更新 settings page，重啟接管 app
   - **第一次起來：`meshtastic --info` 回 `voltage: 17.635 V`** ← BAT_CTL fix 沒生效
   - 改用 `ADC_CTRL` macro → 重燒 → **`voltage: 4.228 V`** ✅

5. **DFU 進入方式（[flash_meshtastic_dfu.sh](scripts/flash_meshtastic_dfu.sh)）**：
   - DAPLink 寫 `0x57` 到 `NRF_POWER->GPREGRET` (0x4000051C) + soft reset，bootloader 看到 magic 進 UF2 mode（mount MSC drive）
   - 後備：`meshtastic --enter-dfu` 進的是 OTA mode（BLE），**MSC drive 不會 mount**；需要 user 手動雙擊 RESET 切到 UF2 mode
   - cp 一定要寫到 `CURRENT.UF2`（覆寫既有 entry）而不是 `/Volumes/HT-n5262/` 目錄（新建 file），新建會卡 macOS FAT directory bookkeeping cache
   - 一定要用 `os.fsync()` + `diskutil eject` — macOS USB MSC 預設大量 buffer，plain `cp` 寫的 byte 不會即時送到 bootloader，UF2 block 收不夠 chip 不重啟

## 待辦

## 待辦

詳見 [docs/open_issues.md](docs/open_issues.md)：region 設 TW/AS923、battery ADC 校正、手機 app BLE pairing 實測、LoRa link 對測、開 GNSS/TFT/DWM3000/RS485 周邊。

⚠️ Region 預設掉到 US 902-928 MHz，**設好 region 之前不要拉天線到戶外發送**。
