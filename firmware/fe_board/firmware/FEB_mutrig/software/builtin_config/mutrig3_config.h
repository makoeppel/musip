#ifndef MUTRIG3_BUILTIN_CONFIG_H_
#define MUTRIG3_BUILTIN_CONFIG_H_

#include <stdint.h>

// Canonical MuTRiG3 slow-control pattern dimensions.
static const uint32_t MUTRIG_CONFIG_LEN_BITS = 2662;
static const uint32_t MUTRIG_CONFIG_LEN_BYTES = 333;
static const uint32_t MUTRIG_CONFIG_LEN_WORDS = 84;

#include "mutrig3/FF.h"
#include "mutrig3/ALL_OFF.h"
#include "mutrig3/beamtime26_qc.h"
#include "mutrig2/PRBS_single.h"
#include "mutrig2/No_TDC_Power.h"
#include "mutrig2/PLL_TEST.h"

static_assert(
    MUTRIG_CONFIG_LEN_BITS == MUTRIG3_BEAMTIME26_QC_BITS,
    "MuTRiG3 bit-count mismatch");
static_assert(
    MUTRIG_CONFIG_LEN_BYTES == MUTRIG3_BEAMTIME26_QC_BYTES,
    "MuTRiG3 byte-count mismatch");
static_assert(
    sizeof(config_ALL_OFF) == MUTRIG_CONFIG_LEN_BYTES,
    "MuTRiG3 all-off pattern has the wrong size");

#endif // MUTRIG3_BUILTIN_CONFIG_H_
