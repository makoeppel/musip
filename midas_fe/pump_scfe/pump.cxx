/*----------------------------------------------------------------------------

  Name:         pump.cxx
  Created by:   Andreas Suter  2004/08/30
  Rewritten by: Andreas Suter  2016/01/25 (new Siemens SPS communication modules)

  Contents:     pump vacuum controller; Fleischli 2017 Siemens SPS basic unit
                protocol as implemented on port 2002 (port 2000 is the full fledged interface)

----------------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <string.h>
#include <math.h>
#include "midas.h"
#include "pump.h"

// channels of the SPS input variables
#define PUMP_LIFESIGN    0
#define PUMP_GP          1
#define PUMP_GTI         2
#define PUMP_TURBO_SPEED 3
#define PUMP_STAT_BYTE_1 4
#define PUMP_STAT_BYTE_2 5
#define PUMP_STAT_BYTE_3 6
#define PUMP_MSG_BYTE_1  7
#define PUMP_MSG_BYTE_2  8
#define PUMP_MSG_BYTE_3  9

#define SPS_MAX_BYTES      28   //!< length of the data structure exchanged between SPS and midas (port 2002 or 2004)
#define PUMP_TIME_CONST    0    //!< trigger time constant for read out of the SPS
#define PUMP_TIMEOUT_ERROR 3600 //!< after what time (sec.) read errors should be reported

//! Stores DD specific internal information
typedef struct {
  INT detailed_msg; //!< flag indicating if detailed status/error messages are wanted
} PUMP_INTERN;

//! Initializing string for the struct PUMP_INTERN
const char *pump_intern_str =
"Detailed Messages = INT : 0\n\
";

//! Stores the names of the various channels which are than transferred form the DD to the variable names
typedef struct {
char in_name[PUMP_IN_VARS][NAME_LENGTH];   //!< Names of the input variable names as found in the ODB
char out_name[NAME_LENGTH];
} PUMP_NAMES;

//! Initializing string for the struct PUMP_NAMES
const char *pump_names_str =
"Input Names = STRING[10] : \n\
[32] Life Sign\n\
[32] GP Pirani\n\
[32] Gti\n\
[32] Turbo Speed\n\
[32] Status Byte 1\n\
[32] Status Byte 2\n\
[32] Status Byte 3\n\
[32] Message Byte 1\n\
[32] Message Byte 2\n\
[32] Message Byte 3\n\
Output Names = STRING : [32] Cmd\n\
";

//! This structure contains private variables for the device driver.
typedef struct {
  PUMP_INTERN intern;          //!< stores DD specific internal settings
  PUMP_NAMES pump_names;       //!< stores the internal DD settings
  char pump_buffer[SPS_MAX_BYTES]; //!< SPS-DB byte buffer
  float pump_data[PUMP_IN_VARS];  //!< stores decoded values from SPS-DB
  INT (*bd)(INT cmd, ...);     //!< bus driver entry function for reading
  void *bd_info;               //!< pointer to the BD info structure of the input channels
  HNDLE hDB;                   //!< main ODB handle
  HNDLE hKey_in;               //!< main device driver handle for input channels
  HNDLE hKey_out;              //!< main device driver handle for input channels
  HNDLE hKey_DB_Buffer;        //!< handle to the raw SPS-DB data
  DWORD time;                  //!< trigger timer
  DWORD errTime;               //!< timer for error handling concerning tcpip communication
  INT   startup_error;         //!< tag if there has been an error at startup
  INT   tcpip_open_error;      //!< how often the attempt to open the tcpip communication failed
  INT   read_error;            //!< how often there has been a read error
  INT   read_counts;           //!< total no of tcpip reading attempts
  DWORD last_success;          //!< timer of last read success
} PUMP_INFO;

PUMP_INFO *gInfo; //!< global info structure, in/out-init routines need the same structure

//----------------------------------------------------------------------------
/**
 * <p>This routine converts the 2 byte input to an integer number.
 *
 * \return number </p>
 *
 * \param buffer pointer to 2 bytes
 */
short spsToNumber(unsigned char *buffer)
{
  int val = 0;

  if (buffer[0] & 0x80)
    val = (buffer[0] &0x7f) << 8;
  else
    val = buffer[0] << 8;

  if (buffer[1] & 0x80) // sign bit set
    val += (buffer[1] &0x7f) + 128;
  else
    val += buffer[1];

  return val;
}

//----------------------------------------------------------------------------
/**
 * <p>This routine converts the 4 byte input to a float number.
 *
 * \return number </p>
 *
 * \param buffer pointer to 4 bytes
 */
float spsToFloat(unsigned char *buffer)
{
  int i;
  float fval = 0.0;

  for (i=0; i<4; i++)
    *((unsigned char*)(&fval)+(3-i)) = buffer[i];

  return fval;
}

//----------------------------------------------------------------------------
/**
 * @brief pump_decode_messages
 * @param buffer
 */
void pump_decode_messages(const char *buffer)
{
  char msg;

  msg = buffer[0];
  if (!(msg & 0x01)) { // pumping station off hence no checking needed
    return;
  }

  msg = buffer[4]; // message byte 1

  if (msg & 0x01) {
    cm_msg(MERROR, "pump", "**ERROR** inrush of air Gti > 1 mbar"); cm_yield(0);
  } else if (msg & 0x02) {
    cm_msg(MERROR, "pump", "**ERROR** pump circut breaker tripped"); cm_yield(0);
  } else if (msg & 0x04) {
    cm_msg(MERROR, "pump", "**ERROR** timeout prevacuum pump"); cm_yield(0);
  } else if (msg & 0x08) {
    cm_msg(MERROR, "pump", "**ERROR** fault TCP"); cm_yield(0);
  } else if (msg & 0x10) {
    cm_msg(MERROR, "pump", "**ERROR** turbo timeout"); cm_yield(0);
  } else if (msg & 0x20) {
    cm_msg(MERROR, "pump", "**ERROR** TPG300 fault"); cm_yield(0);
  } else if (msg & 0x40) {
    cm_msg(MERROR, "pump", "**ERROR** timeout pumping recipient"); cm_yield(0);
  } else if (msg & 0x80) {
    cm_msg(MERROR, "pump", "**ERROR** fault measuring active cell Gti"); cm_yield(0);
  }

  msg = buffer[5]; // message byte 2

  if (msg & 0x01) {
    cm_msg(MERROR, "pump", "**ERROR** fault measuring active cell Pgp"); cm_yield(0);
  } else if (msg & 0x02) {
    cm_msg(MERROR, "pump", "**ERROR** fault measuring TPG300 cell Gti"); cm_yield(0);
  } else if (msg & 0x04) {
    cm_msg(MERROR, "pump", "**ERROR** fault measuring TPG300 cell Pgp"); cm_yield(0);
  } else if (msg & 0x08) {
    cm_msg(MERROR, "pump", "**ERROR** bypass valve fault sensors"); cm_yield(0);
  } else if (msg & 0x10) {
    cm_msg(MERROR, "pump", "**ERROR** bypass valve timeout"); cm_yield(0);
  } else if (msg & 0x20) {
    cm_msg(MERROR, "pump", "**ERROR** buffer valve faults sensors"); cm_yield(0);
  } else if (msg & 0x40) {
    cm_msg(MERROR, "pump", "**ERROR** buffer valve timeout"); cm_yield(0);
  } else if (msg & 0x80) {
    cm_msg(MERROR, "pump", "**ERROR** high vacuum valve faults sensors"); cm_yield(0);
  }

  msg = buffer[6]; // message byte 3

  if (msg & 0x01) {
    cm_msg(MERROR, "pump", "**ERROR** high vacuum valve timeout"); cm_yield(0);
  } else if (msg & 0x02) {
    cm_msg(MERROR, "pump", "**ERROR** venting valve fault sensors"); cm_yield(0);
  } else if (msg & 0x04) {
    cm_msg(MERROR, "pump", "**ERROR** venting valve timeout"); cm_yield(0);
  }
}

//----------------------------------------------------------------------------
/*!
 * <p>decodes the DB buffer and write it into an array which mirrors the midas
 * input variables.
 *
 * \return true, if buffer is ok, otherwise false.
 *
 * \param info pointer to the DD info structure.
 * \param buffer pointer to the internal DB buffer structure.
 */
BOOL pump_decode_data(PUMP_INFO *info, const char *buffer)
{
  static int pump_off=0;
  static int life_sign=0;
  int i;

  if (buffer[0] & 0x0) { // check if pumping station is on
    if (pump_off == 0) {
      pump_off = 1;
      cm_msg(MINFO, "pump", "pumping station is off.");
      cm_yield(0);
    }
    return FALSE;
  } else {
    pump_off = 0;
  }

  info->pump_data[PUMP_LIFESIGN] = life_sign;
  info->pump_data[PUMP_GP] = spsToFloat((unsigned char *)&buffer[12]);
  info->pump_data[PUMP_GTI] = spsToFloat((unsigned char *)&buffer[16]);
  info->pump_data[PUMP_TURBO_SPEED] = spsToNumber((unsigned char*)&buffer[8]);
  info->pump_data[PUMP_STAT_BYTE_1] = buffer[0];
  info->pump_data[PUMP_STAT_BYTE_2] = buffer[1];
  info->pump_data[PUMP_STAT_BYTE_3] = buffer[2];
  info->pump_data[PUMP_MSG_BYTE_1] = buffer[4];
  info->pump_data[PUMP_MSG_BYTE_2] = buffer[5];
  info->pump_data[PUMP_MSG_BYTE_3] = buffer[6];

  life_sign = (life_sign + 1) % 1000;

  pump_decode_messages(buffer);

  return TRUE;
}

//----------------------------------------------------------------------------
/*!
 * <p>Establishes the communication to the SPS controll unit for reading, reads
 * the data and stores them in the local structure <pre>pump_data</pre>.
 * Since the communication sometimes fails, an error protocol system is implemented
 * as well. It record the errors over a period of 10 min. and sends them (cm_msg) to midas.
 *
 * \param info is a pointer to the DD specific info structure
 */
void pump_get_all(PUMP_INFO *info)
{
  INT  status;
  char data[SPS_MAX_BYTES];
  DWORD now;

  float delta = ss_time()-info->time;
  // check timer, if smaller then time constant do nothing
  if (delta < PUMP_TIME_CONST)
    return;

  // communication error report handling
  delta = ss_time()-info->errTime;
  if (delta > PUMP_TIMEOUT_ERROR) {
    if ((info->tcpip_open_error != 0) || (info->read_error != 0)) {
      if (info->intern.detailed_msg) {
        cm_msg(MINFO, "pump_get_all",
               "pump_get_all: No of tcpip open errors = %d, tcpip read errors =%d of %d readings in the last %d secs.",
               info->tcpip_open_error, info->read_error, info->read_counts, PUMP_TIMEOUT_ERROR);
        cm_yield(0);
      }
      // reset error counters
      info->tcpip_open_error = 0;
      info->read_error = 0;
      info->read_counts = 0;
      // restart timer
      info->errTime = ss_time();
    }
  }

  // get data
  status = info->bd(CMD_READ, info->bd_info, &data[0], sizeof(data), 3000); // read data
  if (info->intern.detailed_msg) {
    cm_msg(MDEBUG, "pump_get_all", "pump_get_all: get data (status=%d)", status);
    cm_yield(0);
  }
  if (status == SPS_MAX_BYTES) {
    memcpy(info->pump_buffer, data, SPS_MAX_BYTES);
    // feed readback diagnostic array
    now = ss_time();
    if (info->last_success == 0) {
      info->last_success = now;
    }
  } else {
    if (info->intern.detailed_msg) {
      cm_msg(MINFO, "pump_get_all", "pump_get_all: get.data.status=%d", status);
      cm_yield(0);
    }
    info->read_counts++;
  }

  // check for errors
  // (error byte set) or (haven't gotten all the data)
  if (status != SPS_MAX_BYTES) {
    info->read_error++;
    return;
  } else {
    info->read_counts = 0;
    if (!pump_decode_data(info, data)) {
      info->read_error++;
    }
  }

  info->time = ss_time(); // restart timer
}

//----------------------------------------------------------------------------
/*!
 * <p>sends a command from midas to the SPS. The command is encoded in the DB structure.
 *
 * \param info pointer to the DD info structure
 */
void pump_write_cmd(PUMP_INFO *info)
{
  int status;

  info->tcpip_open_error = 0;

  // write stuff
  status = info->bd(CMD_WRITE, info->bd_info, &info->pump_buffer[0], sizeof(info->pump_buffer)); // write data
  if (info->intern.detailed_msg) {
    cm_msg(MDEBUG, "pump_write_cmd", "pump_write_cmd: write data (status=%d)", status);
    cm_yield(0);
  }
}

/*---- device driver routines ------------------------------------------------*/

typedef INT(func_t) (INT cmd, ...);

/*----------------------------------------------------------------------------*/
/*!
 * <p>Initializes the pump device driver for reading, i.e.\ generates all the necessary
 * structures in the ODB if necessary, initializes the bus driver and the pump.
 *
 * \return
 *   - FE_SUCCESS if everthing is OK
 *   - FE_ERR_ODB if a severe error occured
 *
 * \param hKey is the device driver handle given from the class driver
 * \param **pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param *bd is a pointer to the bus driver
 */
INT pump_in_init(HNDLE hKey, PUMP_INFO **pinfo, INT channels, func_t *bd)
{
  INT   status, size, i;
  char  str[512];
  HNDLE hDB, hkeydd;

  // allocate info structure
  gInfo = (PUMP_INFO *)calloc(1, sizeof(PUMP_INFO));
  *pinfo = gInfo;

  // get ODB handle
  cm_get_experiment_database(&hDB, NULL);
  // store handles (ODB and DD key) in local structure to keep it for latter use
  gInfo->hDB = hDB;
  gInfo->hKey_in = hKey;

  // create pump DD intern structure if not already exists
  status = db_find_key(hDB, hKey, "DD/intern", &hkeydd);
  if (status != DB_SUCCESS) { // key doesn't exist yet
    // create pump DD intern
    status = db_create_record(hDB, hKey, "DD/intern", pump_intern_str);
    if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
      cm_msg(MERROR, "pump_init", "pump_init: Error creating pump intern record in ODB, status=%d", status);
      cm_yield(0);
      return FE_ERR_ODB;
    }
  }
  db_find_key(hDB, hKey, "DD/intern", &hkeydd);
  size = sizeof(gInfo->intern);
  status = db_get_record(hDB, hkeydd, &gInfo->intern, &size, 0);
  // open hotlink
  status = db_open_record(hDB, hkeydd, &gInfo->intern, size, MODE_READ, NULL, NULL);

  // create pump DD names record
  status = db_create_record(hDB, hKey, "DD/Names", pump_names_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "pump_init", "pump_init: Error creating pump Names record in ODB, status=%d", status);
    cm_yield(0);
    return FE_ERR_ODB;
  }
  db_find_key(hDB, hKey, "DD/Names", &hkeydd);
  size = sizeof(gInfo->pump_names);
  db_get_record(hDB, hkeydd, &gInfo->pump_names, &size, 0);


  // check if pump DD SPS-DB buffer record already exists
  status = db_find_key(hDB, hKey, "DD/DB_Buffer", &hkeydd);
  if (status != DB_SUCCESS) { // key doesn't exist yet
    // create pump DD DB buffer
    strcpy(str, "DB_Buffer = BYTE[28] : \n");
    for (i=0; i<SPS_MAX_BYTES; i++)
      strcat(str, " \n");
    status = db_create_record(hDB, hKey, "DD/DB_Buffer", str);
    if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
      cm_msg(MERROR, "pump_init", "pump_init: Error creating pump DB_Buffer record in ODB, status=%d", status);
      cm_yield(0);
      return FE_ERR_ODB;
    }
  }

  db_find_key(hDB, hKey, "DD/DB_Buffer", &hkeydd);
  size = sizeof(gInfo->pump_buffer);
  status = db_get_record(hDB, hkeydd, &gInfo->pump_buffer, &size, 0);
  // open hotlink
  status = db_open_record(hDB, hkeydd, &gInfo->pump_buffer, size, MODE_WRITE, NULL, NULL);
  gInfo->hKey_DB_Buffer = hkeydd;

  // initialize driver
  gInfo->bd = bd;                 // keep the bus driver entry function
  gInfo->bd_info = 0;             // initialize the pointer to the BD info structure
  gInfo->time = ss_time();        // timer for error handling
  gInfo->errTime = ss_time();     // timer for error handling
  gInfo->read_error = 0;          // read error counter
  gInfo->tcpip_open_error = 0;    // open tcpip error counter
  gInfo->read_counts = 0;         // counter how often tcpip reading has benn attempt
  gInfo->last_success = 0;

  // open tcpip connection
  status = gInfo->bd(CMD_INIT, gInfo->hKey_in, &gInfo->bd_info);
  if (gInfo->intern.detailed_msg) {
    cm_msg(MDEBUG, "pump_init", "pump_init: open tcpip connection (status=%d)", status);
    cm_yield(0);
  }
  if (status != SUCCESS) {
    gInfo->tcpip_open_error++;
    if (gInfo->intern.detailed_msg) {
      cm_msg(MINFO, "pump_init", "pump_init: open bounced off");
      cm_yield(0);
    }
    return FE_ERR_DRIVER;
  }

  // initialize pump status message
  cm_msg(MINFO, "pump_init", "pump initialized ...");
  cm_yield(0);

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>Initializes the lemvac device driver for writing, i.e.\ generates all the necessary
 * structures in the ODB if necessary, initializes the bus driver and the lemvac.
 *
 * \return FE_SUCCESS
 *
 * \param hKey is the device driver handle given from the class driver
 * \param **pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param *bd is a pointer to the bus driver
 */
INT pump_out_init(HNDLE hKey, PUMP_INFO **pinfo, INT channels,  func_t *bd)
{
  *pinfo = gInfo; // since gInfo has been allocated in lemvac_in_init, it is enough to pass the pointer

  // initialize driver
  gInfo->hKey_out = hKey;    // keep the DD entry key

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>quits the bus driver and free's the memory allocated for the info structure
 * <pre>PUMP_INFO</pre>.
 *
 * \return FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 */
INT pump_exit(PUMP_INFO *info)
{
  // close all hotlinks
  db_close_record(info->hDB, info->hKey_DB_Buffer);

  // close connection
  info->bd(CMD_EXIT, info->bd_info);

  free(info);
  return FE_SUCCESS;
}

//----------------------------------------------------------------------------
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names into the ODB.
 *
 * \return FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT pump_in_get_label(PUMP_INFO *info, INT channel, char *name)
{
  strcpy(name, info->pump_names.in_name[channel]);
  return FE_SUCCESS;
}

//----------------------------------------------------------------------------
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names into the ODB.
 *
 * \return FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT pump_out_get_label(PUMP_INFO *info, INT channel, char *name)
{
  strcpy(name, info->pump_names.out_name);
  return FE_SUCCESS;
}

//-----------------------------------------------------------------------------
/*!
 * <p>reads the status of the lem SPS vacuum control unit
 *
 * \return FE_SUCCESS
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel to be read back
 * \param pvalue pointer to the ODB value
 */
INT pump_get(PUMP_INFO *info, INT channel, float *pvalue)
{
  if (info->intern.detailed_msg > 1) {
    cm_msg(MDEBUG, "pump_get", "in pump_get ...");
    cm_yield(0);
  }

  if (channel % PUMP_IN_VARS == 0) { // only read if channel is 0 since all data are read at once
    if (info->intern.detailed_msg) {
      cm_msg(MDEBUG, "pump_get", "in pump_get and will call pump_get_all(info)");
      cm_yield(0);
    }
    pump_get_all(info);
  }

  *pvalue = info->pump_data[channel];

  ss_sleep(10);
  return FE_SUCCESS;
}

//----------------------------------------------------------------------
/**
 * @brief pump_start_pump
 * @param info
 */
void pump_start_pump(PUMP_INFO *info)
{
  cm_msg(MDEBUG, "pump_start_pump", "pump_start_pump: will start pump ...");
  cm_yield(0);

  info->pump_buffer[24] = (char)1; // PS_On command
  pump_write_cmd(info);
}

//----------------------------------------------------------------------
/**
 * @brief pump_stop_pump
 * @param info
 */
void pump_stop_pump(PUMP_INFO *info)
{
  cm_msg(MDEBUG, "pump_stop_pump", "pump_stop_pump: will stop pump ...");
  cm_yield(0);

  info->pump_buffer[24] = (char)2; // PS_Off command
  pump_write_cmd(info);
}

//----------------------------------------------------------------------
/**
 * @brief pump_lock_gate_valve
 * @param info
 */
void pump_lock_gate_valve(PUMP_INFO *info)
{
  cm_msg(MDEBUG, "pump_lock_gate_valve", "pump_lock_gate_valve: will lock the gate valve ...");
  cm_yield(0);

  info->pump_buffer[24] = (char)4; // lock command
  pump_write_cmd(info);
}

//----------------------------------------------------------------------
/**
 * @brief pump_unlock_gate_valve
 * @param info
 */
void pump_unlock_gate_valve(PUMP_INFO *info)
{
  cm_msg(MDEBUG, "pump_unlock_gate_valve", "pump_unlock_gate_valve: will unlock the gate valve ...");
  cm_yield(0);

  info->pump_buffer[24] = (char)8; // unlock command
  pump_write_cmd(info);
}

//----------------------------------------------------------------------
/**
 * @brief pump_reset_errors
 * @param info
 */
void pump_reset_errors(PUMP_INFO *info)
{
  cm_msg(MDEBUG, "pump_reset_errors", "pump_reset_errors: will reset fault errors ...");
  cm_yield(0);

  info->pump_buffer[24] = (char)128; // reset fault errors command
  pump_write_cmd(info);
}

//----------------------------------------------------------------------
/**
 * @brief pump_set
 * @param info
 * @param channel
 * @param value
 * @return
 */
INT pump_set(PUMP_INFO *info, INT channel, float value)
{
  HNDLE hKey;
  int size;
  float fval;

  if (value == 0) // idle
    return FE_SUCCESS;

  if (value == 1)
    pump_start_pump(info);
  else if (value == 2)
    pump_stop_pump(info);
  else if (value == 3)
    pump_lock_gate_valve(info);
  else if (value == 4)
    pump_unlock_gate_valve(info);
  else if (value == 5)
    pump_reset_errors(info);

  // reset cmd tag, i.e. set it to idle
  db_find_key(info->hDB, 0, "/Equipment/Pump/Variables/Output", &hKey);
  size = sizeof(float);
  fval = 0.0;
  db_set_data_index(info->hDB, hKey, &fval, size, 0, TID_FLOAT);

  return FE_SUCCESS;
}

//---- device driver entry point -----------------------------------
INT pump_in(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   *pvalue;
  PUMP_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey = va_arg(argptr, HNDLE);
        PUMP_INFO **pinfo = va_arg(argptr, PUMP_INFO**);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t*);
        status = pump_in_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_EXIT:
      info = va_arg(argptr, PUMP_INFO*);
      status = pump_exit(info);
      break;

    case CMD_GET:
      info = va_arg(argptr, PUMP_INFO*);
      channel = va_arg(argptr, INT);
      pvalue  = va_arg(argptr, float*);
      status = pump_get(info, channel, pvalue);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, PUMP_INFO*);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = pump_in_get_label(info, channel, name);
      break;

    default:
      break;
    }

  va_end(argptr);

  return status;
}

INT pump_out(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   value;
  PUMP_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey = va_arg(argptr, HNDLE);
        PUMP_INFO **pinfo = va_arg(argptr, PUMP_INFO**);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t*);
        status = pump_out_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_SET:
      info = va_arg(argptr, PUMP_INFO*);
      channel = va_arg(argptr, INT);
      value   = (float) va_arg(argptr, double);
      status = pump_set(info, channel, value);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, PUMP_INFO*);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = pump_out_get_label(info, channel, name);
      break;

    default:
      break;
    }

  va_end(argptr);

  return status;
}
//---- end --------------------------------------------------------------
