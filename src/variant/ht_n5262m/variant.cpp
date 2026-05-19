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
    // Battery ADC gate (P0.06) is now handled via the ADC_CTRL macro in
    // variant.h — Meshtastic's battery_adcEnable() (Power.cpp) drives it HIGH
    // around each ADC read. I2C bus on P1.00/P1.01 has external 5.1k pull-ups
    // (R30/R31) so no internal pull-up is needed either.
}

void variant_shutdown() {}
