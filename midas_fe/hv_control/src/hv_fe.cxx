/********************************************************************\

  Name:         hv_fe.c
  Created by:   Stefan Ritt

  Contents:     Slow control frontend for Mu3e High Voltage

\********************************************************************/

#include <cstdio>
#include <cstring>

#include "mscb.h"
#include "midas.h"
#include "odbxx.h"
#include "mfe.h"

#include "mdev_hv4.h"

/*-- Globals -------------------------------------------------------*/

/* The frontend name (client name) as seen by other MIDAS clients   */
const char *frontend_name = "HV Frontend";
/* The frontend file name, don't change it */
const char *frontend_file_name = __FILE__;

/*-- Equipment list ------------------------------------------------*/

BOOL equipment_common_overwrite = TRUE;

int hv_loop(void);
int hv_read(char *pevent, int off);

EQUIPMENT equipment[] = {

   {"HV",                       // equipment name
      {140, 0,                  // event ID, trigger mask
         "SYSTEM",              // event buffer
         EQ_PERIODIC,           // equipment type
         0,                     // event source
         "MIDAS",               // format
         TRUE,                  // enabled
         RO_RUNNING,            // only generate events when running
         60000,                 // read full event every 60 sec
         10,                    // read one value every 10 msec
         0,                     // number of sub events
         1,                     // log history every second
         "", "", ""} ,
      hv_read,                  // readout routine
   },

   {""}
};

// master device table
std::vector<mdev *> mdev_table;

/*-- Error dispatcher causing communiction alarm -------------------*/

void fe_error(const char *error)
{
   cm_msg(MERROR, "fe_error", "%s", error);
}

/*-- Frontend Init -------------------------------------------------*/

INT frontend_init()
{
   /*---- set correct ODB device addresses ----*/

   auto mupixHv = new mdev_hv4("HV");

   // ---- US TOP Crate ----
   mupixHv->set_submaster("mscb461.psi.ch");
   mupixHv->add_card(  1,  {    "US Top Pixel CH1",     "US Top Pixel CH2",     "US Top Pixel CH3",     "US Top Pixel CH4" }, 60);
   mupixHv->add_card(  2,  {        "VTX_US_L1_M1",     "US Top Pixel CH6",     "US Top Pixel CH7",     "US Top Pixel CH8" }, 85);
   mupixHv->add_card(  3,  {    "US Top Pixel CH9",    "US Top Pixel CH10",    "US Top Pixel CH11",    "US Top Pixel CH12" }, 60);
   mupixHv->add_card(  4,  {        "VTX_US_L2_M1",    "US Top Pixel CH14",    "US Top Pixel CH15",    "US Top Pixel CH16" }, 20);
   mupixHv->add_card(  5,  {   "US Top Pixel CH17",    "US Top Pixel CH18",    "US Top Pixel CH19",    "US Top Pixel CH20" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 30,  {    "US Top SciFi CH1",     "US Top SciFi CH2",     "US Top SciFi CH3",     "US Top SciFi CH4" }, 60);
   mupixHv->add_card( 31,  {    "US Top SciFi CH5",     "US Top SciFi CH6",     "US Top SciFi CH7",     "US Top SciFi CH8" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 38,  {     "US Top Tile CH1",      "US Top Tile CH2",      "US Top Tile CH3",      "US Top Tile CH4" }, 60);
   mupixHv->add_card( 39,  {     "US Top Tile CH5",      "US Top Tile CH6",      "US Top Tile CH7",      "US Top Tile CH8" }, 60);
   mupixHv->add_card( 40,  {     "US Top Tile CH9",     "US Top Tile CH10",     "US Top Tile CH11",     "US Top Tile CH12" }, 60);
   mupixHv->add_card( 41,  {    "US Top Tile CH13",     "US Top Tile CH14",     "US Top Tile CH15",     "US Top Tile CH16" }, 60);
   mupixHv->add_card( 42,  {    "US Top Tile CH17",     "US Top Tile CH18",     "US Top Tile CH19",     "US Top Tile CH20" }, 60);
   mupixHv->add_card( 43,  {    "US Top Tile CH21",     "US Top Tile CH22",     "US Top Tile CH23",     "US Top Tile CH24" }, 60);
   mupixHv->add_card( 44,  {    "US Top Tile CH25",     "US Top Tile CH26",     "US Top Tile CH27",     "US Top Tile CH28" }, 60);
 
   // ---- US Bottom Crate ---- 
   mupixHv->start_new_group();
   mupixHv->set_submaster("mscb462.psi.ch");
   mupixHv->add_card(  6,  { "US Bottom Pixel CH1",  "US Bottom Pixel CH2",  "US Bottom Pixel CH3",  "US Bottom Pixel CH4" }, 60);
   mupixHv->add_card(  7,  {        "VTX_US_L1_M2",  "US Bottom Pixel CH6",  "US Bottom Pixel CH7",  "US Bottom Pixel CH8" }, 85);
   mupixHv->add_card(  8,  { "US Bottom Pixel CH9", "US Bottom Pixel CH10", "US Bottom Pixel CH11", "US Bottom Pixel CH12" }, 60);
   mupixHv->add_card(  9,  {"US Bottom Pixel CH13", "US Bottom Pixel CH14", "US Bottom Pixel CH15", "US Bottom Pixel CH16" }, 60);
   mupixHv->add_card(  10, {        "VTX_US_L2_M2", "US Bottom Pixel CH18", "US Bottom Pixel CH19", "US Bottom Pixel CH20" }, 85);
   mupixHv->add_card(  11, {"US Bottom Pixel CH21", "US Bottom Pixel CH22", "US Bottom Pixel CH23", "US Bottom Pixel CH24" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 32, {  "US Bottom SciFi CH1",  "US Bottom SciFi CH2",  "US Bottom SciFi CH3",  "US Bottom SciFi CH4" }, 60);
   mupixHv->add_card( 33, {  "US Bottom SciFi CH5",  "US Bottom SciFi CH6",  "US Bottom SciFi CH7",  "US Bottom SciFi CH8" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 45, {   "US Bottom Tile CH1",   "US Bottom Tile CH2",   "US Bottom Tile CH3",   "US Bottom Tile CH4" }, 60);
   mupixHv->add_card( 46, {   "US Bottom Tile CH5",   "US Bottom Tile CH6",   "US Bottom Tile CH7",   "US Bottom Tile CH8" }, 60);
   mupixHv->add_card( 47, {   "US Bottom Tile CH9",  "US Bottom Tile CH10",  "US Bottom Tile CH11",  "US Bottom Tile CH12" }, 60);
   mupixHv->add_card( 48, {  "US Bottom Tile CH13",  "US Bottom Tile CH14",  "US Bottom Tile CH15",  "US Bottom Tile CH16" }, 60);
   mupixHv->add_card( 49, {  "US Bottom Tile CH17",  "US Bottom Tile CH18",  "US Bottom Tile CH19",  "US Bottom Tile CH20" }, 60);
   mupixHv->add_card( 50, {  "US Bottom Tile CH21",  "US Bottom Tile CH22",  "US Bottom Tile CH23",  "US Bottom Tile CH24" }, 60);
   mupixHv->add_card( 51, {  "US Bottom Tile CH25",  "US Bottom Tile CH26",  "US Bottom Tile CH27",  "US Bottom Tile CH28" }, 60);

   // ---- DS TOP Crate ----
   mupixHv->start_new_group();
   mupixHv->set_submaster("mscb469.psi.ch");
   mupixHv->add_card( 12, {     "DS Top Pixel CH1",     "DS Top Pixel CH2",     "DS Top Pixel CH3",     "DS Top Pixel CH4" }, 60);
   mupixHv->add_card( 13, {     "DS Top Pixel CH5",     "DS Top Pixel CH6",     "DS Top Pixel CH7",     "DS Top Pixel CH8" }, 60);
   mupixHv->add_card( 14, {    "DS Top Pixel CH9" ,    "DS Top Pixel CH10",    "DS Top Pixel CH11",    "DS Top Pixel CH12" }, 60);
   mupixHv->add_card( 15, {         "VTX_DS_L2_M1",    "DS Top Pixel CH14",    "DS Top Pixel CH15",    "DS Top Pixel CH16" }, 20);
   mupixHv->add_card( 16, {         "VTX_DS_L1_M1",    "DS Top Pixel CH18",    "DS Top Pixel CH19",    "DS Top Pixel CH20" }, 85);
   mupixHv->add_card( 17, {    "DS Top Pixel CH21",    "DS Top Pixel CH22",    "DS Top Pixel CH23",    "DS Top Pixel CH24" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 34, {     "DS Top SciFi CH1",     "DS Top SciFi CH2",     "DS Top SciFi CH3",     "DS Top SciFi CH4" }, 60);
   mupixHv->add_card( 35, {     "DS Top SciFi CH5",     "DS Top SciFi CH6",     "DS Top SciFi CH7",     "DS Top SciFi CH8" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 52, {      "DS Top Tile CH1",      "DS Top Tile CH2",      "DS Top Tile CH3",      "DS Top Tile CH4" }, 60);
   mupixHv->add_card( 53, {      "DS Top Tile CH5",      "DS Top Tile CH6",      "DS Top Tile CH7",      "DS Top Tile CH8" }, 60);
   mupixHv->add_card( 54, {      "DS Top Tile CH9",     "DS Top Tile CH10",     "DS Top Tile CH11",     "DS Top Tile CH12" }, 60);
   mupixHv->add_card( 55, {             "TL_DS_0_0",             "TL_DS_0_1",     "DS Top Tile CH15",     "DS Top Tile CH16" }, 60);
   mupixHv->add_card( 56, {             "TL_DS_0_2",             "TL_DS_0_3",     "DS Top Tile CH19",     "DS Top Tile CH20" }, 60);
   mupixHv->add_card( 57, {             "TL_DS_6_0",             "TL_DS_6_1",     "DS Top Tile CH23",     "DS Top Tile CH24" }, 60);
   mupixHv->add_card( 58, {             "TL_DS_6_2",             "TL_DS_6_3",     "DS Top Tile CH27",     "DS Top Tile CH28" }, 60);
   
   // ---- DS Bottom Crate ----
   mupixHv->start_new_group();
   mupixHv->set_submaster("mscb470.psi.ch");
   mupixHv->add_card( 18, { "DS Bottom Pixel CH1" ,  "DS Bottom Pixel CH2",  "DS Bottom Pixel CH3",  "DS Bottom Pixel CH4" }, 60);
   mupixHv->add_card( 19, { "VTX_DS_L2_M2"        ,  "DS Bottom Pixel CH6",  "DS Bottom Pixel CH7",  "DS Bottom Pixel CH8" }, 85);
   mupixHv->add_card( 20, { "DS Bottom Pixel CH9" , "DS Bottom Pixel CH10", "DS Bottom Pixel CH11", "DS Bottom Pixel CH12" }, 60);
   mupixHv->add_card( 21, {         "VTX_DS_L1_M2", "DS Bottom Pixel CH14", "DS Bottom Pixel CH15", "DS Bottom Pixel CH16" }, 85);
   mupixHv->add_card( 22, { "DS Bottom Pixel CH17", "DS Bottom Pixel CH18", "DS Bottom Pixel CH19", "DS Bottom Pixel CH20" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 36, {  "DS Bottom SciFi CH1",  "DS Bottom SciFi CH2",  "DS Bottom SciFi CH3",  "DS Bottom SciFi CH4" }, 60);
   mupixHv->add_card( 37, {  "DS Bottom SciFi CH5",  "DS Bottom SciFi CH6",  "DS Bottom SciFi CH7",  "DS Bottom SciFi CH8" }, 60);

   mupixHv->start_new_group();
   mupixHv->add_card( 59, {             "TL_DS_5_0",             "TL_DS_5_1",   "DS Bottom Tile CH3",   "DS Bottom Tile CH4" }, 60);
   mupixHv->add_card( 60, {             "TL_DS_5_2",             "TL_DS_5_3",   "DS Bottom Tile CH7",   "DS Bottom Tile CH8" }, 60);
   mupixHv->add_card( 61, {   "DS Bottom Tile CH9",  "DS Bottom Tile CH10",  "DS Bottom Tile CH11",  "DS Bottom Tile CH12" }, 60);
   mupixHv->add_card( 62, {  "DS Bottom Tile CH13",  "DS Bottom Tile CH14",  "DS Bottom Tile CH15",  "DS Bottom Tile CH16" }, 60);
   mupixHv->add_card( 63, {  "DS Bottom Tile CH17",  "DS Bottom Tile CH18",  "DS Bottom Tile CH19",  "DS Bottom Tile CH20" }, 60);
   mupixHv->add_card( 64, {  "DS Bottom Tile CH21",  "DS Bottom Tile CH22",  "DS Bottom Tile CH23",  "DS Bottom Tile CH24" }, 60);
   mupixHv->add_card( 65, {  "DS Bottom Tile CH25",  "DS Bottom Tile CH26",  "DS Bottom Tile CH27",  "DS Bottom Tile CH28" }, 60);

//   mupixHv->define_history_panel("US V", { "U0-0 Voltage",  "U0-1 Voltage"  });
//   mupixHv->define_history_panel("US I", { "U0-0 Current",  "U0-1 Current"  });

   mdev_table.push_back(mupixHv);

   // ----------------------

   // set error dispatcher for alarm functionality
   mfe_set_error(fe_error);

   // install handle to be continuously called
   install_frontend_loop(hv_loop);

   // setup ODB and initialize all drivers
   try {
      mdev::mdev_odb_setup(mdev_table);
      mdev::mdev_init(mdev_table);
   } catch (mexception& e) {
      cm_msg(MERROR, "frontend_init", "%s", e.what());
      return FE_ERR_HW;
   }

   return CM_SUCCESS;
}

/*-- loop function called continuously ------------------------------*/

int hv_loop()
{
   static DWORD last_error_time = 0;
   static DWORD last_error_message = 0;
   static DWORD skipped_errors = 0;

   // in case of recent error, wait some time to measure again
   if (ss_time() < last_error_time + 30) {
      ss_sleep(100);
      return FE_SUCCESS;
   }

   try {

      // call loop functions of all devices
      mdev::mdev_loop(mdev_table);

   } catch (mexception& e) {
      last_error_time = ss_time();
      // produce one error every ten minutes
      if (last_error_time - last_error_message > 10 * 60) {
         if (skipped_errors)
            cm_msg(MERROR, "hv_loop", "... %d errors skipped", skipped_errors);
         cm_msg(MERROR, "hv_loop", "%s", e.what());

         last_error_message = last_error_time;
         skipped_errors = 0;
      } else
         skipped_errors++;
   }

   ss_sleep(10); // don't eat all CPU

   return FE_SUCCESS;
}

/*-- event readout function -----------------------------------------*/

int hv_read(char *pevent, int off)
{
   for (mdev *m : mdev_table)
      if (EVENT_ID(pevent) == m->get_event_id())
         return m->read_event(pevent, off);

   return 0;
}
