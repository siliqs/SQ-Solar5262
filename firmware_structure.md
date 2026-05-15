# Meshtastic firmware repo 結構速覽

研究日期：2026-05-15
參考：[meshtastic/firmware](https://github.com/meshtastic/firmware) `main` (shallow clone)

## Build system

- **PlatformIO**（不是 arduino-cli）— 整個 firmware 是一個大型 PIO project
- 進入點：repo 根目錄的 `platformio.ini`，`default_envs = tbeam`
- 透過 `extra_configs = variants/*/*.ini` 把每個 board variant 的 PIO env 拉進來
- nrf52840 family 用 `[nrf52840_base]`（在 `variants/nrf52840/nrf52840.ini`）做 inheritance 基底

跑一個變體的 build：

```bash
pio run -e heltec-mesh-node-t114    # 或 -e heltec_mesh_solar，看 [env:...] 名稱
```

## 目錄重點

| 路徑 | 作用 |
|---|---|
| `src/` | C++ 主程式（mesh router、radio driver、display、GPS、power FSM、BLE …） |
| `src/mesh/` | 核心：mesh routing、加密、各家 LoRa chip 的 Interface（SX1262Interface、LR1110Interface …） |
| `src/mesh/generated/` | 從 `protobufs/` 編譯出來的 nanopb 檔（含 `meshtastic_HardwareModel` enum） |
| `protobufs/` | 對外 wire format（手機 app 透過 BLE / Serial 看到的就是這個 protobuf） |
| `variants/` | 每片支援的板子各自一個資料夾，含 `variant.h`、`variant.cpp`、`platformio.ini` |
| `boards/` | PlatformIO board JSON（chip / RAM / flash / bootloader 設定） |
| `bin/` | build 腳本（`platformio-pre.py`、`platformio-custom.py`） |
| `data/` | 預設網路 channel / 韌體資產 |

## 加 variant 要動的點

理論上加一片新板子（例如 `ht_n5262m`）會碰到：

1. **`variants/nrf52840/ht_n5262m/`** — 新資料夾
   - `variant.h`：pin 對應 + macro（`SX126X_CS`、`SX126X_DIO1`、`SX126X_BUSY`、`SX126X_RESET`、`SX126X_DIO2_AS_RF_SWITCH`、`SX126X_DIO3_TCXO_VOLTAGE 1.8` …）
   - `variant.cpp`：Arduino `PinDescription g_APinDescription[]` 陣列
   - `platformio.ini`：定義 `[env:ht_n5262m]`，extends `nrf52840_base`，給 build flag `-DHT_N5262M`
2. **`boards/ht_n5262m.json`**（如果現有的 nrf52840 board JSON 不能直接用）
3. **`meshtastic_HardwareModel` enum** — 兩條路：
   - (a) **bring-up 階段直接用 `PRIVATE_HW = 255`**，不改 firmware enum，build flag 自己 hardcode hw_model = 255
   - (b) **量產正式申請編號** — 開 PR 到 `protobufs/meshtastic/mesh.proto`，等核可後拿到一個新的數字
4. **`userPrefs.jsonc`** 或 build flag — 設預設 region = `TW`

最小 port 用 (a) 就好，不需要碰到 protobuf。

## hw_model 編號（已知）

| 板子 | enum value |
|---|---|
| `HELTEC_MESH_NODE_T114` | 69 |
| `HELTEC_MESH_SOLAR`     | 108 |
| `HELTEC_MESH_NODE_T096` | 127 |
| `HELTEC_MESH_NODE_T1`   | 133 |
| `PRIVATE_HW`            | **255** ← bring-up 用這個 |

## Build flow（猜測，待 port 時驗證）

```
pio run -e ht_n5262m
  └─ bin/platformio-pre.py        # 跑 nanopb，產 src/mesh/generated/
  └─ 套用 [env:ht_n5262m] build_flags
       -Ivariants/nrf52840/ht_n5262m
       -DHT_N5262M
  └─ 編譯 src/* + variants/nrf52840/ht_n5262m/variant.cpp
  └─ link 出 .elf + .hex + .uf2
```

`.uf2` 可以給 Adafruit nRF52 bootloader 走 USB DFU 燒（理論上 HT-N5262M 出廠就是這個 bootloader，所以不一定要 SWD）。**但 Meshtastic 燒進去之後會把 S140 + bootloader 結構動到，要回 Arduino 就得跑 [`restore_bootloader.sh`](https://github.com/livinghuang/25_HT5262M_test/blob/main/scripts/restore_bootloader.sh)（在 `25_HT5262M_test` repo）**。

## BLE stack

Meshtastic 在 nrf52840 上用 **NimBLE**（透過 Adafruit Bluefruit + Adafruit nRFCrypto），不是 Nordic S140。這意思是：

- 燒 Meshtastic 之後，BQB 認證（S140 SoftDevice 的 listing）不適用
- 對 bring-up 沒影響，但**進量產之前**這是 [`arduino_vs_zephyr.md`](https://github.com/livinghuang/25_HT5262M_test/blob/main/docs/arduino_vs_zephyr.md)（在 `25_HT5262M_test` repo）提到的「BLE 認證」trigger 之一

## 不需要的東西可以靠 build flag 關掉

`heltec_mesh_solar` 已經示範了「沒有 TFT、沒有 GPS」要怎麼設定。對 HT-N5262M 來說可以直接抄。

關鍵 macro：
- `HAS_SCREEN 0`
- `HAS_GPS 0`
- `MESHTASTIC_EXCLUDE_GPS`
- `MESHTASTIC_EXCLUDE_BLUETOOTH`（如果想先不打開 BLE）

完整列表要進 firmware 才確認，這裡先列已知的。

## 下一步行動清單

1. 把 `assets/SCH_Schematic1_2026-05-14.pdf` 找出 SX1262 RESET 真實 GPIO
2. Fork meshtastic/firmware 到 livinghuang 名下，cd 到 fork
3. `cp -r variants/nrf52840/heltec_mesh_solar variants/nrf52840/ht_n5262m`，改 RESET、LED、Button、砍 VEXT
4. 改 `platformio.ini` 的 `[env]` 名稱與 build flag
5. `pio run -e ht_n5262m` 看能不能編譯過
6. SWD 燒進去（用 `scripts/flash_swd.sh` 改成燒 `.hex` 而不是 `.uf2`，或直接 `openocd flash` 命令）
7. 用 Meshtastic Android app 試 BLE pairing
8. 在 RF 房試和另一台 Meshtastic 互相收得到
