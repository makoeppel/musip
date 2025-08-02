/********************************************************************\

  Name:         danfysik_spin_rot_scfe.cxx
  Created by:   Andreas Suter

  Contents:     midas slowcontrol frontend to handle the magnet of the
                LEM spin rotator via the danfysik power supply.

\********************************************************************/

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>

#include "midas.h"
#include "mfe.h"

#include "class/multi.h"
#include "danfysik.h"
#include "tcpip_rs232.h"

//-- Globals -------------------------------------------------------

#define DANFYSIK_REMOTE_CH  0
#define DANFYSIK_STATE_CH   1
#define DANFYSIK_DEMAND_CH  2
#define DANFYSIK_MEASURE_CH 3

#define DANFYSIK_TIMEOUT_CHECK 30
// danfysik demand <-> measured check timestamp
DWORD danfysik_check_timestamp;

//! The frontend name (client name) as seen by other MIDAS clients
const char *frontend_name = "PABA_Magnet_SC";
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

//-- Equipment list ------------------------------------------------

/*!
 * <p>device driver list for the danfysik power supply used for the
 *    LEM spin rotator magnet.
 */
DEVICE_DRIVER danfysik_driver[] = {
  { "Danfysik_in",  danfysik_in,  5, tcpip_rs232, DF_INPUT  },
  { "Danfysik_out", danfysik_out, 4, tcpip_rs232, DF_OUTPUT },
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

//! equipment structure for the mfe.c
EQUIPMENT equipment[] = {

  { "Danfysik_PABA_Magnet",  // equipment name
   {98, 0,                // event ID, trigger mask
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
    cd_multi_read,        // readout routine
    cd_multi,             // class driver main routine
    danfysik_driver,      // device driver list
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

  // init danfysik demand <-> measured read timer
  danfysik_check_timestamp = ss_time();

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
 */
INT frontend_loop()
{
  DWORD now;
  HNDLE hDB, hKeyIn, hKeyOut;
  int status, size;
  float setpoint_current, measured_current, remote, state;
  static int err_count = 0;
  char str[128];

  // is it time to check things?
  now = ss_time();
  if (now - danfysik_check_timestamp < DANFYSIK_TIMEOUT_CHECK)
    return CM_SUCCESS;

  // update timestamp
  danfysik_check_timestamp = now;

  // get experiment handle
  cm_get_experiment_database(&hDB, NULL);

  // get danfysik input handle
  status = db_find_key(hDB, 0, "/Equipment/Danfysik_PABA_Magnet/Variables/Input", &hKeyIn);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "frontend_loop", "danfysik_magnet_scfe, frontend_loop: couldn't get danfysik spin rot input key from the ODB.");
    return CM_SUCCESS;
  }
  // get danfysik output handle
  status = db_find_key(hDB, 0, "/Equipment/Danfysik_PABA_Magnet/Variables/Output", &hKeyOut);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "frontend_loop", "danfysik_magnet_scfe, frontend_loop: couldn't get danfysik spin rot output key from the ODB.");
    return CM_SUCCESS;
  }

  // get danfysik state and remote flag
  size = sizeof(float);
  status = db_get_data_index(hDB, hKeyOut, &remote, &size, DANFYSIK_REMOTE_CH, TID_FLOAT);
  size = sizeof(float);
  status = db_get_data_index(hDB, hKeyOut, &state, &size, DANFYSIK_STATE_CH, TID_FLOAT);

  // if remote and on check things
  if ((remote != 1.0) || (state != 1.0))
    return CM_SUCCESS;

  // get current demand
  size = sizeof(float);
  status = db_get_data_index(hDB, hKeyOut, &setpoint_current, &size, DANFYSIK_DEMAND_CH, TID_FLOAT);

  // get current measured
  size = sizeof(float);
  status = db_get_data_index(hDB, hKeyIn, &measured_current, &size, DANFYSIK_MEASURE_CH, TID_FLOAT);

  // max deviation < 10%?
  if (fabsf(setpoint_current-measured_current)/fabsf(setpoint_current) > 0.1) {
    err_count++;
  } else {
    err_count = 0;
  }

  // too many consecutive error counts, hence issue a warning
  if (err_count == 10) {
    sprintf(str, "Danfysik PABA Magnet Setpoint = %0.1f A, Measured = %0.1f A: something is fishy!", setpoint_current, measured_current);
    al_trigger_alarm( "danfysik_magnet_current_monitoring", str, "Warning", str, AT_INTERNAL);
  }

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
