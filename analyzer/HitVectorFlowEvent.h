#ifndef HITVECTORFLOWEVENT_H
#define HITVECTORFLOWEVENT_H

#include "manalyzer.h"
#include <vector>

#include "hits.h"

// flow event creating vectors for the hits
class HitVectorFlowEvent : public TAFlowEvent {
public:

    HitVectorFlowEvent(
        TAFlowEvent* flow,
        uint64_t* hitstart,
        uint32_t nhits
    );

    // Constructor using move semantics for the vectors. If your data is already in typed vectors and you
    // no longer need it, this is preferable to other constructor. If you need the data afterwards, use
    // the other constructor because it makes a copy of the data.
    HitVectorFlowEvent(
        TAFlowEvent* flow,
        std::vector<hit>&& hits
    );

    eventheader header;
    std::vector<hit> hits;
};

#endif
