#include "HitVectorFlowEvent.h"

HitVectorFlowEvent::HitVectorFlowEvent(
    TAFlowEvent* flow,
    eventheader& _header,
    uint64_t* pixelstart,
    uint32_t npixel,
    uint64_t* mutrigstart,
    uint32_t nmutrig
)
    : TAFlowEvent(flow)
    , header(_header)
    , pixelhits(pixelstart, pixelstart + npixel)
    , mutrighits(mutrigstart, mutrigstart + nmutrig)
    // Note that this does perform copies. In place construction would mess up ownership, so C++ does not really allow it.
    // Advantage: We can do type conversion to our structs as we go along
{
}

HitVectorFlowEvent::HitVectorFlowEvent(
    TAFlowEvent* flow,
    eventheader& _header,
    std::vector<pixelhit>&& pixelhits,
    std::vector<mutrighit>&& mutrighits
)
    : TAFlowEvent(flow)
    , header(_header)
    , pixelhits(std::move(pixelhits))
    , mutrighits(std::move(mutrighits))
{
}
