#include "AnalyzerEquipment.h"

AnalyzerEquipment::AnalyzerEquipment(const char* eqname, const char* eqfilename)
    : TMFeEquipment(eqname, eqfilename) {
    // configure the equipment here:
    fEqConfReadConfigFromOdb = false;
    fEqConfEventID = 150;
    fEqConfPeriodMilliSec = 0;
    //fEqConfWriteEventsToOdb = true;
    fEqConfBuffer = "QUADANA";
};

AnalyzerEquipment::~AnalyzerEquipment() {};

void AnalyzerEquipment::HandleUsage() {};

TMFeResult AnalyzerEquipment::HandleInit(const std::vector<std::string>&) {
    fEqConfReadOnlyWhenRunning = false; // overwrite ODB Common RO_RUNNING to false
    //fEqConfWriteEventsToOdb = true; // overwrite ODB Common RO_ODB to true
    //EqSetStatus("Started...", "white");
    return TMFeOk();
};
