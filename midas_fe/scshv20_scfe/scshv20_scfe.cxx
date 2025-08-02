/********************************************************************\

  Name:         scshv20_scfe.c
  Created by:   Zaher Salman (based on code from Andreas Suter)

  Contents:     Midas frontend for the detector high voltage

\********************************************************************/

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>

#include "midas.h"
#include "class/hv.h"
#include "scshv20.h"
#include "bus/null.h"

//-- Globals -------------------------------------------------------

//! The frontend name (client name) as seen by other MIDAS clients
const char *frontend_name = "SCSHV20";
//! The frontend file name, don't change it
const char *frontend_file_name = __FILE__;

//! frontend_loop is called periodically if this variable is TRUE
BOOL frontend_call_loop = TRUE;

//! a frontend status page is displayed with this frequency in ms
INT display_period = 1000;

//! maximum event size produced by this frontend
INT max_event_size = 10000;

//! maximum event size for fragmented events (EQ_FRAGMENTED)
INT max_event_size_frag = 5*1024*1024;

//! buffer size to hold events
INT event_buffer_size = 10*10000;

 extern BOOL should_exit;
 
//-- Equipment list ------------------------------------------------

//! device driver list
  DEVICE_DRIVER hv_driver[] = {
  { "PHV20_1", scshv20, 20, null, DF_PRIO_DEVICE | DF_HW_RAMP | DF_REPORT_STATUS},
  { "PHV20_2", scshv20, 20, null, DF_PRIO_DEVICE | DF_HW_RAMP | DF_REPORT_STATUS},
  { "PHV20_3", scshv20, 20, null, DF_PRIO_DEVICE | DF_HW_RAMP | DF_REPORT_STATUS},
  { "PHV20_4", scshv20, 20, null, DF_PRIO_DEVICE | DF_HW_RAMP | DF_REPORT_STATUS},
 // { "PHV20_5", scshv20, 8, null, DF_PRIO_DEVICE | DF_HW_RAMP | DF_REPORT_STATUS},
  { "" }
  };
/*!
 * equipment_common_overwrite:
 *
 * - If that flag is TRUE, then the contents of the "equipment" structure is copied to 
 *   the ODB on each start of the front-end.
 *
 * - If the flag is FALSE, then the ODB values are kept on the start of the front-end
 */
BOOL equipment_common_overwrite = TRUE;

//! equipment structure for the mfe.c
EQUIPMENT equipment[] = {

  { "SCSHV20",            // equipment name
   {203, 0,               // event ID, trigger mask
    "SYSTEM",             // event buffer
    EQ_SLOW,              // equipment type
    0,                    // event source
    "FIXED",              // format
    TRUE,                 // enabled
    RO_RUNNING |
    RO_TRANSITIONS,       // read when running and on transitions
    30000,                // read every 30 sec
    0,                    // stop run after this event limit
    0,                    // number of sub events
    1,                    // log history every event
    "", "", "",},
    cd_hv_read,           // readout routine
    cd_hv,                // class driver main routine
    hv_driver,            // device driver list
    NULL,                 // init string
  },

  { "" }
};

//-- Dummy routines ------------------------------------------------

INT  poll_event(INT source, INT count, BOOL test) {return 1;};
INT  interrupt_configure(INT cmd, INT source, POINTER_T adr) {return 1;};

//-- Frontend Init -------------------------------------------------
/*!
 * <p>Called by the master frontend (mfe) at initializing stage.
 */
INT frontend_init()
{
  // de-register run-transition notifications
  cm_deregister_transition(TR_START);
  cm_deregister_transition(TR_STOP);
  cm_deregister_transition(TR_PAUSE);
  cm_deregister_transition(TR_RESUME);

  return CM_SUCCESS;
}

//-- Frontend Exit -------------------------------------------------
/*!
 * <p>Called by the mfe at exiting stage.
 * Unlinks all the established hotlinks.
 */
INT frontend_exit()
{
  return CM_SUCCESS;
}

//-- Frontend Loop -------------------------------------------------
/*!
 * <p>Called by the mfe in the main loop, if the frontend_call_loop flag is set to TRUE.
 *
 */
INT frontend_loop()
{
  return CM_SUCCESS;
}

//-- Begin of Run --------------------------------------------------
/*!
 * <p>Called by the mfe at the begin of the run.
 * Here it is only a dummy.
 */
INT begin_of_run(INT run_number, char *error)
{
  return CM_SUCCESS;
}

//-- End of Run ----------------------------------------------------
/*!
 * <p>Called by the mfe at the end of the run.
 * Here it is only a dummy.
 */
INT end_of_run(INT run_number, char *error)
{
  return CM_SUCCESS;
}

//-- Pause Run -----------------------------------------------------
/*!
 * <p>Called by the mfe when the run is paused.
 * Here it is only a dummy.
 */
INT pause_run(INT run_number, char *error)
{
  return CM_SUCCESS;
}

//-- Resume Run ----------------------------------------------------
/*!
 * <p>Called by the mfe when the run is resumed.
 * Here it is only a dummy.
 */
INT resume_run(INT run_number, char *error)
{
  return CM_SUCCESS;
}

//------------------------------------------------------------------
