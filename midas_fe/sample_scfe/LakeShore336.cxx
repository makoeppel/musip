/********************************************************************\

  Name:         LakeShore336.cxx
  Created by:   Andreas Suter   2019/03/14

  Contents: device driver for the LakeShore 336 temperature controller,
            defined as a multi class device.

\********************************************************************/

#include <cstdio>
#include <cstdlib>
#include <cstdarg>
#include <cstring>
#include <cmath>

#include "midas.h"
#include "mfe.h"
#include "msystem.h"

#include "LakeShore336.h"

//---- globals ----------------------------------------------------------------
#define LS336_TIMEOUT 10000  //!< read timeout in (msec)
#define LS336_MAX_READ_ATTEMPTS 5 //!< maximal number of read attempts before giving up
#define LS336_MAX_SENSORS 8 //!< max. number of possible input sensors
#define LS336_INIT_ERROR -2
#define LS336_READ_ERROR -1

#define LS336_P_GAUGE_CALIB_NO 58

typedef struct {
  INT  detailed_msg;  //!< tag indicating if detailed status/error messages are wanted
  BOOL enable_soft_zone; //!< enable zone settings as for the LS340
  BOOL read_raw_data; //!< flag indicating if raw data shall be read
  INT  odb_offset;    //!< odb offset for the output variables. Needed by the forced update routine
  char odb_output[2*NAME_LENGTH]; //!< odb output variable path. Needed by the forced update routine
  INT  num_sensors_used; //!< number of sensors which are actually used  
} LS336_INTERN;

const char *ls336_intern_str =
"Detailed Messages = INT : 0\n\
Enable Soft Zone = BOOL : 1\n\
Read Raw Data = BOOL : 0\n\
ODB Offset = INT : 0\n\
ODB Output Path = STRING : [64] /Equipment/ModCryo/Variables/Output\n\
# Sensors Used = INT : 5\n\
";

//! stores the sensor specific settings
typedef struct {
  INT  type[LS336_MAX_SENSORS];              //!< sensor type: see INTYPE cmd
  INT  curve[LS336_MAX_SENSORS];             //!< sensor calibration curve: see INCRV
  char channel[LS336_MAX_SENSORS][4];        //!< which channel: A-C, D1-D5
  float raw_value[LS336_MAX_SENSORS];        //!< raw sensor readings
} LS336_SENSORS;

const char *ls336_sensors_str =
"Sensor Type = INT[8] : \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
Calibration Curve = INT[8] : \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
1 \n\
Channel = STRING[8] : \n\
[4] A\n\
[4] B\n\
[4] C\n\
[4] D1\n\
[4] D2\n\
[4] D3\n\
[4] D4\n\
[4] D5\n\
Raw Input Channel = FLOAT[8] : \n\
0.0\n\
0.0\n\
0.0\n\
0.0\n\
0.0\n\
0.0\n\
0.0\n\
0.0\n\
";

//! stores the control loop specfic settings
typedef struct {
  char  ctrl_ch[4];        //!< which channel is used for control loop (A-C, D1-D5 possible)
  float temperature_limit; //!< in Kelvin
  int   max_current_tag;   //!< Limits the max. current for the heater (see HTRSET cmd)
  float max_user_current;  //!< Upper limit for the output heater current (see HTRSET cmd)
  int   heater_resistance_tag; //!< heater resistance tag (see HTRSET cmd)
  int   output_on;         //!< output is on=1, off=0 (see OUTMODE cmd)
  int   powerup_enable;    //!< output enable after repower (=1) or not (=0) (see OUTMODE cmd)
} LS336_LOOP;

const char *ls336_loop1_str =
"CTRL_CH = STRING : [4] A\n\
Temperature Limit = FLOAT : 350\n\
Max. Current Tag = INT : 0\n\
Max. User Current = FLOAT : 1.0\n\
Heater Resistance Tag = INT : 0\n\
Output (On=1, Off=0) = INT : 1\n\
Powerup Enabled = INT : 0\n\
";

const char *ls336_loop2_str =
"CTRL_CH = STRING : [4] \n\
Temperature Limit = FLOAT : 350\n\
Max. Current Tag = INT : 0\n\
Max. User Current = FLOAT : 1.0\n\
Heater Resistance Tag = INT : 0\n\
Output (On=1, Off=0) = INT : 1\n\
Powerup Enabled = INT : 0\n\
";

typedef struct {
  char name[NAME_LENGTH];
  char names_in[24][NAME_LENGTH];
  char names_out[14][NAME_LENGTH];
} LS336_ODB_NAMES;

const char *ls336_odb_names_str =
"LS336 Name = STRING : [32]\n\
Names In = STRING[24] : \n\
[32] LS_A\n\
[32] LS_B\n\
[32] LS_C\n\
[32] LS_D1\n\
[32] LS_D2\n\
[32] LS_D3\n\
[32] LS_D4\n\
[32] LS_D5\n\
[32] LS_L1_Heater\n\
[32] LS_L1_Setpoint (read back)\n\
[32] LS_L1_Gain_P (read back)\n\
[32] LS_L1_Reset_I (read back)\n\
[32] LS_L1_Rate_D (read back)\n\
[32] LS_L1_HeaterRange (read back)\n\
[32] LS_L1_ControlMode (read back)\n\
[32] LS_L1_Ramp (read back)\n\
[32] LS_L2_Heater\n\
[32] LS_L2_Setpoint (read back)\n\
[32] LS_L2_Gain_P (read back)\n\
[32] LS_L2_Reset_I (read back)\n\
[32] LS_L2_Rate_D (read back)\n\
[32] LS_L2_HeaterRange (read back)\n\
[32] LS_L2_ControlMode (read back)\n\
[32] LS_L2_Ramp (read back)\n\
Names Out = STRING[14] : \n\
[32] LS_L1_SetPoint (K)\n\
[32] LS_L1_Gain_P\n\
[32] LS_L1_Reset_I\n\
[32] LS_L1_Rate_D\n\
[32] LS_L1_HeaterRange\n\
[32] LS_L1_ControlMode\n\
[32] LS_L1_Ramp\n\
[32] LS_L2_SetPoint (K)\n\
[32] LS_L2_Gain_P\n\
[32] LS_L2_Reset_I\n\
[32] LS_L2_Rate_D\n\
[32] LS_L2_HeaterRange\n\
[32] LS_L2_ControlMode\n\
[32] LS_L2_Ramp\n\
";

const char *ls336_zone_str =
"Zone = STRING[10]: \n\
[64] 1,  1,   7, 500, 300, 0, 0, 1, 1, 0\n\
[64] 1,  2,  10, 500, 200, 2, 0, 2, 1, 0\n\
[64] 1,  3,  15, 500, 100, 2, 0, 2, 1, 0\n\
[64] 1,  4,  20, 500,  50, 2, 0, 2, 1, 0\n\
[64] 1,  5,  30, 500,  20, 2, 0, 2, 1, 0\n\
[64] 1,  6, 320, 500,  20, 2, 0, 3, 1, 0\n\
[64] 1,  7, 320, 500,  20, 2, 0, 3, 1, 0\n\
[64] 1,  8, 320, 500,  20, 2, 0, 3, 1, 0\n\
[64] 1,  9, 320, 500,  20, 2, 0, 3, 1, 0\n\
[64] 1, 10, 320, 500,  20, 2, 0, 3, 1, 0\n\
";

//! stores internal informations within the DD.
typedef struct {
  LS336_ODB_NAMES odb_names;
  LS336_INTERN    intern;
  LS336_SENSORS   sensor;
  LS336_LOOP      loop1;
  LS336_LOOP      loop2;
  char            zone[10][2*NAME_LENGTH];
} LS336_SETTINGS;

typedef struct {
  LS336_SETTINGS settings;
  char  cryo_name[NAME_LENGTH]; //!< name of the LS336
  HNDLE hDB;                    //!< main handle to the ODB
  HNDLE hkey;                   //!< handle to the BD key
  INT   num_channels_in;        //!< number of in-channels
  INT   num_channels_out;       //!< number of out-channels
  INT (*bd)(INT cmd, ...);      //!< bus driver entry function
  void *bd_info;                //!< private info of bus driver
  int   startup_error;          //!< startup error tag
  int   ctrl_mode;              //!< keep the control mode parameter (see OUTMODE <mode>) to mimic the LS340 ZONE behavior
  float pid_l1[3];              //!< pid's of loop1
  float range_l1;               //!< heater range of loop1 (see RANGE)
  float pid_l2[3];              //!< pid's of loop2
  float range_l2;               //!< heater range of loop2 (see RANGE)
  float sensor_data[LS336_MAX_SENSORS]; //!< keeps the raw sensor reading if requested
} LS336_INFO;

LS336_INFO *ls336_info; //!< global info structure, in/out-init routines need the same structure

INT ls336_set(LS336_INFO *info, INT channel, float value);

//---- support routines -------------------------------------------------------
/**
 * @brief ls336_check_ctrl_loop_channel
 * @param ch
 * @param ctrl_ch
 */
void ls336_check_ctrl_loop_channel(LS336_INFO *info, const char *ch, int ctrl_ch)
{
  if (!strstr(ch, "A") && !strstr(ch, "B") && !strstr(ch, "C") && !strstr(ch, "D1") &&
      !strstr(ch, "D2") && !strstr(ch, "D3") && !strstr(ch, "D4") && !strstr(ch, "D5")) {
    if (ctrl_ch == 1) {
      cm_msg(MINFO, "LS336_in_init", "LS336_in_init: ctrl loop channel %s of loop %d is not allowed, will set it to A. Only channels A-C, D1-D5 are possible.", ch, ctrl_ch);
      strcpy(info->settings.loop1.ctrl_ch, "A");
    } else if (ctrl_ch == 2) {
      cm_msg(MINFO, "LS336_in_init", "LS336_in_init: ctrl loop channel %s of loop %d is not allowed, will set it to 'empty'. Only channels A-C, D1-D5 are possible.", ch, ctrl_ch);
      strcpy(info->settings.loop2.ctrl_ch, "");
    }
    cm_yield(0);
  }
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_send_rcv
 * @param cmd
 * @param rcv
 * @return
 */
INT ls336_send_rcv(LS336_INFO *info, const char *cmd, char *rcv)
{
  int cnt, status;

  // send command
  info->bd(CMD_PUTS, info->bd_info, cmd);
  ss_sleep(50);

  // initialize rcv buffer and cnt
  memset(rcv, '\0', sizeof(rcv));
  cnt = 0;
  do {
    status = info->bd(CMD_GETS, info->bd_info, rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    cm_yield(0);
    ss_sleep(50);
  } while ((status == 0) && (cnt++ < LS336_MAX_READ_ATTEMPTS));

  return --cnt;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_decode_sensor_status
 * @param info
 * @param i
 * @param rcv
 * @return
 */
INT ls336_decode_sensor_status(LS336_INFO *info, const int i, const char *rcv)
{
  int ival, status;

  status = sscanf(rcv, "%d", &ival);
  if (status != 1) // something went wrong, rcv not valid?!
    return -1;

  if (ival & 1) {
    cm_msg(MDEBUG, "ls336_decode_sensor_status", "**WARNING** sensor reading of '%s' is invalid.", info->settings.sensor.channel[i]);
    cm_yield(0);
    return -2;
  }

  if (ival & 64) { // sensor units zero
    cm_msg(MDEBUG, "ls336_decode_sensor_status", "**WARNING** sensor units of '%s' is zero.", info->settings.sensor.channel[i]);
    cm_yield(0);
    return -2;
  }

  if (ival & 128) { // sensor units overrange
    cm_msg(MDEBUG, "ls336_decode_sensor_status", "**WARNING** sensor units of '%s' is overrage.", info->settings.sensor.channel[i]);
    cm_yield(0);
    return -2;
  }

  if (ival & 16) { // temperature underrange
    cm_msg(MDEBUG, "ls336_decode_sensor_status", "**WARNING** '%s': temperature underrange.", info->settings.sensor.channel[i]);
    cm_yield(0);
    return -2;
  }

  if (ival & 32) { // temperature overrange
    cm_msg(MDEBUG, "ls336_decode_sensor_status", "**WARNING** '%s': temperature overrange.", info->settings.sensor.channel[i]);
    cm_yield(0);
    return -2;
  }


  return 0;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_check_heater
 * @param info
 */
void ls336_check_heater(LS336_INFO *info)
{
  char cmd[32], rcv[32];
  int status, ival;

  // check heater state loop1
  sprintf(cmd, "HTRST? 1\r\n");
  status = ls336_send_rcv(info, cmd, rcv);

  if (status == LS336_MAX_READ_ATTEMPTS) {
    if (info->settings.intern.detailed_msg) {
      cm_msg(MDEBUG, "ls336_check_heater", "**WARNING** %s, couldn't check heater state of loop1", info->settings.odb_names.name);
      cm_yield(0);
    }
    return;
  }

  status = sscanf(rcv, "%d", &ival);
  if (status != 1) {
    if (info->settings.intern.detailed_msg) {
      cm_msg(MDEBUG, "ls336_check_heater", "**WARNING** %s, couldn't decode heater state of loop1", info->settings.odb_names.name);
      cm_yield(0);
    }
    return;
  }

  switch (ival) {
  case 1:
    cm_msg(MERROR, "ls336_check_heater", "**ERROR** %s: loop1: heater open load!", info->settings.odb_names.name);
    cm_yield(0);
    break;
  case 2:
    cm_msg(MERROR, "ls336_check_heater", "**ERROR** %s: loop1: heater short!", info->settings.odb_names.name);
    cm_yield(0);
    break;
  default:
    break;
  }

  if (ival != 0) { // there was an error, try to switch on the heater again
    if (info->range_l1 > 0) {
      cm_msg(MINFO, "ls336_check_heater", "loop1 off, will try to re-enable it");
      cm_yield(0);
      sprintf(cmd, "RANGE 1, %d", (int)info->range_l1);
      status = ls336_send_rcv(info, cmd, rcv);
    }
  }


  // check heater state loop2
  sprintf(cmd, "HTRST? 2\r\n");
  status = ls336_send_rcv(info, cmd, rcv);

  if (status == LS336_MAX_READ_ATTEMPTS) {
    if (info->settings.intern.detailed_msg) {
      cm_msg(MDEBUG, "ls336_check_heater", "**WARNING** %s, couldn't check heater state of loop2", info->settings.odb_names.name);
      cm_yield(0);
    }
    return;
  }

  status = sscanf(rcv, "%d", &ival);
  if (status != 1) {
    if (info->settings.intern.detailed_msg) {
      cm_msg(MDEBUG, "ls336_check_heater", "**WARNING** %s, couldn't decode heater state of loop2", info->settings.odb_names.name);
      cm_yield(0);
    }
    return;
  }

  switch (ival) {
  case 1:
    cm_msg(MERROR, "ls336_check_heater", "**ERROR** %s: loop2: heater open load!", info->settings.odb_names.name);
    cm_yield(0);
    break;
  case 2:
    cm_msg(MERROR, "ls336_check_heater", "**ERROR** %s: loop2: heater short!", info->settings.odb_names.name);
    cm_yield(0);
    break;
  default:
    break;
  }

  if (ival != 0) { // there was an error, try to switch on the heater again
    if (info->range_l2 > 0) {
      cm_msg(MINFO, "ls336_check_heater", "loop2 off, will try to re-enable it");
      cm_yield(0);
      sprintf(cmd, "RANGE 2, %d", (int)info->range_l2);
      status = ls336_send_rcv(info, cmd, rcv);
    }
  }
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_ch_to_number
 * @param str
 * @return
 */
INT ls336_ch_to_number(const char *str)
{
  int ival = 0;

  if (strstr(str, "A") || strstr(str, "a"))
    ival = 1;
  else if (strstr(str, "B") || strstr(str, "b"))
    ival = 2;
  else if (strstr(str, "C") || strstr(str, "c"))
    ival = 3;
  else if (strstr(str, "D1") || strstr(str, "d1"))
    ival = 4;
  else if (strstr(str, "D2") || strstr(str, "d2"))
    ival = 5;
  else if (strstr(str, "D3") || strstr(str, "d3"))
    ival = 6;
  else if (strstr(str, "D4") || strstr(str, "d4"))
    ival = 7;
  else if (strstr(str, "D5") || strstr(str, "d5"))
    ival = 8;

  return ival;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_cryo_name_changed
 * @param hDB
 * @param dummy
 * @param pinfo
 */
void ls336_cryo_name_changed(HNDLE hDB, HNDLE dummy, void *pinfo)
{
  LS336_INFO *info;
  char str[128], cmd[128], rcv[128];
  HNDLE hKey, hSubKey, hWorkKey;
  int status, size, i;
  int sensor_type[LS336_MAX_SENSORS];
  int calib_curve[LS336_MAX_SENSORS];
  char channel[LS336_MAX_SENSORS][NAME_LENGTH];
  char ctrl_ch[4];
  float temp_limit, max_user_current;
  int max_current_tag, heater_resistance_tag, output_on, powerup_enabled, ch;
  char zone[10][2*NAME_LENGTH];

  info = (LS336_INFO*) pinfo;

  if (strstr(info->cryo_name, "no cryostat")) { // "no cryostat" name chosen
    // switch off the heaters
    sprintf(cmd, "RANGE 1, 0\r\n");
    BD_PUTS(cmd);
    ss_sleep(50);
    sprintf(cmd, "RANGE 2, 0\r\n");
    BD_PUTS(cmd);
    ss_sleep(50);
    return;
  }

  cm_msg(MINFO, "ls336_cryo_name_changed", "cryo name changed to: %s", info->cryo_name);
  cm_yield(0);

  // check if the proper DD entry is present ----------------------------------
  snprintf(str, sizeof(str), "DD/Cryos/%s", info->cryo_name);
  status = db_find_key(info->hDB, info->hkey, str, &hKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find ../%s in the ODB", str);
    cm_yield(0);
    return;
  }

  // handle sensor types ------------------------------------------------------
  status = db_find_key(info->hDB, hKey, "Sensor Type", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MERROR, "ls336_cryo_name_changed", "**ERROR** Couldn't find 'Sensor Type' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(sensor_type);
  status = db_get_data(info->hDB, hSubKey, (void*)&sensor_type, &size, TID_INT);
  if (status != DB_SUCCESS) {
    cm_msg(MERROR, "ls336_cryo_name_changed", "**ERROR** Couldn't get 'Sensor Type' data! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Sensor Type", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "**ERROR** Couldn't find 'DD/Sensors/Sensor Type' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void *)&sensor_type, sizeof(sensor_type), LS336_MAX_SENSORS, TID_INT);

  // handle calibration curves ------------------------------------------------
  status = db_find_key(info->hDB, hKey, "Calibration Curve", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MERROR, "ls336_cryo_name_changed", "**ERROR** Couldn't find 'Calibration Curve' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(calib_curve);
  status = db_get_data(info->hDB, hSubKey, (void*)&calib_curve, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Calibration Curve", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "**ERROR** Couldn't find 'DD/Sensors/Calibration Curve' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&calib_curve, sizeof(calib_curve), LS336_MAX_SENSORS, TID_INT);

  // handle channel assignments -----------------------------------------------
  status = db_find_key(info->hDB, hKey, "Channel", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MERROR, "ls336_cryo_name_changed", "**ERROR** Couldn't find 'Channel' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(channel);
  status = db_get_data(info->hDB, hSubKey, (void*)&channel, &size, TID_STRING);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Channel", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "**ERROR** Couldn't find 'DD/Sensors/Channel' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  size = 4*sizeof(char);
  for (i=0; i<LS336_MAX_SENSORS; i++) {
    db_set_data_index(info->hDB, hWorkKey, (void*)&channel[i], size, i, TID_STRING);
  }

  // handle loop1 settings ----------------------------------------------------
  // loop1 ctrl_ch ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop1/CTRL_CH", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop1/CTRL_CH' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(ctrl_ch);
  status = db_get_data(info->hDB, hSubKey, (void*)&ctrl_ch, &size, TID_STRING);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/CTRL_CH", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop1/CTRL_CH' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&ctrl_ch, sizeof(ctrl_ch), 1, TID_STRING);

  // loop1 temperature limit ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop1/Temperature Limit", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop1/Temperature Limit' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(temp_limit);
  status = db_get_data(info->hDB, hSubKey, (void*)&temp_limit, &size, TID_FLOAT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Temperature Limit", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop1/Temperature Limit' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&temp_limit, sizeof(temp_limit), 1, TID_FLOAT);

  // loop1 Max. Current Tag ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop1/Max. Current Tag", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop1/Max. Current Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(max_current_tag);
  status = db_get_data(info->hDB, hSubKey, (void*)&max_current_tag, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Max. Current Tag", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop1/Max. Current Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&max_current_tag, sizeof(max_current_tag), 1, TID_INT);

  // loop1 Max. User Current ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop1/Max. User Current", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop1/Max. User Current' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(max_user_current);
  status = db_get_data(info->hDB, hSubKey, (void*)&max_user_current, &size, TID_FLOAT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Max. User Current", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop1/Max. User Current' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&max_user_current, sizeof(max_user_current), 1, TID_FLOAT);

  // loop1 Heater Resistance Tag ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop1/Heater Resistance Tag", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop1/Heater Resistance Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(heater_resistance_tag);
  status = db_get_data(info->hDB, hSubKey, (void*)&heater_resistance_tag, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Heater Resistance Tag", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop1/Heater Resistance Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&heater_resistance_tag, sizeof(heater_resistance_tag), 1, TID_INT);

  // loop1 Output (On=1, Off=0) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop1/Output (On=1, Off=0)", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop1/Output (On=1, Off=0)' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(output_on);
  status = db_get_data(info->hDB, hSubKey, (void*)&output_on, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Output (On=1, Off=0)", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop1/Output (On=1, Off=0)' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&output_on, sizeof(output_on), 1, TID_INT);

  // loop1 Powerup Enabled ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop1/Powerup Enabled", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop1/Powerup Enabled' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(powerup_enabled);
  status = db_get_data(info->hDB, hSubKey, (void*)&powerup_enabled, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop1/Powerup Enabled", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop1/Powerup Enabled' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&powerup_enabled, sizeof(powerup_enabled), 1, TID_INT);

  // handle loop2 settings ----------------------------------------------------
  // loop2 ctrl_ch ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop2/CTRL_CH", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop2/CTRL_CH' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(ctrl_ch);
  status = db_get_data(info->hDB, hSubKey, (void*)&ctrl_ch, &size, TID_STRING);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop2/CTRL_CH", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop2/CTRL_CH' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&ctrl_ch, sizeof(ctrl_ch), 1, TID_STRING);

  // loop2 temperature limit ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop2/Temperature Limit", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop2/Temperature Limit' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(temp_limit);
  status = db_get_data(info->hDB, hSubKey, (void*)&temp_limit, &size, TID_FLOAT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop2/Temperature Limit", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop2/Temperature Limit' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&temp_limit, sizeof(temp_limit), 1, TID_FLOAT);

  // loop2 Max. Current Tag ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop2/Max. Current Tag", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop2/Max. Current Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(max_current_tag);
  status = db_get_data(info->hDB, hSubKey, (void*)&max_current_tag, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop2/Max. Current Tag", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop2/Max. Current Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&max_current_tag, sizeof(max_current_tag), 1, TID_INT);

  // loop2 Max. User Current ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop2/Max. User Current", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop2/Max. User Current' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(max_user_current);
  status = db_get_data(info->hDB, hSubKey, (void*)&max_user_current, &size, TID_FLOAT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop2/Max. User Current", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop2/Max. User Current' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&max_user_current, sizeof(max_user_current), 1, TID_FLOAT);

  // loop2 Heater Resistance Tag ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop2/Heater Resistance Tag", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop2/Heater Resistance Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(heater_resistance_tag);
  status = db_get_data(info->hDB, hSubKey, (void*)&heater_resistance_tag, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop2/Heater Resistance Tag", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop2/Heater Resistance Tag' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&heater_resistance_tag, sizeof(heater_resistance_tag), 1, TID_INT);

  // loop2 Output (On=1, Off=0) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop2/Output (On=1, Off=0)", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop2/Output (On=1, Off=0)' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(output_on);
  status = db_get_data(info->hDB, hSubKey, (void*)&output_on, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop2/Output (On=1, Off=0)", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop2/Output (On=1, Off=0)' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&output_on, sizeof(output_on), 1, TID_INT);

  // loop2 Powerup Enabled ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  status = db_find_key(info->hDB, hKey, "Loop2/Powerup Enabled", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Loop2/Powerup Enabled' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(powerup_enabled);
  status = db_get_data(info->hDB, hSubKey, (void*)&powerup_enabled, &size, TID_INT);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Loop2/Powerup Enabled", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Loop2/Powerup Enabled' key! Cannot switch the cryo!");
    cm_yield(0);
    return;
  }
  db_set_data(info->hDB, hWorkKey, (void*)&powerup_enabled, sizeof(powerup_enabled), 1, TID_INT);

  // handle zone settings -----------------------------------------------------
  status = db_find_key(info->hDB, hKey, "Zone", &hSubKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'Zone' key!");
    cm_yield(0);
    return;
  }

  // get data
  size = sizeof(zone);
  status = db_get_data(info->hDB, hSubKey, (void*)&zone, &size, TID_STRING);

  // write data to DD ODB (in case of a restart)
  status = db_find_key(info->hDB, info->hkey, "DD/Zone/Zone", &hWorkKey);
  if (status != DB_SUCCESS) {
    cm_msg(MINFO, "ls336_cryo_name_changed", "couldn't find 'DD/Zone/Zone' key!");
    cm_yield(0);
    return;
  }
  size = 2*NAME_LENGTH*sizeof(char);
  for (i=0; i<10; i++) {
    db_set_data_index(info->hDB, hWorkKey, (void *)&zone[i], size, i, TID_STRING);
  }

  // send all the updated information to the LS336 ----------------------------

  // set input type parameters (INTYPE), and calibration curve (INCRV)
  for (i=0; i<LS336_MAX_SENSORS; i++) {
    if (info->settings.sensor.curve[i] == LS336_P_GAUGE_CALIB_NO) { // pressure gauge calibration curve
      sprintf(cmd, "INTYPE %s, %d, 0, 1, 0, 1\r\n", info->settings.sensor.channel[i], info->settings.sensor.type[i]);
    } else {
      sprintf(cmd, "INTYPE %s, %d, 1, 0, 0, 1\r\n", info->settings.sensor.channel[i], info->settings.sensor.type[i]);
    }
    BD_PUTS(cmd);
    ss_sleep(50);
    sprintf(cmd, "INCRV %s, %d\r\n", info->settings.sensor.channel[i], info->settings.sensor.curve[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
  }

  // the TLIMIT is much more generic than used here. Please check the manual for more details
  // set temp. limit for the control loop1
  sprintf(cmd, "TLIMIT %s, %.2f\r\n", info->settings.loop1.ctrl_ch, info->settings.loop1.temperature_limit);
  BD_PUTS(cmd);
  ss_sleep(50);
  // set temp. limit for the control loop2
  if (strlen(info->settings.loop2.ctrl_ch) == 0) // no loop2 ctrl channel given -> set TLIMIT to 0.0, i.e. no temp. limit check
    sprintf(cmd, "TLIMIT %s, %.2f\r\n", info->settings.loop2.ctrl_ch, 0.0);
  else
    sprintf(cmd, "TLIMIT %s, %.2f\r\n", info->settings.loop2.ctrl_ch, info->settings.loop2.temperature_limit);
  BD_PUTS(cmd);
  ss_sleep(50);

  // readback from the LS336 -> midas for the user
  cm_msg(MINFO, "ls336_cryo_name_changed", "cryo: %s", info->settings.odb_names.name);
  for (i=0; i<LS336_MAX_SENSORS; i++) {
    if (info->settings.sensor.type[i] > 0) {
      sprintf(cmd, "CRVHDR? %d\r\n", info->settings.sensor.curve[i]);
      BD_PUTS(cmd);
      status = BD_GETS(str, sizeof(str), "\r\n", LS336_TIMEOUT);
      if (status > 0) {
        cm_msg(MINFO, "ls336_cryo_name_changed", "sensor info: (ch=%s,type=%d,calib.crv=%d)",
               info->settings.sensor.channel[i], info->settings.sensor.type[i], info->settings.sensor.curve[i]);
        cm_msg(MINFO, "%s", str);
      }
      ss_sleep(50);
    }
  }
  cm_yield(0);

  // Loop1 : HTRSET, OUTMODE, RANGE
  sprintf(cmd, "HTRSET 1, %d, %d, %.2f, 1\r\n", info->settings.loop1.heater_resistance_tag,
          info->settings.loop1.max_current_tag, info->settings.loop1.max_user_current);
  BD_PUTS(cmd);
  ss_sleep(50);
  // check if the heater output is off
  if (info->settings.loop1.output_on == 0) {
    sprintf(cmd, "RANGE 1, 0\r\n");
  } else {
    sprintf(cmd, "RANGE 1, 1\r\n");
  }
  BD_PUTS(cmd);
  ss_sleep(50);

  sprintf(cmd, "OUTMODE 1, %d, %d, %d\r\n",
          info->ctrl_mode,
          ls336_ch_to_number(info->settings.loop1.ctrl_ch),
          info->settings.loop1.powerup_enable);
  BD_PUTS(cmd);
  ss_sleep(50);

  // Loop2 : HTRSET, OUTMODE
  sprintf(cmd, "HTRSET 2, %d, %d, %.2f, 1\r\n", info->settings.loop2.heater_resistance_tag,
          info->settings.loop2.max_current_tag, info->settings.loop2.max_user_current);
  BD_PUTS(cmd);
  ss_sleep(50);
  // check if the heater output is off
  if (info->settings.loop2.output_on == 0) {
    sprintf(cmd, "RANGE 2, 0\r\n");
  } else {
    sprintf(cmd, "RANGE 2, 1\r\n");
  }
  BD_PUTS(cmd);
  ss_sleep(50);

  sprintf(cmd, "OUTMODE 2, 2, %d, %d\r\n",
          ls336_ch_to_number(info->settings.loop2.ctrl_ch),
          info->settings.loop2.powerup_enable);
  BD_PUTS(cmd);
  ss_sleep(50);

  // ZONE
  for (i=0; i<10; i++) {
    sprintf(cmd, "ZONE %s\r\n", info->settings.zone[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
  }

  // set/query the input type and calibration curve assigned
  for (i=0; i<info->settings.intern.num_sensors_used; i++) {

    // specifing sensor type
    if (info->settings.sensor.curve[i] == LS336_P_GAUGE_CALIB_NO) { // pressure gauge calibration curve number
      sprintf(cmd, "INTYPE %s, %d, 0, 1, 0, 1\r\n", info->settings.sensor.channel[i], info->settings.sensor.type[i]);
    } else {
      sprintf(cmd, "INTYPE %s, %d, 1, 0, 0, 1\r\n", info->settings.sensor.channel[i], info->settings.sensor.type[i]);
    }
    BD_PUTS(cmd);
    ss_sleep(50);
    sprintf(cmd, "INTYPE? %s\r\n", info->settings.sensor.channel[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
    status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    if ( !status ) { // no response
      cm_msg(MERROR, "ls336_cryo_name_changed", "LS336: %s: Error getting channel %s type assignment.",
             info->settings.odb_names.name, info->settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return; // since the whole things hangs otherwise
    }

    // specifing curve which is used to convert to temperature
    sprintf(cmd, "INCRV %s, %d\r\n", info->settings.sensor.channel[i], info->settings.sensor.curve[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
    sprintf(cmd, "INCRV? %s\r\n", info->settings.sensor.channel[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
    status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    if ( !status ) { // no response
      cm_msg(MERROR, "ls336_cryo_name_changed", "LS336: %s: Error getting channel %s curve assignment.",
             info->settings.odb_names.name, info->settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return; // since the whole things hangs otherwise
    }

    // read the header related to a curve
    sscanf(rcv, "%d", &ch);
    sprintf(cmd, "CRVHDR? %d\r\n", ch);
    BD_PUTS(cmd);
    ss_sleep(50);
    status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    if ( !status ) { // no response
      cm_msg(MERROR, "ls336_cryo_name_changed", "LS336: %s: Error getting channel %s curve header.",
             info->settings.odb_names.name, info->settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return; // since the whole things hangs otherwise
    }

    // status output message
    cm_msg(MINFO,"LS336_in_init", "LS336: %s: Channel %s curve (type=%d):\n %s",
                  info->settings.odb_names.name, info->settings.sensor.channel[i],
                  info->settings.sensor.type[i], rcv);
    cm_yield(0);
  } // for

  cm_msg(MINFO, "ls336_cryo_name_changed", "Cryo changed to '%s'.", info->settings.odb_names.name);
  cm_yield(0);
}

//---- device driver routines -------------------------------------------------

typedef INT(func_t) (INT cmd, ...);

/**
 * @brief ls336_in_init
 * @param hKey
 * @param pinfo
 * @param channels
 * @return
 */
INT ls336_in_init(HNDLE hKey, LS336_INFO **pinfo, INT channels, func_t *bd)
{
  INT status, i, ch;
  char cmd[128], rcv[128];
  HNDLE hDB, hkeydd;
  float zone_val[10];

  cm_get_experiment_database(&hDB, NULL);

  // allocate info structure
  LS336_INFO *info = (LS336_INFO *)calloc(1, sizeof(LS336_INFO));
  ls336_info = info; // keep global pointer
  *pinfo = info;
    
  // create LS336 odb names record
  status = db_create_record(hDB, hKey, "DD/ODB Names", ls336_odb_names_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls336_in_init", "ls336_in_init: Couldn't create DD/ODB Names in ODB: status=%d", status);
    cm_yield(0);
    return FE_ERR_ODB;
  }

  // create LS336 intern record
  status = db_create_record(hDB, hKey, "DD/Intern", ls336_intern_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls336_in_init", "ls336_in_init: Couldn't create DD/Internal in ODB: status=%d", status);
    cm_yield(0);
    return FE_ERR_ODB;
  }

  // create LS336 sensors record
  status = db_create_record(hDB, hKey, "DD/Sensors", ls336_sensors_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls336_in_init", "ls336_in_init: Couldn't create DD/Sensors in ODB: status=%d", status);
    cm_yield(0);
    return FE_ERR_ODB;
  }

  // create LS336 loop1 record
  status = db_create_record(hDB, hKey, "DD/Loop1", ls336_loop1_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls336_in_init", "ls336_in_init: Couldn't create DD/Loop1 in ODB: status=%d", status);
    return FE_ERR_ODB;
  }

  // create LS336 loop2 record
  status = db_create_record(hDB, hKey, "DD/Loop2", ls336_loop2_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls336_in_init", "ls336_in_init: Couldn't create DD/Loop2 in ODB: status=%d", status);
    return FE_ERR_ODB;
  }

  // create LS336 zone record
  status = db_create_record(hDB, hKey, "DD/Zone", ls336_zone_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "ls336_in_init", "ls336_in_init: Couldn't create DD/Zone in ODB: status=%d", status);
    cm_yield(0);
    return FE_ERR_ODB;
  }

  // establish necessary hotlinks - needs to be split into various hotlinks due to DD/Cryos which
  // depends on the usage of the LS336
  // get ODB Names
  db_find_key(hDB, hKey, "DD/ODB Names", &hkeydd);
  db_open_record(hDB, hkeydd, (void*)&info->settings.odb_names, sizeof(info->settings.odb_names), MODE_READ, NULL, NULL);
  // get Intern
  db_find_key(hDB, hKey, "DD/Intern", &hkeydd);
  db_open_record(hDB, hkeydd, (void*)&info->settings.intern, sizeof(info->settings.intern), MODE_READ, NULL, NULL);
  // get Sensor settings
  db_find_key(hDB, hKey, "DD/Sensors", &hkeydd);
  db_open_record(hDB, hkeydd, (void*)&info->settings.sensor, sizeof(info->settings.sensor), MODE_READ, NULL, NULL);
  // get Loop1
  db_find_key(hDB, hKey, "DD/Loop1", &hkeydd);
  db_open_record(hDB, hkeydd, (void*)&info->settings.loop1, sizeof(info->settings.loop1), MODE_READ, NULL, NULL);
  // get Loop2
  db_find_key(hDB, hKey, "DD/Loop2", &hkeydd);
  db_open_record(hDB, hkeydd, (void*)&info->settings.loop2, sizeof(info->settings.loop2), MODE_READ, NULL, NULL);
  // get Zone
  db_find_key(hDB, hKey, "DD/Zone/Zone", &hkeydd);
  db_open_record(hDB, hkeydd, (void*)&info->settings.zone, sizeof(info->settings.zone), MODE_READ, NULL, NULL);

  // initialize driver
  info->hDB                   = hDB;
  info->hkey                  = hKey;
  info->num_channels_in       = channels;
  info->bd                    = bd;
  info->ctrl_mode             = 1; // default Closed Loop PID
  info->startup_error         = 0;
  for (i=0; i<3; i++) {
    info->pid_l1[i] = -1.0;
    info->pid_l2[i] = -1.0;
  }
  info->range_l1 = -1.0;
  info->range_l2 = -1.0;

  // check if the control channels are valid
  ls336_check_ctrl_loop_channel(info, info->settings.loop1.ctrl_ch, 1);
  ls336_check_ctrl_loop_channel(info, info->settings.loop2.ctrl_ch, 2);

  cm_msg(MINFO, "ls336_in", "loop1.ctrl_ch=%s", info->settings.loop1.ctrl_ch);
  cm_msg(MINFO, "ls336_in", "loop2.ctrl_ch=%s", info->settings.loop2.ctrl_ch);
  cm_yield(0);

  if (!bd)
    return FE_ERR_ODB;

  // initialize bus driver
  status = info->bd(CMD_INIT, hKey, &info->bd_info);
  if (status != FE_SUCCESS) {
    info->startup_error = 1;
    return status;
  }

  // initialize LS336
  strcpy(cmd, "*CLS\r\n");
  BD_PUTS(cmd);
  ss_sleep(100);

  strcpy(cmd, "*IDN?\r\n");
  BD_PUTS(cmd);
  ss_sleep(50);
  status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
  if ( !status ) { // error occurred
    cm_msg(MERROR,"LS336_in_init", "Error getting device query from LS336, %s",info->settings.odb_names.name);
    info->startup_error = 1;
    return FE_SUCCESS;
  }
  cm_msg(MINFO,"LS336_in_init", "Device query of LS336 yields %s = %s", info->settings.odb_names.name, rcv);
  cm_yield(0);

  // set/query the input type and calibration curve assigned
  for (i=0; i<info->settings.intern.num_sensors_used; i++) {

    // specifing sensor type
    if (info->settings.sensor.curve[i] == LS336_P_GAUGE_CALIB_NO) { // pressure gauge calibration curve number
      sprintf(cmd, "INTYPE %s, %d, 0, 1, 0, 1\r\n", info->settings.sensor.channel[i], info->settings.sensor.type[i]);
    } else {
      sprintf(cmd, "INTYPE %s, %d, 1, 0, 0, 1\r\n", info->settings.sensor.channel[i], info->settings.sensor.type[i]);
    }
    BD_PUTS(cmd);
    ss_sleep(50);
    sprintf(cmd, "INTYPE? %s\r\n", info->settings.sensor.channel[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
    status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    if ( !status ) { // no response
      cm_msg(MERROR, "LS336_in_init", "LS336: %s: Error getting channel %s type assignment.",
             info->settings.odb_names.name, info->settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return FE_SUCCESS; // since the whole things hangs otherwise
    }

    // specifing curve which is used to convert to temperature
    sprintf(cmd, "INCRV %s, %d\r\n", info->settings.sensor.channel[i], info->settings.sensor.curve[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
    sprintf(cmd, "INCRV? %s\r\n", info->settings.sensor.channel[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
    status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    if ( !status ) { // no response
      cm_msg(MERROR, "LS336_in_init", "LS336: %s: Error getting channel %s curve assignment.",
             info->settings.odb_names.name, info->settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return FE_SUCCESS; // since the whole things hangs otherwise
    }

    // read the header related to a curve
    sscanf(rcv, "%d", &ch);
    sprintf(cmd, "CRVHDR? %d\r\n", ch);
    BD_PUTS(cmd);
    ss_sleep(50);
    status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    if ( !status ) { // no response
      cm_msg(MERROR, "LS336_in_init", "LS336: %s: Error getting channel %s curve header.",
             info->settings.odb_names.name, info->settings.sensor.channel[i]);
      cm_yield(0);
      info->startup_error = 1;
      return FE_SUCCESS; // since the whole things hangs otherwise
    }

    // status output message
    cm_msg(MINFO,"LS336_in_init", "LS336: %s: Channel %s curve (type=%d):\n %s",
                  info->settings.odb_names.name, info->settings.sensor.channel[i],
                  info->settings.sensor.type[i], rcv);
    cm_yield(0);
  } // for

  // check if the requested sensor input(s) are available ---------------------
  for (i=0; i<info->settings.intern.num_sensors_used; i++) {
    sprintf(cmd, "RDGST? %s\r\n", info->settings.sensor.channel[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
    status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
    ls336_decode_sensor_status(info, i, rcv);
    ss_sleep(50);
  }

  // write zone settings to the LS336 -----------------------------------------
  // check that zone settings from ODB make some sense
  for (i=0; i<10; i++) {
    status = sscanf(info->settings.zone[i], "%f, %f, %f, %f, %f, %f, %f, %f, %f, %f",
                    &zone_val[0], &zone_val[1], &zone_val[2], &zone_val[3], &zone_val[4],
                    &zone_val[5], &zone_val[6], &zone_val[7], &zone_val[8], &zone_val[9]);
    if ((zone_val[0] != 1.0) && (zone_val[0] != 2.0)) {
      cm_msg(MERROR, "LS336_in_init", "**ERROR** in ZONE string from ODB in entry %d.", i);
      cm_msg(MERROR, "LS336_in_init", "First value needs to be either 1 or 2, found %.0f", zone_val[0]);
      cm_yield(0);
      return FE_SUCCESS;
    }
    if ((zone_val[1] < 1.0) || (zone_val[1] > 10.0)) {
      cm_msg(MERROR, "LS336_in_init", "**ERROR** in ZONE string from ODB in entry %d.", i);
      cm_msg(MERROR, "LS336_in_init", "Second value needs to be in the range 1..10, found %.0f", zone_val[1]);
      cm_yield(0);
      return FE_SUCCESS;
    }
    if ((zone_val[7] < 0.0) || (zone_val[7] > 3.0)) {
      cm_msg(MERROR, "LS336_in_init", "**ERROR** in ZONE string from ODB in entry %d.", i);
      cm_msg(MERROR, "LS336_in_init", "Range value needs to be in the range 0..3, found %.0f", zone_val[7]);
      cm_yield(0);
      return FE_SUCCESS;
    }
    if ((zone_val[8] < 0.0) || (zone_val[8] > 8.0)) {
      cm_msg(MERROR, "LS336_in_init", "**ERROR** in ZONE string from ODB in entry %d.", i);
      cm_msg(MERROR, "LS336_in_init", "Input value needs to be in the range 0..8, found %.0f", zone_val[8]);
      cm_yield(0);
      return FE_SUCCESS;
    }
    if ((zone_val[9] < 0.0) || (zone_val[9] > 100.0)) {
      cm_msg(MERROR, "LS336_in_init", "**ERROR** in ZONE string from ODB in entry %d.", i);
      cm_msg(MERROR, "LS336_in_init", "Ramp rate value needs to be in the range 0.0..100.0, found %.0f", zone_val[9]);
      cm_yield(0);
      return FE_SUCCESS;
    }
  }
  // set zone settings
  for (i=0; i<10; i++) {
    sprintf(cmd, "ZONE %s\r\n", info->settings.zone[i]);
    BD_PUTS(cmd);
    ss_sleep(50);
  }

  // init loop1,2 according the ODB
  // set ctrl ch for loop1
  sprintf(cmd, "OUTMODE 1, 1, %d, %d\r\n", ls336_ch_to_number(info->settings.loop1.ctrl_ch), info->settings.loop1.powerup_enable);
  BD_PUTS(cmd);
  ss_sleep(50);
  // set temperature limit for loop1
  sprintf(cmd, "TLIMIT %s, %.1f\r\n", info->settings.loop1.ctrl_ch, info->settings.loop1.temperature_limit);
  BD_PUTS(cmd);
  ss_sleep(50);
  // set max. current tag, max. user current, heater resistance tag
  sprintf(cmd, "HTRSET 1, %d, %d, %.2f, 1\r\n", info->settings.loop1.heater_resistance_tag,
          info->settings.loop1.max_current_tag, info->settings.loop1.max_user_current);
  BD_PUTS(cmd);
  ss_sleep(50);
  // set ctrl ch for loop2
  sprintf(cmd, "OUTMODE 2, 1, %d, %d\r\n", ls336_ch_to_number(info->settings.loop2.ctrl_ch), info->settings.loop2.powerup_enable);
  BD_PUTS(cmd);
  ss_sleep(50);
  // set temperature limit for loop2
  sprintf(cmd, "TLIMIT %s, %.1f\r\n", info->settings.loop2.ctrl_ch, info->settings.loop2.temperature_limit);
  BD_PUTS(cmd);
  ss_sleep(50);
  // set max. current tag, max. user current, heater resistance tag
  sprintf(cmd, "HTRSET 2, %d, %d, %.2f, 1\r\n", info->settings.loop2.heater_resistance_tag,
          info->settings.loop2.max_current_tag, info->settings.loop2.max_user_current);
  BD_PUTS(cmd);
  ss_sleep(50);

  // check if loop1,2 output is enabled
  if (info->settings.loop1.output_on == 0) {
    sprintf(cmd, "RANGE 1, 0\r\n");
    BD_PUTS(cmd);
    ss_sleep(200);
  }
  if (info->settings.loop2.output_on == 0) {
    sprintf(cmd, "RANGE 2, 0\r\n");
    BD_PUTS(cmd);
    ss_sleep(200);
  }

  // establish hotlink to cryo name
  status = db_find_key(hDB, hKey, "DD/ODB Names/LS336 Name", &hkeydd);
  if (status != DB_SUCCESS) {
    cm_msg(MERROR, "ls336_in_init", "**ERROR** couldn't get ODB key needed to establish Cryo switching! (status=%d)", status);
    cm_yield(0);
    FE_SUCCESS;
  }
  status = db_open_record(hDB, hkeydd, (void*)&info->cryo_name, sizeof(info->cryo_name),
                          MODE_READ, &ls336_cryo_name_changed, (void *)info);
  if (status != DB_SUCCESS) {
    cm_msg(MERROR, "ls336_in_init", "**ERROR** couldn't establish hotlink to cryo name! (status=%d)", status);
    cm_yield(0);
  }

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_out_init
 * @param hKey
 * @param pinfo
 * @param channels
 * @return
 */
INT ls336_out_init(HNDLE hKey, LS336_INFO **pinfo, INT channels, func_t *bd)
{  
  ls336_info->num_channels_out = channels;
  *pinfo = ls336_info;

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_exit
 * @param info
 * @return
 */
INT ls336_exit(LS336_INFO *info)
{
  // call EXIT function of bus driver, usually closes device
  info->bd(CMD_EXIT, info->bd_info);

  free(info);

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_soft_zone
 * @param info
 * @param value
 * @return
 */
INT ls336_soft_zone(LS336_INFO *info, float value)
{
  int i, idx=-1, status;
  int tok[10];

  // go through the zone settings and find the proper zone
  for (i=0; i<10; i++) {
    status = sscanf(info->settings.zone[i], "%d, %d, %d, %d, %d, %d, %d, %d, %d, %d",
                    &tok[0], &tok[1], &tok[2], &tok[3], &tok[4], &tok[5], &tok[6], &tok[7], &tok[8], &tok[9]);
    if (status != 10) {
      cm_msg(MDEBUG, "ls336_soft_zone", "ls336_soft_zone: found in zone string only %d tokens instead of 10. Will do nothing.", status);
      cm_yield(0);
      return FE_SUCCESS;
    }
    if (tok[2] >= (int)value) {
      idx = i;
      break;
    }
  }
  if (idx == -1) {
    cm_msg(MDEBUG, "ls336_soft_zone", "ls336_soft_zone: found no proper zone setting. Will do nothing.");
    cm_yield(0);
    return FE_SUCCESS;
  }

  // set PID's according to the SP ZONE
  info->pid_l1[0] = tok[3];
  info->pid_l1[1] = tok[4];
  info->pid_l1[2] = tok[5];
  ss_sleep(50);
  ls336_set(info, 1, tok[3]);

  // set heater range according to the SP ZONE
  ss_sleep(50);
  ls336_set(info, 4, tok[7]);

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_set
 * @param info
 * @param channel
 * @param value
 * @return
 */
INT ls336_set(LS336_INFO *info, INT channel, float value)
{
  char cmd[32];
  int ival;

  if (channel == 0) { // setpoint of loop1
    sprintf(cmd, "SETP 1, %.2f\r\n", value);
  } else if (channel == 1) { // PID, P of loop1
    if (info->pid_l1[0] == -1.0)
      return FE_SUCCESS;
    sprintf(cmd, "PID 1, %.1f, %.1f, %.1f\r\n", value, info->pid_l1[1], info->pid_l1[2]);
  } else if (channel == 2) { // PID, I of loop1
    if (info->pid_l1[0] == -1.0)
      return FE_SUCCESS;
    sprintf(cmd, "PID 1, %.1f, %.1f, %.1f\r\n", info->pid_l1[0], value, info->pid_l1[2]);
  } else if (channel == 3) { // PID, D of loop1
    if (info->pid_l1[0] == -1.0)
      return FE_SUCCESS;
    sprintf(cmd, "PID 1, %.1f, %.1f, %.1f\r\n", info->pid_l1[0], info->pid_l1[1], value);
  } else if (channel == 4) { // heater range of loop1
    if ((value != 0.0) && (value != 1.0) && (value != 2.0) && (value != 3.0)) {
      cm_msg(MERROR, "ls336_set", "**ERROR** found unspported loop1 heater range (%.1f), allowed are 0..3. Will set it to 0.", value);
      cm_yield(0);
      value = 0.0;
    }
    sprintf(cmd, "RANGE 1, %.0f\r\n", value);
  } else if (channel == 5) { // control mode of loop1
    if ((value != 0.0) && (value != 1.0) && (value != 2.0) &&
        (value != 3.0) && (value != 4.0) && (value != 5.0)) {
      cm_msg(MERROR, "ls336_set", "**ERROR** found unspported loop1 outmode (%.0f), allowed are 0..5. Will set it to 1 (Closed Loop PID).", value);
      cm_yield(0);
      value = 1.0;
    }
    info->ctrl_mode = value; // keep control mode of loop1 to mimic LS340 zone settings behavior
    sprintf(cmd, "OUTMODE 1, %d, %d, %d\r\n", (int)value, ls336_ch_to_number(info->settings.loop1.ctrl_ch), info->settings.loop1.powerup_enable);
  } else if (channel == 6) { // ramp value of loop1
    if ((value < 0.0) || (value > 100.0)) {
      cm_msg(MERROR, "ls336_set", "**ERROR** found unspported loop1 ramp value (%.0f), allowed are 0..100. Will switch off ramping.", value);
      cm_yield(0);
      ival = 0;
      value = 0.0;
    } else {
      if (value == 0.0)
        ival = 0;
      else
        ival = 1;
    }
    sprintf(cmd, "RAMP 1, %d, %.1f\r\n", ival, value);
  } else if (channel == 7) { // setpoint of loop2
    sprintf(cmd, "SETP 2, %.2f\r\n", value);
  } else if (channel == 8) { // PID, P of loop2
    if (info->pid_l2[0] == -1.0)
      return FE_SUCCESS;
    sprintf(cmd, "PID 2, %.1f, %.1f, %.1f\r\n", value, info->pid_l2[1], info->pid_l2[2]);
  } else if (channel == 9) { // PID, I of loop2
    if (info->pid_l2[0] == -1.0)
      return FE_SUCCESS;
    sprintf(cmd, "PID 2, %.1f, %.1f, %.1f\r\n", info->pid_l2[0], value, info->pid_l2[2]);
  } else if (channel == 10) { // PID, D of loop2
    if (info->pid_l2[0] == -1.0)
      return FE_SUCCESS;
    sprintf(cmd, "PID 2, %.1f, %.1f, %.1f\r\n", info->pid_l2[0], info->pid_l2[1], value);
  } else if (channel == 11) { // heater range of loop2
    if ((value != 0.0) && (value != 1.0) && (value != 2.0) && (value != 3.0)) {
      cm_msg(MERROR, "ls336_set", "**ERROR** found unspported loop2 heater range (%.1f), allowed are 0..3. Will set it to 0.", value);
      cm_yield(0);
      value = 0.0;
    }
    sprintf(cmd, "RANGE 2, %.0f\r\n", value);
  } else if (channel == 12) { // control mode of loop2
    if ((value != 0.0) && (value != 1.0) && (value != 2.0) &&
        (value != 3.0) && (value != 4.0) && (value != 5.0)) {
      cm_msg(MERROR, "ls336_set", "**ERROR** found unspported loop2 outmode (%.0f), allowed are 0..5. Will set it to 2 (ZONE).", value);
      cm_yield(0);
      value = 2.0;
    }
    sprintf(cmd, "OUTMODE 2, %.0f, %d, %d\r\n", value, ls336_ch_to_number(info->settings.loop2.ctrl_ch), info->settings.loop2.powerup_enable);
  } else if (channel == 13) { // ramp value of loop2
    if ((value < 0.0) || (value > 100.0)) {
      cm_msg(MERROR, "ls336_set", "**ERROR** found unspported loop2 ramp value (%.0f), allowed are 0..100. Will switch off ramping.", value);
      cm_yield(0);
      ival = 0;
      value = 0.0;
    } else {
      if (value == 0.0)
        ival = 0;
      else
        ival = 1;
    }
    sprintf(cmd, "RAMP 2, %d, %.1f\r\n", ival, value);
  }

  BD_PUTS(cmd);
  ss_sleep(50);

  // check if the setpoint has changed and the control mode is "Closed Loop PID".
  // If this is the case, the ZONE setting behavior of the LS340 will be simulated
  if ((channel == 0) && (info->ctrl_mode == 1) && info->settings.intern.enable_soft_zone) {
    ls336_soft_zone(info, value);
  }

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * <p> resets the communication in case of readback failures
 *
 * @param info
 * @return
 */
INT ls336_reset_communication(LS336_INFO *info)
{
  char cmd[32];
  int cnt, status;

  // call exit routine of the bus driver
  if (info->settings.intern.detailed_msg) {
    cm_msg(MDEBUG, "ls336_get", "**INFO** exit bus driver (%s).", info->cryo_name);
    cm_yield(0);
  }
  info->bd(CMD_EXIT, info->bd_info);

  // wait 1 sec
  ss_sleep(1000);
  cm_yield(0);

  // re-establish the bus driver communication
  if (info->settings.intern.detailed_msg) {
    cm_msg(MDEBUG, "ls336_get", "**INFO** re-establish bus driver connection (%s).", info->cryo_name);
    cm_yield(0);
  }
  status = info->bd(CMD_INIT, info->hkey, &info->bd_info);
  if (status != FE_SUCCESS) {
    info->startup_error = 1;
    return status;
  }

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_get
 * @param info
 * @param channel
 * @param pvalue
 * @return
 */
INT ls336_get(LS336_INFO *info, INT channel, float *pvalue)
{
  int status, i;
  char cmd[32], rcv[128], rcv2[128];
  static float temp[8];
  static float pid[3];
  static float sens[8];
  float fval, farray[10];
  static HNDLE hKeyRaw=-1;
  int cnt;

  // check for startup_error
  if (info->startup_error == 1) { // error during CMD_INIT, return -2
    *pvalue = (float) LS336_INIT_ERROR;
    ss_sleep(10); // to keep CPU load low when Run active
    return FE_SUCCESS;
  }

  // check the heater state before proceeding
  if (channel == LS336_MAX_SENSORS+3) // for this channel there wouldn't be any action
    ls336_check_heater(info);

  strcpy(cmd, "no-cmd");
  if (channel == 0) { // all the temperature sensors
    strcpy(cmd, "KRDG? 0\r\n"); // read ALL temperature in units Kelvin
  } else if (channel == LS336_MAX_SENSORS) { // heater output loop1
    strcpy(cmd, "HTR? 1\r\n");
  } else if (channel == LS336_MAX_SENSORS+1) { // setpoint loop1
    strcpy(cmd, "SETP? 1\r\n");
  } else if (channel == LS336_MAX_SENSORS+2) { // read ALL PID parameter of loop1
    strcpy(cmd, "PID? 1\r\n");
  } else if (channel == LS336_MAX_SENSORS+5) { // read heater range of loop1
    strcpy(cmd, "RANGE? 1\r\n");
  } else if (channel == LS336_MAX_SENSORS+6) { // control mode of loop1
    strcpy(cmd, "OUTMODE? 1\r\n");
  } else if (channel == LS336_MAX_SENSORS+7) { // ramping of loop1
    strcpy(cmd, "RAMP? 1\r\n");
  } else if (channel == LS336_MAX_SENSORS+8) { // heater output loop2
    strcpy(cmd, "HTR? 2\r\n");
  } else if (channel == LS336_MAX_SENSORS+9) { // setpoint loop2
    strcpy(cmd, "SETP? 2\r\n");
  } else if (channel == LS336_MAX_SENSORS+10) { // read ALL PID parameter of loop2
    strcpy(cmd, "PID? 2\r\n");
  } else if (channel == LS336_MAX_SENSORS+13) { // read heater range of loop2
    strcpy(cmd, "RANGE? 2\r\n");
  } else if (channel == LS336_MAX_SENSORS+14) { // control mode of loop2
    strcpy(cmd, "OUTMODE? 2\r\n");
  } else if (channel == LS336_MAX_SENSORS+15) { // ramping of loop2
    strcpy(cmd, "RAMP? 2\r\n");
  }

  memset(rcv, 0, sizeof(rcv));
  if (!strstr(cmd, "no-cmd")) { // not all channel request something
    // send/recive command
    BD_PUTS(cmd);
    ss_sleep(50);
    // get response
    cnt = 0;
    do {
      status = BD_GETS(rcv, sizeof(rcv), "\r\n", LS336_TIMEOUT);
      if ( !status ) {
        cnt++;
        if (info->settings.intern.detailed_msg) {
          cm_msg(MDEBUG, "ls336_get", "debug> ls336_get: channel=%d, no readback value!", channel);
          cm_yield(0);
        }
        ss_sleep(50);
      }
    } while ((status == 0) && (cnt < 5));

    if (info->settings.intern.detailed_msg && (status == 0)) {
      cm_msg(MDEBUG, "ls336_get", "debug> ls336_get: channel=%d, readback failure for %d time(s)!", channel, cnt);
      cm_yield(0);
    }

    if ((channel == 0) && (info->settings.intern.read_raw_data)) {
      ss_sleep(100);
      strcpy(cmd, "SRDG? 0\r\n");
      BD_PUTS(cmd);
      ss_sleep(50);
      status = BD_GETS(rcv2, sizeof(rcv2), "\r\n", LS336_TIMEOUT);
      if ( !status ) {
        if (info->settings.intern.detailed_msg) {
          cm_msg(MDEBUG, "ls336_get", "debug> ls336_get: srdg? 0: no readback value!");
          cm_yield(0);
        }
      }
    }
  }

  // manage response
  if (channel == 0) { // get all the temperature values at once
    // init temp array
    for (i=0; i<LS336_MAX_SENSORS; i++)
      temp[i] = LS336_READ_ERROR;
    status = sscanf(rcv, "%f,%f,%f,%f,%f,%f,%f,%f",
                    &temp[0], &temp[1], &temp[2], &temp[3],
                    &temp[4], &temp[5], &temp[6], &temp[7]);
    if (status != LS336_MAX_SENSORS) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** temperature sensor readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
      ls336_reset_communication(info);
    } else {
      *pvalue = temp[0];
    }

    // check if raw sensor reading has been requested
    if (info->settings.intern.read_raw_data) {
      for (i=0; i<LS336_MAX_SENSORS; i++)
        sens[i] = LS336_READ_ERROR;

      status = sscanf(rcv2, "%f,%f,%f,%f,%f,%f,%f,%f",
                      &sens[0], &sens[1], &sens[2], &sens[3],
                      &sens[4], &sens[5], &sens[6], &sens[7]);
      if (status != LS336_MAX_SENSORS) {
        if (info->settings.intern.detailed_msg) {
          cm_msg(MDEBUG, "ls336_get", "**WARNING** raw sensor readback failure.");
          cm_yield(0);
        }
      } else { // everything looks good, hence dump it to the ODB
        if (hKeyRaw == -1) { // first time hence it is necessary to get the ODB key
          status = db_find_key(info->hDB, info->hkey, "DD/Sensors/Raw Input Channel", &hKeyRaw);
          if (status != DB_SUCCESS) {
            if (info->settings.intern.detailed_msg) {
              cm_msg(MDEBUG, "ls336_get", "**WARNING** couldn't get 'Raw Input Channel' key.");
              cm_yield(0);
              return FE_SUCCESS;
            }
          }
        } else {
          db_set_data(info->hDB, hKeyRaw, (void*)&sens, sizeof(sens), LS336_MAX_SENSORS, TID_FLOAT);
        }
      }
    }
  } else if ((channel >= 1) && (channel < LS336_MAX_SENSORS)) { // feed the temperature
    *pvalue = temp[channel];
  } else if (channel == LS336_MAX_SENSORS) { // heater output loop1
    status = sscanf(rcv, "%f", &fval);
    if (status != 1) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop1 heater output readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = fval;
    }
  } else if (channel == LS336_MAX_SENSORS+1) { // setpoint loop1
    status = sscanf(rcv, "%f", &fval);
    if (status != 1) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop1 setpoint readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = fval;
    }
  } else if (channel == LS336_MAX_SENSORS+2) { // PID's loop1
    // init pid array
    for (i=0; i<3; i++)
      pid[i] = LS336_READ_ERROR;
    status = sscanf(rcv, "%f,%f,%f", &pid[0], &pid[1], &pid[2]);
    if (status != 3) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop1 pid readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = pid[0];
      // keep pid's (needed for set command)
      for (i=0; i<3; i++)
        info->pid_l1[i] = pid[i];
    }
  } else if (channel == LS336_MAX_SENSORS+3) {
    *pvalue = pid[1];
  } else if (channel == LS336_MAX_SENSORS+4) {
    *pvalue = pid[2];
  } else if (channel == LS336_MAX_SENSORS+5) { // read heater range of loop1
    status = sscanf(rcv, "%f", &fval);
    if (status != 1) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop1 heater range readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = fval;
      if (fval > 0.0) // keep range setting only if heater is on (needed to re-enable)
        info->range_l1 = fval;
    }
  } else if (channel == LS336_MAX_SENSORS+6) { // control mode of loop1
    status = sscanf(rcv, "%f,%f,%f", &farray[0], &farray[1], &farray[2]);
    if (status != 3) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop1 control mode readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = farray[0];
    }
    info->ctrl_mode = (int)(*pvalue); // keep the ctrl mode of the loop1 in order to mimic the LS340 zone settings behavior
  } else if (channel == LS336_MAX_SENSORS+7) { // ramping of loop1
    status = sscanf(rcv, "%f,%f", &farray[0], &farray[1]);
    if (status != 2) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop1 ramp value readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      if (farray[0] == 1.0)
        *pvalue = farray[1];
      else
        *pvalue = 0.0;
    }
  } else if (channel == LS336_MAX_SENSORS+8) { // heater output loop2
    status = sscanf(rcv, "%f", &fval);
    if (status != 1) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop2 heater output readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = fval;
    }
  } else if (channel == LS336_MAX_SENSORS+9) { // setpoint loop2
    status = sscanf(rcv, "%f", &fval);
    if (status != 1) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop2 setpoint readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = fval;
    }
  } else if (channel == LS336_MAX_SENSORS+10) { // read ALL PID parameter of loop2
    // init pid array
    for (i=0; i<3; i++)
      pid[i] = LS336_READ_ERROR;
    status = sscanf(rcv, "%f,%f,%f", &pid[0], &pid[1], &pid[2]);
    if (status != 3) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop2 pid readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = pid[0];
      // keep pid's (needed for set command)
      for (i=0; i<3; i++)
        info->pid_l2[i] = pid[i];
    }
  } else if (channel == LS336_MAX_SENSORS+11) {
    *pvalue = pid[1];
  } else if (channel == LS336_MAX_SENSORS+12) {
    *pvalue = pid[2];
  } else if (channel == LS336_MAX_SENSORS+13) { // read heater range of loop2
    status = sscanf(rcv, "%f", &fval);
    if (status != 1) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop2 heater range readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = fval;
      if (fval > 0.0) // keep range setting only if heater is on (needed to re-enable)
        info->range_l2 = fval;
    }
  } else if (channel == LS336_MAX_SENSORS+14) { // control mode of loop2
    status = sscanf(rcv, "%f,%f,%f", &farray[0], &farray[1], &farray[2]);
    if (status != 3) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop2 control mode readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      *pvalue = farray[0];
    }
  } else if (channel == LS336_MAX_SENSORS+15) { // ramping of loop2
    status = sscanf(rcv, "%f,%f", &farray[0], &farray[1]);
    if (status != 2) {
      if (info->settings.intern.detailed_msg) {
        cm_msg(MDEBUG, "ls336_get", "**WARNING** loop2 ramp value readback failure.");
        cm_yield(0);
      }
      *pvalue = LS336_READ_ERROR;
    } else {
      if (farray[0] == 1.0)
        *pvalue = farray[1];
      else
        *pvalue = 0.0;
    }
  }

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_in_get_label
 * @param info
 * @param channel
 * @param name
 * @return
 */
INT ls336_in_get_label(LS336_INFO *info, INT channel, char *name)
{
  strcpy(name, info->settings.odb_names.names_in[channel]);

  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/**
 * @brief ls336_out_get_label
 * @param info
 * @param channel
 * @param name
 * @return
 */
INT ls336_out_get_label(LS336_INFO *info, INT channel, char *name)
{
  strcpy(name, info->settings.odb_names.names_out[channel]);

  return FE_SUCCESS;
}

//---- device driver entry point ----------------------------------------------
INT ls336_in(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   *pvalue;
  LS336_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey    = va_arg(argptr, HNDLE);
        LS336_INFO **pinfo = va_arg(argptr, LS336_INFO **);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - not needed here
        func_t *bd = va_arg(argptr, func_t *);
      status  = ls336_in_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_EXIT:
      info   = va_arg(argptr, LS336_INFO *);
      status = ls336_exit(info);
      break;

    case CMD_GET:
      info    = va_arg(argptr, LS336_INFO *);
      channel = va_arg(argptr, INT);
      pvalue  = va_arg(argptr, float*);
      status  = ls336_get(info, channel, pvalue);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, LS336_INFO *);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = ls336_in_get_label(info, channel, name);
      break;

    default:
      break;
  }

  va_end(argptr);
  return status;
}

INT ls336_out(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   value;
  LS336_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey    = va_arg(argptr, HNDLE);
        LS336_INFO **pinfo = va_arg(argptr, LS336_INFO **);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - not needed here
        func_t *bd = va_arg(argptr, func_t *);
        status  = ls336_out_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_SET:
      info    = va_arg(argptr, LS336_INFO *);
      channel = va_arg(argptr, INT);
      value   = (float) va_arg(argptr, double);
      status  = ls336_set(info, channel, value);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, LS336_INFO *);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = ls336_out_get_label(info, channel, name);
      break;

    default:
      break;
  }

  va_end(argptr);

  return status;
}

// end ------------------------------------------------------------------------
