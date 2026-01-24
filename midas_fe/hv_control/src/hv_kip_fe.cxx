/********************************************************************\

  Name:         hv_kip_fe.c
  Created by:   Konrad Briggl

  Contents:     Tile Slow control frontend for SciTile High Voltage

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
         RO_ALWAYS,
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

   mupixHv->set_submaster("192.168.0.6"); //changed from mscb426.psi.ch
   mupixHv->add_card(26, {"TL-DS0-0", "TL-DS0-1", "TL-DS0-2", "TL-DS0-3"}, 60);

   mupixHv->start_new_group();
   mupixHv->add_card(27, {"TL-DS1-0", "TL-DS1-1", "TL-DS1-2", "TL-DS1-3"}, 60);

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
