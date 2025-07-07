/********************************************************************\

  Name:         bronkhorst.cxx
  Created by:   Andreas Suter   2003/09/12

  Contents: device driver for Bronkhorst He gas flowcontroller,
            defined as a multi class device.

            RS232: 38400 baud, 8 data bits, 1 stop bit, no parity bit,
                   protocol: no flow control, termination \r\n (CR\LF)

  device driver: Naming of the input and output channels in "../Settings/Names Input" and
                 "../Settings/Names Ouput". The channel names are defined in the device driver
                 settings key ("../Settings/Device/<Name of Device>/DD").

\********************************************************************/

#include <cstdio>
#include <cstdlib>
#include <cstdarg>
#include <cstring>

#include "midas.h"
#include "mfe.h"
#include "msystem.h"

#include "bronkhorst.h"

#include "ets_logout.h"

/*---- globals -----------------------------------------------------*/

//! timeout in (ms) for the communication between pc and bronkhorst
#define BH_TIME_OUT 2000

//! timeout in (sec) between logout terminal server an reconnection trial
#define BH_RECONNECTION_TIMEOUT 5
//! maximum number of readback failures before a reconnect will take place
#define BH_MAX_READBACK_FAILURE 5
//! maximum number of reconnections before bailing off
#define BH_MAX_RECONNECTION_FAILURE 5

/* --------- to handle error messages ------------------------------*/
#define BH_MAX_ERROR        10     //!< maximum number of error messages
#define BH_DELTA_TIME_ERROR 3600   //!< reset error counter after BH_DELTA_TIME_ERROR seconds

#define BH_WAIT 500                //!< time (ms) to BH_WAIT between commands

#define BH_CMD_ERROR  -3           //!< unvalid command error
#define BH_INIT_ERROR -2           //!< initialize error tag
#define BH_READ_ERROR -1           //!< read error tag

//! sleep time (us) between the telnet commands of the ets_logout
#define BH_ETS_LOGOUT_SLEEP 10000

/* --------- Bronkhorst stuff --------------------------------------*/

/*!
 * bronkhorst <-> midas tags.
 * def's starting with BH_ aren't documented here. For a detailed
 * description of them see the bronkhorst manual 'RS232 INTERFACE
 * with FLOW-BUS protocol' Doc. no.: 9.17.027 D
 */
#define BH_SUCCESS      1

#ifndef DOXYGEN_SHOULD_SKIP_THIS

#define BH_CMD_UNKNOWN  2
#define BH_COMM_ERR     3
#define BH_STATUS_ERR   4
#define BH_DECODE_ERR   5

// bronkhorst commands
#define BH_NO_CMD      -1
#define BH_IDENTSTRNG   1
#define BH_MEASURE      8
#define BH_SETPOINT     9
#define BH_SETSLOPE    10
#define BH_CNTRLMODE   12
#define BH_POLYCNSTA   13
#define BH_POLYCNSTB   14
#define BH_POLYCNSTC   15
#define BH_POLYCNSTD   16
#define BH_POLYCNSTE   17
#define BH_POLYCNSTF   18
#define BH_POLYCNSTG   19
#define BH_POLYCNSTH   20
#define BH_CAPACITY    21
#define BH_SENSORTYPE  22
#define BH_CAPUNIT     23
#define BH_FLUIDNR     24
#define BH_FLUIDNAME   25
#define BH_ALARMINFO   28
#define BH_ALARMMSGTA  33
#define BH_ALARMMSGNR  34
#define BH_VALVEOUT    55
#define BH_IOSTATUS    86
#define BH_DEVICETYPE  90
#define BH_MODELNUM    91
#define BH_SERIALNUM   92
#define BH_VERSION    105
#define BH_TEMPERATUR 142
#define BH_FLUIDTEMP  181
// etc, rest still missing

// bronkhorst flowbus commands, addresses
#define BH_STATUSMSG 0
#define BH_SETPARAM  1
#define BH_GETPARAM  4

#define BH_CHAR     0x00
#define BH_INTEGER  0x20
#define BH_LONG     0x40
#define BH_FLOAT    0x40
#define BH_STRING   0x60

// bronkhorst status and error messages
#define BH_NOERROR          0x00
#define BH_PROCESS_CLAIMED  0x01
#define BH_CMD_ERR          0x02
#define BH_PROC_ERR         0x03
// etc, rest still missing

// bronkhorst node
#define BH_NODE 0x80

// bronkhorst chained
#define BH_UNCHAINED 0x00
#define BH_CHAINED   0x80

// bronkhorst max needle valve value = 2^24 - 1
#define BH_MAX_NEEDLE_VALVE 16777215

#define BH_IN_CHANNELS  2  //!< number of input channels
#define BH_OUT_CHANNELS 2  //!< number of output channels

#endif // DOXYGEN_SHOULD_SKIP_THIS

/*!
 * <p> generally it stores internal informations within the DD. In this
 * case this are the names for the ODB describing the <b>in-channels</b>.
 */
typedef struct {
  INT   detailed_msg; //!< flag indicating if detailed status/error messages are wanted
  INT   ets_in_use;   //!< flag indicating if the rs232 terminal server is in use
  char  name[BH_IN_CHANNELS][32]; //!< input channel names
} BH_IN_SETTINGS;

/*!
 * <p> generally it stores internal informations within the DD. In this
 * case this are the names for the ODB describing the <b>out-channels</b>.
 */
typedef struct {
 char  name[BH_OUT_CHANNELS][32]; //!< output channel names
} BH_OUT_SETTINGS;

//! initializing string for the BH_IN_SETTINGS structure.
const char *bh_in_settings_str = 
"Detailed Messages = INT : 0\n\
ETS_IN_USE = INT : 1\n\
Input = STRING[2]:\n\
[32] BH Flow measured\n\
[32] BH ValvePos Get\n\
";

//! initializing string for the BH_OUT_SETTINGS structure.
const char *bh_out_settings_str =
"Output = STRING[2] :\n\
[32] BH Flow setpoint\n\
[32] BH ValvePos Set\n\
";

/*!
 * <p> This structure contains private variables for the device driver.
 */
typedef struct {
  BH_IN_SETTINGS  bh_in_settings;  //!< internal DD settings for the <b>in-channels</b>
  BH_OUT_SETTINGS bh_out_settings; //!< internal DD settings for the <b>out-channels</b>
  HNDLE hkey;                      //!< ODB key for bus driver info
  INT   num_channels_in;           //!< number of <b>in-channels</b>
  INT   num_channels_out;          //!< number of <b>out-channels</b>
  INT (*bd)(INT cmd, ...);         //!< bus driver entry function
  void *bd_info;                   //!< private info of bus driver
  int   bd_connected;              //!< flag showing if bus driver is connected
  int   first_bd_error;            //!< flag showing if the bus driver error message is already given
  INT   errorcount;                //!< error coutner
  INT   startup_error;             //!< startup error tag; if set, the get and bh_set and bh_get routines wont do anything
  DWORD lasterrtime;               //!< timer for error handling
  INT   readback_failure;          //!< counts the number of readback failures
  float last_valid_value[2];       //!< stores the last valid value
  DWORD last_reconnect;            //!< timer for bus driver reconnect error handling
  int   reconnection_failures;     //!< how often reconnection failed
  INT   startup_tag;               //!< tag indicating that the DD is starting (see bh_in_init and BH_out_init)
} BH_INFO;

BH_INFO *bh_info;  //!< global info structure since port (rs232 or terminal server) can only be initialized once.

typedef INT(func_t) (INT cmd, ...);

/*---- support routines ------------------------------------------------------------*/

/*----------------------------------------------------------------------------------*/
/*!
 * <p>decodes for any error messages coming from the bronkhorst flow meter.</p>
 * <p><b>return error tag:</b>
 *    - BH_SUCCESS    = no error
 *    - BH_STATUS_ERR = bronkhost status error
 * </p>
 * \param str  return string from the flowmeter
 * \param error_msg error message return string (if error), otherwise empty string.
 */
int bh_success(char *str, char *error_msg)
{
  int  error = 0;
  int  error_byte = 0;

  strcpy(error_msg, ""); // initialize error message

  if (strstr(str, ":01")) { // error message
    sscanf(str, ":01%02d", &error);
    switch (error) {
      case 1:
        strcpy(error_msg, "BH ERROR: no ':' at the start of the message.");
        break;
      case 2:
        strcpy(error_msg, "BH ERROR: error in 1st byte.");
        break;
      case 3:
        strcpy(error_msg, "BH ERROR: error in 2nd byte or number of bytes is 0 or message to long.");
        break;
      case 4:
        strcpy(error_msg, "BH ERROR: error in recieved message (reciever overrun, framing error, etc.).");
        break;
      case 5:
        strcpy(error_msg, "BH ERROR: flowbus communication BH ERROR: timeout or message rejected by reciver.");
        break;
      case 8:
        strcpy(error_msg, "BH ERROR: timeout during sending.");
        break;
      case 9:
        strcpy(error_msg, "BH ERROR: no answer recieved within timeout.");
        break;
      default:
        strcpy(error_msg, "BH ERROR: unknown error, obscure.");
        break;
    } // end switch
  } // end if

  if (strstr(str, ":04")) { // status error messages
    sscanf(str, ":048000%02d%02d", &error, &error_byte);
    switch (error) {
      case 0x00:
        break;
      case 0x01:
        sprintf(error_msg, "BH ERROR: process claimed. claimed process = %x\n", error_byte);
        break;
      case 0x02:
        sprintf(error_msg, "BH ERROR: command error. error_byte = %d\n", error_byte);
        break;
      case 0x03:
        sprintf(error_msg, "BH ERROR: process error. error_byte = %d\n", error_byte);
        break;
      case 0x04:
        sprintf(error_msg, "BH ERROR: parameter error. error_byte = %d\n", error_byte);
        break;
      case 0x05:
        sprintf(error_msg, "BH ERROR: parameter type error. error_byte = %d\n", error_byte);
        break;
      case 0x06:
        sprintf(error_msg, "BH ERROR: parameter value error. error_byte = %d\n", error_byte);
        break;
      case 0x07:
        sprintf(error_msg, "BH ERROR: network not active. error_byte = %d\n", error_byte);
        break;
      case 0x08:
        sprintf(error_msg, "BH ERROR: timeout start character. error_byte = %d\n", error_byte);
        break;
      case 0x09:
        sprintf(error_msg, "BH ERROR: timeout serial line. error_byte = %d\n", error_byte);
        break;
      case 0x0A:
        sprintf(error_msg, "BH ERROR: hardware memory error. error_byte = %d\n", error_byte);
        break;
      case 0x0B:
        sprintf(error_msg, "BH ERROR: node number error. error_byte = %d\n", error_byte);
        break;
      case 0x0C:
        sprintf(error_msg, "BH ERROR: general communication error. error_byte = %d\n", error_byte);
        break;
      case 0x0D:
        sprintf(error_msg, "BH ERROR: read only parameter. error_byte = %d\n", error_byte);
        break;
      case 0x0E:
        sprintf(error_msg, "BH ERROR: error pc-communication. error_byte = %d\n", error_byte);
        break;
      case 0x0F:
        sprintf(error_msg, "BH ERROR: no rs232 connection. error_byte = %d\n", error_byte);
        break;
      case 0x10:
        sprintf(error_msg, "BH ERROR: pc out of memory. error_byte = %d\n", error_byte);
        break;
      case 0x11:
        sprintf(error_msg, "BH ERROR: write only parameter. error_byte = %d\n", error_byte);
        break;
      case 0x12:
        sprintf(error_msg, "BH ERROR: system configuration unknown. error_byte = %d\n", error_byte);
        break;
      case 0x13:
        sprintf(error_msg, "BH ERROR: no free node address. error_byte = %d\n", error_byte);
        break;
      case 0x14:
        sprintf(error_msg, "BH ERROR: wrong interface type. error_byte = %d\n", error_byte);
        break;
      case 0x15:
        sprintf(error_msg, "BH ERROR: error serial port connection. error_byte = %d\n", error_byte);
        break;
      case 0x16:
        sprintf(error_msg, "BH ERROR: error opening communication. error_byte = %d\n", error_byte);
        break;
      case 0x17:
        sprintf(error_msg, "BH ERROR: communication error. error_byte = %d\n", error_byte);
        break;
      case 0x18:
        sprintf(error_msg, "BH ERROR: error interface bus master. error_byte = %d\n", error_byte);
        break;
      case 0x19:
        sprintf(error_msg, "BH ERROR: timeout answer. error_byte = %d\n", error_byte);
        break;
      case 0x1A:
        sprintf(error_msg, "BH ERROR: no start character. error_byte = %d\n", error_byte);
        break;
      case 0x1B:
        sprintf(error_msg, "BH ERROR: error first digit. error_byte = %d\n", error_byte);
        break;
      case 0x1C:
        sprintf(error_msg, "BH ERROR: buffer overflow in host. error_byte = %d\n", error_byte);
        break;
      case 0x1D:
        sprintf(error_msg, "BH ERROR: buffer overflow. error_byte = %d\n", error_byte);
        break;
      case 0x1E:
        sprintf(error_msg, "BH ERROR: no answer found. error_byte = %d\n", error_byte);
        break;
      case 0x1F:
        sprintf(error_msg, "BH ERROR: error closing communication. error_byte = %d\n", error_byte);
        break;
      case 0x20:
        sprintf(error_msg, "BH ERROR: synchronization error. error_byte = %d\n", error_byte);
        break;
      case 0x21:
        sprintf(error_msg, "BH ERROR: send error. error_byte = %d\n", error_byte);
        break;
      case 0x22:
        sprintf(error_msg, "BH ERROR: protocol error. error_byte = %d\n", error_byte);
        break;
      case 0x23:
        sprintf(error_msg, "BH ERROR: buffer overflow in module. error_byte = %d\n", error_byte);
        break;
      default:
        sprintf(error_msg, "BH ERROR: unknown error, obscure. error_byte = %d\n", error_byte);
        break;
    } // end switch
  } // end if

  if (strlen(error_msg)>0)
    return BH_STATUS_ERR;
  else
    return BH_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * converts a hex string into a readable ascii string.
 *
 * \param str    hex input string
 * \param len    length of 'str'
 * \param result converted ascii string
 */
void hex2ascii(char *str, int len, char *result)
{
  int  i, j;
  char hexchar[3];

  strcpy(result, "");
  for (i=0; i<len; i++) {
    strncpy(hexchar, str+2*i, 2);
    hexchar[2]='\0';
    sscanf(hexchar, "%x", &j);
    strcat(result, (const char *)&j);
  }
}


/*----------------------------------------------------------------------------------*/
/*!
 * <p> if the return message of the flowcontroller is a number, this routine
 * is used to decode the return string into a number.</p>
 * <p><b>Return:</b>
 *   - BH_SUCCESS if everthing went fine
 *   - BH_DECODE_ERR otherwise
 * </p>
 * \param rply       return string from flowcontroller
 * \param decode_tag BH_CHAR, BH_INTEGER, BH_FLOAT
 * \param err_msg    error message if something went wrong
 * \param result     decoded value
 */
int bh_decode_number(char *rply, int decode_tag, char *err_msg, float *result)
{
  int  totlen, len;
  int  ivalue;
  char str[128];
  union {
    int   ival;
    float fval;
  } hexfloat;

  totlen = strlen(rply);
  if (totlen == 0) { // no input string
    strcpy(err_msg, "BH ERROR: no string to decode ...");
    return BH_DECODE_ERR;
  }

  switch (decode_tag) {
    case BH_CHAR:
    case BH_INTEGER:
      sscanf(rply, ":%02x%s", &len, str);
      if (totlen != 2*len+5) {
        strcpy(err_msg, "BH ERROR: wrong string length ...");
        return BH_DECODE_ERR;
      }
      sscanf(rply, ":%10x%x", &len, &ivalue);
      *result = (float)ivalue;
      break;
    case BH_FLOAT:
      sscanf(rply, ":%02x%s", &len, str);
      if (totlen != 2*len+5) {
        strcpy(err_msg, "BH ERROR: wrong string length ...");
        return BH_DECODE_ERR;
      }
      sscanf(rply, ":%10x%x", &len, &(hexfloat.ival));
      *result = hexfloat.fval;
      break;
    default:
      break;
  }
  return BH_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>if the return message of the flowcontroller is a string, this routine
 * is used to decode the return string.</p>
 * <p><b>Return:</b>
 *   - BH_SUCCESS if everthing went fine
 *   - BH_DECODE_ERR otherwise
 * </p>
 * \param rply    return string from flowcontroller
 * \param err_msg error message if something went wrong
 * \param result  decoded message
 */
int bh_decode_string(char *rply, char *err_msg, char *result)
{
  int  totlen, len;
  int  ivalue;
  char str[128];

  totlen = strlen(rply);
  if (totlen == 0) { // no string to decode
    strcpy(err_msg, "BH ERROR: no string to decode ...");
    return BH_DECODE_ERR;
  }

  sscanf(rply, ":%02x%s", &len, str);
  if (totlen != 2*len+5) {
    strcpy(err_msg, "BH ERROR: wrong string length ...");
    return BH_DECODE_ERR;
  }
  sscanf(rply, ":%10x%02x%s", &ivalue, &len, str);
  hex2ascii(str, len, result);

  return BH_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>routine which is used to read back values from the flowcontroller.</p>
 * <p><b>Return:</b>
 *   - BH_SUCCESS if everthing went fine
 *   - BH_COMM_ERR otherwise
 * \param info   info structure used by BD_PUTS and BD_GETS macros
 * \param cmd    command tag telling which value to read back from the flowcontroller.
 * \param result return string from the flowcontroller.
 */
INT bh_get_send_rcv(BH_INFO *info, INT cmd, char *result)
{
  char str[128], err_msg[128];
  int  status;
  int  cmd_length, process, parameter, decode_tag;

  // filter command and generate command string for device
  switch (cmd) {
    case BH_IDENTSTRNG:
      cmd_length = 7;
      process    = 0;
      parameter  = 0;
      decode_tag = BH_STRING;
      sprintf(str, ":%02X%02X%02X%02X%02X%02X%02X%02X\r\n",
                   cmd_length, BH_NODE, BH_GETPARAM, BH_UNCHAINED|process,
                   BH_UNCHAINED|BH_STRING, process, BH_STRING|parameter, 12);
      break;
    case BH_MEASURE:
      cmd_length = 6;
      process    = 1;
      parameter  = 0;
      decode_tag = BH_INTEGER;
      sprintf(str, ":%02X%02X%02X%02X%02X%02X%02X\r\n",
                   cmd_length, BH_NODE, BH_GETPARAM, BH_UNCHAINED|process,
                   BH_UNCHAINED|BH_INTEGER, process, BH_INTEGER|parameter);
      break;
    case BH_SETPOINT:
      cmd_length = 6;
      process    = 1;
      parameter  = 1;
      decode_tag = BH_INTEGER;
      sprintf(str, ":%02X%02X%02X%02X%02X%02X%02X\r\n",
                   cmd_length, BH_NODE, BH_GETPARAM, BH_UNCHAINED|process,
                   BH_UNCHAINED|BH_LONG, process, BH_LONG|parameter);
      break;
    case BH_VALVEOUT:
      cmd_length = 6;
      process    = 114;
      parameter  = 1;
      decode_tag = BH_INTEGER;
      sprintf(str, ":%02X%02X%02X%02X%02X%02X%02X\r\n",
                   cmd_length, BH_NODE, BH_GETPARAM, BH_UNCHAINED|process,
                   BH_UNCHAINED|BH_LONG, process, BH_LONG|parameter);
      break;
    default:
      return BH_CMD_UNKNOWN;
      break;
  }

  // send command to device
  BD_PUTS(str);
  // read back response from device
  status = BD_GETS(str, sizeof(str), "\r\n", BH_TIME_OUT);
  strcpy(result, str);

  if (!status) { // no response
    if ( info->errorcount < BH_MAX_ERROR ) {
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MERROR, "bh_get_send_rcv", "Communication error with bronkhorst flowcontroller.");
      info->errorcount++;
    }
    return BH_COMM_ERR;
  }

  // check for errors
  if (!bh_success(str, err_msg)) {
    if ( info->errorcount < BH_MAX_ERROR ) {
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MERROR, "bh_get_send_rcv", "%s", err_msg);
      info->errorcount++;
    }
    return BH_COMM_ERR;
  }

  return BH_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>routine which is used to set values of the flowcontroller.</p>
 * <p><b>Return:</b>
 *   - BH_SUCCESS  if everthing went fine
 *   - BH_COMM_ERR if there was a communication problem
 *   - BH_CMD_UNKNOWN if the command is unkown
 * \param info  info structure used by BD_PUTS and BD_GETS macros
 * \param cmd   command tag telling which value to read back from the flowcontroller.
 * \param value value to be set
 */
INT bh_set_send_rcv(BH_INFO *info, INT cmd, float value)
{
  char str[128], err_msg[128];
  int  status;
  int  cmd_length, process, parameter, decode_tag;

  // filter command and generate command string for device
  switch (cmd) {
    case BH_SETPOINT:
      cmd_length = 6;
      process    = 1;
      parameter  = 1;
      decode_tag = BH_INTEGER;
      sprintf(str, ":%02X%02X%02X%02X%02X%04X\r\n",
                   cmd_length, BH_NODE, BH_SETPARAM, BH_UNCHAINED|process,
                   BH_UNCHAINED|BH_INTEGER|parameter, (int)value);
      break;
    case BH_VALVEOUT:
      if (value >= 0) { // if value < 0 do nothing!!
        cmd_length = 8;
        process    = 114;
        parameter  = 1;
        decode_tag = BH_INTEGER;
        sprintf(str, ":%02X%02X%02X%02X%02X%08X\r\n",
                     cmd_length, BH_NODE, BH_SETPARAM, BH_UNCHAINED|process,
                     BH_UNCHAINED|BH_LONG|parameter, value*BH_MAX_NEEDLE_VALVE);
      } else {
        return BH_SUCCESS;
      }
      break;
    default:
      return BH_CMD_UNKNOWN;
      break;
  }

  // send command to device
  BD_PUTS(str);
  // read back response from device
  status = BD_GETS(str, sizeof(str), "\r\n", BH_TIME_OUT);

  if (!status) { // no response
    if ( info->errorcount < BH_MAX_ERROR ) {
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MERROR, "bh_set_send_rcv", "Communication error with bronkhorst flowcontroller.");
      info->errorcount++;
    }
    return BH_COMM_ERR;
  }

  // decode return string and check for errors
  if (!bh_success(str, err_msg)) {
    if ( info->errorcount < BH_MAX_ERROR ) {
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MERROR, "bh_set_send_rcv", "%s", err_msg);
      info->errorcount++;
    }
    return BH_COMM_ERR;
  }

  return BH_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>routine which filters the channel name and generates the command tag</p>
 * <p><b>Return:</b> command tag</p>
 * \param str        channel name
 * \param decode_tag decode tag needed for the decode routines
 *    bh_set_send_rcv, bh_get_send_rcv
 */
INT bh_get_cmd(char *str, int *decode_tag)
{
  int cmd=BH_NO_CMD;

  if (strstr(str,"measured")) {
    cmd = BH_MEASURE;
    *decode_tag = BH_INTEGER;
  }
  if (strstr(str,"setpoint")) {
    cmd = BH_SETPOINT;
    *decode_tag = BH_INTEGER;
  }
  if (strstr(str,"fluidtemp")) {
    cmd = BH_FLUIDTEMP;
    *decode_tag = BH_INTEGER;
  }
  if (strstr(str, "ValvePos")) {
    cmd = BH_VALVEOUT;
    *decode_tag = BH_INTEGER;
  }

  return cmd;
}

/*---- device driver routines ---------------------------------------------------------*/
/*!
 * <p>Initializes the bronkhorst device driver, i.e. generates all the necessary
 * structures in the ODB if necessary, initializes the bus driver and the bronkhorst mass
 * flow meter.</p>
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - FE_ERR_ODB otherwise
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT bh_in_init(HNDLE hKey, BH_INFO **pinfo, INT channels, func_t *bd)
{
  INT     status, chno;
  INT     cmd;
  HNDLE   hDB, hkeydd;
  char    bh_id[128], result[128], err_msg[128];

  cm_get_experiment_database(&hDB, NULL);

  // allocate info structure
  BH_INFO *info = (BH_INFO*)calloc(1, sizeof(BH_INFO));
  bh_info = info; // keep global pointer
  *pinfo = info;

  // create BH settings record
  status = db_create_record(hDB, hKey, "DD/BH", bh_in_settings_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "bh_in_init", "bh_in_init: Couldn't create DD/BH in ODB: status=%d", status); 
    cm_yield(0);
    return FE_ERR_ODB;
  }
  
  // copy DD entries into the info structure
  db_find_key(hDB, hKey, "DD/BH", &hkeydd);
  db_open_record(hDB, hkeydd, &info->bh_in_settings, sizeof(info->bh_in_settings), MODE_READ, NULL, NULL);

  /* initialize driver */
  info->hkey                  = hKey;
  info->num_channels_in       = channels;
  info->bd                    = bd;
  info->errorcount            = 0;
  info->lasterrtime           = ss_time();
  info->startup_error         = 0;
  info->readback_failure      = 0;
  info->last_reconnect        = ss_time();
  info->reconnection_failures = 0;
  info->first_bd_error        = 1;
  info->startup_tag           = 0;

  if ( info->num_channels_in > BH_IN_CHANNELS ) {
    chno = BH_IN_CHANNELS;
    cm_msg(MERROR,"BH_in_init", "Error, max. number of BH input channels is %d, not %d.", chno, info->num_channels_in);
    cm_yield(0);
    info->startup_error = 1;
    return FE_SUCCESS;
  }

  if (!bd)
    return FE_ERR_ODB;

  /* initialize bus driver */
  status = info->bd(CMD_INIT, hKey, &info->bd_info);
  if (status != FE_SUCCESS) {
    info->startup_error = 1;
    info->bd_connected = FALSE;
    return FE_SUCCESS;
  }
  info->bd_connected = TRUE;

  /* initialize BH */
  cmd = BH_IDENTSTRNG;
  status = bh_get_send_rcv(info, cmd, result);

  if ( status != BH_SUCCESS ) { // error occurred
    cm_msg(MERROR,"BH_in_init", "Error getting device query from BH, %s",info->bh_in_settings.name[0]);
    cm_yield(0);
    info->startup_error = 1;
    return FE_SUCCESS;//FE_ERR_HW;
  }

  if (bh_decode_string(result, err_msg, bh_id) != BH_SUCCESS) {
    cm_msg(MERROR,"BH_in_init", "%s", err_msg);
    cm_yield(0);
    info->startup_error = 1;
    return FE_SUCCESS;
  }

  cm_msg(MINFO,"BH_in_init", "Device query of BH yields %s", bh_id);
  cm_yield(0);

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>Initializes the bronkhorst device driver, i.e. generates all the necessary
 * structures in the ODB if necessary, <b>no</b> initialization of the bus driver etc.
 * is done, since this is part of BH_in_init.</p>
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - FE_ERR_ODB otherwise
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 * \param bd is a pointer to the bus driver
 */
INT bh_out_init(HNDLE hKey, BH_INFO **pinfo, INT channels, func_t *bd)
{
  INT   status, chno;
  HNDLE hDB, hkeydd;

  cm_get_experiment_database(&hDB, NULL);

  BH_INFO *info = bh_info;
  *pinfo = info;

  /* create BH settings record */
  status = db_create_record(hDB, hKey, "DD", bh_out_settings_str);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD)) {
    cm_msg(MERROR, "bh_out_init", "Couldn't create DD: status=%d", status); 
    return FE_ERR_ODB;
  }

  // copy DD entries into the info structure
  db_find_key(hDB, hKey, "DD", &hkeydd);
  db_open_record(hDB, hkeydd, &info->bh_out_settings, sizeof(info->bh_out_settings), MODE_READ, NULL, NULL);

  /* initialize driver */
  info->num_channels_out = channels;

  if ( info->num_channels_out != BH_OUT_CHANNELS ) {
    chno = BH_OUT_CHANNELS;
    cm_msg(MERROR,"bh_out_init", "Error, allowed number of BH output channels is %d, not %d.", chno, info->num_channels_out);
    info->startup_error = 1;
    return FE_ERR_HW;
  }

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>terminates the bus driver and free's the memory allocated for the info structure
 * BH_INFO.</p>
 * <p><b>Return:</b> FE_SUCCESS</p>
 * \param info is a pointer to the DD specific info structure
 */
INT bh_exit(BH_INFO *info)
{
  // call EXIT function of bus driver, usually closes device
  info->bd(CMD_EXIT, info->bd_info);

  free(info);

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>set a value of the bronkhorst mass flow meter.</p>
 * <p><b>Return:</b> FE_SUCCESS</p>
 * \param info is a pointer to the DD specific info structure.
 * \param channel is the channel number
 * \param value to be set
 */
INT bh_set(BH_INFO *info, INT channel, float value)
{
  int cmd, status, decode_tag;

  if (info->startup_error)
    return FE_SUCCESS;

  if (!info->bd_connected) {
    if (info->first_bd_error) {
      info->first_bd_error = 0;
      cm_msg(MINFO, "BH_set",
            "BH_set: set values not possible at the moment, since the bus driver is not available!");
    }
    ss_sleep(10);
    return FE_SUCCESS;
  }

  // if dd is starting up, do not do anything!!
  if (info->startup_tag < 2) {
    info->startup_tag++;
    return FE_SUCCESS;
  }

  // get command and decode tag from the name
  cmd = bh_get_cmd(info->bh_out_settings.name[channel], &decode_tag);

  // set value in the flowcontroller
  status = bh_set_send_rcv(info, cmd, value);

  if (status != BH_SUCCESS) {
    if ( info->errorcount < BH_MAX_ERROR ) {
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MERROR, "BH_set", "BH communication or command error.");
      info->errorcount++;
    }
  }

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>get a value from the bronkhorst mass flow meter.</p>
 * <p><b>Return:</b> FE_SUCCESS</p>
 * \param info is a pointer to the DD specific info structure.
 * \param channel is the channel number
 * \param pvalue read
 */
INT bh_get(BH_INFO *info, INT channel, float *pvalue)
{
  int   cmd, status, decode_tag;
  char  str[128], err_msg[128];
  DWORD nowtime, difftime;

  // error timeout facility
  nowtime = ss_time();
  difftime = nowtime - info->lasterrtime;
  if ( difftime >  BH_DELTA_TIME_ERROR ) {
    info->errorcount = 0;
    info->lasterrtime = ss_time();
  }

  // check if there was a startup error
  if ( info->startup_error ) {
     *pvalue = (float) BH_INIT_ERROR;
     ss_sleep(10); // to keep CPU load low when Run active
     return FE_SUCCESS;
  }

  // check if they where too many reconnection failures
  if (info->reconnection_failures > BH_MAX_RECONNECTION_FAILURE) {
    *pvalue = (float) BH_READ_ERROR;
    if (info->reconnection_failures == BH_MAX_RECONNECTION_FAILURE+1) {
      cm_msg(MERROR, "BH_get", "too many reconnection failures, bailing out :-(");
      info->reconnection_failures++;
    }
    return FE_SUCCESS;
  }

  // if disconnected, try to reconnect after the timeout expires
  if (!info->bd_connected) {
    if (ss_time()-info->last_reconnect > BH_RECONNECTION_TIMEOUT) { // timeout expired
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MINFO, "BH_get", "Bronkhorst: reconnection trial ...");
      status = info->bd(CMD_INIT, info->hkey, &info->bd_info);
      if (status != FE_SUCCESS) {
        info->reconnection_failures++;
        *pvalue = (float) BH_READ_ERROR;
        if (info->bh_in_settings.detailed_msg)
          cm_msg(MINFO, "BH_get", "Bronkhorst: reconnection attempted failed");
        return FE_ERR_HW;
      } else {
        info->bd_connected = 1; // bus driver is connected again
        info->last_reconnect = ss_time();
        info->reconnection_failures = 0;
        info->first_bd_error = 1;
        if (info->bh_in_settings.detailed_msg)
          cm_msg(MINFO, "BH_get", "Bronkhorst: successfully reconnected");
      }
    } else { // timeout still running
      *pvalue = info->last_valid_value[channel];
      return FE_SUCCESS;
    }
  }

  // get command and decode tag from the name
  cmd = bh_get_cmd(info->bh_in_settings.name[channel], &decode_tag);
  if (cmd == BH_NO_CMD) { // error
    *pvalue = BH_CMD_ERROR;

    return FE_SUCCESS;
  }

  // get value from the flowcontroller
  status = bh_get_send_rcv(info, cmd, str);

  if (status != BH_SUCCESS) {
    if ( info->errorcount < BH_MAX_ERROR ) {
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MERROR, "BH_get", "BH communication or command error.");
      info->errorcount++;
    }
    info->readback_failure++;

    if (info->readback_failure == BH_MAX_READBACK_FAILURE) {
      info->readback_failure = 0;
      // try to disconnect and reconnect the bus driver
      if ((ss_time()-info->last_reconnect > BH_RECONNECTION_TIMEOUT) && info->bd_connected) {
        info->bd(CMD_EXIT, info->bd_info); // disconnect bus driver
        if (info->bh_in_settings.detailed_msg)
          cm_msg(MINFO, "BH_get", "Bronkhorst: try to disconnect and reconnect the bus driver");
        info->last_reconnect = ss_time();
        info->bd_connected = 0;
        if (info->bh_in_settings.ets_in_use)
          ets_logout(info->bd_info, BH_ETS_LOGOUT_SLEEP, info->bh_in_settings.detailed_msg);
      }
    }
    return FE_SUCCESS;
  }

  // decode return hexcode string
  status = bh_decode_number(str, decode_tag, err_msg, pvalue);

  if (status != BH_SUCCESS) {
    if ( info->errorcount < BH_MAX_ERROR ) {
      if (info->bh_in_settings.detailed_msg)
        cm_msg(MERROR, "BH_get", "%s", err_msg);
      info->errorcount++;
    }
  }

  // rescale needle valve position from 0..2^24 - 1 to the intervall 0..1
  if (cmd == BH_VALVEOUT) {
    *pvalue /= BH_MAX_NEEDLE_VALVE;
  }

  info->last_valid_value[channel] = *pvalue;
  info->readback_failure          = 0;

  ss_sleep(100);

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names of the in-channels into the ODB.</p>
 * <p><b>Return:</b> FE_SUCCESS
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT bh_in_get_label(BH_INFO *info, INT channel, char *name)
{
  strcpy(name, info->bh_in_settings.name[channel]);
  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------------*/
/*!
 * <p>at startup, after initialization of the DD, this routine allows to write
 * default names of the out-channels into the ODB.</p>
 * <p><b>Return:</b> FE_SUCCESS
 * \param info is a pointer to the DD specific info structure
 * \param channel of the name to be set
 * \param name pointer to the ODB name
 */
INT bh_out_get_label(BH_INFO *info, INT channel, char *name)
{
  strcpy(name, info->bh_out_settings.name[channel]);
  return FE_SUCCESS;
}

/*---- device driver entry point ---------------------------------------------------*/
INT bh_flow_in(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   *pvalue;
  BH_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey    = va_arg(argptr, HNDLE);
        BH_INFO **pinfo    = va_arg(argptr, BH_INFO **);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t *);
        status  = bh_in_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_EXIT:
      info   = va_arg(argptr, BH_INFO *);
      status = bh_exit(info);
      break;

    case CMD_GET:
      info    = va_arg(argptr, BH_INFO *);
      channel = va_arg(argptr, INT);
      pvalue  = va_arg(argptr, float*);
      status  = bh_get(info, channel, pvalue);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, BH_INFO *);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = bh_in_get_label(info, channel, name);
      break;

    default:
      break;
  }

  va_end(argptr);
  return status;
}

/************************************************************************/

INT bh_flow_out(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   value;
  BH_INFO *info;
  char    *name;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hKey    = va_arg(argptr, HNDLE);
        BH_INFO **pinfo    = va_arg(argptr, BH_INFO**);
        channel = va_arg(argptr, INT);
        va_arg(argptr, DWORD); // flags - currently not used
        func_t *bd = va_arg(argptr, func_t *);
        status  = bh_out_init(hKey, pinfo, channel, bd);
      }
      break;

    case CMD_SET:
      info    = va_arg(argptr, BH_INFO*);
      channel = va_arg(argptr, INT);
      value   = (float) va_arg(argptr, double);
      status  = bh_set(info, channel, value);
      break;

    case CMD_GET_LABEL:
      info    = va_arg(argptr, BH_INFO*);
      channel = va_arg(argptr, INT);
      name    = va_arg(argptr, char *);
      status  = bh_out_get_label(info, channel, name);
      break;

    default:
      break;
  }

  va_end(argptr);

  return status;
}

/*------------------------------------------------------------------*/
