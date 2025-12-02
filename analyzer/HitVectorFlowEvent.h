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
        eventheader& header,
        uint64_t* pixelstart,
        uint32_t npixel,
        uint64_t* mutrigstart,
        uint32_t nmutrig
    );

    // Constructor using move semantics for the vectors. If your data is already in typed vectors and you
    // no longer need it, this is preferable to other constructor. If you need the data afterwards, use
    // the other constructor because it makes a copy of the data.
    HitVectorFlowEvent(
        TAFlowEvent* flow,
        eventheader& header,
        std::vector<pixelhit>&& pixelhits,
        std::vector<mutrighit>&& mutrighits
    );

    eventheader header;
    std::vector<pixelhit> pixelhits;
    std::vector<mutrighit> mutrighits;
};

#endif
