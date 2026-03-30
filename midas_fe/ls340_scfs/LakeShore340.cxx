/********************************************************************\

  Name:         LakeShore340.cxx
  Created by:   Andreas Suter   2003/10/22
  Modified by:  Zaher Salman   30 Mar 2026

  Contents: device driver for the LakeShore 340 temperature controller,
            defined as a multi class device.

    RS232: 19200 baud, 8 data bits, 1 stop bit, no parity bit,
           protocol: no flow control, termination \r\n (CR\LF)

\********************************************************************/

#include <cstdio>
#include <cstdlib>
#include <cstdarg>
#include <cstring>
#include <cmath>
#include <ctime>

#include "midas.h"
#include "mfe.h"
#include "msystem.h"

#include "LakeShore340.h"
// Can we get rid of this?
#include "ets_logout.h"

/*---- globals -----------------------------------------------------*/

#define LS340_SHUTDOWN -999
#define LS340_MAX_SENSORS 10 //!< max. number of possible input sensors
#define LS340_DELTA_R 2.0    //!< max. allowed deviation between ODB heater resistance and LS340 readback
#define LS340_TIME_OUT 2000  //!< time out in msecs for read (rs232)

/* --------- to handle error messages ------------------------------*/
#define LS340_MAX_ERROR 3             //!< maximum number of error messages
#define LS340_DELTA_TIME_ERROR 3600   //!< reset error counter after LS340_DELTA_TIME_ERROR seconds
#define LS340_MAX_TRY_MANY 10         //!< maximum number of communication attempts for important reads
#define LS340_MAX_TRY_LESS  3         //!< maximum number of communication attempts for less important reads

#define LS340_WAIT 500                //!< time (ms) to wait between commands

#define LS340_INIT_ERROR -2           //!< initialize error tag
#define LS340_READ_ERROR -1           //!< read error tag

//! max. length of the average array
#define LS340_MAX_AVG 100

//! debug tag, if set to TRUE, additional messages will be displayed at execution time
#define LS340_DEBUG 0

//! maximum number of readback failures before a reconnect will take place
#define LS340_MAX_READBACK_FAILURE 5
#define LS340_MAX_RECONNECTION_FAILURE 5

//! sleep time (us) between the telnet commands of the ets_logout
#define LS340_ETS_LOGOUT_SLEEP 10000

//! stores internal informations within the DD.
typedef struct {
  char datetime[32];                         //!< current date and time
  INT  type[LS340_MAX_SENSORS];              //!< sensor type: 1-12, see LakeShore340 manual, p.9-33
  INT  curve[LS340_MAX_SENSORS];             //!< sensor calibration curve: see LakeShore340 manual, p.9-33
  char channel[LS340_MAX_SENSORS][4];        //!< which channel: A, B, C1-C4, D1-D4
  char name[LS340_MAX_SENSORS][NAME_LENGTH]; //!< name for each channel
  float raw_value_1;                         //!< raw sensor reading channel 1
  float raw_value_2;                         //!< raw sensor reading channel 2
  float raw_value_3;                         //!< raw sensor reading channel 3
  float raw_value_4;                         //!< raw sensor reading channel 4
  float raw_value_5;                         //!< raw sensor reading channel 5
  float raw_value_6;                         //!< raw sensor reading channel 6
  float raw_value_7;                         //!< raw sensor reading channel 7
  float raw_value_8;                         //!< raw sensor reading channel 8
  float raw_value_9;                         //!< raw sensor reading channel 9
  float raw_value_10;                        //!< raw sensor reading channel 10
} LS340_SENSORS;

//! initializing string for LS340_SENSORS
const char *ls340_sensors_str =
"Date and Time = STRING : [32] \n\
Sensor Type = INT[10]: \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
Calibration Curve = INT[10]: \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
Channel = STRING[10]: \n\
[4] A\n\
[4] B\n\
[4] C1\n\
[4] C2\n\
[4] C3\n\
[4] C4\n\
[4] D1\n\
[4] D2\n\
[4] D3\n\
[4] D4\n\
Sensor Name = STRING[10]: \n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
[32] LS_\n\
Raw Input Ch 1  = FLOAT : 0.0\n\
Raw Input Ch 2  = FLOAT : 0.0\n\
Raw Input Ch 3  = FLOAT : 0.0\n\
Raw Input Ch 4  = FLOAT : 0.0\n\
Raw Input Ch 5  = FLOAT : 0.0\n\
Raw Input Ch 6  = FLOAT : 0.0\n\
Raw Input Ch 7  = FLOAT : 0.0\n\
Raw Input Ch 8  = FLOAT : 0.0\n\
Raw Input Ch 9  = FLOAT : 0.0\n\
Raw Input Ch 10 = FLOAT : 0.0\n\
";

/*---------------------------------------------------------------------*/

//! stores internal informations within the DD.
typedef struct {
  char  ctrl_ch[4];        //!< which channel is used for control loop (A/B/C1-C4/D1-D4 possible)
  float setpoint_limit;    //!< in Kelvin
  int   max_current_tag;   //!< 1->0.25A, 2->0.5A, 3->1.0A, 4->2.0A, 5->User
  float max_user_current;  //!< max. current (in A) for user current tag 5
  int   max_heater_range;  //!< upper limit for the heater range (see LakeShore340 manual, 6-9, 9-27)
  float heater_resistance; //!< heater resistance in OhmLakeShore340.sav
} LS340_LOOP1;     // see lakeshore 340 manual chapter 9 (CSET, PID, CLIMIT)

//! initializing string for LS340_LOOP1
const char *ls340_loop1_str = 
"CTRL_CH = STRING : [4] A\n\
SetPoint Limit = FLOAT : 320.f\n\
Max. Current Tag = INT : 4\n\
Max. User Current = FLOAT : 0.85\n\
Max. Heater Range = INT : 5\n\
Heater Resistance = FLOAT : 25.0\n\
";

/*---------------------------------------------------------------------*/

//! stores internal informations within the DD.
typedef struct {
  INT   detailed_msg;      //!< flag indicating if detailed status/error messages are wanted
  INT   ets_in_use;        //!< flag indicating if the rs232 terminal server is in use
  INT   no_connection;     //!< flag showing that there is no connection at the moment
  INT   reconnect_timeout; //!< reconnection timeout in (sec)
  INT   read_timeout;      //!< get data every read_timeout (sec), if zero midas has the timing control
  BOOL  read_raw_data;     //!< flag indicating if raw data shall be read
  INT   odb_offset;        //!< odb offset for the output variables. Needed by the forced update routine
  char  odb_output[2*NAME_LENGTH]; //!< odb output variable path. Needed by the forced update routine
  INT   remote;            //!< stores if the LS340 is computer controlled of not
  INT   no_of_sensors;     //!< number of sensors used
} LS340_INTERNAL;

//! initializing string for LS340_INTERNAL
const char *ls340_internal_str =
"Detailed Messages = INT : 0\n\
ETS_IN_USE = INT : 1\n\
No Connection = INT : 1\n\
Reconnection Timeout = INT : 10\n\
Read Timeout = INT : 5\n\
Read Raw Data = BOOL : FALSE\n\
ODB Offset = INT : 0\n\
ODB Output Path = STRING : [64] /Equipment/LS340 Moddy/Variables/Output\n\
Remote = INT : 1\n\
# Sensors = INT : 7\n\
";

/*---------------------------------------------------------------------*/

/*!
 * <p> initializing string for the zone settings. Each zone string has
 * the following syntax:
 * <pre>loop, zone, top_temp, P, I, D, man_out, range</pre>
 */
const char *ls340_zone_str =
"Zone = STRING[10]: \n\
[32] 1,  1,   7, 500, 300, 0, 0, 3\n\
[32] 1,  2,  10, 500, 200, 2, 0, 4\n\
[32] 1,  3,  15, 500, 100, 2, 0, 4\n\
[32] 1,  4,  20, 500,  50, 2, 0, 4\n\
[32] 1,  5,  30, 500,  20, 2, 0, 4\n\
[32] 1,  6, 320, 500,  20, 2, 0, 5\n\
[32] 1,  7, 320, 500,  20, 2, 0, 5\n\
[32] 1,  8, 320, 500,  20, 2, 0, 5\n\
[32] 1,  9, 320, 500,  20, 2, 0, 5\n\
[32] 1, 10, 320, 500,  20, 2, 0, 5\n\
";

/*---------------------------------------------------------------------*/

//! stores internal informations within the DD.
typedef struct {
  LS340_INTERNAL intern;
  LS340_SENSORS  sensor;
  LS340_LOOP1    loop1;
  char           zone[10*NAME_LENGTH];
} LS340_SETTINGS;

/*---------------------------------------------------------------------*/

//! stores internal informations within the DD.
typedef struct {
  char ls_name[NAME_LENGTH];      //!< name of the LS340
  char names_in[8][NAME_LENGTH];  //!< names of the in-channels
  char names_out[8][NAME_LENGTH]; //!< names of the out-channels
} LS340_ODB_NAMES;

//! initializing string for LS340_ODB_NAMES
const char *ls340_odb_names_str =
"LakeShore 340 Name = STRING : [32] Sample\n\
Names In = STRING[8] : \n\
[32] LS_Heater\n\
[32] LS_SetPoint (read back)\n\
[32] LS_Gain  P (read back)\n\
[32] LS_Reset I (read back)\n\
[32] LS_Rate  D (read back)\n\
[32] LS_HeaterRange (read back)\n\
[32] LS_ControlMode (read back)\n\
[32] LS_Ramp (read back)\n\
Names Out = STRING[8] : \n\
[32] LS_Remote (1/0)\n\
[32] LS_SetPoint (K)\n\
[32] LS_Gain  P\n\
[32] LS_Reset I\n\
[32] LS_Rate  D\n\
[32] LS_HeaterRange\n\
[32] LS_ControlMode\n\
[32] LS_Ramp\n\
";

/*---------------------------------------------------------------------*/

//! This structure contains private variables for the device
//! driver.
typedef struct {
  LS340_SETTINGS  ls340_settings;  //!< ODB data for the DD
  LS340_ODB_NAMES ls340_odb_names; //!< ODB data for the DD
  char  cryo_name[NAME_LENGTH];    //!< name of the LS340
  HNDLE hDB;                       //!< main handle to the ODB
  HNDLE hkey;                      //!< handle to the BD key
  HNDLE hkey_no_connection;        //!< handle to the no connection flag
  HNDLE hkey_datetime;             //!< handle to the date and time DD entry
  HNDLE hkey_raw_value[10];        //!< handle to the raw value input DD entry
  INT   num_channels_in;           //!< number of in-channels
  INT   num_channels_out;          //!< number of out-channels
  INT (*bd)(INT cmd, ...);         //!< bus driver entry function
  void *bd_info;                   //!< private info of bus driver
  DWORD read_timer[20];            //!< timer telling the system when to read data (via LS340_get, in (ms))
  INT   errorcount;                //!< error counter
  INT   startup_error;             //!< startup error tag
  DWORD lasterrtime;               //!< timer for error handling
  DWORD last_value[15];            //!< stores the last valid value
  int   bd_connected;              //!< flag showing if bus driver is connected
  int   first_bd_error;            //!< flag showing if the bus driver error message is already given
  DWORD last_reconnect;            //!< timer for bus driver reconnect error handlingLakeShore340.sav
  INT   readback_failure;          //!< counts the number of readback failures
  INT   reconnection_failures;     //!< how many reconnection failures took place
  INT   readback_err;              //!< number of readback errors for the temperature reading
  INT   heater_setting;            //!< current output heater setting
  float setpoint;                  //!< prevailing setpoint
  float cmode;                     //!< prevailing control mode
  float history[LS340_MAX_AVG];    //!< stores last temperatures of sensor 1
  int   ihis;                      //!< index in history
  BOOL  his_full;                  //!< flag used to indicate that the history buffer is full
  int   set_startup_counter;       //!< counter to supress setting of PID and Range at startup
} LS340_INFO;

LS340_INFO *ls340_info; //!< global info structure, in/out-init routines need the same structure

typedef INT(func_t) (INT cmd, ...);

/*---- support routines --------------------------------------------*/
/*!
 * <p> send/recieve routine. loops LS340_MAX_TRY times if there would be
 * a communication problem.</p>
 * <p><b>Return:</b> number of read bytes</p>
 * \param info is a pointer to the DD specific info structure
 * \param cmd command string
 * \param str reply string
 * \param max_try maximal number of read trials
 */
INT ls340_send_rcv(LS340_INFO *info, char *cmd, char *str, int max_try)
{
  char tmpstr[128];
  INT status, status_yield, i;

  if (!info->bd_connected) // bus driver not connected at the moment
    return 0;

  status = 0;
  i      = 0;
  do {
    
    BD_PUTS(cmd);
    status = BD_GETS(tmpstr, sizeof(tmpstr), "\r\n", LS340_TIME_OUT);
    if (LS340_DEBUG)
      cm_msg(MINFO,"ls340_send_rcv", "LS340: %s: trial %d, status = %d, str = %s",
             info->ls340_odb_names.ls_name, i, status, tmpstr);
    i++;
    
    if (status <= 0) { 
      status_yield = cm_yield(10);
      if ((status_yield == RPC_SHUTDOWN) || (status_yield == SS_ABORT)) {
        cm_msg(MINFO, "ls340_send_rcv", "ls340_send_rcv: status of cm_yield = %d", status_yield);
        return LS340_SHUTDOWN;
      }
      ss_sleep(LS340_WAIT);
    }
    
  } while ((status<=0) && (i < max_try));
  
  strcpy(str, tmpstr);
  
  if (LS340_DEBUG)
    cm_msg(MINFO,"ls340_send_rcv", "LS340: %s: str = %s", info->ls340_odb_names.ls_name, str);
  
  return status;
}

/*------------------------------------------------------------------*/
/*!
 * <p> delivers the correct command tags for LS340_get.</p>
 * <p><b>Return:</b> command tag</p>
 * \param info is a pointer to the DD specific info structure
 * \param ch current channel
 * \param sub_tag pointer to a sub_tag (for PID settings)
 */
INT ls340_get_decode(LS340_INFO *info, INT ch, int *sub_tag)
{
  int cmd_tag=0;

  if (ch < info->ls340_settings.intern.no_of_sensors) { // read temperature
    cmd_tag=0;
  }

  if (ch == info->ls340_settings.intern.no_of_sensors) { // heater output
    cmd_tag=1;
  }

  if (ch == info->ls340_settings.intern.no_of_sensors+1) { // setpoint
    cmd_tag=2;
  }

  if ((ch >= info->ls340_settings.intern.no_of_sensors+2) &&
      (ch <= info->ls340_settings.intern.no_of_sensors+4)) { // PID's
    cmd_tag=3;
    switch (ch-info->ls340_settings.intern.no_of_sensors-2) { // check if P, I or D
    case 0:
      *sub_tag=0;
      break;
    case 1:
      *sub_tag=1;
      break;
    case 2:
      *sub_tag=2;
      break;
    default:
      *sub_tag=0;
      break;
    }
  }
  
  if (ch == info->ls340_settings.intern.no_of_sensors+5) { // heater range
    cmd_tag=4;
  }
  
  if (ch == info->ls340_settings.intern.no_of_sensors+6) { // control mode
    cmd_tag=5;
  }
  
  if (ch == info->ls340_settings.intern.no_of_sensors+7) { // ramp
    cmd_tag=6;
  }

  return cmd_tag;
}

/*------------------------------------------------------------------*/
/*!
 * <p>Forces an update when switching to remote. This is necessary,
 * since otherwise there is no synchronization between the Input
 * and Output settings.
 *
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - DB_INVALID_HANDLE invalid database handle
 *   - DB_NO_ACCESS key has no read access
 *   - DB_NO_KEY key does not exist
 *
 * \param info is a pointer to the DD specific info structure
 */
INT ls340_force_update(LS340_INFO *info)
{
  HNDLE hDB, keyOut;
  INT   status, size;
  float value[3];
  char  cmd[128], qry[128], rcv[128];
  int   control_mode;

  cm_get_experiment_database(&hDB, NULL);

  // get Output key
  status = db_find_key(hDB, 0, info->ls340_settings.intern.odb_output, &keyOut);
  if (status != FE_SUCCESS) { // couldn't get the output key
    cm_msg(MERROR, "ls340_force_update", "ls340_force_update: %s. Couldn't get the Output key.",
           info->ls340_odb_names.ls_name);
    return status;
  }
  
  size = sizeof(float);
  
  // update 'set point'
  db_get_data_index(hDB, keyOut, &value[0], &size, 1+info->ls340_settings.intern.odb_offset, TID_FLOAT);
  sprintf(cmd, "SETP 1, %05.2f\r\n", value[0]);      // setpoint loop1
  info->setpoint = value[0];                         // store in info
  sprintf(qry, "SETP? 1\r\n");
  status = ls340_send_rcv(info, cmd, rcv, LS340_MAX_TRY_MANY); // send command
  status = ls340_send_rcv(info, qry, rcv, LS340_MAX_TRY_MANY); // query
  if ( !status )
    cm_msg(MERROR,"ls340_force_update","ls340_force_update: %s: Failed to query %s",
	   info->ls340_odb_names.ls_name, qry);
  else
    cm_msg(MINFO,"ls340_force_update", "ls340_force_update: %s: Result of query %s = %s",
	   info->ls340_odb_names.ls_name, qry, rcv);
  
  // update control mode
  db_get_data_index(hDB, keyOut, &value[0], &size, 6+info->ls340_settings.intern.odb_offset, TID_FLOAT);
  control_mode = (int) value[0];                  // store in order to made decision on PID
  sprintf(cmd, "CMODE 1, %d\r\n", (int)value[0]); // control mode
  sprintf(qry, "CMODE? 1\r\n");
  status = ls340_send_rcv(info, cmd, rcv, LS340_MAX_TRY_MANY); // send command
  status = ls340_send_rcv(info, qry, rcv, LS340_MAX_TRY_MANY); // query
  if ( !status )
    cm_msg(MERROR,"ls340_force_update","ls340_force_update: %s: Failed to query %s",
	   info->ls340_odb_names.ls_name, qry);
  else
    cm_msg(MINFO,"ls340_force_update", "ls340_force_update: %s: Result of query %s = %s",
	   info->ls340_odb_names.ls_name, qry, rcv);
  
  // update PID's
  if (control_mode != 2) { // i.e. not ZONE 
    db_get_data_index(hDB, keyOut, &value[0], &size, 2+info->ls340_settings.intern.odb_offset, TID_FLOAT); // gain 'P'
    db_get_data_index(hDB, keyOut, &value[1], &size, 3+info->ls340_settings.intern.odb_offset, TID_FLOAT); // reset 'I'
    db_get_data_index(hDB, keyOut, &value[2], &size, 4+info->ls340_settings.intern.odb_offset, TID_FLOAT); // rate 'D'
    sprintf(cmd, "PID 1, %d, %d, %d\r\n", (int)value[0], (int)value[1], (int)value[2]);
    sprintf(qry, "PID? 1\r\n");
    status = ls340_send_rcv(info, cmd, rcv, LS340_MAX_TRY_MANY); // send command
    status = ls340_send_rcv(info, qry, rcv, LS340_MAX_TRY_MANY); // query
    if ( !status )
      cm_msg(MERROR,"ls340_force_update","ls340_force_update: %s: Failed to query %s",
	     info->ls340_odb_names.ls_name, qry);
    else
      cm_msg(MINFO,"ls340_force_update", "ls340_force_update: %s: Result of query %s = %s",
	     info->ls340_odb_names.ls_name, qry, rcv);
    
    // update heater range
    db_get_data_index(hDB, keyOut, &value[0], &size, 5+info->ls340_settings.intern.odb_offset, TID_FLOAT);
    sprintf(cmd, "RANGE %d\r\n", (int)value[0]);	// heater range
    sprintf(qry, "RANGE?\r\n");
    status = ls340_send_rcv(info, cmd, rcv, LS340_MAX_TRY_MANY); // send command
    status = ls340_send_rcv(info, qry, rcv, LS340_MAX_TRY_MANY); // query
    if ( !status )
      cm_msg(MERROR,"ls340_force_update","ls340_force_update: %s: Failed to query %s",
	     info->ls340_odb_names.ls_name, qry);
    else
      cm_msg(MINFO,"ls340_force_update", "ls340_force_update: %s: Result of query %s = %s",
	     info->ls340_odb_names.ls_name, qry, rcv);
  }
  
  // update ramp
  db_get_data_index(hDB, keyOut, &value[0], &size, 7+info->ls340_settings.intern.odb_offset, TID_FLOAT);
  if (value[0] == 0) // ramp rate == 0, i.e. no ramp wished
    value[1] = 0;
  else
    value[1] = 1;
  sprintf(cmd, "RAMP 1, %d, %d\r\n", (int)value[1], (int)value[0]); // ramp
  sprintf(qry, "RAMP? 1\r\n");
  status = ls340_send_rcv(info, cmd, rcv, LS340_MAX_TRY_MANY); // send command
  status = ls340_send_rcv(info, qry, rcv, LS340_MAX_TRY_MANY); // query
  if ( !status )
    cm_msg(MERROR,"ls340_force_update","ls340_force_update: %s: Failed to query %s",
	   info->ls340_odb_names.ls_name, qry);
  else
    cm_msg(MINFO,"ls340_force_update", "ls340_force_update: %s: Result of query %s = %s",
	   info->ls340_odb_names.ls_name, qry, rcv);
  
  return FE_SUCCESS;
}

/*------------------------------------------------------------------*/
/*!
 * <p>Set's the <em>no connection</em> flag.
 *
 * \param info is a pointer to the DD specific info structure.
 * \param value equal 1 if the connection is available, otherwise 0.
 */
void ls340_no_connection(LS340_INFO *info, INT value)
{
  db_set_data(info->hDB, info->hkey_no_connection, &value, sizeof(value), 1, TID_INT);
}

/*------------------------------------------------------------------*/
/*!
 * <p>Hotlink routine which is switching LakeShore340 and ODB relevant informations.
 * Here the details:
 *
 * <p>Under the DD entry in the ODB, there is a tree Cryos. For each used cryostat
 * there should be an entry with its name (e.g. DD/Cryos/Konti-1). The cryo sub-tree
 * is structured as follows:
 *
 * - <b>Heater Resistance</b>: holds the resistance of the cryo's heater.
 * - <b>Max. Current Tag</b>: 1->0.25A, 2->0.5A, 3->1.0A, 4->2.0A, 5->User
 * - <b>Max. User Current</b>: if Max. Current Tag == 5, this current will be set (given in A).
 * - <b>Max. Heater Range</b>: upper limit for the heater range (see LakeShore340 manual, 6-9, 9-27)
 * - <b>Sensor Type</b>: sensor types for the 10 possible channels (for sensor types see
 *                       the LakeShore340 user manual p.9-33, INTYPE).
 * - <b>Calibration Curve</b>: calibration curve number for the 10 possible channels
 *                       (for details see the LakeShore340 user manual p.9-33 INCRV).
 * - <b>Channel</b>: channel name (A, B, C1-C4, D1-D4) for the 10 possible channels.
 * - <b>Sensor Name</b>: ODB Names of the 10 possible channels.
 * - <b>Zone</b>: 10 Zone settings (see LakeShore340 user manual p.9-42 ZONE).
 *
 * <p>The routine does the following:
 *
 * -# read all the above mentioned settings from the cryo specific ODB tree (e.g. DD/Cryos/Konti-1).
 * -# write these values to the ODB relevant subtrees (DD/.. etc., for details see the code).
 * -# update the LakeShore340 according the settings.
 *
 * <p>This procedure assures that even after a restart of the frontend, the settings of the new
 * cryo will be used.
 *
 * <p><b>WARNING:</b> Two things one should be aware of:
 *
 * -# The mlogger needs to be restarted if the ODB names are changed, otherwise the history will not
 *    be available.
 * -# If the number of temperature channels are different between cryo settings (hopefully not). The
 *    frontend needs to be restarted, since the ODB will change!
 *
 * \param hDB main ODB handle
 * \param dummy not used
 * \param pinfo is a pointer to the DD specific info structure
 */
void ls340_cryo_name_changed(HNDLE hDB, HNDLE dummy, void *pinfo)
{
  LS340_INFO *info;
  int   i, ch_no, value[4];
  int   status, size;
  float fvalue;
  float heater_resistance;
  int   sensor_type[10], calib_curve[10];
  char  str[128], cmd[128];
  char  sensor_name[10*NAME_LENGTH], channel[10*NAME_LENGTH], zone[10*NAME_LENGTH];
  char  ch[NAME_LENGTH+1];
  HNDLE hKey, hWorkKey, hSubKey;
  INT   loop, zone_no, range, zone_diff=0;;
  float top_temp, pid_p, pid_i, pid_d, man_out;
  float zone_dd[6], zone_ls340[6];

  info = (LS340_INFO *) pinfo;

  if (strstr(info->cryo_name, "no cryostat")) // "no cryostat" name chosen
    return;

  strcpy(info->ls340_odb_names.ls_name, info->cryo_name);

  cm_msg(MINFO, "ls340_cryo_name_changed", "cryo name = %s", info->cryo_name);

  // check if the proper DD entry is present
  sprintf(str, "DD/Cryos/%s", info->cryo_name);
  status = db_find_key(info->hDB, info->hkey, str, &hKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find ../%s in the ODB", str);
    return;
  }
  
  // handle heater resistance ----------------------------------------------
  
  // find ODB key
  status = db_find_key(info->hDB, hKey, "Heater Resistance", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Heater Resistance' key!");
    return;
  }
  
  // get data
  size = sizeof(float);
  status = db_get_data(info->hDB, hSubKey, (void*)&heater_resistance, &size, TID_FLOAT);
  
  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Heater Resistance", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Loop1/Heater Resistance' key!");
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void *)&heater_resistance, sizeof(float), 1, TID_FLOAT);
  
  // handle Max. Current Tag ----------------------------------------------
  
  // find ODB key
  status = db_find_key(info->hDB, hKey, "Max. Current Tag", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Max. Current Tag' key!");
    return;
  }
  
  // get data
  size = sizeof(float);
  status = db_get_data(info->hDB, hSubKey, (void*)&value[0], &size, TID_INT);
  
  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Max. Current Tag", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Loop1/Max. Current Tag' key!");
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void *)&value[0], sizeof(int), 1, TID_INT);

  // handle Max. User Current ----------------------------------------------

  // find ODB key
  status = db_find_key(info->hDB, hKey, "Max. User Current", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Max. User Current' key!");
    return;
  }

  // get data
  size = sizeof(float);
  status = db_get_data(info->hDB, hSubKey, (void*)&fvalue, &size, TID_FLOAT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Max. User Current", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Loop1/Max. User Current' key!");
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void *)&fvalue, sizeof(float), 1, TID_FLOAT);

  // handle Max. Heater Range ----------------------------------------------

  // find ODB key
  status = db_find_key(info->hDB, hKey, "Max. Heater Range", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Max. Heater Range' key!");
    return;
  }

  // get data
  size = sizeof(float);
  status = db_get_data(info->hDB, hSubKey, (void*)&value[0], &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Max. Heater Range", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Loop1/Max. Heater Range' key!");
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void *)&value[0], sizeof(int), 1, TID_INT);

  // handle sensor type ----------------------------------------------------

  // find ODB key
  status = db_find_key(info->hDB, hKey, "Sensor Type", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Sensor Type' key!");
    return;
  }

  // get data
  size = sizeof(sensor_type);
  status = db_get_data(info->hDB, hSubKey, (void*)&sensor_type, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Sensor Type", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Sensors/Sensor Type' key!");
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void *)&sensor_type, sizeof(sensor_type), 10, TID_INT);


  // handle calibration curves ----------------------------------------------

  // find ODB key
  status = db_find_key(info->hDB, hKey, "Calibration Curve", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Calibration Curve' key!");
    return;
  }

  // get data
  size = sizeof(calib_curve);
  status = db_get_data(info->hDB, hSubKey, (void*)&calib_curve, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Calibration Curve", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Sensors/Calibration Curve' key!");
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void *)&calib_curve, sizeof(calib_curve), 10, TID_INT);

  // handle channel assignments ---------------------------------------------

  // find ODB key
  status = db_find_key(info->hDB, hKey, "Channel", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Channel' key!");
    return;
  }

  // get data
  size = sizeof(channel);
  status = db_get_data(info->hDB, hSubKey, (void*)&channel, &size, TID_STRING);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Channel", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Sensors/Channel' key!");
    return;
  }
  for (i=0; i<10; i++) {
    memset(ch, 0, sizeof(ch));
    memcpy(ch, &channel[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    db_set_data_index(info->hDB, hWorkKey, (void *)&ch, 4*sizeof(char), i, TID_STRING);
  }

  // handle sensor names ----------------------------------------------------

  // find ODB key
  status = db_find_key(info->hDB, hKey, "Sensor Name", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Sensor Name' key!");
    return;
  }

  // get data
  size = sizeof(sensor_name);
  status = db_get_data(info->hDB, hSubKey, (void*)&sensor_name, &size, TID_STRING);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Sensor Name", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Sensors/Sensor Name' key!");
    return;
  }
  for (i=0; i<10; i++) {
    memset(ch, 0, sizeof(ch));
    memcpy(ch, &sensor_name[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    db_set_data_index(info->hDB, hWorkKey, (void *)&ch, NAME_LENGTH*sizeof(char), i, TID_STRING);
  }

  // find ODB key for Settings/Names Input
  status = db_find_key(info->hDB, info->hkey, "../../Names Input", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Settings/Names Input' key!");
    return;
  }
  for (i=0; i<info->ls340_settings.intern.no_of_sensors; i++) {
    memset(ch, 0, sizeof(ch));
    memcpy(ch, &sensor_name[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    db_set_data_index(info->hDB, hWorkKey, (void *)&ch, NAME_LENGTH*sizeof(char),
                      i+info->ls340_settings.intern.odb_offset, TID_STRING);
  }


  // handle zone settings ---------------------------------------------------

  // find ODB key
  status = db_find_key(info->hDB, hKey, "Zone", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'Zone' key!");
    return;
  }

  // get data
  size = sizeof(zone);
  status = db_get_data(info->hDB, hSubKey, (void*)&zone, &size, TID_STRING);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Zone/Zone", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls340_cryo_name_changed", "couldn't find 'DD/Zone/Zone' key!");
    return;
  }
  for (i=0; i<10; i++) {
    memset(ch, 0, sizeof(ch));
    memcpy(ch, &zone[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    db_set_data_index(info->hDB, hWorkKey, (void *)&ch, NAME_LENGTH*sizeof(char), i, TID_STRING);
  }

  // send all the stuff to the LS340 ----------------------------------------

  for (i=0; i<info->ls340_settings.intern.no_of_sensors; i++) {

    // specifing sensor type
    memset(ch, 0, sizeof(ch));
    memcpy(ch, &channel[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    sprintf(cmd, "INTYPE %s, %d\r\n", ch, sensor_type[i]);
    BD_PUTS(cmd);
    sprintf(cmd, "INTYPE? %s\r\n", ch);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    if ( !status ) { // no response
      cm_msg(MERROR, "ls340_cryo_name_changed", "LS340: %s: Error getting channel %s type assignment.",
             info->ls340_odb_names.ls_name, ch);
      return;
    }

    // specifing curve which is used to convert to temperature
    sprintf(cmd, "INCRV %s, %d\r\n", ch, calib_curve[i]);
    BD_PUTS(cmd);
    sprintf(cmd, "INCRV? %s\r\n", ch);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    if ( !status ) { // no response
      cm_msg(MERROR, "ls340_cryo_name_changed", "LS340: %s: Error getting channel %s curve assignment.",
             info->ls340_odb_names.ls_name, ch);
      return;
    }

    // read the header related to a curve
    sscanf(str, "%d", &ch_no);
    sprintf(cmd, "CRVHDR? %d\r\n", ch_no);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    if ( !status ) { // no response
      cm_msg(MERROR, "ls340_cryo_name_changed", "LS340: %s: Error getting channel %s curve header.",
             info->ls340_odb_names.ls_name, ch);
      return;
    }

    // status output message
    cm_msg(MINFO,"ls340_cryo_name_changed",
           "LS340: %s: Channel %s curve = (ODB=%d,LS340=%d).\n LS340=%d -> %s",
           info->ls340_odb_names.ls_name, ch, sensor_type[i], ch_no, ch_no, str);
  }

  // set heater resistance setting of the LakeShore 340 ----------------------------
  sprintf(cmd, "CDISP 1,1,%d\r\n", (int)truncf(heater_resistance));
  cm_msg(MINFO, "ls340_cryo_name_changed", "LS340: %s: going to set the heater resistance to %d(Ohm)",
         info->ls340_odb_names.ls_name, (int)truncf(heater_resistance));
  BD_PUTS(cmd);
  // check if the heater resistance is set properly
  sprintf(cmd, "CDISP? 1\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
  if ( !status ) { // no response
    cm_msg(MERROR, "ls340_cryo_name_changed", "LS340: %s: Failed reading the heater resistance settings of loop1.",
           info->ls340_odb_names.ls_name);
    return;
  }
  sscanf(str, "%d,%d,%d,%d", &value[0], &value[1], &value[2], &value[3]);
  fvalue = (float)value[1];
  if (fabs(fvalue-heater_resistance)>LS340_DELTA_R)
    cm_msg(MERROR, "ls340_cryo_name_changed",
           "LS340: %s: Controll loop1 heater resistance: ODB entry %2.0f(Ohm) is inconsistent with readback value %2.0f(Ohm)",
            info->ls340_odb_names.ls_name, heater_resistance, fvalue);

  // specify setpoint units (necessary, otherwise the setpoint is in V!! stupid LS340 firmware)
  sprintf(cmd, "CSET 1, , 1, 1\r\n"); // CSET loop1, , Kelvin, enable Heater
  BD_PUTS(cmd);
  sprintf(cmd, "CSET? 1\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
  if ( !status ) { // no response
    cm_msg(MERROR, "ls340_cryo_name_changed",
           "LS340: %s: Error in configuring control loop parameter.",
           info->ls340_odb_names.ls_name);
    return; // since the whole things hangs otherwise
  }
  cm_msg(MINFO, "ls340_cryo_name_changed",
         "LS340: %s: Controll loop1 settings: %s",
         info->ls340_odb_names.ls_name, str);

  // set control loop1 limits to protect the equipment
  sprintf(cmd, "CLIMIT 1, %f, , , %d, %d\r\n", info->ls340_settings.loop1.setpoint_limit,
          info->ls340_settings.loop1.max_current_tag, info->ls340_settings.loop1.max_heater_range);
  BD_PUTS(cmd);
  sprintf(cmd, "CLIMIT? 1\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
  if ( !status ) { // no response
    cm_msg(MERROR, "ls340_cryo_name_changed", "LS340: %s: Error in configuring control loop limit parameter.",
           info->ls340_odb_names.ls_name);
  }
  cm_msg(MINFO, "ls340_cryo_name_changed", "LS340: %s: Control loop1 limits: %s", info->ls340_odb_names.ls_name, str);

  // if max_current_tag == 5, i.e. User, set to max. user current
  if (info->ls340_settings.loop1.max_current_tag == 5) {
    if ((info->ls340_settings.loop1.max_user_current > 0.0) && (info->ls340_settings.loop1.max_user_current < 2.0)) {
      sprintf(cmd, "CLIMI %f\r\n", info->ls340_settings.loop1.max_user_current);
      BD_PUTS(cmd);
      sprintf(cmd, "CLIMI?\r\n");
      status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
      if ( !status ) { // no response
        cm_msg(MERROR, "LS340_in_init", "LS340: %s: Error in configuring control loop max. user current.",
               info->ls340_odb_names.ls_name);
      }
      cm_msg(MINFO, "ls340_cryo_name_changed", "LS340: %s: Control max. user current: %s (A)", info->ls340_odb_names.ls_name, str);
    }
  }

  // write zone settings to the LS340 and validate them --------------------------------------
  for (i=0; i<10; i++) {
    memset(str, 0, sizeof(str));
    memcpy(str, &zone[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    status = sscanf(str, "%d, %d, %f, %f, %f, %f, %f, %d",
                    &loop, &zone_no, &top_temp, &pid_p, &pid_i, &pid_d, &man_out, &range);
    if (status != 8) {
      cm_msg(MINFO, "ls340_cryo_name_changed", "%s. Couldn't get the zone settings from the DD.",
             info->ls340_odb_names.ls_name);
    } else {
      sprintf(cmd, "ZONE %d, %d, %0.1f, %0.1f, %0.1f, %0.1f, %0.1f, %d\r\n",
              loop, zone_no, top_temp, pid_p, pid_i, pid_d, man_out, range);
      BD_PUTS(cmd);
    }
    ss_sleep(500); // needed since bloody LS340 is sooo slow
  }
  // validate zone settings
  for (i=0; i<10; i++) {
    sprintf(cmd, "ZONE? 1, %d\r\n", i+1);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    // settings form the dd
    memset(cmd, 0, sizeof(cmd));
    memcpy(cmd, &zone[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    sscanf(cmd, "%d, %d, %f, %f, %f, %f, %f, %d",
           &loop, &zone_no, &top_temp, &pid_p, &pid_i, &pid_d, &man_out, &range);
    zone_dd[0] = top_temp;
    zone_dd[1] = pid_p;
    zone_dd[2] = pid_i;
    zone_dd[3] = pid_d;
    zone_dd[4] = man_out;
    zone_dd[5] = range;
    // settings form the LS340
    sscanf(str, "%f, %f, %f, %f, %f, %d",
           &top_temp, &pid_p, &pid_i, &pid_d, &man_out, &range);
    zone_ls340[0] = top_temp;
    zone_ls340[1] = pid_p;
    zone_ls340[2] = pid_i;
    zone_ls340[3] = pid_d;
    zone_ls340[4] = man_out;
    zone_ls340[5] = range;
    // check them
    if ((zone_dd[0] != zone_ls340[0]) || (zone_dd[1] != zone_ls340[1]) || (zone_dd[2] != zone_ls340[2]) ||
        (zone_dd[3] != zone_ls340[3]) || (zone_dd[4] != zone_ls340[4]) || (zone_dd[5] != zone_ls340[5])) {
      cm_msg(MINFO, "ls340_cryo_name_changed",
             "%s. Zone settings from the DD and from the LS340 are different.",
             info->ls340_odb_names.ls_name);
      zone_diff = 1;
    }
  }
  if (!zone_diff)
    cm_msg(MINFO, "ls340_cryo_name_changed",
           "%s. Zone settings successfully transferred to the LS340.",
           info->ls340_odb_names.ls_name);

  cm_msg(MINFO, "ls340_cryo_name_changed", "successfully switched to %s",
         info->ls340_odb_names.ls_name);
}

/*---- device driver routines --------------------------------------*/
/*!
 * <p>Initializes the LS340 device driver, i.e. generates all the necessary
 * structures in the ODB if necessary, initializes the bus driver and the LS340 temperature controller.</p>
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - FE_ERR_ODB otherwise
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT ls340_in_init(HNDLE hKey, LS340_INFO **pinfo, INT channels, func_t *bd)
{
  INT   status, size, i, ch, value[4];
  INT   loop, zone, range, zone_diff=0;;
  float top_temp, pid_p, pid_i, pid_d, man_out;
  float zone_dd[6], zone_ls340[6];
  float fvalue;
  char  str[128], cmd[128];
  HNDLE hDB, hkeydd;
  time_t tt;
  struct tm tm;

  cm_get_experiment_database(&hDB, NULL);

  // allocate info structure
  LS340_INFO *info = (LS340_INFO*)calloc(1, sizeof(LS340_INFO));
  ls340_info = info; // keep global pointer
  *pinfo = info;

  // create LS340 odb names record
  status = db_create_record(hDB, hKey, "DD/ODB Names", ls340_odb_names_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls340_in_init", "ls340_in_init: Couldn't create DD/ODB Names in ODB: status=%d", status); 
    cm_yield(0);
    return FE_ERR_ODB;
  }
    
  // create LS340 internal record
  status = db_create_record(hDB, hKey, "DD/Internal", ls340_internal_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls340_in_init", "ls340_in_init: Couldn't create DD/Internal in ODB: status=%d", status); 
    cm_yield(0);
    return FE_ERR_ODB;
  }

  // create LS340 sensors record
  status = db_create_record(hDB, hKey, "DD/Sensors", ls340_sensors_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls340_in_init", "ls340_in_init: Couldn't create DD/Sensors in ODB: status=%d", status); 
    cm_yield(0);
    return FE_ERR_ODB;
  }

  // create LS340 loop1 record
  status = db_create_record(hDB, hKey, "DD/Loop1", ls340_loop1_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls340_in_init", "ls340_in_init: Couldn't create DD/Loop1 in ODB: status=%d", status); 
    return FE_ERR_ODB;
  }

  // create LS340 zone record
  status = db_create_record(hDB, hKey, "DD/Zone", ls340_zone_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls340_in_init", "ls340_in_init: Couldn't create DD/Zone in ODB: status=%d", status); 
    cm_yield(0);
    return FE_ERR_ODB;
  }

  // open hot-links to different DD subtrees
  db_find_key(hDB, hKey, "DD/ODB Names/LakeShore 340 Name", &hkeydd);
  db_open_record(hDB, hkeydd, (void *)&info->cryo_name, sizeof(info->cryo_name), MODE_READ,
                 &ls340_cryo_name_changed, (void *)info);
  db_find_key(hDB, hKey, "DD/ODB Names", &hkeydd);
  db_open_record(hDB, hkeydd, (void *)&info->ls340_odb_names, sizeof(info->ls340_odb_names),
                 MODE_READ, NULL, NULL);
  db_find_key(hDB, hKey, "DD/Internal", &hkeydd);
  db_open_record(hDB, hkeydd, (void *)&info->ls340_settings.intern, sizeof(info->ls340_settings.intern),
                 MODE_READ, NULL, NULL);
  db_find_key(hDB, hKey, "DD/Sensors", &hkeydd);
  db_open_record(hDB, hkeydd, (void *)&info->ls340_settings.sensor, sizeof(info->ls340_settings.sensor),
                 MODE_READ, NULL, NULL);
  db_find_key(hDB, hKey, "DD/Loop1", &hkeydd);
  db_open_record(hDB, hkeydd, (void *)&info->ls340_settings.loop1, sizeof(info->ls340_settings.loop1),
                 MODE_READ, NULL, NULL);
  db_find_key(hDB, hKey, "DD/Zone", &hkeydd);
  db_open_record(hDB, hkeydd, (void *)&info->ls340_settings.zone, sizeof(info->ls340_settings.zone),
                 MODE_READ, NULL, NULL);

  // initialize driver
  info->hDB                   = hDB;
  info->hkey                  = hKey;
  info->num_channels_in       = channels;
  info->bd                    = bd;
  info->read_timer[0]         = ss_millitime();
  for (i=1; i<18; i++)
    info->read_timer[i] = info->read_timer[0];
  info->errorcount            = 0;
  info->lasterrtime           = ss_time();
  info->startup_error         = 0;
  info->bd_connected          = 0;
  info->last_reconnect        = ss_time();
  info->readback_failure      = 0;
  info->reconnection_failures = 0;
  info->readback_err          = 0;
  info->heater_setting        = 0;
  info->first_bd_error        = 1;
  info->set_startup_counter   = 0;

  // check if the control channel is valid
  if (!strstr(info->ls340_settings.loop1.ctrl_ch, "A") && !strstr(info->ls340_settings.loop1.ctrl_ch, "B") &&
      !strstr(info->ls340_settings.loop1.ctrl_ch, "C1") && !strstr(info->ls340_settings.loop1.ctrl_ch, "C2") &&
      !strstr(info->ls340_settings.loop1.ctrl_ch, "C3") && !strstr(info->ls340_settings.loop1.ctrl_ch, "C4") &&
      !strstr(info->ls340_settings.loop1.ctrl_ch, "D1") && !strstr(info->ls340_settings.loop1.ctrl_ch, "D2") &&
      !strstr(info->ls340_settings.loop1.ctrl_ch, "D3") && !strstr(info->ls340_settings.loop1.ctrl_ch, "D4") && 
      !strstr(info->ls340_settings.loop1.ctrl_ch, "C") && !strstr(info->ls340_settings.loop1.ctrl_ch, "D")) {
    cm_msg(MINFO, "LS340_in_init", "LS340_in_init: ctrl loop channel %s is not allowed, will set it to A. Only channels A/B/C1-C4/D1-D4 are possible.", info->ls340_settings.loop1.ctrl_ch);
    cm_yield(0);
    strcpy(info->ls340_settings.loop1.ctrl_ch, "A");
  }

  // initialize history
  info->ihis                  = 0;
  info->his_full              = FALSE;
  for (i=0; i<LS340_MAX_AVG; i++) info->history[i] = 0.0;

  // find datetime dd entry
  status = db_find_key(hDB, hKey, "DD/Sensors/Date and Time", &info->hkey_datetime);
  // find bd connected dd entry
  status = db_find_key(hDB, hKey, "DD/Internal/No Connection", &info->hkey_no_connection);
  // find raw_value dd entry
  for (i=0; i<LS340_MAX_SENSORS; i++) {
    sprintf(str, "DD/Sensors/Raw Input Ch %d", i+1);
    status = db_find_key(hDB, hKey, str, &info->hkey_raw_value[i]);
  }

  if (!bd)
    return FE_ERR_ODB;

  // initialize bus driver
  status = info->bd(CMD_INIT, hKey, &info->bd_info);
  if (status != FE_SUCCESS) {
    info->startup_error = 1;
    return status;
  }
  info->bd_connected = 1;
  // set bd connected flag in DD entry
  ls340_no_connection(info, 0);

  // initialize LS340
  strcpy(cmd, "*IDN?\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
  if ( !status ) { // error occurred
    cm_msg(MERROR,"LS340_in_init", "Error getting device query from LS340, %s",info->ls340_odb_names.ls_name);
    info->startup_error = 1;
    return FE_SUCCESS;//FE_ERR_HW;
  }
  cm_msg(MINFO,"LS340_in_init", "Device IDN query of LS340 yields %s = %s", info->ls340_odb_names.ls_name,str);
  cm_yield(0);

  // sync date-time between computer and LakeShore340
  tt = time(NULL);
  localtime_r(&tt, &tm);
  sprintf(cmd, "DATETIME %d, %d, %d, %d, %d, %d, %d", tm.tm_mon+1, tm.tm_mday, tm.tm_year+1900, tm.tm_hour, tm.tm_min, tm.tm_sec, 0);
  cm_msg(MDEBUG, "ls340_in_init", "ls340_in_init: set date and time to %s", cmd);
  cm_yield(0);
  BD_PUTS(cmd);

  // set/query the input type and calibration curve assigned
  for (i=0; i<info->ls340_settings.intern.no_of_sensors; i++) {

    // specifing sensor type
    sprintf(cmd, "INTYPE %s, %d\r\n", info->ls340_settings.sensor.channel[i], info->ls340_settings.sensor.type[i]);
    BD_PUTS(cmd);
    sprintf(cmd, "INTYPE? %s\r\n", info->ls340_settings.sensor.channel[i]);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    if ( !status ) { // no response
      cm_msg(MERROR, "LS340_in_init", "LS340: %s: Error getting channel %s type assignment.",
             info->ls340_odb_names.ls_name, info->ls340_settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return FE_SUCCESS; // since the whole things hangs otherwise
    }

    // specifing curve which is used to convert to temperature
    sprintf(cmd, "INCRV %s, %d\r\n", info->ls340_settings.sensor.channel[i], info->ls340_settings.sensor.curve[i]);
    BD_PUTS(cmd);
    sprintf(cmd, "INCRV? %s\r\n", info->ls340_settings.sensor.channel[i]);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    if ( !status ) { // no response
      cm_msg(MERROR, "LS340_in_init", "LS340: %s: Error getting channel %s curve assignment.",
             info->ls340_odb_names.ls_name, info->ls340_settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return FE_SUCCESS; // since the whole things hangs otherwise
    }

    // read the header related to a curve
    sscanf(str, "%d", &ch);
    sprintf(cmd, "CRVHDR? %d\r\n", ch);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    if ( !status ) { // no response
      cm_msg(MERROR, "LS340_in_init", "LS340: %s: Error getting channel %s curve header.",
             info->ls340_odb_names.ls_name, info->ls340_settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return FE_SUCCESS; // since the whole things hangs otherwise
    }

    // status output message
    cm_msg(MINFO,"LS340_in_init", "LS340: %s: Channel %s curve = (ODB=%d,LS340=%d).\n LS340=%d -> %s",
                  info->ls340_odb_names.ls_name, info->ls340_settings.sensor.channel[i],
                  info->ls340_settings.sensor.type[i], ch, ch, str);
    cm_yield(0);
  } // for

  // specify setpoint units
  //sprintf(cmd, "CSET 1, %s, 2, 1\r\n", info->ls340_settings.loop1.ctrl_ch); // CSET loop1, ctrl ch (A/B), Celsius, enable Heater
  sprintf(cmd, "CSET 1, %s, 1, 1\r\n", info->ls340_settings.loop1.ctrl_ch); // CSET loop1, ctrl ch (A/B), Kelvin, enable Heater
  BD_PUTS(cmd);
  sprintf(cmd, "CSET? 1\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
  if ( !status ) { // no response
    cm_msg(MERROR, "LS340_in_init", "LS340: %s: Error in configuring control loop parameter.",
           info->ls340_odb_names.ls_name);
    cm_yield(0);
    info->startup_error = 1;
    return FE_SUCCESS; // since the whole things hangs otherwise
  }
  cm_msg(MINFO, "LS340_in_init", "LS340: %s: Control loop1 settings: %s", info->ls340_odb_names.ls_name, str);
  cm_yield(0);

  // set control loop1 limits to protect the equipment
  sprintf(cmd, "CLIMIT 1, %f, , , %d, %d\r\n", info->ls340_settings.loop1.setpoint_limit,
          info->ls340_settings.loop1.max_current_tag, info->ls340_settings.loop1.max_heater_range);
  BD_PUTS(cmd);
  sprintf(cmd, "CLIMIT? 1\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
  if ( !status ) { // no response
    cm_msg(MERROR, "LS340_in_init", "LS340: %s: Error in configuring control loop limit parameter.",
           info->ls340_odb_names.ls_name);
    info->startup_error = 1;
    return FE_SUCCESS; // since the whole things hangs otherwise
  }
  cm_msg(MINFO, "LS340_in_init", "LS340: %s: Control loop1 limits: %s", info->ls340_odb_names.ls_name, str);
  cm_yield(0);

  // if max_current_tag == 5, i.e. User, set to max. user current
  if (info->ls340_settings.loop1.max_current_tag == 5) {
    if ((info->ls340_settings.loop1.max_user_current > 0.0) && (info->ls340_settings.loop1.max_user_current < 2.0)) {
      sprintf(cmd, "CLIMI %f\r\n", info->ls340_settings.loop1.max_user_current);
      BD_PUTS(cmd);
      sprintf(cmd, "CLIMI?\r\n");
      status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
      if ( !status ) { // no response
        cm_msg(MERROR, "LS340_in_init", "LS340: %s: Error in configuring control loop max. user current.",
               info->ls340_odb_names.ls_name);
        info->startup_error = 1;
        return FE_SUCCESS; // since the whole things hangs otherwise
      }
      cm_msg(MINFO, "LS340_in_init", "LS340: %s: Control max. user current: %s (A)", info->ls340_odb_names.ls_name, str);
      cm_yield(0);
    }
  }

  // check if heater resistance corresponds to the ODB settings
  sprintf(cmd, "CDISP? 1\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
  if ( !status ) { // no response
    cm_msg(MERROR, "LS340_in_init", "LS340: %s: Reading the heater resistance settings of loop1.",
           info->ls340_odb_names.ls_name);
    cm_yield(0);
    info->startup_error = 1;
    return FE_SUCCESS; // since the whole things hangs otherwise
  }
  sscanf(str, "%d,%d,%d,%d", &value[0], &value[1], &value[2], &value[3]);
  fvalue = (float)value[1];
  if (fabs(fvalue-info->ls340_settings.loop1.heater_resistance)>LS340_DELTA_R) {
    cm_msg(MERROR, "LS340_in_init",
           "LS340: %s: Controll loop1 heater resistance: ODB entry %2.0f(Ohm) is inconsistent with readback value %2.0f(Ohm)",
            info->ls340_odb_names.ls_name, info->ls340_settings.loop1.heater_resistance, fvalue);
    cm_yield(0);
  }

  // write zone settings to the LS340 and validate them --------------------------------------
  for (i=0; i<10; i++) {
    memset(str, 0, sizeof(str));
    memcpy(str, &info->ls340_settings.zone[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    status = sscanf(str, "%d, %d, %f, %f, %f, %f, %f, %d",
                    &loop, &zone, &top_temp, &pid_p, &pid_i, &pid_d, &man_out, &range);
    if (status != 8) {
      cm_msg(MINFO, "LS340_in_init", "%s. Couldn't get the zone settings from the DD.",
             info->ls340_odb_names.ls_name);
      cm_yield(0);
    } else {
      sprintf(cmd, "ZONE %d, %d, %0.1f, %0.1f, %0.1f, %0.1f, %0.1f, %d\r\n",
              loop, zone, top_temp, pid_p, pid_i, pid_d, man_out, range);
      BD_PUTS(cmd);
    }
    ss_sleep(500); // needed since bloody LS340 is sooo slow
  }
  // validate zone settings
  for (i=0; i<10; i++) {
    sprintf(cmd, "ZONE? 1, %d\r\n", i+1);
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_MANY);
    // settings form the dd
    memset(cmd, 0, sizeof(str));
    memcpy(cmd, &info->ls340_settings.zone[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
    sscanf(cmd, "%d, %d, %f, %f, %f, %f, %f, %d",
           &loop, &zone, &top_temp, &pid_p, &pid_i, &pid_d, &man_out, &range);
    zone_dd[0] = top_temp;
    zone_dd[1] = pid_p;
    zone_dd[2] = pid_i;
    zone_dd[3] = pid_d;
    zone_dd[4] = man_out;
    zone_dd[5] = range;
    // settings form the LS340
    sscanf(str, "%f, %f, %f, %f, %f, %d",
           &top_temp, &pid_p, &pid_i, &pid_d, &man_out, &range);
    zone_ls340[0] = top_temp;
    zone_ls340[1] = pid_p;
    zone_ls340[2] = pid_i;
    zone_ls340[3] = pid_d;
    zone_ls340[4] = man_out;
    zone_ls340[5] = range;
    // check them
    if ((zone_dd[0] != zone_ls340[0]) || (zone_dd[1] != zone_ls340[1]) || (zone_dd[2] != zone_ls340[2]) ||
        (zone_dd[3] != zone_ls340[3]) || (zone_dd[4] != zone_ls340[4]) || (zone_dd[5] != zone_ls340[5])) {
      cm_msg(MINFO, "LS340_in_init", "%s. Zone settings from the DD and from the LS340 are different.",
             info->ls340_odb_names.ls_name);
      zone_diff = 1;
    }
  }
  if (!zone_diff) {
    cm_msg(MINFO, "LS340_in_init", "%s. Zone settings successfully transferred to the LS340.", info->ls340_odb_names.ls_name);
    cm_yield(0);
  }

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>Initializes the LS340 device driver.</p>
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - FE_ERR_ODB otherwise
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT ls340_out_init(HNDLE hKey, LS340_INFO **pinfo, INT channels, func_t *bd)
{
  ls340_info->num_channels_out = channels;
  *pinfo = ls340_info;

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>terminates the bus driver and free's the memory allocated for the info structure
 * LS340_INFO.</p>
 * <p><b>Return:</b> FE_SUCCESS</p>
 * \param info is a pointer to the DD specific info structure
 */
INT ls340_exit(LS340_INFO *info)
{
  // call EXIT function of bus driver, usually closes device
  info->bd(CMD_EXIT, info->bd_info);

  free(info);

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>sets the values of the LS340, if the device is remote.
 * It relies on a specific order in the ODB (see code).</p>
 * <p><b>Return:</b> FE_SUCCESS</p>
 * \param info is a pointer to the DD specific info structure
 * \param channel to be set
 * \param value to be sent to the LS330
 */
INT ls340_set(LS340_INFO *info, INT channel, float value)
{
  char str[128], qry[128], rcv[128];
  INT  status, i;

  // at startup, PID and Range set will NOT be executed! This is important if CMODE == 2, i.e. ZONE
  // This also means for CMODE != 2, PID and Range needs to be set once explicitly! Since the ususal
  // operation is CMODE == 2, this is not too bad
  if (info->set_startup_counter < info->num_channels_out) {
    info->set_startup_counter++;
    switch (channel) {
      case 2: // P
      case 3: // I
      case 4: // D
      case 5: // Range
        return FE_SUCCESS;
        break;
      default:
        break;
    }
  }

  // get out if not remote or startup error
  if (info->ls340_settings.intern.remote == 0 || info->startup_error == 1) {
     ss_sleep(10);
     return FE_SUCCESS;
  }

  if (!info->bd_connected) {
    ss_sleep(10);
    if (info->first_bd_error) {
      info->first_bd_error = 0;
      cm_msg(MINFO, "LS340_set",
             "LS340_set: %s: set values not possible at the moment, since the bus driver is not available!",
             info->ls340_odb_names.ls_name);
    }
    return FE_SUCCESS;
  }

  // check if someone wants to switch to remote
  if (channel == 0) {
    if (value == 0) { // switch to local message
      cm_msg(MINFO, "LS340_set", "LS340_set: %s: switch to local", info->ls340_odb_names.ls_name);
    } else { // switch to remote
      if (info->ls340_settings.intern.remote == 0) { // check if not already on remote
        ls340_force_update(info);
        cm_msg(MINFO, "LS340_set", "LS340_set: %s: switch to remote", info->ls340_odb_names.ls_name);
      }
    }
    info->ls340_settings.intern.remote = value;
    return FE_SUCCESS;
  }

  switch (channel) { // relies on the order of the DD/ODB Names/Names Out!!!
    case 1: // setpoint, loop1
      if ( value > info->ls340_settings.loop1.setpoint_limit ) {
        value = info->ls340_settings.loop1.setpoint_limit;
        cm_msg(MERROR, "LS340_set", "LS340: %s: Max. allowed setpoint is set to %f",
                       info->ls340_odb_names.ls_name, info->ls340_settings.loop1.setpoint_limit);
      }
      sprintf(str, "SETP 1, %.3f\r\n", value); // setpoint loop1
      info->setpoint = value;                  // store in info
      sprintf(qry, "SETP? 1\r\n");
      break;
    case 2:  // gain P, loop1
      if ( value > 1000.f || value < 0.f)
        value = 0.f;
      sprintf(str, "PID 1, %d\r\n", (int)value);	// gain P, loop1
      sprintf(qry, "PID? 1\r\n");
      break;
    case 3: // reset I, loop1
      if ( value > 1000.f || value < 1.f)
        value = 0.f;
      sprintf(str, "PID 1, , %d\r\n", (int)value);	// reset I, loop1
      sprintf(qry, "PID? 1\r\n");
      break;
    case 4:
      if ( value > 1000.f || value < 1.f)
        value = 0.f;
      sprintf(str, "PID 1, , , %d\r\n", (int)value);	// rate D, loop1
      sprintf(qry, "PID? 1\r\n");
      break;
    case 5: // heater range
      if ( value > (float)info->ls340_settings.loop1.max_heater_range || value < 0.f ) {
        value = 0.f;
        cm_msg(MERROR, "LS340_set", "LS340_set: %s: The heater range must be in the integer range [0,%d]",
               info->ls340_odb_names.ls_name, info->ls340_settings.loop1.max_heater_range);
      }
      sprintf(str, "RANGE %d\r\n", (int)value);	// heater range
      sprintf(qry, "RANGE?\r\n");
      info->heater_setting = value; // keep new heater setting
      break;
    case 6: // control mode loop1
      if ( value > 6.f || value < 1.f )
        value = 1.f; // i.e. manual
      sprintf(str, "CMODE 1, %d\r\n", (int)value); // control mode
      sprintf(qry, "CMODE? 1\r\n");
      break;
    case 7:
      if (value > 100.f) {
        value = 0.f;
        cm_msg(MERROR, "LS340_set",
               "LS340_set: %s: setpoint ramping only in the range [0.1, 100] (K/min) possible",
               info->ls340_odb_names.ls_name);
      }
      if (value <= 0.f)
        sprintf(str, "RAMP 1, 0, 0.1\r\n"); // no ramp
      else
        sprintf(str, "RAMP 1, 1, %0.1f\r\n", value); // ramp
      sprintf(qry, "RAMP? 1\r\n");
      break;
    default:
      return FE_SUCCESS;
  }

  //--- send command and query parameter to check ---
  status = i = 0;
  do {
    if (LS340_DEBUG)
      cm_msg(MINFO,"LS340_set", "LS340_set: %s: command = %s", info->ls340_odb_names.ls_name, str);
    BD_PUTS(str);
    status = ls340_send_rcv(info, qry, rcv, LS340_MAX_TRY_MANY);
    i++;
    if (!status) 
      ss_sleep(LS340_WAIT);
  } while (!status && (i < LS340_MAX_TRY_MANY));

  if ( !status )
     cm_msg(MERROR,"LS340_set","LS340_set: %s: Failed to query %s", info->ls340_odb_names.ls_name, qry);
  else
     cm_msg(MINFO,"LS340_set", "LS340_set: %s: Result of query %s = %s", info->ls340_odb_names.ls_name, qry, rcv);

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>checks the state of the heater and tries to switch it on again if it is disabled.</p>
 *
 * \param info is a pointer to the DD specific info structure
 */
void ls340_check_heater(LS340_INFO *info)
{
  char  cmd[128], str[128], *s;
  INT   status, value[4], i;
  float loop, zone_no, top_temp, pid_p, pid_i, pid_d, man_out;
  INT   range;

  if (!info->bd_connected) // bus driver not connected at the moment
    return;

  // check heater state
  strcpy(cmd, "HTRST?\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
  if (!status) {
    ls340_no_connection(info, 1);
    if (info->ls340_settings.intern.detailed_msg)
      cm_msg(MINFO, "ls340_check_heater",
             "%s: ls340_check_heater: WARNING: couldn't check heater state",
             info->ls340_odb_names.ls_name);
    return;
  }

  sscanf(str, "%d", &value[0]);

  switch (value[0]) {
    case 1:
      cm_msg(MERROR, "ls340_check_heater", "%s: power supply over voltage",
             info->ls340_odb_names.ls_name);
      break;
    case 2:
      cm_msg(MERROR, "ls340_check_heater", "%s: power supply under voltage",
             info->ls340_odb_names.ls_name);
      break;
    case 3:
      cm_msg(MERROR, "ls340_check_heater", "%s: output DAC error",
             info->ls340_odb_names.ls_name);
      break;
    case 4:
      cm_msg(MERROR, "ls340_check_heater", "%s: current limit DAC error",
             info->ls340_odb_names.ls_name);
      break;
    case 5:
      cm_msg(MERROR, "ls340_check_heater", "%s: open heater load",
             info->ls340_odb_names.ls_name);
      break;
    case 6:
      cm_msg(MERROR, "ls340_check_heater", "%s: heater load less than 10 ohms",
             info->ls340_odb_names.ls_name);
      break;
    default:
      break;
  }

  // check control loop 1 parameters
  strcpy(cmd, "CSET? 1\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
  if (!status) {
    if (info->ls340_settings.intern.detailed_msg)
      cm_msg(MINFO, "ls340_check_heater",
             "%s: ls340_check_heater: WARNING: couldn't check control loop 1 parameters",
             info->ls340_odb_names.ls_name);
    return;
  }
  s = strstr(str, ","); // shift the pointer over the channel assignment
  if (s == NULL)
    return;
  sscanf(s, ",%d,%d,%d", &value[0], &value[1], &value[2]);

  if (value[1] == 0) { // heater output loop1 has been disabled
    cm_msg(MERROR, "ls340_check_heater",
           "%s: heater output disabled. Will try to switch it on again. NO guarantee that it will work. CHECK it!", info->ls340_odb_names.ls_name);
    // enable heater power
    strcpy(cmd, "CSET 1,,1,1\r\n");
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
    // set the heater power back to its previous value
    sprintf(cmd, "RANGE %d\r\n", info->heater_setting); // heater range
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);

     // check if the heater range is still ok
    strcpy(cmd, "RANGE?\r\n");
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
    sscanf(str, "%d", &value[0]);
    // check if heater range changed. If so set it back
    if ((value[0] != info->heater_setting) && (info->heater_setting !=0)) {
      // set the heater power back to its previous value
      sprintf(cmd, "RANGE %d\r\n", info->heater_setting); // heater range
      status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
      if (info->ls340_settings.intern.detailed_msg)
        cm_msg(MINFO, "ls340_check_heater",
               "%s, heater range readback is %d, should be %d, will set it to its demand value",
               info->ls340_odb_names.ls_name, value[0], info->heater_setting);
    }
  }

  // check if the heater range is still ok
  strcpy(cmd, "RANGE?\r\n");
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
  if (!status) {
    if (info->ls340_settings.intern.detailed_msg)
      cm_msg(MINFO, "ls340_check_heater",
             "%s: ls340_check_heater: WARNING: couldn't check heater range",
             info->ls340_odb_names.ls_name);
    return;
  }
  sscanf(str, "%d", &value[0]);

  if (info->cmode != 2) { // no ZONE settings
    // check if heater range changed. If so set it back
    if ((value[0] != info->heater_setting) && (info->heater_setting !=0)) {
      // set the heater power back to its previous value
      sprintf(cmd, "RANGE %d\r\n", info->heater_setting); // heater range
      status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
      if (info->ls340_settings.intern.detailed_msg)
        cm_msg(MINFO, "ls340_check_heater",
               "%s, heater range readback is %d, should be %d, will set it to its demand value",
               info->ls340_odb_names.ls_name, value[0], info->heater_setting);
    }
  } else { // ZONE settings
    // find the proper zone
    for (i=0; i<10; i++) {
      memset(str, 0, sizeof(str));
      memcpy(str, &info->ls340_settings.zone[i*NAME_LENGTH], NAME_LENGTH*sizeof(char));
      sscanf(str, "%f, %f, %f, %f, %f, %f, %f, %d",
             &loop, &zone_no, &top_temp, &pid_p, &pid_i, &pid_d, &man_out, &range);
      if (info->setpoint < top_temp)
        break;
    }
    // check if heater is ok
    if (value[0] != range) {
      // set the heater power back to its proper value
      sprintf(cmd, "RANGE %d\r\n", range); // heater range
      status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
      if (info->ls340_settings.intern.detailed_msg)
        cm_msg(MINFO, "ls340_check_heater",
               "%s, heater range readback is %d, should be %d, will set it to its demand value",
               info->ls340_odb_names.ls_name, value[0], range);
    }
  }
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>reads the values of the LS340.</p>
 * <p><b>Return:</b> FE_SUCCESS</p>
 * \param info is a pointer to the DD specific info structure
 * \param channel to be set
 * \param pvalue pointer to the result
 */
INT ls340_get(LS340_INFO *info, INT channel, float *pvalue)
{
  char  str[128], cmd[128], datetime[32];
  INT   cmd_tag, sub_tag, status;
  int   size, i, enabled;
  float pid_p, pid_i, pid_d, fvalue;
  DWORD nowtime, difftime;


  // check for startup_error
  if ( info->startup_error == 1 ) {   // error during CMD_INIT, return -2
    *pvalue = (float) LS340_INIT_ERROR;
    ss_sleep(10); // to keep CPU load low when Run active
    return FE_SUCCESS;
  }

  // check if time limiter for reading is set
  if (info->ls340_settings.intern.read_timeout != 0) {
    nowtime = ss_millitime();
    if ( nowtime - info->read_timer[channel] > 1000 * info->ls340_settings.intern.read_timeout )
      info->read_timer[channel] = nowtime; // reset timer and go on
    else
      return FE_SUCCESS;          // not yet time to read anything
  }

  // error handling routines
  nowtime  = ss_time();
  difftime = nowtime - info->lasterrtime;

  if ( difftime > LS340_DELTA_TIME_ERROR ) {
    info->errorcount  = 0;
    info->lasterrtime = nowtime;
  }

  if (info->reconnection_failures > LS340_MAX_RECONNECTION_FAILURE) {
    *pvalue = (float) LS340_READ_ERROR;
    if (info->reconnection_failures == LS340_MAX_RECONNECTION_FAILURE+1) {
      cm_msg(MERROR, "LS340_get", "too many reconnection failures, bailing out :-(");
      info->reconnection_failures++;
    }
    return FE_SUCCESS;
  }

  // check the heater state before proceeding
  ls340_check_heater(info);

  sub_tag = 0;
  cmd_tag = ls340_get_decode(info, channel, &sub_tag);

  switch(cmd_tag) {
    case 0: // read temperature
      //sprintf(cmd, "CRDG? %s\r\n", info->ls340_settings.sensor.channel[channel]); // Celsius
      sprintf(cmd, "KRDG? %s\r\n", info->ls340_settings.sensor.channel[channel]);   // Kelvin
      break;
    case 1: // heater output
      strcpy(cmd, "HTR?\r\n");
      break;
    case 2: // set point read back from loop1
      strcpy(cmd, "SETP? 1\r\n");
      break;
    case 3: // PID read back from loop1
      strcpy(cmd, "PID? 1\r\n");
      break;
    case 4: // heater range read back
      strcpy(cmd, "RANGE?\r\n");
      break;
    case 5: // control mode read back from loop1
      strcpy(cmd, "CMODE? 1\r\n");
      break;
    case 6:
      strcpy(cmd, "RAMP? 1\r\n");
      break;
    default:
      *pvalue = (float) LS340_READ_ERROR;
      return FE_SUCCESS;
  }

  // if cmd_tag = 0, i.e. read temp, then look whether info->settings.sensor.channel[channel] == "AVA",
  // in that case return average value of sensor A

  if ((cmd_tag == 0) && strstr(info->ls340_settings.sensor.name[channel],"AVA")) {
    *pvalue = 0.0;
    for (i=0; i<LS340_MAX_AVG; i++)
      *pvalue += info->history[i];
    if (info->his_full)
      *pvalue /= LS340_MAX_AVG;
    else
      if (info->ihis != 0)
        *pvalue /= info->ihis;
    return FE_SUCCESS;
  }

  ss_sleep(100); // try to keep mscb happy
  status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
  if (status == LS340_SHUTDOWN) {
    return FE_SUCCESS;
  }
  if (status <= 0) { // error
    ls340_no_connection(info, 1);
    if (cmd_tag != 3) // not a PID value
      *pvalue = info->last_value[channel]; // return last valid value
    else // PID value
      *pvalue = (float) LS340_READ_ERROR;

    if (info->errorcount < LS340_MAX_ERROR) {
      if (info->ls340_settings.intern.detailed_msg)
        cm_msg(MERROR, "LS340_get", "LS340: %s: LakeShore340 does not respond.",
               info->ls340_odb_names.ls_name);
      info->errorcount++;
    }

    info->readback_failure++;

    if (info->readback_failure == LS340_MAX_READBACK_FAILURE) {
      info->readback_failure = 0;
      // try to disconnect and reconnect the bus driver
      if ((ss_time()-info->last_reconnect > info->ls340_settings.intern.reconnect_timeout) && info->bd_connected) { // disconnect bus driver
        status = info->bd(CMD_EXIT, info->bd_info);
        if (info->ls340_settings.intern.detailed_msg)
          cm_msg(MINFO, "LS340_get", "LS340: %s: try to disconnect and reconnect the bus driver (status = %d)",
                 info->ls340_odb_names.ls_name, status);
        info->last_reconnect = ss_time();
        info->bd_connected = 0;
        if (info->ls340_settings.intern.ets_in_use)
          ets_logout(info->bd_info, LS340_ETS_LOGOUT_SLEEP, info->ls340_settings.intern.detailed_msg);
      }
    }

    // try to reconnect after a timeout
    if ((ss_time()-info->last_reconnect > info->ls340_settings.intern.reconnect_timeout) && !info->bd_connected) {
      status = info->bd(CMD_INIT, info->hkey, &info->bd_info);
      if (status != FE_SUCCESS) {
        if (info->ls340_settings.intern.detailed_msg)
          cm_msg(MINFO, "LS340_get", "LS340: %s: reconnection attempted failed (status = %d)",
                 info->ls340_odb_names.ls_name, status);
        info->reconnection_failures++;
        info->last_reconnect = ss_time(); // in order not to block anything
        return FE_ERR_HW;
      } else {
        info->bd_connected = 1; // bus driver is connected again
        info->errorcount = 0;   // reinitialize error counter
        info->reconnection_failures = 0; // reset counter
        info->last_reconnect = ss_time();
        info->first_bd_error = 1;
        if (info->ls340_settings.intern.detailed_msg)
          cm_msg(MINFO, "LS340_get", "LS340: %s: successfully reconnected", info->ls340_odb_names.ls_name);
      }
    }
    return FE_SUCCESS;
  }

  ls340_no_connection(info, 0);

  if (cmd_tag == 3) { // filter PID's
    sscanf(str, "%f,%f,%f", &pid_p, &pid_i, &pid_d);
    switch (sub_tag) {
      case 0:
        if (strlen(str)==20)
          *pvalue = pid_p;
        else // something fishy
          *pvalue = (float) LS340_READ_ERROR;
        break;
      case 1:
        if (strlen(str)==20)
          *pvalue = pid_i;
        else // something fishy
          *pvalue = (float) LS340_READ_ERROR;
        break;
      case 2:
        if (strlen(str)==20)
          *pvalue = pid_d;
        else // something fishy
          *pvalue = (float) LS340_READ_ERROR;
        break;
      default:
        *pvalue = (float) LS340_READ_ERROR;
        break;
    }
  } else if (cmd_tag == 6) { // ramp
    sscanf(str, "%d, %f", &enabled, &fvalue);
    if (!enabled) // ramp not enabled
      fvalue = 0.f;
    *pvalue = fvalue;
    info->last_value[channel] = fvalue;
  } else if (cmd_tag == 4) { // heater setting
    sscanf(str, "%f", pvalue);
    if (*pvalue != 0.0) {
      info->heater_setting = *pvalue;
    }
    info->last_value[channel] = *pvalue; // keep last valid value
    info->readback_failure = 0;
  } else { // all the others
    if (channel < info->ls340_settings.intern.no_of_sensors) { // temp reading
      if (!(strlen(str)==13) || !(str[0]='+')) { // something fishy
        *pvalue = info->last_value[channel];
        info->readback_err++;
        if (info->readback_err == 10)
          cm_msg(MINFO, "LS340_get", "LS340_get: WARNING: Too many temp. readback errors! Please check %s",
                 info->ls340_odb_names.ls_name);
        return FE_SUCCESS;
      } else {
        info->readback_err = 0;
      }
      // update history if cmd_tag = 0 and channel = 0
      if ((cmd_tag == 0) && strstr(info->ls340_settings.sensor.channel[channel],"A")) {
        info->history[info->ihis] = *pvalue;
        info->ihis++;
        if ( info->ihis == LS340_MAX_AVG ) {
          info->ihis = 0;
          info->his_full = TRUE;
        }
      }
    }
    sscanf(str, "%f", pvalue);
    info->last_value[channel] = *pvalue; // keep last valid value
    info->readback_failure = 0;

    if (cmd_tag == 2) // setpoint
      info->setpoint = *pvalue;
    if (cmd_tag == 5) // cmode
      info->cmode = *pvalue;
  }

  // for diagnostic and calibration purposes
  if (channel == 0) {
    // read date and time
    strcpy(cmd, "DATETIME?\r\n");
    status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
    if (status == LS340_SHUTDOWN) {
      return FE_SUCCESS;
    }
    if (status > 0) {
      strncpy(datetime, str, 32);
      size = strlen(datetime);
      if (strstr(datetime, "\r\n"))
        datetime[size-2]=0;
      db_set_data(info->hDB, info->hkey_datetime, datetime, sizeof(datetime), 1, TID_STRING);
    }

    // read raw input values if enabled
    if (info->ls340_settings.intern.read_raw_data) {
      for (i=0; i<LS340_MAX_SENSORS; i++) {
        sprintf(cmd, "SRDG? %s\r\n", info->ls340_settings.sensor.channel[i]);
        status = ls340_send_rcv(info, cmd, str, LS340_MAX_TRY_LESS);
        if (status == LS340_SHUTDOWN) {
          return FE_SUCCESS;
        }
        if (status > 0) {
          sscanf(str, "%f", &fvalue);
          size = sizeof(fvalue);
          db_set_data(info->hDB, info->hkey_raw_value[i], &fvalue, size, 1, TID_FLOAT);
        }
      }
    }
  }

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names of the channels into the ODB.</p>
 * <p><b>Return:</b> FE_SUCCESS
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT ls340_in_get_label(LS340_INFO *info, INT channel, char *name)
{

  if (channel < info->ls340_settings.intern.no_of_sensors) { // sensor names
    strcpy(name, info->ls340_settings.sensor.name[channel]);
  } else { // loops related stuff
    strcpy(name, info->ls340_odb_names.names_in[channel-info->ls340_settings.intern.no_of_sensors]);
  }
  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names of the channels into the ODB.</p>
 * <p><b>Return:</b> FE_SUCCESS
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT ls340_out_get_label(LS340_INFO *info, INT channel, char *name)
{
  strcpy(name, info->ls340_odb_names.names_out[channel]);
  return FE_SUCCESS;
}

/*---- device driver entry point -----------------------------------*/
INT ls340_in(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   *pvalue;
  LS340_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey    = va_arg(argptr, HNDLE);
        LS340_INFO **pinfo    = va_arg(argptr, LS340_INFO **);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t*);
        status  = ls340_in_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_EXIT:
      info   = va_arg(argptr, LS340_INFO *);
      status = ls340_exit(info);
      break;

    case CMD_GET:
      info    = va_arg(argptr, LS340_INFO *);
      channel = va_arg(argptr, INT);
      pvalue  = va_arg(argptr, float*);
      status  = ls340_get(info, channel, pvalue);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, LS340_INFO *);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = ls340_in_get_label(info, channel, name);
      break;

    default:
      break;
  }

  va_end(argptr);
  return status;
}

INT ls340_out(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   value;
  LS340_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey    = va_arg(argptr, HNDLE);
        LS340_INFO **pinfo    = va_arg(argptr, LS340_INFO **);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t *);
        status  = ls340_out_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_SET:
      info    = va_arg(argptr, LS340_INFO *);
      channel = va_arg(argptr, INT);
      value   = (float) va_arg(argptr, double);
      status  = ls340_set(info, channel, value);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, LS340_INFO *);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = ls340_out_get_label(info, channel, name);
      break;

    default:
      break;
  }

  va_end(argptr);

  return status;
}

/*------------------------------------------------------------------*/
