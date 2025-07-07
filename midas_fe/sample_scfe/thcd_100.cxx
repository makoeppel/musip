/*----------------------------------------------------------------------------

  Name:         thcd_100.cxx
  Created by:   Andreas Suter  2001/08/29

  Contents:     device driver for THCD-100 Hastings Flow Monitor

  RS232:        9600 baud, 8 data bits, 1 stop bit, no parity,
                protocol: CTS (hardware), termination \r\n (CR\LF)

----------------------------------------------------------------------------*/

#include <cstdio>
#include <cstdlib>
#include <cstdarg>
#include <cstring>

#include "midas.h"
#include "mfe.h"

#include "thcd_100.h"

#include "ets_logout.h"

#define THCD_100_INIT_ERROR -2   //!< tag: initializing error
#define THCD_100_READ_ERROR -1   //!< tag: read error

#define THCD_100_MAX_READ    5   //!< maximal number for reading retries

//! timeout in (ms) for the communication between pc and thcd_100
#define THCD_100_TIME_OUT 2000

//! maximum number of readback failures before a reconnect will take place
#define THCD_100_MAX_READBACK_FAILURE 5

//! timeout in (sec) between logout terminal server an reconnection trial
#define THCD_100_RECONNECTION_TIMEOUT 5

//! sleep time (us) between the telnet commands of the ets_logout
#define THCD_100_ETS_LOGOUT_SLEEP 10000

#define THCD_100_READBACK_QUERY 3
#define THCD_100_READBACK_CMD   2

//--------- to handle error messages ------------------------------

//! maximum number of error messages
#define THCD_100_MAX_ERROR 2
//! reset error counter after THCD_100_DELTA_TIME_ERROR seconds
#define THCD_100_DELTA_TIME_ERROR  3600

//! Stores all the parameters the device driver needs
typedef struct {
  INT   detailed_msg; //!< flag indicating if detailed status/error messages are wanted
  INT   ets_in_use;   //!< flag indicating if the rs232 terminal server is in use
  char  names_in[NAME_LENGTH];   //!< Names of the input channels as found in the ODB
  char  names_out[NAME_LENGTH]; //!< Names of the output channels as found in the ODB
} THCD_100_SETTINGS;

//! Initializing string for the struct THCD_100_SETTINGS
const char *thcd_100_settings_str = 
"Detailed Messages = INT : 0\n\
ETS_IN_USE = INT : 1\n\
Input Names = STRING : [32] Flow\n\
Output Names = STRING : [32] Re-Zero\n\
";

//! This structure contains private variables for the device driver.
typedef struct {
  THCD_100_SETTINGS thcd_100_settings; //!< stores the internal DD settings
  INT   (*bd)(INT cmd, ...);   //!< bus driver entry function
  void  *bd_info;              //!< private info of bus driver
  int   bd_connected;          //!< flag showing if bus driver is connected
  int   first_bd_error;        //!< flag showing if the bus driver error message is already given
  HNDLE hkey;                  //!< ODB key for bus driver info
  INT   errcount;              //!< error counter in order not to flood the message queue
  INT   startup_error;         //!< initializer error tag, if set, thcd_100_get and thcd_100_set won't do anything
  DWORD lasterrtime;           //!< last error time stamp
  INT   readback_failure;      //!< counts the number of readback failures
  DWORD last_reconnect;        //!< timer for bus driver reconnect error handling
  int   reconnection_failures; //!< how often reconnection failed
} THCD_100_INFO;

THCD_100_INFO *thcd_100_info; //!< global info structure, in/out-init routines need the same structure

//---- support routines --------------------------------------------

typedef INT(func_t) (INT cmd, ...);

/*!
 * <p>send<->recieve command
 *
 * <p><b>Return:</b> number of bytes read.
 *
 * \param cmd command string
 * \param str reply string
 * \param size size of str
 * \param no_rbk number of readbacks of the command
 */
INT thcd_100_send_rcv(THCD_100_INFO *info, char *cmd, char *str, int size, int no_rbk)
{
  int status[3] = {0, 0, 0};
  int status_ok = 1;
  int i;
  char reply[3][128];

  for (i=0; i<3; i++)
    status[i] = 0;

  BD_PUTS(cmd);

  // get the reply
  for (i=0; i<no_rbk; i++)
    status[i] = BD_GETS(reply[i], 128*sizeof(char), "\r\n", THCD_100_TIME_OUT);

  // check that there enough readbacks
  for (i=0; i<no_rbk; i++) {
    if (status[i] == 0) {
      status_ok = 0;
      status[1] = 0;
    }
  }

  // feed message queue if detailed messages are wanted
  if (status_ok && info->thcd_100_settings.detailed_msg==2) {
    for (i=0; i<no_rbk; i++)
      cm_msg(MDEBUG, "thcd_100_send_rcv", "thcd_100_send_rcv: %d> %s", i, reply[i]);
    cm_yield(0);
  }

  if (status_ok) {
    // analyze error code
    if (!strstr(reply[no_rbk-1], "!a!o!")) { // something NOT OK
      if (strstr(reply[no_rbk-1], "!a!b!") && info->thcd_100_settings.detailed_msg) {
        cm_msg(MDEBUG, "thcd_100_send_rcv", "thcd_100_send_rcv: command error.");
        cm_yield(0);
      } else if (strstr(reply[no_rbk-1], "!a!e!") && info->thcd_100_settings.detailed_msg) {
        cm_msg(MDEBUG, "thcd_100_send_rcv", "thcd_100_send_rcv: internal communication error.");
        cm_yield(0);
      } else if (strstr(reply[no_rbk-1], "!a!w!") && info->thcd_100_settings.detailed_msg) {
        cm_msg(MDEBUG, "thcd_100_send_rcv", "thcd_100_send_rcv: communication port busy.");
        cm_yield(0);
      }
    }

    if (no_rbk == THCD_100_READBACK_QUERY)
      strncpy(str, reply[1], size);
  } else {
    strncpy(str, "???", size);
  }

  return status[1];
}

/*---- device driver routines --------------------------------------*/

/*!
 * <p>Initializes the thcd_100 device driver, i.e.\ generates all the necessary
 * structures in the ODB if necessary, initializes the bus driver and the thcd_100.
 *
 * <p><b>Return:</b> FE_SUCCESS
 *
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT thcd_100_in_init(HNDLE hKey, THCD_100_INFO **pinfo, INT channels, func_t *bd)
{
  INT   status, size;
  char  cmd[64], str[64];
  HNDLE hDB, hkeydd;

  // allocate info structure
  THCD_100_INFO *info = (THCD_100_INFO*)calloc(1, sizeof(THCD_100_INFO));
  thcd_100_info = info; // keep global pointer
  *pinfo = info;

  cm_get_experiment_database(&hDB, NULL);

  // create THCD-100 settings record
  status = db_create_record(hDB, hKey, "DD", thcd_100_settings_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "thcd_100_init", "thcd_100_init: Error creating THCD-100 DD record in ODB, status=%d", status);
    cm_yield(0);
    return FE_ERR_ODB;
  }

  db_find_key(hDB, hKey, "DD", &hkeydd);
  size = sizeof(info->thcd_100_settings);
  db_get_record(hDB, hkeydd, &info->thcd_100_settings, &size, 0);

  // initialize driver
  info->bd                    = bd;
  info->hkey                  = hKey;
  info->errcount              = 0;
  info->startup_error         = 0;
  info->lasterrtime           = ss_time();
  info->readback_failure      = 0;
  info->last_reconnect        = ss_time();
  info->reconnection_failures = 0;
  info->first_bd_error        = 1;

  if (!bd)
    return FE_ERR_ODB;

  // initialize bus driver
  status = info->bd(CMD_INIT, info->hkey, &info->bd_info);
  if (status != SUCCESS) {
    cm_msg(MERROR, "thcd_100_init", "Couldn't initialize the bus driver :-(");
    info->startup_error = 1;
    info->bd_connected = FALSE;
    return FE_SUCCESS;
  }
  info->bd_connected = TRUE;

  // since there is nothing like a identification, I will use the 'last calibration date' instead.
  cm_msg(MINFO, "thcd_100_init", "initialize thcd_100 ...");
  cm_yield(0);
  strcpy(cmd, "adlc?\r");
  status = thcd_100_send_rcv(info, cmd, str, sizeof(str), THCD_100_READBACK_QUERY);
  if (status == 0) {
    info->startup_error = 1;
    return FE_SUCCESS;
  }
  cm_msg(MINFO, "thcd_100_init", "thcd_100: %s", str);
  cm_yield(0);

  cm_msg(MINFO, "thcd_100_init", "thcd_100 initialized");
  cm_yield(0);

  return FE_SUCCESS;
}

//---------------------------------------------------------------------------------
/*!
 * <p>The out init routine is just needed to keep some pointers.
 *
 * <p><b>Return:</b> FE_SUCCESS
 *
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT thcd_100_out_init(HNDLE hKey, THCD_100_INFO **pinfo, INT channels, func_t *bd)
{
  *pinfo = thcd_100_info;

  return FE_SUCCESS;
}

//---------------------------------------------------------------------------------
/*!
 * <p>Quits the bus driver and free's the memory allocated for the info structure
 * <pre>THCD_100_INFO</pre>.
 *
 * <p><b>Return:</b> FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 */
INT thcd_100_exit(THCD_100_INFO *info)
{
  // call EXIT function of bus driver, usually closes device
  info->bd(CMD_EXIT, info->bd_info);

  free(info);

  return FE_SUCCESS;
}

//---------------------------------------------------------------------------------
/*!
 * <p>Sends a new value to the THCD-100. Currently only 'User input rezero' is
 * implemented. If value==1 will execute re-zeroing, otherwise nothing will happen.
 *
 * <p><b>Return:</b> FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel for which channel is this command
 * \param value to be set.
 */
INT thcd_100_set(THCD_100_INFO *info, INT channel, float value)
{
  char cmd[64], str[64];
  INT  status;

  if (info->startup_error)
    return FE_SUCCESS;

  if (!info->bd_connected) {
    if (info->first_bd_error) {
      info->first_bd_error = 0;
      cm_msg(MINFO, "thcd_100_set",
            "set values not possible at the moment, since the bus driver is not available!");
    }
  }

  if (value == 1) {
    strncpy(cmd, "airz\r", sizeof(cmd));
    status = thcd_100_send_rcv(info, cmd, str, sizeof(str), THCD_100_READBACK_CMD);
  }

  return FE_SUCCESS;
}

//---------------------------------------------------------------------------------
/*!
 * <p>At startup, after initialization of the DD, this routine allows to write
 * default names into the ODB.
 *
 * <p><b>Return:</b> FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT thcd_100_get_label_in(THCD_100_INFO *info, INT channel, char *name)
{
  strcpy(name, info->thcd_100_settings.names_in);
  return FE_SUCCESS;
}

//---------------------------------------------------------------------------------
/*!
 * <p>At startup, after initialization of the DD, this routine allows to write
 * default names into the ODB.
 *
 * <p><b>Return:</b> FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT thcd_100_get_label_out(THCD_100_INFO *info, INT channel, char *name)
{
  strcpy(name, info->thcd_100_settings.names_out);
  return FE_SUCCESS;
}

//---------------------------------------------------------------------------------
/*!
 * <p>Reads a value back from the THCD-100 Hastings Flow Monitor.
 *
 * <p><b>Return:</b> FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel to be read back
 * \param pvalue pointer to the ODB value
 */
INT thcd_100_get(THCD_100_INFO *info, INT channel, float *pvalue)
{
  char  cmd[64], str[64];
  INT   status;
  float fvalue;
  DWORD nowtime, difftime;

  // check if there was a startup error
  if ( info->startup_error ) {
     *pvalue = (float) THCD_100_INIT_ERROR;
     ss_sleep(10); // to keep CPU load low when Run active
     return FE_SUCCESS;
  }

  // error timeout facility
  nowtime = ss_time();
  difftime = nowtime - info->lasterrtime;
  if ( difftime >  THCD_100_DELTA_TIME_ERROR ) {
    info->errcount = 0;
    info->lasterrtime = nowtime;
  }

  // check if they where too many reconnection failures
  if (info->reconnection_failures > 5) {
    *pvalue = (float) THCD_100_READ_ERROR;
    if (info->reconnection_failures == 6) {
      cm_msg(MERROR, "thcd_100_get", "too many reconnection failures, bailing out :-(");
      info->reconnection_failures++;
    }
    return FE_SUCCESS;
  }

  // if disconnected, try to reconnect after a timeout of a timeout
  if (!info->bd_connected) {
    if (ss_time()-info->last_reconnect > THCD_100_RECONNECTION_TIMEOUT) { // timeout expired
      if (info->thcd_100_settings.detailed_msg)
        cm_msg(MINFO, "thcd_100_get", "THCD-100: reconnection trial ...");
      status = info->bd(CMD_INIT, info->hkey, &info->bd_info);
      if (status != FE_SUCCESS) {
        info->reconnection_failures++;
        *pvalue = (float) THCD_100_READ_ERROR;
        if (info->thcd_100_settings.detailed_msg)
          cm_msg(MINFO, "thcd_100_get", "THCD-100: reconnection attempted failed");
        return FE_SUCCESS;
      } else {
        info->bd_connected = 1; // bus driver is connected again
        info->last_reconnect = ss_time();
        info->reconnection_failures = 0;
        info->first_bd_error = 1;
        if (info->thcd_100_settings.detailed_msg)
          cm_msg(MINFO, "thcd_100_get", "THCD-100: successfully reconnected");
      }
    } else { // timeout still running
      ss_sleep(10); // in order to keep the CPU happy
      return FE_SUCCESS;
    }
  }

  // generate read command ------------------------------------------
  strcpy(cmd, "ar\r");

  // send<->recieve -------------------------------------------------
  status = thcd_100_send_rcv(info, cmd, str, sizeof(str), THCD_100_READBACK_QUERY);

  if (info->thcd_100_settings.detailed_msg==2)
    cm_msg(MINFO,"thcd_100_get","%s status = %d, received string = %s", cmd, status, str);
  if (!status) {
    if ((info->errcount < THCD_100_MAX_ERROR) && (info->readback_failure > 3)) {
      cm_msg(MERROR, "thcd_100_get",
             "CHN thcd_100 does not respond. Check power and RS232 connection, further check Lantronix.");
      info->errcount++;
    }

    info->readback_failure++;

    if (info->readback_failure == THCD_100_MAX_READBACK_FAILURE) {
      info->readback_failure = 0;
      // try to disconnect and reconnect the bus driver
      if ((ss_time()-info->last_reconnect > THCD_100_RECONNECTION_TIMEOUT) && info->bd_connected) {
        info->bd(CMD_EXIT, info->bd_info); // disconnect bus driver
        if (info->thcd_100_settings.detailed_msg)
          cm_msg(MINFO, "thcd_100_get", "THCD-100: try to disconnect and reconnect the bus driver");
        info->last_reconnect = ss_time();
        info->bd_connected = 0;
        if (info->thcd_100_settings.ets_in_use)
          ets_logout(info->bd_info, THCD_100_ETS_LOGOUT_SLEEP, info->thcd_100_settings.detailed_msg);
      }
    }
    return FE_SUCCESS;
  }

  // decode reply string ---------------------------------------------------------------
  sscanf(str, "READ:%f;", &fvalue);

  // new valid value
  *pvalue = fvalue;

  // reset readback error counter
  info->readback_failure = 0;

  return FE_SUCCESS;
}

/*---- device driver entry point -----------------------------------*/
INT thcd_100_in(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   *pvalue;
  THCD_100_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey = va_arg(argptr, HNDLE);
        THCD_100_INFO **pinfo = va_arg(argptr, THCD_100_INFO**);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t*);
        status = thcd_100_in_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_EXIT:
      info = va_arg(argptr, THCD_100_INFO *);
      status = thcd_100_exit(info);
      break;

    case CMD_GET:
      info = va_arg(argptr, THCD_100_INFO *);
      channel = va_arg(argptr, INT);
      pvalue  = va_arg(argptr, float*);
      status = thcd_100_get(info, channel, pvalue);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, THCD_100_INFO *);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = thcd_100_get_label_in(info, channel, name);
      break;

    default:
      break;
  }

  va_end(argptr);

  return status;
}

//---------------------------------------------------------------------------------
INT thcd_100_out(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   value;
  THCD_100_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey = va_arg(argptr, HNDLE);
        THCD_100_INFO **pinfo = va_arg(argptr, THCD_100_INFO**);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t*);
        status = thcd_100_out_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, THCD_100_INFO *);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = thcd_100_get_label_out(info, channel, name);
      break;

    case CMD_SET:
      info = va_arg(argptr, THCD_100_INFO *);
      channel = va_arg(argptr, INT);
      value   = (float) va_arg(argptr, double);
      status = thcd_100_set(info, channel, value);
      break;

    default:
      break;
  }

  va_end(argptr);

  return status;
}
//---------------------------------------------------------------------------------
