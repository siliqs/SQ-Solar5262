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
// Carrier-board LED mapping is a follow-up.
#define PIN_LED1 (32 + 15)  // P1.15 — same slot as Solar; floating on this board
#define LED_BLUE PIN_LED1
#define LED_GREEN PIN_LED1
#define LED_STATE_ON 0

// No buttons wired on the bare module
// (carrier board has BTN1/BTN2 on USER_KEY net — TODO map after schematic recheck)

// Adafruit nRF52 core's Uart.cpp instantiates Serial1/Serial2 unconditionally,
// so we must define both pin pairs even though neither bus is wired here.
#define PIN_SERIAL1_RX (-1)
#define PIN_SERIAL1_TX (-1)
#define PIN_SERIAL2_RX (-1)
#define PIN_SERIAL2_TX (-1)

// I2C — carrier has a sensor header on P0.27 SDA / P0.26 SCL.
// Internal pull-ups are enabled in variant.cpp::initVariant() so the bus has
// a defined state when no device is attached. Without pull-ups, Meshtastic's
// periodic battery-gauge probe hung TwoWire::endTransmission() (nRF52 TWIM
// stuck-SCL errata when SDA/SCL float).
#define WIRE_INTERFACES_COUNT 1
#define PIN_WIRE_SDA (0 + 27)
#define PIN_WIRE_SCL (0 + 26)

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
// Defining BATTERY_PIN lets Meshtastic report voltage; ADC_MULTIPLIER 4.9
// matches the divider used by the existing Arduino ble_advertise sketch.
#define BATTERY_PIN (0 + 4)
#define ADC_MULTIPLIER (4.9F)
#define BATTERY_SENSE_RESOLUTION_BITS 12

#define SERIAL_PRINT_PORT 0

#ifdef __cplusplus
}
#endif

#endif
