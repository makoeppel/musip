/**
 * @file missing_hardware.h
 * @brief Hardware abstraction flags for simulation or emulation builds.
 *
 * This header defines macros used to compile the project in environments
 * without physical hardware access. These flags help isolate and test
 * the software stack in simulated or development environments.
 *
 * @details
 * - `NO_A10_BOARD`: Disables hardware-specific initialization and enables dummy interfaces.
 * - `EMULATE_HARDWARE_ERRORS`: Could be used to inject artificial errors for
 * testing robustness.
 *
 * This file is typically included early in the frontend logic and affects
 * conditional compilation of hardware interfaces.
 */

/* Emulate the hardware */
#define NO_A10_BOARD 1
// #define EMULATE_HARDWARE_ERRORS 1
