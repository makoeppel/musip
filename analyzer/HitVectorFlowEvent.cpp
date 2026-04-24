#include "HitVectorFlowEvent.h"

HitVectorFlowEvent::HitVectorFlowEvent(
    TAFlowEvent* flow,
    uint64_t* hitstart,
    uint32_t nhits
)
    : TAFlowEvent(flow)
    , hits(hitstart, hitstart + nhits)
    // Note that this does perform copies. In place construction would mess up ownership, so C++ does not really allow it.
    // Advantage: We can do type conversion to our structs as we go along
{
}

HitVectorFlowEvent::HitVectorFlowEvent(
    TAFlowEvent* flow,
    std::vector<hit>&& hits
)
    : TAFlowEvent(flow)
    , hits(std::move(hits))
{
}
