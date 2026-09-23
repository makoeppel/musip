/********************************************************************\

  Name:         hv_fe.c
  Created by:   Stefan Ritt

  Contents:     Slow control frontend for Mu3e High Voltage

\********************************************************************/

#include <cstdio>
#include <cstring>
#include <cstdlib>

#include "mscb.h"
#include "midas.h"
#include "odbxx.h"
#include "mfe.h"

#include "mdev_hv4.h"
#include "mdev_tti_ql564p.h"

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

   {"TTI HV",                  // equipment name
      {141, 0,                  // event ID, trigger mask
         "SYSTEM",              // event buffer
         EQ_PERIODIC,            // equipment type
         0,                     // event source
         "MIDAS",              // format
         TRUE,                  // enabled
         RO_RUNNING,            // only generate events when running
         60000,                 // read full event every 60 sec
         10,                    // read one value every 10 msec
         0,                     // number of sub events
         1,                     // log history every second
         "", "", ""},
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

   //auto mupixHv = new mdev_hv4("HV");
   //mupixHv->set_submaster("mscb382.psi.ch");
   //mupixHv->add_card(  35,  {"none0", "quad 1", "quad 2", "quad 3"}, 50);
   //mupixHv->add_card(  35,  {"quad 0", "none1", "none2",  "none3"},  75);

   //mdev_table.push_back(mupixHv);


   auto ttiHv = new mdev_tti_ql564p("TTI HV");
   ttiHv->set_host("ql564p02.psi.ch");
   ttiHv->add_card({"TTI QL564P CH1", "TTI QL564P CH2"});
   mdev_table.push_back(ttiHv);

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
