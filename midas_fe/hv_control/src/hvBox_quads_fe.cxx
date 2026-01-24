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
#include "class/hv.h"
#include "device/mscbhv4.h"
#include "device/mscbdev.h"
#include "device/mdevice.h"
#include "mdevice_mscbhv4.h"
#include "mstrlcpy.h"
/*-- Globals -------------------------------------------------------*/

/* The frontend name (client name) as seen by other MIDAS clients   */
const char *frontend_name = "HV Frontend";
/* The frontend file name, don't change it */
const char *frontend_file_name = __FILE__;

/*-- Equipment list ------------------------------------------------*/

BOOL equipment_common_overwrite = TRUE;

EQUIPMENT equipment[] = {

   {"Quad HV",                 // equipment name
      {140, 0,                  // event ID, trigger mask
         "SYSTEM",              // event buffer
         EQ_SLOW,               // equipment type
         0,                     // event source
         "MIDAS",               // format
         TRUE,                  // enabled
         RO_ALWAYS,
         60000,                 // read full event every 60 sec
         10,                    // read one value every 10 msec
         0,                     // number of sub events
         1,                     // log history every second
         "", "", ""} ,
      cd_hv_read,               // readout routine
      cd_hv,                    // class driver main routine
   },

   {""}
};

/*-- Error dispatcher causing communiction alarm -------------------*/

void fe_error(const char *error)
{
   char str[256];

   mstrlcpy(str, error, sizeof(str));
   cm_msg(MERROR, "fe_error", "%s", str);
   al_trigger_alarm("MSCB", str, "MSCB Alarm", "Communication Problem", AT_INTERNAL);
}

/*-- Frontend Init -------------------------------------------------*/

INT frontend_init()
{
   /* set error dispatcher for alarm functionality */
   mfe_set_error(fe_error);

   /* set maximal retry count */
   mscb_set_max_retry(100);
   midas::odb::delete_key("/Equipment/MuPix HV/Settings");
//   midas::odb::delete_key("/Equipment/SciFi HV/Settings");

   /*---- set correct ODB device addresses ----*/

   mdevice_mscbhv4 quadHV("Quad HV", "Quad HV modules", "mscb382"); //this should not be hardcoded!
   quadHV.set_hvmax(50);
   quadHV.define_box(1, {"none0", "quad 1", "quad 2", "quad 3"}, 35);
   quadHV.set_hvmax(50);
   quadHV.define_box(2, {"quad 0", "none1", "none2", "none3"}, 75);
   quadHV.define_history_panel("US V", "Measured");
   quadHV.define_history_panel("US I", "Current");


   return CM_SUCCESS;
}
