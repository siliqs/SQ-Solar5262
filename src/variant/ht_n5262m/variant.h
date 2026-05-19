// HT-N5262M Meshtastic variant — minimal v0 bring-up
// Derived from variants/nrf52840/heltec_mesh_solar/variant.h
//
// Differences vs Solar:
//   - No BQ4050 battery management IC
//   - No L76K GPS (carrier board has GNSS header but v0 leaves it disabled)
//   - No on-PCB LED on the bare HT-N5262M (carrier LEDs not yet mapped)
//   - Single I2C bus (no Wire1)
//   - No buttons wired to MCU on bare module
//
// SX1262 pins are identical to Solar / Mesh Node T114 — verified empirically:
// the existing Heltec Arduino sketch lora_tx.ino uses P0.25 for RESET and
// the board is currently receiving cleanly with that mapping.

#ifndef _VARIANT_HT_N5262M_
#define _VARIANT_HT_N5262M_

#define VARIANT_MCK (64000000ul)

#define USE_LFXO  // 32 kHz crystal on module

#include "WVariant.h"

#ifdef __cplusplus
extern "C" {
#endif

#define PINS_COUNT (48)
#define NUM_DIGITAL_PINS (48)
#define NUM_ANALOG_INPUTS (1)
#define NUM_ANALOG_OUTPUTS (0)

// LED — bare HT-N5262M has no user LED on PCB.
// Map to an unused GPIO so Meshtastic's LED-blink code is harmless.
// NOT P1.15 — that is the carrier's RS485 RX (RO) line, verified by
// 25_HT5262M_test/src/rs485_loopback_zephyr (20/20 echo @ 9600 baud).
// Driving LED blinks there would corrupt RS485 receive when the bus is enabled.
// P1.11 is not used by any verified subsystem on silic_solar_panel_5262M v1.
#define PIN_LED1 (32 + 11)  // P1.11 — unconnected on carrier
#define LED_BLUE PIN_LED1
#define LED_GREEN PIN_LED1
#define LED_STATE_ON 0

// User button — carrier wires USER_KEY to P1.10 (same slot as Heltec T114).
// Active-LOW with internal pull-up handled by Meshtastic's InputBroker.
#define PIN_BUTTON1 (32 + 10)

// TFT (ST7789, 1.14" 240×135) — pinout matches Heltec T114 exactly.
// Two P-MOSFET enables (active LOW): VTFT_CTRL = panel VDD, VTFT_LEDA = backlight.
// SPI1 carries TFT traffic (SX1262 owns SPI0). MISO/BUSY unused (single-direction).
// Verified by 25_HT5262M_test/src/tft_test_zephyr (RGB+W+K colour cycle passed).
#define USE_ST7789
#define ST7789_NSS    (0 + 11)   // P0.11 (CS)
#define ST7789_RS     (0 + 12)   // P0.12 (DC)
#define ST7789_SDA    (32 + 9)   // P1.09 (MOSI)
#define ST7789_SCK    (32 + 8)   // P1.08
#define ST7789_RESET  (0 + 2)    // P0.02
#define ST7789_MISO   -1
#define ST7789_BUSY   -1
#define VTFT_CTRL     (0 + 3)    // P0.03 — panel VDD enable (LOW = ON via Q2 AO3401A P-FET)
#define VTFT_LEDA     (0 + 15)   // P0.15 — backlight enable (LOW = ON via Q1 AO3401A P-FET)
#define TFT_BACKLIGHT_ON LOW
#define ST7789_SPI_HOST SPI1_HOST

#define TFT_HEIGHT 135
#define TFT_WIDTH 240
#define TFT_OFFSET_X 0
#define TFT_OFFSET_Y 0

#define PIN_SPI1_MISO ST7789_MISO
#define PIN_SPI1_MOSI ST7789_SDA
#define PIN_SPI1_SCK  ST7789_SCK

// Adafruit nRF52 core's Uart.cpp instantiates Serial1/Serial2 unconditionally,
// so we must define both pin pairs even though neither bus is wired here.
#define PIN_SERIAL1_RX (-1)
#define PIN_SERIAL1_TX (-1)
#define PIN_SERIAL2_RX (-1)
#define PIN_SERIAL2_TX (-1)

// I2C — carrier's sensor bus is on P1.00 SDA / P1.01 SCL with external 5.1k
// pull-ups to 3V3 (R30/R31). Verified end-to-end by
// 25_HT5262M_test/src/i2c_hdc1080_zephyr reading HDC1080 T=27.3°C / H=90.8% RH.
// (Earlier bring-up of this variant used P0.27/P0.26 — that was wrong:
//  P0.27 is the carrier's DWM3000 MISO line, and P0.26 had no pull-up,
//  so the bus floated and Meshtastic's max17048 probe hung
//  TwoWire::endTransmission() via the nRF52 TWIM stuck-SCL errata.)
#define WIRE_INTERFACES_COUNT 1
#define PIN_WIRE_SDA (32 + 0)
#define PIN_WIRE_SCL (32 + 1)

// SX1262 — identical to heltec_mesh_solar
#define USE_SX1262
#define SX126X_CS (0 + 24)
#define LORA_CS (0 + 24)
#define SX126X_DIO1 (0 + 20)
#define SX126X_BUSY (0 + 17)
#define SX126X_RESET (0 + 25)
#define SX126X_DIO2_AS_RF_SWITCH
#define SX126X_DIO3_TCXO_VOLTAGE 1.8

// LoRa SPI (SPI 0)
#define PIN_SPI_MISO (0 + 23)
#define PIN_SPI_MOSI (0 + 22)
#define PIN_SPI_SCK (0 + 19)

// Battery ADC — carrier wires BAT through divider to P0.04, gated by P0.06.
// ADC_CTRL/ADC_CTRL_ENABLED let Meshtastic's battery_adcEnable() (Power.cpp)
// drive the FET HIGH just before each ADC read and LOW after — saves the
// ~9 µA divider current the rest of the time. Earlier attempt (commit
// 7e2958f) drove it HIGH in initVariant(); Meshtastic resets the PIN_CNF
// later during board init so that approach lost the drive and the ADC kept
// reading ~16 V. Switching to the macro convention gives voltage 4.228 V
// (verified 2026-05-19 via `meshtastic --info`).
#define BATTERY_PIN (0 + 4)
#define ADC_CTRL (0 + 6)
#define ADC_CTRL_ENABLED HIGH
#define ADC_MULTIPLIER (4.9F)
#define BATTERY_SENSE_RESOLUTION_BITS 12

#define SERIAL_PRINT_PORT 0

#ifdef __cplusplus
}
#endif

#endif
