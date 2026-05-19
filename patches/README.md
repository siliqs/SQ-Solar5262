# Upstream patches for `meshtastic-firmware`

`external/meshtastic-firmware/` is gitignored — we keep edits to upstream
source files as patch files here and apply them at setup time
(`scripts/setup.sh`).

Upstream base: [`meshtastic/firmware`](https://github.com/meshtastic/firmware)
`develop` branch, last verified against `4827498` (2026-05-20).

## Patches

- `0001-nodedb-ht-n5262m-hasscreen.patch` — extend the existing
  `HELTEC_MESH_NODE_T114` ST7789-SPI probe in `installDefaultConfig()` to
  cover `HT_N5262M`. When the TFT reads back `0xFFFFFF` (panel not
  populated), `hasScreen = false` flips Bluetooth pairing from `RANDOM_PIN`
  to `FIXED_PIN` so the user can pair with the default PIN `123456`.
