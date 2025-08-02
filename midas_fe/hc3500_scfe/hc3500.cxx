/********************************************************************\

  Name:         hc3500.cxx
  Created by:   Zaher Salman, 22/02/2022

  Contents:     Device driver for the TecTra HC3500 PSU
                Only limited functionality is implemented using 
                modbus calls over rs232.

\********************************************************************/

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cstdarg>
#include <cerrno>
#include <cmath>

#include "midas.h"
#include "mfe.h"

#include "hc3500.h"

//----- globals -----------------------------------------------------

#define HC3500_IN_CHANNELS  7  //!< number of input channels
#define HC3500_OUT_CHANNELS 5  //!< number of output channels
#define NAME_LENGTH         32 //!< number of chars in name

#define HC3500_READ_ERROR   -1 //!< read error tag
#define HC3500_INIT_ERROR   -2 //!< initialize error tag
#define HC3500_OUT_OF_RANGE -3 //!< read back pressure out of range tag

#define HC3500_MAX_ERROR 3          //!< maximum number of error messages
#define HC3500_DELTA_TIME_ERROR 600 //!< reset error counter after this number of seconds

//! maximum number of readback failures before a reconnect will take place
#define HC3500_MAX_READBACK_FAILURE 5

//! time out in msecs for read (rs232)
#define HC3500_TIME_OUT 1000

typedef unsigned short int uint16;
typedef unsigned char uint8;

//! stores internal informations within the DD.
typedef struct {
  INT   enabled;        //!< flag showing if the device is enabled.
  INT   aibus_address;  //!< aibus_id of the HC3500
  INT   detailed_msg;   //!< flag indicating if detailed status/error messages are wanted
  INT   odb_offset;     //!< odb offset for the output variables. Needed by the forced update routine
  char name_in[HC3500_IN_CHANNELS][NAME_LENGTH];   //!< name of the input channels
  char name_out[HC3500_OUT_CHANNELS][NAME_LENGTH]; //!< name of the output channels
} HC3500_SETTINGS;

//! initializing string for HC3500_SETTINGS
const char *hc3500_settings_str = 
"ENABLED = INT : 1\n\
AIBUS address = INT : 1\n\
Detailed Messages = INT : 0\n\
ODB Offset = INT : 0\n\
Input = STRING[7] : \n\
[32] Temperature (C)\n\
[32] Temperature SP rb (C)\n\
[32] P rb\n\
[32] I rb\n\
[32] D rb\n\
[32] Ctrl Mode rb\n\
[32] Heater\n\
Output = STRING[5] : \n\
[32] Temperature SP (C)\n\
[32] P\n\
[32] I\n\
[32] D\n\
[32] Crtl Mode (0-4)\n\
";

//! This structure contains private variables for the device driver.
typedef struct {
  HC3500_SETTINGS hc3500_settings;       //!< ODB hot-link data for the DD
  HNDLE hkey;                            //!< holds the ODB key to the DD
  INT   num_channels_in;                 //!< number of in-channels
  INT   num_channels_out;                //!< number of out-channels
  INT (*bd)(INT cmd, ...);               //!< bus driver entry function
  void *bd_info;                         //!< private info of bus driver
  INT   aibus_address;                   //!< AIBUS address, usually 1
  INT   errorcount;                      //!< error counter
  INT   startup_error;                   //!< startup error tag
  DWORD lasterrtime;                     //!< timer for error handling
  INT   readback_failure;                //!< counts the number of readback failures
  int   bd_connected;                    //!< flag showing if bus driver is connected
  int   first_bd_error;                  //!< flag showing if the bus driver error message is already given
  DWORD last_reconnect;                  //!< timer for bus driver reconnect error handling
  float temprb;                          //!< the current temperature readback
  float tempsp;                          //!< the temperature setpoint
  int   tempatsp;                        //!< tag showing that the temperature reached the setpoint           
} HC3500_INFO;

HC3500_INFO *hc3500_info; //!< global info structure, in/out-init routines need the same structure

typedef INT(func_t) (INT cmd, ...);


/*----------------------------------------------------------------------------------*/
/*!
 * <p>AIBUS Read 
 * <p><b>Return:</b>
 *   - status from BD_GETS
 * 
 * \param cmd_code is the AIBUS parameter code
 * \param info     is the global info structure
 * \param ivalue   is the decimal integer value received
   */
INT aibus_read(INT cmd_code, HC3500_INFO *info, INT *ivalue)
{
  INT     status,ecc,cmd_orig;
  INT     aibus_address;
  uint8   cmd[8], rcv[10];

  // Take AIBUS address from DD
  aibus_address = info->hc3500_settings.aibus_address;
  // Keep original cmd_code (in case it is negative)
  cmd_orig = cmd_code;
  if (cmd_code < 0) cmd_code =0;

  // ecc read = (parameter code * 100H + 52H + address) mod 10000H
  ecc = (cmd_code * 256 + 82 + aibus_address) % 65536;
  memset(cmd, 0, sizeof(cmd));
  cmd[0] = 128 + aibus_address; // 80H + address
  cmd[1] = 128 + aibus_address; // 80H + address
  cmd[2] = 82;  // 52H/43H=82/67 for read/write 
  cmd[3] = cmd_code;  // parameter code (see table)
  cmd[4] = 0;  // null
  cmd[5] = 0;  // null
  cmd[6] = (ecc & 0x00FF);     // ECC LSB 
  cmd[7] = (ecc & 0xFF00)>>8;  // ECC MSB 

  // Send 8 bytes
  status = info->bd(CMD_WRITE, info->bd_info, (char *)cmd, 8);
  // printf("Status write= %d\n",status);
  // printf("Command: %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",cmd[0],cmd[1],cmd[2],cmd[3], cmd[4],cmd[5],cmd[6],cmd[7],cmd[8]);

  memset(rcv, 0, sizeof(rcv));
  // Recieve 10 bytes
  status = info->bd(CMD_READ, info->bd_info, (char*)rcv, 10, HC3500_TIME_OUT);
  // printf("Status read= %d\n",status);
  // printf("Reply: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",rcv[0],rcv[1],rcv[2],rcv[3], rcv[4],rcv[5],rcv[6],rcv[7],rcv[8],rcv[9]);

  // ECC for rcv
  // (PV (2 bytes) + SV (2 bytes) + MV (1 byte) +
  // Alarm_status (1 byte) + R/W value (2 byte) + address (1 byte) ) mod 10000H 

  
  if (info->hc3500_settings.detailed_msg == 2) {// debug only
    cm_msg(MINFO, "hc3500_get", "hc3500_get: cmd_code: %d\n",cmd_code);
    cm_msg(MINFO, "hc3500_get", "hc3500_get: Command: %02x %02x %02x %02x %02x %02x %02x %02x\n",cmd[0],cmd[1],cmd[2],cmd[3], cmd[4],cmd[5],cmd[6],cmd[7]);
    cm_msg(MINFO, "hc3500_get", "hc3500_get: Reply: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",rcv[0],rcv[1],rcv[2],rcv[3], rcv[4],rcv[5],rcv[6],rcv[7],rcv[8],rcv[9]);
  }

  // Convert from hex to int
  // rcv structure : PV (2 byte)| SV (2 byte) | Alarm (1 byte) | Read Par (2 byte) | ECC (2 byte)
  // Read parameter is rcv[6] (LSB) and rcv[7] (MSB)
  // To pack into a 2 byte data type, shift each element the 
  // appropriate number of bits and perform bitwise OR on all shifted elements.
  if (status) {
    if (cmd_orig == -1) {
      // Special case, return PV
      *ivalue = (rcv[0] | rcv[1] << 8);
    } else if (cmd_orig == -2) {
      // Special case, return SV
      *ivalue = (rcv[2] | rcv[3] << 8);
    } else if (cmd_orig == -3) {
      // Special case, return MV
      *ivalue = rcv[4];
    } else {
      *ivalue = (rcv[6] | rcv[7] << 8);
    }
  } else {
    *ivalue = status;
  }
  return status;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>AIBUS Write 
 * <p><b>Return:</b>
 *   - status from BD_GETS
 * 
 * \param cmd_code is the AIBUS parameter code
 * \param info     is the global info structure 
 * \param ivalue   is the decimal value to write
   */
INT aibus_write(INT cmd_code, HC3500_INFO *info, INT ivalue)
{
  INT     status,ecc;
  INT     aibus_address;
  uint8   cmd[8], rcv[10];

  // Take AIBUS address from DD
  aibus_address = info->hc3500_settings.aibus_address;

  // eec write = (parameter code * 100H + 43H + value + address) mod 10000H
  ecc = (cmd_code * 256 + 67 + ivalue + aibus_address) % 65536;
  memset(cmd, 0, sizeof(cmd));
  cmd[0] = 128 + aibus_address; // 80H + address
  cmd[1] = 128 + aibus_address; // 80H + address
  cmd[2] = 67;                  // 52H/43H=82/67 for read/write 
  cmd[3] = cmd_code;            // parameter code (see table)
  cmd[4] = (ivalue & 0x00FF);   // LSB of write ivalue
  cmd[5] = (ivalue & 0xFF00)>>8;// MSB of write ivalue
  cmd[6] = (ecc & 0x00FF);      // ECC LSB (parameter code * 100H + 52H + address)mod 10000H
  cmd[7] = (ecc & 0xFF00)>>8;   // ECC MSB 

  // Send 8 bytes
  status = info->bd(CMD_WRITE, info->bd_info, (char *)cmd, 8);
  // printf("Status write= %d\n",status);
  // printf("Command: %02x %02x %02x %02x %02x %02x %02x %02x\n",cmd[0],cmd[1],cmd[2],cmd[3], cmd[4],cmd[5],cmd[6],cmd[7]);

  // Recieve 10 bytes
  status = info->bd(CMD_READ, info->bd_info, (char*)rcv, 10, HC3500_TIME_OUT);
  // printf("Status read= %d\n",status);
  // printf("Reply: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",rcv[0],rcv[1],rcv[2],rcv[3], rcv[4],rcv[5],rcv[6],rcv[7],rcv[8],rcv[9]);

  if (info->hc3500_settings.detailed_msg == 2) {// debug only
    cm_msg(MINFO, "hc3500_set", "hc3500_set: cmd_code: %d, value: %d\n",cmd_code,ivalue);
    cm_msg(MINFO, "hc3500_set", "hc3500_set: Command: %02x %02x %02x %02x %02x %02x %02x %02x\n",cmd[0],cmd[1],cmd[2],cmd[3], cmd[4],cmd[5],cmd[6],cmd[7]);
    cm_msg(MINFO, "hc3500_set", "hc3500_set: Reply: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",rcv[0],rcv[1],rcv[2],rcv[3], rcv[4],rcv[5],rcv[6],rcv[7],rcv[8],rcv[9]);
  }

  return status;
}


//------------------------------------------------------------------------------------
/*!
 * <p>Initializes the HC3500 device driver, i.e. generates all the necessary
 * structures in the ODB if necessary, initializes the bus driver and the HC3500
 * controller.</p>
 *
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - FE_ERR_ODB otherwise
 *
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT hc3500_in_init(HNDLE hKey, HC3500_INFO **pinfo, INT channels, func_t *bd)
{
  INT   status;
  INT   ivalue,address,model;
  HNDLE hDB, hkeydd;
  float fval;

  cm_get_experiment_database(&hDB, NULL);

  // allocate info structure
  HC3500_INFO *info = (HC3500_INFO*)calloc(1, sizeof(HC3500_INFO));
  hc3500_info = info;
  *pinfo = info;

  // create HC3500 settings record
  status = db_create_record(hDB, hKey, "DD", hc3500_settings_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "hc3500_in_init", "hc3500_in_init: Error creating hc3500 DD record in ODB, status=%d", status);
    cm_yield(0);
    return FE_ERR_ODB;
  }
    
  // hotlink DD settings record
  db_find_key(hDB, hKey, "DD", &hkeydd);
  db_open_record(hDB, hkeydd, &info->hc3500_settings, sizeof(info->hc3500_settings), MODE_READ, NULL, NULL);

  // initialize driver
  info->hkey             = hKey;
  info->num_channels_in  = channels;
  info->bd               = bd;
  info->errorcount       = 0;
  info->lasterrtime      = ss_time();
  info->startup_error    = 0;
  info->readback_failure = 0;
  info->bd_connected     = 0;
  info->last_reconnect   = ss_time();
  info->first_bd_error   = 1;
  info->temprb = -1.0;
  info->tempatsp = 1;

  // Do I need enable option for my applications?
  if (!info->hc3500_settings.enabled) {
    cm_msg(MINFO, "hc3500_in_init", "HC3500 disabled from within the DD ...");
    cm_yield(0);
    return FE_SUCCESS;
  }

  if (!bd)
    return FE_ERR_ODB;

  // initialize bus driver
  status = info->bd(CMD_INIT, hKey, &info->bd_info);
  
  if (status != FE_SUCCESS) {
    cm_msg(MERROR,"hc3500_in_init", "Couldn't init bus driver of 'HC3500'");
    cm_yield(0);
    info->startup_error = 1;
    return FE_SUCCESS;
  }
  info->bd_connected = 1;


  //status = aibus_read(0,info,&ivalue);
  //status = aibus_read(7,info,&ivalue); //P
  //status = aibus_read(8,info,&ivalue); //I
  //status = aibus_read(9,info,&ivalue); //D
  status = aibus_read(22,info,&address); //Address
  status = aibus_read(21,info,&model); //Identity
  
  // initialize HC3500
  cm_msg(MINFO, "hc3500_in_init", "HC3500 initialized");
  cm_msg(MINFO, "hc3500_in_init", "found UDIAN AI-%d at address %d",model,address);
  if (info->hc3500_settings.aibus_address != address) 
    cm_msg(MINFO, "hc3500_in_init", "*WARNING* AIBUSS address mismatch! Change value in ODB");
  cm_yield(0);

  return FE_SUCCESS;
}

//------------------------------------------------------------------------------------
/*!
 * <p>Initializes the HC3500 device driver, i.e. generates all the necessary
 * structures in the ODB if necessary, initializes the bus driver and the HC3500
 * controller.</p>
 *
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - FE_ERR_ODB otherwise
 *
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT hc3500_out_init(HNDLE hKey, HC3500_INFO **pinfo, INT channels, func_t *bd)
{
  *pinfo = hc3500_info; // keep global pointer

  return FE_SUCCESS;
}

//------------------------------------------------------------------------------------
/*!
 * <p>terminates the bus driver and free's the memory allocated for the
 * info structure HC3500_INFO.</p>
 *
 * <p><b>Return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure
 */
INT hc3500_exit(HC3500_INFO *info)
{
  if (info->hc3500_settings.enabled) {
    // call EXIT function of bus driver, usually closes device
    info->bd(CMD_EXIT, info->bd_info);
  }

  free(info);

  return FE_SUCCESS;
}


//------------------------------------------------------------------------------------
/*!
 * <p>sets the values of the HC3500</p>
 *
 * <p><b>Return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel to be set
 * \param value to be sent to the HC3500
 */
INT hc3500_set(HC3500_INFO *info, INT channel, float value)
{
  int    cmd_code;
  int    ivalue,multi;
  int    status, i;

  if (info->startup_error) {
    ss_sleep(10); // to keep CPU load low when Run active
    return FE_SUCCESS;
  }

  //if (!info->hc3500_settings.enabled) {
  //  ss_sleep(10); // to keep CPU load low
  //  return FE_SUCCESS;
  //}

  if (!info->bd_connected) {
    if (info->first_bd_error) {
      info->first_bd_error = 0;
      cm_msg(MINFO, "hc3500_set",
             "hc3500_set: set values not possible at the moment, since the bus driver is not available!");
    }
    ss_sleep(10);
    return FE_SUCCESS;
  }

  // Default multiplier is 10
  multi = 10;
  switch (channel) {
  case 0:
    cmd_code = 0;
    break;
  case 1: // P
    cmd_code = 7;
    break;
  case 2: // I
    cmd_code = 8;
    break;
  case 3: // D
    cmd_code = 9;
    break;
  case 4: // Crtl Mode
    cmd_code = 6;
    // value must be 0-4
    if (ivalue > 4 || ivalue < 0) ivalue = 0;
    multi=1;
    break;
  default:
    return FE_SUCCESS;
  }
    
  // multiply by 10 then make int before sending
  value = multi * value;
  ivalue = (int) value;
  // Send a write request
  status = aibus_write(cmd_code,info,ivalue);
    
  // if (status != 10) {
  //   cm_msg(MINFO, "hc3500_set", "hc3500_set: **WARNING**: could only write %d bytes (%d expected)", status, 10);
  //   return FE_SUCCESS;
  // }

  // if (!found && info->hc3500_settings.detailed_msg) {
  //   cm_msg(MINFO, "hc3500_set", "hc3500_set: **WARNING**: readback timeout 3 occured; couldn't get header");
  //   return FE_SUCCESS;
  // }

  return FE_SUCCESS;
}


//------------------------------------------------------------------------------------
/*!
 * <p>reads the values of the HC3500.</p>
 *
 * <p><b>Return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel to be set
 * \param pvalue pointer to the result
 */
INT hc3500_get(HC3500_INFO *info, INT channel, float *pvalue)
{
  DWORD nowtime, difftime;
  INT   status, cmd_code, multi, ivalue;

  if (!info->hc3500_settings.enabled) {
    ss_sleep(10); // to keep CPU load low
    return FE_SUCCESS;
  }
  // error handling
  nowtime  = ss_time();
  difftime = nowtime - info->lasterrtime;

  if ( difftime > HC3500_DELTA_TIME_ERROR ) {
    info->errorcount  = 0;
    info->lasterrtime = nowtime;
  }

  if ( info->startup_error == 1 ) { // error during CMD_INIT, return -2
    *pvalue = (float) HC3500_INIT_ERROR;
    ss_sleep(10); // to keep CPU load low when Run active
    return FE_SUCCESS;
  }

  // multiplier is usually 10
  multi = 10;
  // command according to the channel
  // cmd_code is the AIBUS code
  switch (channel) {
  case 0: // Temperature (C)
    cmd_code = -1;
    break;
  case 1: // Temperature SP rb
    cmd_code = -2;
    break;
  case 2: // P rb
    cmd_code = 7;
    break;
  case 3: // I rb
    cmd_code = 8;
    break;
  case 4: // D rb
    cmd_code = 9;
    break;
  case 5: // Ctrl Mode rb
    cmd_code = 6;
    multi = 1;
    break;
  case 6: // Heater
    cmd_code = -3;
    multi = 1;
    break;
  default:
    *pvalue = (float) HC3500_READ_ERROR;
    status = HC3500_READ_ERROR;
    return FE_SUCCESS;
  }

  status = aibus_read(cmd_code,info,&ivalue);
  *pvalue = (float) ivalue / (float) multi;
  
  return FE_SUCCESS;
}

//------------------------------------------------------------------------------------
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names of the channels into the ODB.</p>
 *
 * <p><b>Return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT hc3500_in_get_label(HC3500_INFO *info, INT channel, char *name)
{
  strcpy(name, info->hc3500_settings.name_in[channel]);
  return FE_SUCCESS;
}

//------------------------------------------------------------------------------------
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names of the channels into the ODB.</p>
 *
 * <p><b>Return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT hc3500_out_get_label(HC3500_INFO *info, INT channel, char *name)
{
  strcpy(name, info->hc3500_settings.name_out[channel]);
  return FE_SUCCESS;
}

/*---- device driver entry point -----------------------------------*/
INT hc3500_in(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   *pvalue;
  HC3500_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey = va_arg(argptr, HNDLE);
        HC3500_INFO **pinfo = va_arg(argptr, HC3500_INFO**);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t*);
        status  = hc3500_in_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_EXIT:
      info   = va_arg(argptr, HC3500_INFO*);
      status = hc3500_exit(info);
      break;

    case CMD_GET:
      info    = va_arg(argptr, HC3500_INFO*);
      channel = va_arg(argptr, INT);
      pvalue  = va_arg(argptr, float*);
      status  = hc3500_get(info, channel, pvalue);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, HC3500_INFO*);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = hc3500_in_get_label(info, channel, name);
      break;

    default:
      break;
  } // switch

  va_end(argptr);
  return status;
}

INT hc3500_out(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   value;
  HC3500_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey = va_arg(argptr, HNDLE);
        HC3500_INFO **pinfo = va_arg(argptr, HC3500_INFO**);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t*);
        status  = hc3500_out_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_SET:
      info    = va_arg(argptr, HC3500_INFO*);
      channel = va_arg(argptr, INT);
      value   = (float) va_arg(argptr, double);
      status  = hc3500_set(info, channel, value);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, HC3500_INFO*);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = hc3500_out_get_label(info, channel, name);
      break;

    default:
      break;
  } // switch

  va_end(argptr);

  return status;
}

// end --------------------------------------------------------------------

