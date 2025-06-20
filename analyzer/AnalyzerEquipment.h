#ifndef ANALYZEREQUIPMENT_H
#define ANALYZEREQUIPMENT_H

// Frontend to send data back to MIDAS
#include "tmfe.h"
#include <stdio.h>

class AnalyzerEquipment : public TMFeEquipment {
public:
    AnalyzerEquipment(const char* eqname, const char* eqfilename);

    ~AnalyzerEquipment();

    void HandleUsage();

    TMFeResult HandleInit(const std::vector<std::string>& args);
};

class AnalyzerFrontend : public TMFrontend {
public:
};

#endif
