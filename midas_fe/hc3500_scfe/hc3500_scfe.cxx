/********************************************************************\

  Name:         hc3500_scfe.cxx
  Created by:   Zaher Salman

  Contents:     Midas frontend to operate the HC3500 PSU

\********************************************************************/

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <unistd.h>

#include "midas.h"
#include "mfe.h"

#include "class/multi.h"
#include "hc3500.h"
#include "tcpip_rs232.h"

//-- Globals -------------------------------------------------------

//! The frontend name (client name) as seen by other MIDAS clients
const char *frontend_name = "HC3500_SC";
//! The frontend file name, don't change it
const char *frontend_file_name = __FILE__;

//! frontend_loop is called periodically if this variable is TRUE
BOOL frontend_call_loop = FALSE;

//! a frontend status page is displayed with this frequency in ms
INT display_period = 1000;

//! maximum event size produced by this frontend
INT max_event_size = 10000;

//! maximum event size for fragmented events (EQ_FRAGMENTED)
INT max_event_size_frag = 5*1024*1024;

//! buffer size to hold events
INT event_buffer_size = 10*10000;

float *input;

//-- Equipment list ------------------------------------------------

//! device driver list
DEVICE_DRIVER hc3500_driver[] = {
  { "HC3500_In",   hc3500_in,   7, tcpip_rs232, DF_INPUT  },
  { "HC3500_Out",  hc3500_out,  5, tcpip_rs232, DF_OUTPUT },
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
BOOL equipment_common_overwrite = FALSE;

EQUIPMENT equipment[] = {

  { "HC3500",             // equipment name
   {13, 0,                // event ID, trigger mask
    "SYSTEM",             // event buffer
    EQ_SLOW,              // equipment type
    0,                    // event source
    "FIXED",              // format
    TRUE,                 // enabled
    RO_RUNNING |
    RO_TRANSITIONS,       // read when running and on transitions
    1000,                 // read every 1 sec
    0,                    // stop run after this event limit
    0,                    // number of sub events
    1,                    // log history every event
    "", "", "",},
    cd_multi_read,        // readout routine
    cd_multi,             // class driver main routine
    hc3500_driver,        // device driver list
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
 * Here it is only a dummy.
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
 * Here it is only a dummy.
 */
INT frontend_exit()
{
  return CM_SUCCESS;
}

//-- Frontend Loop -------------------------------------------------
/*!
 * <p>Called by the mfe in the main loop.
 * Here it is only a dummy.
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
