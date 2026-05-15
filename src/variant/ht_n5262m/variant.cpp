// HT-N5262M variant — minimal v0 bring-up
// Derived from variants/nrf52840/heltec_mesh_solar/variant.cpp
// Removed: BQ4050 init, GPS_PPS detach (no GPS), Button1 detach (no button)

#include "variant.h"
#include "Arduino.h"
#include "nrf.h"
#include "wiring_constants.h"
#include "wiring_digital.h"

const uint32_t g_ADigitalPinMap[] = {
    // P0 — pins 0 and 1 are hardwired for xtal and must stay disabled
    0xff, 0xff, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,

    // P1
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47};

void initVariant()
{
    // Force internal pull-ups on the I2C lines.
    // Without external pull-ups + no slave attached, the nRF52 TWIM peripheral
    // hangs TwoWire::endTransmission() on Meshtastic's periodic battery-gauge
    // probe. ~13 kOhm internal pull-ups give the bus a defined high state.
    pinMode(PIN_WIRE_SDA, INPUT_PULLUP);
    pinMode(PIN_WIRE_SCL, INPUT_PULLUP);
}

void variant_shutdown() {}
