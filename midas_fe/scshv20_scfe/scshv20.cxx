/*---------------------------------------------------------------------------------------

  Name:         scshv20.c
  Created by:   RA36 06-MAR-2020 (modified copy of SA35 hvr400.c)

  Contents:     MIDAS device driver for the MSCB "high" voltage
  power supply SCSHV20. typically up to 150V max.300V
  for the APD's. It has up to 20 channels and is operated via
  MSCB bus master (Node 0 scshv20 rightmost side of crate) 
  attached to the network
  -> MSCB<name> is always the name of Node 0 of the crate
  -> specifying the slot number of the scshv20 as Node address
  -> scshv20 HV channel numbers and names are 00-19

  NOTE: device driver units are V and uA 

  Initial setup

  . Specify all scshv20 drivers in the DEVICE_DRIVER structure for the EQUIPMENT.
  . Start and then stop the frontend executable a first time to create the ODB structure
  . In the /Equipment/<equipment>/Settings/<device_n>/DD/SCSHV20 of each SCSHV20 device
  - Specify y if the device is used
  - ALWAYS Specify the MSCB name and the Pwd of the MSCB submaster of the rightmost 
  slot (Node 0 is handling the network communication of the entire crate)
  - Specify the Group Addr (default for SCSHV20 is 2000)
  - Specify the "unique" Node Addr of the slot position 
  NOTE: Node address must not be configured on the MSCB submaster of the module. 
  The node address is automatically assigned to the module when inserted 
  into the slot!!
  Use the msc program. Use command "scan" to verify the current adress of the device.
  - Specify the SCSHV20 Name (usually <device>_<n> 
  e.g.: hvflame_1 for the first is taken)
  - Specify the ODB Offset for the first HV channel of the module
  e.g.: for the first SCSHV20 offset is 0, for the second offset is 20.
  - Specify if the module should be accessed read only.
  - If HandlePowerOn is set to y all channels of the module set with non zero demand
  will be reset to the ODB demand value when a power on condition is detected.
  - HV power will be turned on when channel 160 (HV enable) of the module is set to 1.
  Specify if the "HV enable" command should be sent as group command by setting
  "Group HV_enable" y. If not each "HV enable" channel of each module of the device 
  will be enabled separately when the module is initialized.
  - Specify "Voltage Limit" [V] and "Current Limit" [uA]. 
  Maximum channel voltage is 300V and current 1000uA.
  Current SCSHV20 crate is a prototype version with limited power due to a 600W
  power supply. 
  
  . Start the frontend and check if drivers are OK

  . Set the DD/SCSHV20/"Voltage limit" to 2-5 V above the highest possible value to 
  be set when adjusting APD settings.  
  NOTE: After changing a module's "Voltage Limit" restart the Midas front-end
  program.
  FE program will set ODB "Voltage Limit[ch]" and Chxx_Umax of all HV channels
  higher than the module's "Voltage limit" to this voltage limit.
  NOTE: If "Voltage Limit[ch]" and Chxx_Umax of a HV channel are lower than the
  "Voltage limit" of the module they will not be modified at all when
  "Voltage Limit" of the module is increased.
  To be able to set a higher voltage, modify the channels voltage limit in
  /Equipment/<equipment>/Settings/Voltage Limit[ch] and set the HV channels
  voltage again in the ODB.
  NOTE: Restart deltat after changing "Voltage Limit[ch]" of a HV channel.

  . Set the DD/SCSHV20/"Current limit" to 5-10 uA above the highest possible value to 
  be reached by HV channel regulation.  
  NOTE: After changing a module's "Current Limit" restart the Midas front-end
  program.
  FE program will set ODB "Current Limit[ch]" and Chxx_Imax of all HV channels higher
  than the module's "Current limit" to this current limit.
  NOTE: If "Current Limit[ch]" and Chxx_Imax of a HV channel are lower than the
  "Current limit" of the module they will not be modified at all when
  "Current limit" of the module is increased.
  To be able to "set" a higher current e.g. after tripping, modify the channels
  current limit in /Equipment/<equipment>/Settings/Current Limit[ch] and
  then set the HV channels voltage again in the ODB.

  . To permanently store limit values in the module's EEPROM you have to
  start msc and address the node and do a flash reboot.

  Start the msc program as described above.
  Address the node specifying DD/SCSHV20/"Node Addr" of the module

  e.g.: > addr 0

  command "read" will then show the setup of node 0

  you have to enter the two commands "flash" and "reboot" as follows
  flash<return> to write limits of the addressed node to EEPROM and
  reboot<return> to load/update them from EEPROM when the node reboots


  for Midas 2.1N CVS version (experiment name is td_musr2n)
  ----------------------------

  to log NODEINFO and HVINFO values for FLAMEs SCSHC20 hvs20flame0
    
  /usr/local/midas2n_32/odbedit    for i686  or 
  /usr/local/midas2n_64/odbedit    for x86_64

  cd /History/Links
  mkdir lhvs20flame0
  cd lhvs20flame0

  to create event ID 510 for this History link 
  (NOTE: always check Midas_eventIDs.txt and all /History/Links/<link>/Common in ODB)
    
  mkdir Common
  cd Common
  create WORD "Event ID"
  set "Event ID" 510
  cd ..
    
  enter links as follows
    
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/NODELOG/Temperature" (cont.)
  "Mod1_Temperature"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/NODELOG/Load"        (cont.)
  "Mod1_Load"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/NODELOG/Supply24V"   (cont.)
  "Mod1_Supply24V"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/NODELOG/Supply24C"   (cont.)
  "Mod1_Supply24C"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/HVLOG/HV_Enable"     (cont.)
  "Mod1_HV_Enable"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/HVLOG/HV_Set"        (cont.)
  "Mod1_HV_Set"   
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/HVLOG/HV_Read"       (cont.)
  "Mod1_HV_Read"  
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_2/DD/NODELOG/Temperature" (cont.)
  "Mod2_Temperature"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_2/DD/NODELOG/Load"        (cont.)
  "Mod2_Load"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_2/DD/NODELOG/Supply24V"   (cont.)
  "Mod2_Supply24V"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_2/DD/NODELOG/Supply24C"   (cont.)
  "Mod2_Supply24C"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_2/DD/HVLOG/HV_Enable"     (cont.)
  "Mod2_HV_Enable"
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_2/DD/HVLOG/HV_Set"        (cont.)
  "Mod2_HV_Set"   
  ln "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_2/DD/HVLOG/HV_Read"       (cont.)
  "Mod2_HV_Read"  
 
  restart logger

  to set alarm for a SCSHV20 module e.g. "SCSHV20_1 Enabled" for SCSHV20_1
  use odbedit to connect to the experiment database as described above
  
  cd /Alarms/Alarms

  copy "Demo ODB" "SCSHV20_1 Enabled"

  cd "SCSHV20_1 Enabled"

  Type = 3
  Check interval = 60
  Alarm Class = Alarm
  States = 7      (when alarm should be activated in all run states)
  0=all, 1=stopped | 2=paused | 4=running, 7=all
  set  Condition = "/Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/" (cont.)
  "DD/SCSHV20/Sum_NOT_Enabled > 0"
  set  Alarm Message = "SCSHV20_1 HV Channels not Enabled"
  set  Active = y

  To automatically reset the alarm when condition is OK

  cd /Equipment/hvs20flame0/Settings/Devices/SCSHV20_1/DD/SCSHV20/
  set AlarmWhenNOTEnabled = "SCSHV20_1 Enabled"

  ----------------------------------------------------------------------------*/

#include <cstdio>
#include <cstdlib>
#include <cstdarg>
#include <cstring>
#include <cmath>

#include "midas.h"
#include "mfe.h"
#include "msystem.h"
#include "mscb.h"
#include "odbxx.h"

#include "scshv20.h"

#define SCSHV20_NCHANS  20      // number of high voltage channels

// --------- to handle error messages ------------------------------

#define SCSHV20_INIT_ERROR -2   //!< tag: initializing error

#define SCSHV20_MAX_ERROR_LOG        10   //!< maximum number of error messages logged
#define SCSHV20_MAX_ERROR_RECONNECT  150  //!< maximum number of error messages before rec

#define SCSHV20_DELTA_TIME_ERROR 600 //!< reset error counter after DELTA_TIME_ERROR secs

// ----------- SCSHV20 related infos ---------------------------------
//! MSCB debug flag
#define MSCB_DEBUG FALSE
//#define MSCB_DEBUG TRUE  // debug mscb communication

#define SCSHV20_DELTA_TIME_ALL       10 //!< read all values of all channels every .. 
                                        //   seconds in _get()
                                        // NOTE: was initially 60
#define SCSHV20_DELTA_TIME_HVSUPPLY  30 //!< read HV supply from module every .. seconds 
                                        // in _get()
                                        // NOTE: was initially 3600
#define SCSHV20_DELTA_TIME_NODEINFO  60 //!< read NODEINFO from module every .. seconds 
                                        //in _get()

// SCSHV20 module channel offsets for each HV channel ----------------------------------
#define SCSHV20_ENABLE    0
#define SCSHV20_USET      1
#define SCSHV20_UREAD     2
#define SCSHV20_UMAX      3
#define SCSHV20_IREAD     4
#define SCSHV20_IMAX      5
#define SCSHV20_STATUS    6
#define SCSHV20_ERROR     7

#define SCSHV20_FIRST     0
#define SCSHV20_LAST      7

#define SCSHV20_NCHVARS   8

// SCSHV20 HV power specific channels
#define SCSHV20_HVENABLE 160
#define SCSHV20_HVSET    161
#define SCSHV20_HVREAD   162

// SCSHV20 Status Bits ChXX_Status ---------------------------- Channel Status returned 
#define SCSHV20_STATUS_NOVCALIB  0x01  //                        -> 0x01   1
#define SCSHV20_STATUS_NOCCALIB  0x02  //                        -> 0x02   2
#define SCSHV20_STATUS_HVSET     0x04  //                        -> 0x04   4

// additional status bits added
// SCSHV20 Channel ChXX_Enable   <> 1                            -> 0x08   8
// SCSHV20 Channel 160 HV enable <> 1                            -> 0x10  16

// SCSHV20 Error Bits ChXX_Error       // error bits are also returned 
#define SCSHV20_ERROR_HVLOW      0x01  // *32 for return status  -> 0x20  32
#define SCSHV20_ERROR_OVERC      0x02  // *32 for return status  -> 0x40  64

/*!
 * <p>Stores all the parameters the device driver needs.
 */
typedef struct {
  BOOL enabled;              //!< flag indicating if the device is enabled or disabled
  INT  detailed_msg;         //!< flag indicating if detailed status/error messages are 
                             //   wanted
  int  Sum_NOT_Enabled;      //!< sum of HV channels (not enabled and setpoint > 10) +
                             //!< HV enable == 0
  char AlarmWhenNOTEnabled[NAME_LENGTH]; //! alarm to reset
  char port[NAME_LENGTH];    //!< MSCB port, e.g. MSCB ethernet modules
  char pwd[NAME_LENGTH];     //!< MSCB password for MSCB ethernet modules
  INT  group_addr;           //!< group address within the MSCB
  INT  node_addr;            //!< node address of the first HV channel within the MSCB
  char name[NAME_LENGTH];    //!< name of the SCSHV20 card (should be identical with
                             //   device driver name specified in device driver list of 
                             //   equipment)
  INT  odb_offset;           //!< HV channel offset within ODB 0, 20, 40, ...
  BOOL readonly;             //!< Readonly if TRUE
  char  handle_poweron;      //!< handle poweron 
  BOOL group_hvenable;       //!< HV enable (CH160) will be sent as group command if TRUE
  float voltage_limit;       //!< maximum voltage limit (<= 300v) of SCSHV20 module must
                             //   be increased when setting higher voltages
  float current_limit;       //!< maximum current limit (<= 1000 uA) of SCSHV20 module
                             //   must be increased when setting higher voltages
} SCSHV20_SETTINGS;

//! Initializing string for the struct SCSHV20_SETTINGS
#define SCSHV20_SETTINGS_STR "\
Enabled = BOOL : 0\n\
Detailed Messages = INT : 0\n\
Sum_NOT_Enabled = INT : 0\n\
AlarmWhenNOTEnabled = STRING : [32] NONE\n\
MSCB Port = STRING : [32] XXX\n\
MSCB Pwd = STRING : [32]\n\
Group Addr = INT : 2000\n\
Node Addr = INT : 1\n\
SCSHV20 Name = STRING : [32] SCSHV20_X\n\
HV ODB Offset = INT : 0\n\
Readonly = BOOL : 0\n\
HandlePowerOn = CHAR : N\n\
Group HV_enable = BOOL : 0\n\
Voltage Limit = FLOAT : 300.0\n\
Current Limit = FLOAT : 1000.0\n\
"

typedef struct {
  float temperature;
  float load;
  float supply24v;
  float supply24c;
} SCSHV20_NODELOG;

#define SCSHV20_NODELOG_STR "\
Temperature = FLOAT : 0.0\n\
Load        = FLOAT : 0.0\n\
Supply24V   = FLOAT : 0.0\n\
Supply24C   = FLOAT : 0.0\n\
"

//------------------------------------------------------------------
/*!
 * <p>Variable set of a scshv20 HV channel. 
 *
 * <p>The status byte can be or'ed with the following states:
 * - 0x1 No voltage calibration
 * - 0x2 No current calibration
 * - 0x4 HV settled
 *
 * <p>The error byte can be or'ed with the following states:
 * - 0x1 HV low
 * - 0x2 overcurrent
 */
typedef struct {
  DWORD enable;             //!< ChXX_Enable
  float uset;               //!< ChXX_USet volt
  float uread;              //!< ChXX_URead volt
  float umax;               //!< ChXX_Umax volt
  float iread;              //!< ChXX_IRead microampere 
  float imax;               //!< ChXX_Imax microampere
  DWORD status;             //!< ChXX_Status
  DWORD error;              //!< ChXX_Error

  unsigned char cached;     //!< cache flag 0=not updated/1=updated since last _get()

  DWORD ret_status;         //!< combined return status
} SCSHV20_NODE_VARS;

/*!
 * <p>Variables of the HV power channels of the module
 */
typedef struct { // NIY TODO maybe add HV Current, Error status ...
  DWORD enable;            //!<   HV enable
  float demand;            //!<   HV set  : voltage demand   (V) 
  float measured;          //!<   HV read : voltage measured (V)
  float voltage_limit;     //!<   voltage limit (V)  module constant is 300
  float current_limit;     //!<   current limit (uA) module constant is 1000
} SCSHV20_POWER_SUPPLY;     

#define SCSHV20_POWER_SUPPLY_STR "\
HV_Enable    = DWORD : 0\n\
HV_Set       = FLOAT : 0.0\n\
HV_Read      = FLOAT : 0.0\n\
HV_Vlim      = FLOAT : 0.0\n\
HV_Clim      = FLOAT : 0.0\n\
"


//! This structure contains private variables for the device driver.
typedef struct {
  SCSHV20_SETTINGS       settings;    //!< stores the internal DD settings
  SCSHV20_NODELOG        nodelog;     //!< stores the internal DD nodelog 
  SCSHV20_NODE_VARS     *node_vars;   //!< stores the variables of all SCSHV20 HV      
                                      //   channels of this module
  SCSHV20_NODE_VARS     *node_vars_m; //!< stores the mirrored variables of all 
                                      //   SCSHV20 HV channels of this module
  SCSHV20_POWER_SUPPLY   hv_supply;   //!< stores the information of the power supply
  SCSHV20_POWER_SUPPLY   hv_supply_m; //!< stores the mirrored information of the power 
                                      //   supply
  INT   channels;                     //!< number of HV channels
  INT   fd;                           //!< MSCB file desciptor
  INT   errcount;                     //!< error counter in order not to flood the 
                                      //   message queue
  INT   startup_error;                //!< initializer error tag, if set, 
                                      //   scshv20_get and scshv20_set won't do anything
  DWORD lasterrtime;                  //!< last error time stamp
  DWORD lastreadalltime;              //!< last readout all of all channels time stamp
                                      //   in _get()
  DWORD lasthvsupplytime;             //!< last readout of HV power supply time stamp
                                      //   in _get()
  DWORD lastnodeinfotime;             //!< last readout of node info time stamp
                                      //   in _get()

  INT   highest_demand;               //!< highest demand value of this device (V) 
  int   nsettled;                     //!< number of HV channels with state HV settled

  DWORD scshv20_last_set[SCSHV20_NCHANS];//!< timestamp demand value was last set
  float scshv20_last_demand[SCSHV20_NCHANS]; //!< last demand value (V) set in ODB

  HNDLE keydemand;                    //!< HNDLE to /Equipment/<name>/Variables/Demand
  HNDLE keynodelog;                   //!< HANDLE to .../DD/NODELOG
  HNDLE keyhvlog;                     //!< HANDLE to .../DD/HVLOG
  HNDLE keysumnotenabled;             //!< HANDLE to .../DD/SCHV20/Sum_NOT_Enabled

  char name[NAME_LENGTH];             //!< equipment <name>

  unsigned int  uptime;               //!< uptime
  INT           pon;                  //!< uptime < previous uptime >> power_on
} SCSHV20_INFO;

// device driver support routines -------------------------------------------------

INT scshv20_exit(SCSHV20_INFO *);
INT scshv20_status_string(DWORD status, char *);
INT scshv20_error_string(DWORD error, char *);

/*!
 * <p> read all variables of the SCSHV20 module assigned to this channel
 * 
 * \param info
 * \param channel
 */
INT scshv20_read_all(SCSHV20_INFO* info, int channel)
{
  int           size, status;
  unsigned char buffer[36], *pbuf; // 8*4 + 4??

#ifdef MIDEBUG1
  cm_msg(MLOG,"","++scshv20_read_all(HV channel=%d)",channel+info->settings.odb_offset);
  cm_msg_flush_buffer();
#endif

 read_again:

  if (info->fd >= 0) {
    size = sizeof(buffer);
    status=mscb_read_range(info->fd,(unsigned short)info->settings.node_addr, 
			   (unsigned char) (channel*SCSHV20_NCHVARS+SCSHV20_FIRST), 
			   (unsigned char) (channel*SCSHV20_NCHVARS+SCSHV20_LAST),buffer,&size);

    if (status != MSCB_SUCCESS) {
      if (info->errcount < SCSHV20_MAX_ERROR_LOG) {
	cm_msg(MERROR, "scshv20_read_all", "%s: Cannot access MSCB SCSHV20 HV channel "
	       "%d at node address \"%d\". Check power, node addresses and connection.",
	       info->settings.name, channel+info->settings.odb_offset, 
	       info->settings.node_addr);
	cm_msg_flush_buffer();
      }
      info->errcount++;
      //return FE_ERR_HW;
    }
  } else {
    info->errcount++;
    status = MSCB_SUBM_ERROR;
  }
   
  if (status != MSCB_SUCCESS) {
    // Try to disconnect and reconnect to MSCB submaster
    if (info->errcount > SCSHV20_MAX_ERROR_RECONNECT) {
      if (info->fd >= 0) {
	mscb_exit(info->fd);
	info->fd = -1;
	ss_sleep(1000);
      }
      // initialize MSCB
      info->fd = mscb_init(info->settings.port, sizeof(info->settings.port),
			   info->settings.pwd, MSCB_DEBUG);
      if (info->fd < 0) {
	cm_msg(MINFO, "scshv20_read_all", "scshv20_read_all: %s: Couldn't reinitialize"
	       " MSCB port %s, Error no: %d", info->settings.name,
	       info->settings.port, info->fd);
	cm_msg_flush_buffer();
	info->errcount = SCSHV20_MAX_ERROR_RECONNECT/2;
      } else {
	cm_msg(MINFO, "scshv20_read_all", "scshv20_read_all: %s: (re)initialized "
	       "connection to MSCB port %s", info->settings.name, info->settings.port);
	cm_msg_flush_buffer();
	info->errcount = SCSHV20_MAX_ERROR_LOG;
	goto read_again;
      }
    }
    return FE_ERR_HW;
  }

  if (size != 5*sizeof(float)+3*sizeof(DWORD)) {
    cm_msg(MERROR, "scshv20_read_all","%s: Returned buffer size (%d) <> "
	   "expected size %d bytes! Buffer is discarded!", info->settings.name, size, 
	   (INT) (5*sizeof(float)+3*sizeof(DWORD)));
    cm_msg_flush_buffer();
    return FE_ERR_HW;
  }

  /*   node0(0x0)> r          module channels of each HV channel e.g. channel 00
       0: Ch00_Enable       32bit U               0 (0x00000000) dword
       1: Ch00_USet         32bit F               0 volt
       2: Ch00_URead        32bit F      0.00953161 volt
       3: Ch00_Umax         32bit F             300 volt
       4: Ch00_IRead        32bit F        0.111181 microampere
       5: Ch00_Imax         32bit F            1000 microampere
       6: Ch00_Status       32bit U               0 (0x00000000) dword
       7: Ch00_Error        32bit U               0 (0x00000000) dword
  */

  /* decode variables from buffer */
  pbuf = buffer;
  DWORD_SWAP(pbuf);
  info->node_vars[channel].enable = *((DWORD *)pbuf);  // 0  _Enable DWORD
  pbuf += sizeof(DWORD);

  DWORD_SWAP(pbuf);
  info->node_vars[channel].uset   = *((float *)pbuf);  // 1  _USet float
  pbuf += sizeof(float);

  DWORD_SWAP(pbuf);
  info->node_vars[channel].uread  = *((float *)pbuf);  // 2  _URead float
  pbuf += sizeof(float);

  DWORD_SWAP(pbuf);
  info->node_vars[channel].umax   = *((float *)pbuf);  // 3  _Umax float
  pbuf += sizeof(float);

  DWORD_SWAP(pbuf);
  info->node_vars[channel].iread  = *((float *)pbuf);  // 4  _IRead float
  pbuf += sizeof(float);

  DWORD_SWAP(pbuf);
  info->node_vars[channel].imax   = *((float *)pbuf);  // 5  _Imax float
  pbuf += sizeof(float);

  DWORD_SWAP(pbuf);
  info->node_vars[channel].status = *((DWORD *)pbuf);  // 6  _Status DWORD
  pbuf += sizeof(DWORD);

  DWORD_SWAP(pbuf);
  info->node_vars[channel].error  = *((DWORD *)pbuf);  // 7  _Error DWORD

  // compose return status adding additional bits to ret_status
  info->node_vars[channel].ret_status = info->node_vars[channel].status;

  // SCSHV20 Channel ChXX_Enable   <> 1                            -> 0x08 
  if (info->node_vars[channel].enable != 1) 
    info->node_vars[channel].ret_status += 0x08;

  // SCSHV20 Channel 160 HV enable <> 1                            -> 0x10
  if (info->hv_supply.enable != 1)
    info->node_vars[channel].ret_status += 0x10;

  // SCSHV20 Error Bits ChXX_Error
  if (info->node_vars[channel].error & SCSHV20_ERROR_HVLOW) //     -> 0x20
    info->node_vars[channel].ret_status += 0x20;

  if (info->node_vars[channel].error & SCSHV20_ERROR_OVERC) //     -> 0x40
    info->node_vars[channel].ret_status += 0x40;

  /* mark voltage/current/status as valid (up to date) in cache */
  info->node_vars[channel].cached = 1;

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/

INT scshv20_read_hv_supply(SCSHV20_INFO* info) {

  int           size, updated;
  unsigned char buffer[16], *pbuf; // 3*4 + 4??
  INT status;

#ifdef MIDEBUG1
  cm_msg(MLOG,"","++scshv20_read_hv_supply()");
#endif
  status = FE_SUCCESS;
  updated = 0;

  // mirror values first to be able to compare after reading
  info->hv_supply_m.enable        = info->hv_supply.enable;
  info->hv_supply_m.demand        = info->hv_supply.demand;
  info->hv_supply_m.measured      = info->hv_supply.measured;
  info->hv_supply_m.voltage_limit = info->hv_supply.voltage_limit; 
  info->hv_supply_m.current_limit = info->hv_supply.current_limit; 

  if (info->fd < 0) return FE_SUCCESS;

  size = sizeof(buffer);
  status = mscb_read_range(info->fd, (unsigned short) (info->settings.node_addr),
			   (unsigned char) SCSHV20_HVENABLE, (unsigned char) SCSHV20_HVREAD, 
			   buffer, &size);
  if (status != MSCB_SUCCESS) {
    info->errcount++;
    if (info->errcount < SCSHV20_MAX_ERROR_LOG) {
      cm_msg(MERROR, "scshv20_read_hv_supply", "%s: Cannot access MSCB SCSHV20 node "
	     "address \"%d\". Check power, node addresses and connection.",
	     info->settings.name, info->settings.node_addr);
      cm_msg_flush_buffer();
    }
    return FE_SUCCESS;      
  }
  
  // decode variables from buffer
  if (size == sizeof(DWORD) + 2*sizeof(float)) {
    pbuf = buffer;
    DWORD_SWAP(pbuf);
    info->hv_supply.enable = *((DWORD *) pbuf);   // Channel 160 HV enable DWORD
    pbuf += sizeof(DWORD);
    DWORD_SWAP(pbuf);
    info->hv_supply.demand = *((float *) pbuf);   // Channel 161 HV set    float
    pbuf += sizeof(float);
    DWORD_SWAP(pbuf);
    info->hv_supply.measured = *((float *) pbuf); // Channel 162 HV read   float

    if (info->hv_supply_m.enable != info->hv_supply.enable) {
      cm_msg(MLOG,"","%s: \"HV enable\" changed from %d (%s) to %d (%s)",
	     info->settings.name, info->hv_supply_m.enable,
	     info->hv_supply_m.enable?"ON":"OFF",info->hv_supply.enable,
	     info->hv_supply.enable?"ON":"OFF");   
      updated++;
    }

    if (info->hv_supply_m.demand        != info->hv_supply.demand)        updated++; 
    if (info->hv_supply_m.measured      != info->hv_supply.measured)      updated++; 

    info->hv_supply.voltage_limit = info->settings.voltage_limit; // reading of set-up 
    info->hv_supply.current_limit = info->settings.current_limit; // reading of set-up
    if (info->hv_supply_m.voltage_limit != info->hv_supply.voltage_limit) updated++; 
    if (info->hv_supply_m.current_limit != info->hv_supply.current_limit) updated++; 

    if (updated && info->keyhvlog ) {
      HNDLE hDB;

      cm_get_experiment_database(&hDB, NULL);
      db_set_record(hDB, info->keyhvlog, &info->hv_supply, 
		    sizeof(SCSHV20_POWER_SUPPLY), 0);
    }
  } else {
    cm_msg(MERROR, "scshv20_get","%s: Returned buffer size (%d) <> expected size %d "
	   "bytes! Buffer is discarded!", info->settings.name, size, 
	   (INT)(sizeof(DWORD)+2*sizeof(float)));
    cm_msg_flush_buffer();
    return FE_ERR_HW;
  }

  return status;
}

/*----------------------------------------------------------------------------*/

INT scshv20_read_node_info(SCSHV20_INFO* info) {
  MSCB_INFO     node_info;
  unsigned int  uptime;
  INT status,status1,updated;

#ifdef MIDEBUG1
  cm_msg(MLOG,"","++scshv20_read_node_info()");
#endif
  status = FE_SUCCESS;
  status1 = MSCB_SUCCESS;
  updated = 0;

  if (info->fd < 0) return FE_SUCCESS;

  status = mscb_info(info->fd, (unsigned short)info->settings.node_addr, &node_info);
  status1 = mscb_uptime(info->fd, (unsigned short)info->settings.node_addr, &uptime);
  if (status != MSCB_SUCCESS) {
    info->errcount++;
    if (info->errcount < SCSHV20_MAX_ERROR_LOG) {
      cm_msg(MERROR, "scshv20_read_node_info", "%s: Cannot access MSCB SCSHV20 node "
	     "address \"%d\". Check power, node addresses and connection.",
	     info->settings.name, info->settings.node_addr);
      cm_msg_flush_buffer();
    }
    return FE_SUCCESS;      
  }

  if (status1 == MSCB_SUCCESS) {
    if (uptime < info->uptime) {
      cm_msg(MLOG,"","%s: Uptime (%u) less than previous value %u! "
	     "**** POWER OUTAGE? ****",info->settings.name,uptime,info->uptime);
      info->pon = 1;    
    }
    info->uptime = uptime;
  }

  if (info->nodelog.temperature != node_info.pcbTemp) {
    info->nodelog.temperature    = node_info.pcbTemp;
    updated++;
  }

  if (info->nodelog.load        != node_info.systemLoad) {
    info->nodelog.load           = node_info.systemLoad;
    updated++;
  }
  if (info->nodelog.supply24v   != node_info.Supply24V0) {
    info->nodelog.supply24v      = node_info.Supply24V0;
    updated++;
  }
  if (info->nodelog.supply24c   != node_info.Supply24V0Current) {
    info->nodelog.supply24c      = node_info.Supply24V0Current;
    updated++;
  }

  if (updated && info->keynodelog ) {
    HNDLE hDB;

    cm_get_experiment_database(&hDB, NULL);
    db_set_record(hDB, info->keynodelog, &(info->nodelog), sizeof(SCSHV20_NODELOG), 0);
  }

  return status;
}

//---- device driver routines --------------------------------------

INT scshv20_handle_pon(SCSHV20_INFO* info) {
  DWORD         eflag;
  INT           rstatus, status;
  int           i;

#ifdef MIDEBUG1
  cm_msg(MLOG,"","++scshv20_handle_pon()");
#endif
  rstatus = FE_SUCCESS;
  info->pon = 0;

  if (!info->settings.readonly) {
    if ((info->settings.handle_poweron == 'Y') ||
	(info->settings.handle_poweron == 'y')    ) {
      if (info->hv_supply.enable != 1) {
	cm_msg(MLOG,"","scshv20_handle_pon: %s : Setting \"HV enable\" to 1 (ON) "
	       "at node address %d ", info->settings.name, info->settings.node_addr);
	eflag = 1;
	status = mscb_write(info->fd, (unsigned short)info->settings.node_addr,
			    (unsigned char)SCSHV20_HVENABLE, &eflag,4);
	if (status != MSCB_SUCCESS) {
	  cm_msg(MERROR, "scshv20_handle_pon", "%s: Status %d writing HV Enable "
		 "0x%x to node address %d", info->settings.name, status, 
		 eflag, info->settings.node_addr);
	}
      } else {
	cm_msg(MLOG,"","scshv20_handle_pon: %s : \"HV enable\" is aleady set to 1 (ON) "
	       "at node address %d ", info->settings.name, info->settings.node_addr);
      }
      cm_msg_flush_buffer();

      cm_msg(MLOG, "", "scshv20_handle_pon: %s : Setting %d HV channels to CHxx_Enabled"
	     " if their demand voltage is larger than 10V",info->settings.name,info->channels);

      for (i=0; i < info->channels; i++) {
	if (info->node_vars[i].uset < 10.0f)    // demand 0 or < 10V?
	  eflag = 0;          // then do not enable HV on channel
	else
	  eflag = 1;          //  enable HV on channel

	status = mscb_write(info->fd, (unsigned short)(info->settings.node_addr), 
			    (unsigned char) (i*SCSHV20_NCHVARS+SCSHV20_ENABLE), &eflag, 4);
	if (status != MSCB_SUCCESS) {
	  cm_msg(MERROR, "scshv20_handle_pon", "%s: Status %d writing Enable 0x%x "
		 "to HV channel %d at node address %d", info->settings.name, status, eflag, i+info->settings.odb_offset, 
		 info->settings.node_addr);
	}
      } // for all HV channels
    } else {
      // handle_poweron flag not set
      cm_msg(MLOG,"","%s: HandlePowerOn flag is set to N in DD/SCSHV20 : Not handling "
	     "Power On condition", info->settings.name);
    }
  } else {
    cm_msg(MLOG, "", "scshv20_handle_pon: %s : **** READONLY **** flag! NOT setting "
	   "any demand value", info->settings.name);
  }
  return rstatus;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>Initializes the scshv20 device driver, i.e. generates all the necessary
 * structures in the ODB if necessary, and initializes the MSCB connection. Furthermore 
 * it makes some consistency checks to verify that the addressed module is indeed a 
 * SCSHV20 MSCB card.</p>
 *
 * <p><b>Return:</b>
 *   - FE_SUCCESS if everything went smooth
 *   - FE_ERR_ODB otherwise
 *
 * \param hKey is the device driver handle given from the class driver
 * \param pinfo is needed to store the internal info structure
 * \param channels is the number of channels of the device (from the class driver)
 */
INT scshv20_init(HNDLE hKey, SCSHV20_INFO **pinfo, INT channels)
{
  INT            status, size;
  INT            i;
  HNDLE          hDB, hkeydd,hkeyni,hkeyhvl;
  MSCB_INFO      node_info;
  SCSHV20_INFO   *info;
  std::string    tpath;
  DWORD          eflag;

#ifdef MIDEBUG
  cm_msg(MLOG,"","++scshv20_init(channels=%d)", channels);
  cm_msg_flush_buffer();
#endif

  // allocate info structure
  info = (SCSHV20_INFO *) calloc(1, sizeof(SCSHV20_INFO));
  info->node_vars   = (SCSHV20_NODE_VARS *) calloc(channels, sizeof(SCSHV20_NODE_VARS));
  info->node_vars_m = (SCSHV20_NODE_VARS *) calloc(channels, sizeof(SCSHV20_NODE_VARS));
  info->channels = channels;
  *pinfo = info;

  cm_get_experiment_database(&hDB, NULL);

  // create SCSHV20 settings record
  status = db_create_record(hDB, hKey, "DD/SCSHV20", SCSHV20_SETTINGS_STR);
  if (status != DB_SUCCESS) {
    cm_msg(MERROR, "scshv20_init", "Error creating DD Settings record in ODB.");
    cm_msg_flush_buffer();
    return FE_ERR_ODB;
  }

  db_find_key(hDB, hKey, "DD/SCSHV20", &hkeydd);
  size = sizeof(info->settings);
  db_get_record(hDB, hkeydd, &info->settings, &size, 0);

  // get key Sum_NOT_Enabled and reset ODB value to 0
  status = db_find_key(hDB, hKey, "DD/SCSHV20/Sum_NOT_Enabled", &info->keysumnotenabled);
  if (status == DB_SUCCESS) {
    if (info->settings.Sum_NOT_Enabled != 0) {
      info->settings.Sum_NOT_Enabled = 0;
      db_set_data(hDB,info->keysumnotenabled,&info->settings.Sum_NOT_Enabled,
		  sizeof(int),1,TID_INT);
    }
  } else {
    info->keysumnotenabled = 0;
    info->settings.Sum_NOT_Enabled = 0;
  }

  /* reset alarm */
  if (strncmp(info->settings.AlarmWhenNOTEnabled,"NONE",4) != 0)
    al_reset_alarm(info->settings.AlarmWhenNOTEnabled);

  // create NODELOG record (may be already opened by Logger via /History/Link)
  status = db_create_record(hDB, hKey, "DD/NODELOG", SCSHV20_NODELOG_STR);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD))  {
    cm_msg(MERROR, "scshv20_init", "Error creating DD NODELOG record in ODB.");
    cm_msg_flush_buffer();
    return FE_ERR_ODB;
  } else if (status == DB_OPEN_RECORD) {
    cm_msg(MINFO, "scshv20_init", "scshv20_init: %s **** DD/NODELOG record is already "
	   "open maybe by Logger see /History/Link", info->settings.name);
  }

  db_find_key(hDB, hKey, "DD/NODELOG", &hkeyni);
  size = sizeof(info->nodelog);
  db_get_record(hDB, hkeyni, &info->nodelog, &size, 0);
  info->keynodelog = hkeyni;

  // create HVLOG record (may be already opened by Logger via /History/Link)
  status = db_create_record(hDB, hKey, "DD/HVLOG", SCSHV20_POWER_SUPPLY_STR);
  if ((status != DB_SUCCESS) && (status != DB_OPEN_RECORD))  {
    cm_msg(MERROR, "scshv20_init", "Error creating DD HVLOG record in ODB.");
    cm_msg_flush_buffer();
    return FE_ERR_ODB;
  } else if (status == DB_OPEN_RECORD) {
    cm_msg(MINFO, "scshv20_init", "scshv20_init: %s **** DD/HVLOG record is already "
	   "open maybe by Logger see /History/Link", info->settings.name);
  }

  db_find_key(hDB, hKey, "DD/HVLOG", &hkeyhvl);
  size = sizeof(info->hv_supply);
  db_get_record(hDB, hkeyhvl, &info->hv_supply, &size, 0);
  info->keyhvlog = hkeyhvl;

  // initialize driver
  info->errcount         = 0;
  info->startup_error    = 0;
  info->lasterrtime      = ss_time();
  info->lastreadalltime  = 0;
  info->lasthvsupplytime = 0;
  info->lastnodeinfotime = 0;
  info->fd = -1;

  for (i=0; i < SCSHV20_NCHANS; i++) { 
    info->scshv20_last_set[i] = 0;
    info->scshv20_last_demand[i] = 0.0f;
  }

  if (!info->settings.enabled) {
    cm_msg(MINFO, "scshv20_init", "scshv20_init: **** %s **** not enabled", 
	   info->settings.name);
    cm_msg_flush_buffer();
    info->startup_error = 1;
    return FE_SUCCESS;
  }

  // initialize MSCB connection
  info->fd = mscb_init(info->settings.port, sizeof(info->settings.port), 
                       info->settings.pwd, MSCB_DEBUG);
  if (info->fd < 0) {
    cm_msg(MINFO, "scshv20_init", "scshv20_init: Couldn't initialize MSCB port %s, "
	   "Error no: %d", info->settings.port, info->fd);
    cm_msg_flush_buffer();
    info->startup_error = 1;
    //return FE_SUCCESS;
    scshv20_exit(info); // RA36 26-FEB-2019
    *pinfo = NULL;
    return FE_ERR_DRIVER;
  } else {
    cm_msg(MLOG,"","scshv20_init: %s: opened connection to MSCB port %s", 
	   info->settings.name, info->settings.port);
    cm_msg_flush_buffer();
  }

  // check MSCB node information
  /*
    node0(0x0)> info
    Node name         : SCSHV20
    Node address      : 0 (0x0)
    Group address     : 2000 (0x7D0)
    Protocol version  : 5
    Revision          : V 1.4.3
    Real Time Clock   : 06-03-20 08:01:21
    Uptime            : 2d 00h 47m 15s
    Buffer size       : 1450
    Pin/Ext WD Resets : 11
    SW-resets         : 7
    Int. WD resets    : 0
    Boot-Bank         : 1
    Silicon Revision  : 3
    System load       : 0.90%
    Peak system load  : 41.30%
    PCB Temp          : 30.47▒C
    Supply 1.8V       : 0.00V
    Supply 3.3V       : 3.33V
    Supply 5.0V       : 5.03V
    Supply 24.0V      : 23.91V
    Supply 5V Ext.    : 0.00V
    Supply 24V Ext.   : 0.00V
    Supply current    : 0.097A
    Battery voltage   : 3.04V
  */
  status = mscb_info(info->fd, (unsigned short)info->settings.node_addr, &node_info);
  if (status != MSCB_SUCCESS) {
    cm_msg(MINFO, "scshv20_init", "%s: Cannot access HVR node at address \"%d\". "
	   "Please check cabling, node addresses and power.", info->settings.name, 
	   info->settings.node_addr);
    cm_msg_flush_buffer();
    info->startup_error = 1;
    //return FE_SUCCESS;
    scshv20_exit(info); // RA36 26-FEB-2019
    *pinfo = NULL;
    return FE_ERR_DRIVER;
#ifdef MIDEBUG1
  } else {
    cm_msg(MLOG,"","scshv20_init: %s : Node at address %d is accessible", 
	   info->settings.name, info->settings.node_addr);
    cm_msg_flush_buffer();
#endif
  }
  
  // check if it is a SCSHV20 module
  if (strcmp(node_info.node_name, "SCSHV20") != 0) {
    if (strlen(node_info.node_name) > 0) {
      cm_msg(MERROR,"scshv20_init","%s: Found unexpected node \"%s\" at address \"%d\".",
             info->settings.name, node_info.node_name, info->settings.node_addr);
    } else {
      cm_msg(MERROR, "scshv20_init", "%s: ERROR Empty node name: node not connected or "
	     "node address \"%d\" may be wrong.", 
	     info->settings.name, info->settings.node_addr);
    }
    cm_msg_flush_buffer();
    info->startup_error = 1;
    //return FE_SUCCESS;
    scshv20_exit(info); // RA36 26-FEB-2019
    *pinfo = NULL;
    return FE_ERR_DRIVER;
  } else {
    cm_msg(MLOG,"","scshv20_init: %s : Node at address %d is %s", info->settings.name,
	   info->settings.node_addr, node_info.node_name);
    if (info->settings.group_addr != node_info.group_address)
      cm_msg(MLOG,"","scshv20_init: %s : WARNING group address %d of node is not "
	     "identical with group address %d specified in DD/Settings",
	     info->settings.name, node_info.group_address, info->settings.group_addr);
    cm_msg_flush_buffer();
  }
  cm_msg_flush_buffer();
  
  // check if the SVN Rev No is high enough to be used with this software version 
  // Not clear about revision -> TODO find out required revision for this module
  if (/*node_info.revision < 3518 ||*/ node_info.revision < 10) {
    cm_msg(MERROR, "scshv20_init",
	   "%s: Found node \"%d\" with old firmware %d (SVN revision >= 3518 required)", 
	   info->settings.name, info->settings.node_addr, node_info.revision);
    cm_msg_flush_buffer();
    info->startup_error = 1;
    //return FE_SUCCESS;
    scshv20_exit(info); // RA36 26-FEB-2019
    *pinfo = NULL;
    return FE_ERR_DRIVER;
  }

  // get information about HV channels
  if (scshv20_read_hv_supply(info) == FE_SUCCESS) {

    cm_msg(MLOG,"","%s: HV enable= %d,  HV set=%fV, HV read=%fV", info->settings.name,
	   info->hv_supply.enable, info->hv_supply.demand, info->hv_supply.measured);
    cm_msg(MLOG,"","%s: HW Voltage limit of the HV channels is %fV", 
	   info->settings.name, info->hv_supply.voltage_limit);
    cm_msg(MLOG,"","%s: HW Current limit of the HV channels is %fuA", 
	   info->settings.name, info->hv_supply.current_limit);
  } else {
    cm_msg(MLOG,"","%s: ERROR(S) reading ODB information of HV power supply",
	   info->settings.name);
  }

  info->lasthvsupplytime = ss_time();

  if (info->settings.readonly) {
    cm_msg(MLOG, "", "scshv20_init: %s : **** READONLY **** flag! NOT setting any "
	   "demand value", info->settings.name);
  }
  cm_msg_flush_buffer();

  // reset _Umax when larger than voltage_limit, reset _Imax when larger than 
  // current_limit, set _USet to the limit when larger,
  // turn on the HV, setting channel 160 "HV enable" of the module to 1
  if (!info->settings.readonly) {

    for (i=0; i<channels; i++) {
      status = scshv20_read_all(info, i);   // get all info
      if (status == FE_SUCCESS) {
        // _Umax of node larger than voltage limit?
        if (info->settings.voltage_limit > 0.f) {
          if (info->node_vars[i].umax > info->settings.voltage_limit) {
            float ulimit;

            ulimit = info->settings.voltage_limit;

            cm_msg(MINFO,"","scshv20_init: %s: HV channel %d at node address %d: "
		   "Setting _Umax from %.1fV to DD/Voltage_limit (%.1fV)",info->settings.name,
		   i+info->settings.odb_offset, info->settings.node_addr, 
		   info->node_vars[i].umax, ulimit);
            status = mscb_write(info->fd, (unsigned short)(info->settings.node_addr), 
				(unsigned char) (SCSHV20_NCHVARS*i+SCSHV20_UMAX), &ulimit, 4);
            if (status != MSCB_SUCCESS) {
              cm_msg(MERROR, "scshv20_init", "%s: Status %d writing _Umax (%.1fV) "
		     "to HV channel %d at node address %d", info->settings.name, status, 
		     ulimit, i+info->settings.odb_offset,
		     info->settings.node_addr);
              info->node_vars[i].umax = ulimit;
            } else {
              info->node_vars[i].umax = ulimit;
            }
            cm_msg_flush_buffer();
          }
        }

        // _Imax of node larger than current limit?
        if (info->settings.current_limit > 0.f) {
          if (info->node_vars[i].imax > info->settings.current_limit) {
            float climit;

            climit = info->settings.current_limit;

            cm_msg(MINFO,"","scshv20_init: %s: HV channel %d at node address %d: "
		   "Setting _Imax from %.1fuA to DD/Current_limit (%.1fuA)",
		   info->settings.name, i+info->settings.odb_offset, info->settings.node_addr,
		   info->node_vars[i].imax, climit);
            status = mscb_write(info->fd, (unsigned short)(info->settings.node_addr), 
				(unsigned char) (SCSHV20_NCHVARS*i+SCSHV20_IMAX), &climit, 4);
            if (status != MSCB_SUCCESS) {
              cm_msg(MERROR, "scshv20_init", "%s: Status %d writing _Imax (%.1fuA) "
		     "to HV channel %d at node address %d", info->settings.name, status, 
		     climit, i+info->settings.odb_offset,
		     info->settings.node_addr);
              info->node_vars[i].imax = climit;
            } else {
              info->node_vars[i].imax = climit;
            }
            cm_msg_flush_buffer();
          }
        }

        // uset of node larger than node limit umax?
        if (info->node_vars[i].umax > 0.f) {
          if (info->node_vars[i].uset > info->node_vars[i].umax) {
            float udemand;

            udemand = info->node_vars[i].umax;

            cm_msg(MINFO,"","scshv20_init: %s: HV channel %d at node address %d:"
		   "Setting _USet from %.1fV to HV channel's _Umax (%.1fV)", 
		   info->settings.name, i+info->settings.odb_offset, info->settings.node_addr,
		   info->node_vars[i].uset, udemand);

            status = mscb_write(info->fd, (unsigned short)(info->settings.node_addr), 
				(unsigned char)(i*SCSHV20_NCHVARS+SCSHV20_USET), &udemand, 4);
            if (status != MSCB_SUCCESS) {
              cm_msg(MERROR, "scshv20_init", "%s: Status %d writing USet (%.1fV) "
		     "to HV channel %d at node address %d", info->settings.name, status, 
		     udemand, i+info->settings.odb_offset, 
		     info->settings.node_addr);

              info->node_vars[i].uset = udemand;
            } else {
              info->node_vars[i].uset = udemand;
            }
            cm_msg_flush_buffer();
          }
        }
      }
    } // for

    // Turn on HV of the SCSHV20 group (any SCSHV20 module of the MSCB bus)
    if (info->settings.group_hvenable) {
      cm_msg(MLOG,"","scshv20_init: %s : Setting MSCB group %d \"HV enable\" to 1 (ON)",
	     info->settings.name, info->settings.group_addr);
      eflag = 1;
      status = mscb_write_group(info->fd, (unsigned short)info->settings.group_addr,
				(unsigned char)SCSHV20_HVENABLE, &eflag,4);
      if (status != MSCB_SUCCESS) {
        cm_msg(MERROR, "scshv20_init", "%s: Status %d writing HV enable 0x%x to "
	       "group address %d", info->settings.name, status, 
	       eflag, info->settings.group_addr);
      }
      cm_msg_flush_buffer();
      // NOTE: HV channels are not enabled in group command
      // else is now decoupled to enable HV channels of this module in both cases
    }

    // "else" only channels of this module is now always 
    {
      cm_msg(MLOG, "", "scshv20_init: %s : Setting %d HV channels to CHxx_Enabled if "
	     "their demand voltage is larger than 10V", info->settings.name, channels);
      for (i=0; i<channels; i++) {
        //status = scshv20_read_all(info, i);   // get all info
        if (info->node_vars[i].uset < 10.0f)    // demand 0 or < 10V?
          eflag = 0;          // then do not enable HV on channel
        else
          eflag = 1;          //  enable HV on channel

        status = mscb_write(info->fd, (unsigned short)(info->settings.node_addr), 
			    (unsigned char) (i*SCSHV20_NCHVARS+SCSHV20_ENABLE), &eflag, 4);
        if (status != MSCB_SUCCESS) {
          cm_msg(MERROR, "scshv20_init", "%s: Status %d writing Enable 0x%x to "
		 "HV channel %d at node address %d", info->settings.name, status, 
		 eflag, i+info->settings.odb_offset, 
		 info->settings.node_addr);
        }
      }
      if (!info->settings.group_hvenable) {
        if (info->hv_supply.enable != 1) {
          cm_msg(MLOG,"","scshv20_init: %s : Setting \"HV enable\" to 1 (ON) "
		 "at node address %d ", info->settings.name, info->settings.node_addr);
          eflag = 1;
          status = mscb_write(info->fd, (unsigned short)info->settings.node_addr,
			      (unsigned char)SCSHV20_HVENABLE, &eflag,4);
          if (status != MSCB_SUCCESS) {
            cm_msg(MERROR, "scshv20_init", "%s: Status %d writing HV Enable 0x%x to"
		   " node address %d", info->settings.name, status, 
		   eflag, info->settings.node_addr);
          }
        } else {
          cm_msg(MLOG,"","scshv20_init: %s : \"HV enable\" is aleady set to 1 (ON) "
		 "at node address %d ", info->settings.name, info->settings.node_addr);
        }
        cm_msg_flush_buffer();
      }
    }
  } else {
    if (info->settings.group_hvenable) {
      cm_msg(MLOG, "", "scshv20_init: %s : **** READONLY **** flag! NOT setting MSCB "
	     "group %d HV enable to 1 (Enabled)", info->settings.name, 
	     info->settings.group_addr);
    }
    cm_msg(MLOG, "", "scshv20_init: %s : **** READONLY **** flag! NOT setting SCSHV20 "
	   "module at node address %d HV enable to 1 (Enabled) and HV channels"
	   " _Enable  and _USet", info->settings.name, info->settings.node_addr);
  }
  cm_msg_flush_buffer();

  ss_sleep(100);

  cm_msg(MLOG, "", "scshv20_init: %s : Reading all HV channel variables of the module", 
	 info->settings.name);
  cm_msg_flush_buffer();

  // read all values from the SCSHV20 device channels
  info->highest_demand = -1;
  for (i=0; i < channels; i++) {
    status = scshv20_read_all(info, i);
    if (status != FE_SUCCESS) {
      info->startup_error = 1;
    } else {
      int j;
      char sstring[70];
      char estring[70];

      j = i+info->settings.odb_offset;   // calculate ODB channel index

      // find largest demand value when channel _Enable == 1
      if ((info->highest_demand < info->node_vars[i].umax) && 
          (info->node_vars[i].enable == 1))
        info->highest_demand = info->node_vars[i].umax;

      // log current values
      scshv20_status_string(info->node_vars[i].status, &sstring[0]);
      scshv20_error_string(info->node_vars[i].error, &estring[0]);
      cm_msg(MLOG,"","%s: HV channel %2.2d : _Enable=%d, _Status=0X%x (%s), _Error=0X%x "
	     "(%s)", info->settings.name, j, info->node_vars[i].enable, 
	     info->node_vars[i].status, sstring, info->node_vars[i].error, estring);
      cm_msg(MLOG,"","%s: HV channel %2.2d : _USet=%f V, _URead=%f V, _IRead=%f uA", 
	     info->settings.name, j, info->node_vars[i].uset, info->node_vars[i].uread,
	     info->node_vars[i].iread); 
      cm_msg(MLOG,"","%s: HV channel %2.2d : _Umax=%f V, _Imax=%f uA", 
	     info->settings.name, j, info->node_vars[i].umax, info->node_vars[i].imax);

      // remember currently set demand value
      info->scshv20_last_demand[i] = info->node_vars[i].uset;
      info->scshv20_last_set[i] = ss_time();
    }
    cm_msg_flush_buffer();
  } // for all channels of module

  if (info->startup_error != 0)   
    return FE_SUCCESS;

  info->lastreadalltime = ss_time();

  cm_msg(MINFO, "scshv20_init", "scshv20_init: %s : **** initialized **** ", 
	 info->settings.name);
  // get equipment name
  tpath = db_get_path(hDB, hKey);
  if (tpath == "(DB_INVALID_HANDLE)" ||
      tpath == "(RPC_DB_GET_PATH status 503)" ||
      tpath == "(RPC_DB_GET_PATH status 512)" ||
      tpath == "(RPC_DB_GET_PATH status 508)" ||
      tpath == "(RPC_DB_GET_PATH status 504)") {
      cm_msg(MERROR, "scshv20_init", "ERROR %s getting key path", tpath.c_str());
  } else {
    size_t i;
    for (i = strlen("/Equipment/"); i < tpath.length(); i++) {
      if (tpath[i] == '/') {
        tpath[i] = '\0';
        strncpy(info->name, &tpath[strlen("/Equipment/")], NAME_LENGTH);
        info->name[NAME_LENGTH - 1] = '\0';
        break;
      }
    }
    cm_msg(MINFO, "scshv20_init", "%s: Equipment name is %s", info->settings.name,
	  info->name);
  }
  cm_msg_flush_buffer();

  // get Demand key
  tpath = "/Equipment/" + std::string(info->name) + "/Variables/Demand";
  status = midas::odb::exists(tpath);
  if (status != FE_SUCCESS) {  // couldn't get the demand key
    cm_msg(MERROR, "scshv20_init", "scshv20_init: Couldn't get the Demand key.");
    //return status;
    info->keydemand = 0;
  }

  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>terminates the MSCB and free's the memory allocated for the DD info structure.</p>
 *
 * <p><b>Return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure
 */
INT scshv20_exit(SCSHV20_INFO *info)
{
  // call EXIT function of MSCB driver, usually closes device
  if (!info->startup_error)
    mscb_exit(info->fd);

  free(info->node_vars);
  free(info);
  
  return FE_SUCCESS;
}

/*----------------------------------------------------------------------------*/
/*!
 * <p>set a high voltage value of a SCSHV20 HV channel.</p>
 *
 * <p><b>return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure.
 * \param channel is the HV channel number
 * \param value high voltage value in (kV) to be set
 */
INT scshv20_set(SCSHV20_INFO *info, INT channel, float value)
{
  INT   status;
  float lim_value, ulim_value, mscb_value;
  DWORD eflag;

  //#ifdef MIDEBUG
  cm_msg(MLOG,"","++scshv20_set(HV channel=%d, MSCB node = %d, value=%f)", 
	 channel+info->settings.odb_offset, info->settings.node_addr, value);
  cm_msg_flush_buffer();
  //#endif

  if ( info->startup_error ) {
    ss_sleep(10);
    return FE_SUCCESS;
  }

  if (!info->settings.readonly) {
    if (scshv20_read_hv_supply(info) == FE_SUCCESS) {
      if (value > info->hv_supply.demand) { // maybe write message when HV settled
        cm_msg(MLOG,"","%s: Voltage (%f V) of HV channel %d is larger than the voltage"
	       " demand %f of \"HV set\"", info->settings.name, value, 
	       channel+info->settings.odb_offset, info->hv_supply.demand);
        cm_msg_flush_buffer();
      }
    }

    // when not connected try to force reconnect 
    if (info->fd < 0) {
      int itries;
      itries = 0;
      do {
        itries++;
        info->errcount = SCSHV20_MAX_ERROR_RECONNECT + 1;
      } while ((scshv20_read_all(info, channel) != FE_SUCCESS)&&
               (itries < 4));
    }

    if ( info->fd >= 0) {

      scshv20_read_all(info, channel);

      // set HV value
      mscb_value = ulim_value = lim_value = fabs(value); // V -> V

      if (info->settings.voltage_limit > 0.f) {
        if (mscb_value > info->settings.voltage_limit) {
          lim_value = info->settings.voltage_limit;
        }
      }

      if (info->node_vars[channel].umax > 0.f) {
        if (mscb_value > info->node_vars[channel].umax) {
          ulim_value = info->node_vars[channel].umax;
        }
      }

      if (ulim_value <= lim_value) {
        if (mscb_value != ulim_value) {
          cm_msg(MLOG,"","%s: Voltage (%f V) of HV channel %d is larger than channel's "
		 "_Umax (%.1fV) -> Setting _Umax", info->settings.name, 
		 mscb_value, channel+info->settings.odb_offset, ulim_value);
          mscb_value = ulim_value;
        }
      } else {
        if (mscb_value != lim_value) {
          cm_msg(MLOG,"","%s: Voltage (%f V) of HV channel %d is larger than DD/Voltage"
		 "_limit (%.1fV) -> Setting limit", info->settings.name, 
		 mscb_value, channel+info->settings.odb_offset, lim_value);
          mscb_value = lim_value;
        }
      }

      
      if ((mscb_value < 10.f) && (mscb_value != 0.f)) {
        // when demand is < 10V ->  give a warning
        // Readout will set odb value to zero
        cm_msg(MINFO,"","Warning: %s voltage set to (%f V) of HV channel %d is below operation limit!", info->settings.name,
	       mscb_value, channel+info->settings.odb_offset);
        //mscb_value = 0.f;
      }

      cm_msg(MLOG, "scshv20_set", "%s: Setting HV channel %d voltage demand _USet "
	     "to %f V", info->settings.name, 
	     channel+info->settings.odb_offset, mscb_value);
      status=mscb_write(info->fd, (unsigned short) (info->settings.node_addr), 
			(unsigned char) (channel*SCSHV20_NCHVARS+SCSHV20_USET), &mscb_value, 4);

      if (status != MSCB_SUCCESS) {
        cm_msg(MERROR, "scshv20_set", "%s: Status %d writing _USet (%f V) "
	       "of HV channel %d to node address %d", info->settings.name, status, 
	       mscb_value, channel+info->settings.odb_offset, 
	       info->settings.node_addr);
        cm_msg_flush_buffer();
      }

      // enable/disable channel?
      /*
      if (mscb_value < 10.0f)          // new demand <10V?
        eflag = 0;                     // then turn HV off
      else
      */
      eflag = 1; // turn HV on
      
      if (info->node_vars[channel].enable != eflag) {
        cm_msg(MLOG, "scshv20_set", "%s: Setting HV channel %d _Enable "
	       "to %d : HV Channel power %s", info->settings.name, 
	       channel+info->settings.odb_offset, eflag, 
	       eflag?"ON":"OFF");
        status = mscb_write(info->fd, (unsigned short)(info->settings.node_addr), 
			    (unsigned char)(channel*SCSHV20_NCHVARS+SCSHV20_ENABLE), &eflag, 4);
      } else { 
        status = MSCB_SUCCESS;
      }
      // if (HV enable == 0) then enable HV setting channel 160 "HV enable" to 1
      if (status == MSCB_SUCCESS) {
        scshv20_read_all(info, channel);   // get all info
        scshv20_read_hv_supply(info);
        if (eflag == 1) {
          if (info->hv_supply.enable != 1) {
            eflag = 1;
            cm_msg(MLOG, "scshv20_set", "%s: Setting \"HV enable\" to 1 to turn HV "
		   "of module ON", info->settings.name);
            status=mscb_write(info->fd, (unsigned short) (info->settings.node_addr), 
			      (unsigned char)SCSHV20_HVENABLE, &eflag, 4);
            if (status == MSCB_SUCCESS) {
              scshv20_read_hv_supply(info);
            }
          }
          
        }
      }

      if (status != MSCB_SUCCESS) {
        cm_msg(MERROR, "scshv20_set", "%s: Status %d writing enable tag 0x%x to "
	       "HV channel %d at node address %d", info->settings.name, status, 
	       eflag, channel, info->settings.node_addr);
      }
    } else {
      cm_msg(MERROR, "scshv20_set", "%s: Not able to send ODB value to device!",
	     info->settings.name);
    }

  } else {
    cm_msg(MLOG, "", "scshv20_set: %s : **** READONLY **** flag! NOT setting voltage "
	   "demand of HV channel %d at node address %d to %f V",
	   info->settings.name, channel, info->settings.node_addr, value);
  }

  if ((channel >= 0)&&(channel < SCSHV20_NCHANS)) {
    info->scshv20_last_set[channel] = ss_time();
    info->scshv20_last_demand[channel] = value;
  }

#ifdef MIDEBUG
  cm_msg(MLOG,"","--scshv20_set()");
#endif
  cm_msg_flush_buffer();
  return FE_SUCCESS;
}

/*-----------------------------------------------------------------------------*/
/* NOTE: string must be at least 21 char */
INT scshv20_error_string(DWORD error, char *string) {
  INT rstatus;

  rstatus = FALSE;
  if (string) {

    if (error & 0x1)
      strcpy(string,"HV low ");
    else
      strcpy(string,"");
    
    if (error & 0x2)
      strcat(string,"overcurrent");
    if (strlen(string)==0) strcpy(string,"OK");
    rstatus = TRUE;
  }
  return rstatus;
}
/*-----------------------------------------------------------------------------*/
/* NOTE: string must be at least 69 char */
INT scshv20_status_string(DWORD status, char *string) {
  INT rstatus;

  rstatus = FALSE;
  if (string) {
    //  12345678901234567890123456789012345678901234567890123456789
    // "No voltage calibration; No current calibration; HV settled"
    *(string+0) = '\0';
    if (status & 0x01) strcat(string,"No voltage calibration; ");
    if (status & 0x02) strcat(string,"No current calibration; ");
    if (status & 0x04) strcat(string,"HV settled");
    if (strlen(string) == 0) strcpy(string,"OK");
    rstatus = TRUE;
  }
  return rstatus;
}
/*-----------------------------------------------------------------------------*/
/*!
 * <p>get a high voltage value from a SCSHV20 channel.</p>
 *
 * <p><b>return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure.
 * \param channel is the channel number
 * \param pvalue read
 */
INT scshv20_get(SCSHV20_INFO *info, INT channel, float *pvalue)
{
  INT    status, size;
  DWORD  nowtime, difftime;
  unsigned char buffer[256], *pbuf;

#ifdef MIDEBUG1
  cm_msg(MLOG,"","++scshv20_get(HV channel=%d, MSCB node = %d)", 
	 channel+info->settings.odb_offset, info->settings.node_addr);
  cm_msg_flush_buffer();
#endif
  // error timeout facility
  nowtime = ss_time();
  difftime = nowtime - info->lasterrtime;
  if ( difftime >  SCSHV20_DELTA_TIME_ERROR ) {
    info->errcount = 0;
    info->lasterrtime = ss_time();
  }

  // check if there was a startup error
  if ( info->startup_error ) {
    *pvalue = (float) SCSHV20_INIT_ERROR;
    ss_sleep(10); // to keep CPU load low when Run active
    return FE_SUCCESS;
  }

  // periodically (every minute) update all 
  if (nowtime < info->lastreadalltime) 
    info->lastreadalltime = nowtime -SCSHV20_DELTA_TIME_ALL;

  if ((nowtime - info->lastreadalltime)> SCSHV20_DELTA_TIME_ALL) {
    SCSHV20_NODE_VARS *tnode_vars;
    int i, sumnotenabled, sumenabled; 
    HNDLE hDB;
    float olddemand, odbdemand, demand;

    cm_get_experiment_database(&hDB,NULL);

    // swap pointers before reading all to be able to compare node_vars and node_vars_m
    tnode_vars                 = info->node_vars;
    info->node_vars            = info->node_vars_m;
    info->node_vars_m          = tnode_vars;

    // read all values from the SCSHV20 device channels
    info->highest_demand = -1.f;
    info->nsettled = 0;

    sumnotenabled = 0;
    sumenabled = 0;

    for (i=0; i<info->channels; i++) {
      status = scshv20_read_all(info, i);
      if (status == FE_SUCCESS) {

        if (info->node_vars[i].status & 0x04) info->nsettled++;

        // get highest demand value to be able to compare with HV supply
        if (info->highest_demand < info->node_vars[i].uset)
          info->highest_demand = info->node_vars[i].uset;

        // _Enable changed?
        if (info->node_vars[i].enable != info->node_vars_m[i].enable) {
          cm_msg(MLOG,"","%s: HV Channel %d Node Addr %d: _Enable changed from "
		 "%d (%s) to %d (%s)", info->settings.name, i+info->settings.odb_offset, 
		 info->settings.node_addr,info->node_vars_m[i].enable,
		 info->node_vars_m[i].enable?"ON":"OFF", info->node_vars[i].enable,
		 info->node_vars[i].enable?"ON":"OFF"); 
        }

        if (info->node_vars[i].uset != info->node_vars_m[i].uset) {
          cm_msg(MLOG,"","%s: HV Channel %d Node Addr %d: Voltage demand changed from "
		 "%f to %f V", info->settings.name, i+info->settings.odb_offset, 
		 info->settings.node_addr,
		 info->node_vars_m[i].uset, info->node_vars[i].uset); 

          // check against HVsupply
	  if (scshv20_read_hv_supply(info) == FE_SUCCESS) {
	    if (info->node_vars[i].uset > info->hv_supply.demand) {
	      cm_msg(MLOG,"","%s: voltage (%f V) of HV channel %d is larger than the "
		     "voltage demand %f of \"HV set\"", info->settings.name, 
		     info->node_vars[i].uset, 
		     i+info->settings.odb_offset, info->hv_supply.demand);
	      cm_msg_flush_buffer();
	    }
	  }
        } 

        // update ODB demand value
        if ((i >= 0) && (i < SCSHV20_NCHANS)){
          if (info->scshv20_last_set[i] > ss_time()) info->scshv20_last_set[i]=ss_time();
          if ((info->keydemand != 0) && (ss_time() > info->scshv20_last_set[i]+60)) {
            float diff;

            olddemand = odbdemand = info->scshv20_last_demand[i];
            demand = info->node_vars[i].uset;
            diff = demand -odbdemand;
            if (diff < 0.f) diff = -diff;
            if (diff > 0.000001) {
              cm_msg(MLOG,"","%s: HV channel %d _USet (%f V) was changed on SCSHV20 to "
		     "%f", info->settings.name,i+info->settings.odb_offset,odbdemand, demand);
              cm_msg_flush_buffer();

              odbdemand = demand;

              // consider voltage limit or node's Ulimit
              if (info->settings.voltage_limit > 0) {
                if (info->settings.voltage_limit < odbdemand)
                  odbdemand = info->settings.voltage_limit;
              }

              if (info->node_vars[i].umax > 0) {
                if (info->node_vars[i].umax < odbdemand)
                  odbdemand = info->node_vars[i].umax; 
              }

              if (odbdemand != demand)
                cm_msg(MLOG,"","%s: HV channel %d _USet reading on SCSHV20 (%f V) was "
		       "changed to %fV to be in voltage limit",
		       info->settings.name,i+info->settings.odb_offset, 
		       demand, odbdemand);

              if (olddemand != odbdemand) {
		// set new demand value on device
		scshv20_set(info, i, odbdemand);
		if (info->settings.readonly) info->scshv20_last_demand[i] = odbdemand;

		// update ODB
		size = sizeof(float);
		db_set_data_index(hDB, info->keydemand, &odbdemand, size, 
				  i+info->settings.odb_offset, TID_FLOAT);
              }
            }
          }
        }
   
        // check if limits were modified
        if (info->node_vars[i].umax != info->node_vars_m[i].umax) {
          cm_msg(MLOG,"","%s: HV channel %d Node Addr %d: _Umax changed from %f to "
		 "%f V", info->settings.name, i+info->settings.odb_offset, 
		 info->settings.node_addr,
		 info->node_vars_m[i].umax, info->node_vars[i].umax);        
	  if (info->node_vars[i].umax > info->hv_supply.voltage_limit) {
	    cm_msg(MLOG,"","%s: Voltage limit _Umax (%f V) of HV channel %d is "
		   "larger than the maximum allowed voltage limit %f", 
		   info->settings.name, info->node_vars[i].umax, 
		   i+info->settings.odb_offset, info->hv_supply.voltage_limit);
	  }
        }
        if (info->node_vars[i].imax != info->node_vars_m[i].imax) {
          cm_msg(MLOG,"","%s: HV channel %d Node Addr %d: Current limit _Imax changed "
		 "from %fuA to %f", info->settings.name, i+info->settings.odb_offset, 
		 info->settings.node_addr,info->node_vars_m[i].imax, info->node_vars[i].imax);        
	  if (info->node_vars[i].imax > info->hv_supply.current_limit) {
	    cm_msg(MLOG,"","%s: Current limit _Imax (%f uA) of HV channel %d is "
		   "larger than the maximum allowed current limit %f", 
		   info->settings.name, info->node_vars[i].imax, 
		   i+info->settings.odb_offset, info->hv_supply.current_limit);
	  }
        }

        if (info->node_vars[i].error != info->node_vars_m[i].error) {
          char s_error[32],s_error_m[32];

          scshv20_error_string(info->node_vars_m[i].error,s_error_m);
          scshv20_error_string(info->node_vars[i].error,  s_error);
          cm_msg(MLOG,"","%s: HV channel %d Node Addr %d: Error word changed from 0x%X "
		 "(%s) to 0x%X (%s)", info->settings.name, i+info->settings.odb_offset, 
		 info->settings.node_addr, info->node_vars_m[i].error, s_error_m, 
		 info->node_vars[i].error, s_error);        
        }

        if (info->node_vars[i].status != info->node_vars_m[i].status) {
          char s_status[70],s_status_m[70];

          scshv20_status_string(info->node_vars_m[i].status,s_status_m);
          scshv20_status_string(info->node_vars[i].status,  s_status);

          cm_msg(MLOG,"","%s: HV channel %2.2d Node Addr %d: Status word changed from "
		 "0x%X (%s) to 0x%X (%s)", info->settings.name, i+info->settings.odb_offset, 
		 info->settings.node_addr, info->node_vars_m[i].status, s_status_m, 
		 info->node_vars[i].status, s_status);        
        }

        // measured value changed more than +-1 V
        if (((info->node_vars[i].uread+1.0) < info->node_vars_m[i].uread) ||
            ((info->node_vars[i].uread-1.0) > info->node_vars_m[i].uread)) {
          // if power is on, check, if measured value differs from demand
          if (info->node_vars[i].status & 0x04) { // only check when HV settled
            if (((info->node_vars[i].uset+10.0) < info->node_vars[i].uread) ||
                ((info->node_vars[i].uset-10.0) > info->node_vars[i].uread)) {
              cm_msg(MLOG,"","%s: HV channel %d Node Addr %d: Measured voltage _URead "
		     "%fV differs more than 10 V from demand value _USet %f V", 
		     info->settings.name, i+info->settings.odb_offset, 
		     info->settings.node_addr, info->node_vars[i].uread, 
		     info->node_vars[i].uset);        
            }
          }
        }

        // sum cases where demand value >= 10.f
        if (info->node_vars[i].uset >= 10.f) {
          if (info->node_vars[i].enable == 0) {
            sumnotenabled++;
          } else {
            sumenabled++;
          }
        }   
      }
    } // for all channels

    // check if hv supply should be enabled too
    if ((info->hv_supply.enable == 0) && (sumnotenabled+sumenabled > 0)) {
      sumnotenabled++;
    }

    // update ODB when Sum_NOT_Enabled changed
    if (info->settings.Sum_NOT_Enabled != sumnotenabled) {

      cm_msg(MLOG,"","%s: Number of HV Channels (including HV supply) NOT Enabled "
	     " and _USet >= 10V changed from %d to %d", info->settings.name,
	     info->settings.Sum_NOT_Enabled, sumnotenabled);

      info->settings.Sum_NOT_Enabled = sumnotenabled;

      // update DD/SCSHV20/Sum_NOT_Enabled
      if (info->keysumnotenabled != 0)
	db_set_data(hDB,info->keysumnotenabled,&info->settings.Sum_NOT_Enabled,
		    sizeof(int),1,TID_INT);

      /* reset alarm when everything is as expected */
      if (info->settings.Sum_NOT_Enabled == 0) {
	if (strncmp(info->settings.AlarmWhenNOTEnabled,"NONE",4) != 0) {
	  cm_msg(MLOG,"","%s: Resetting alarm \"%s\"", info->settings.name,
		 info->settings.AlarmWhenNOTEnabled);
	  al_reset_alarm(info->settings.AlarmWhenNOTEnabled);
	}
      }
    }

    info->lastreadalltime = ss_time();
    cm_msg_flush_buffer();
  }

  // periodically (every 1/2 minute) check hv supply
  if (nowtime < info->lasthvsupplytime) 
    info->lasthvsupplytime = nowtime -SCSHV20_DELTA_TIME_HVSUPPLY;

  if ((nowtime - info->lasthvsupplytime)> SCSHV20_DELTA_TIME_HVSUPPLY) {
    if (scshv20_read_hv_supply(info) == FE_SUCCESS) {

      // if demand value of HV supply decreased
      // or measured value of HV supply dropped
      if ((info->hv_supply.demand < info->hv_supply_m.demand) ||
	  ((info->highest_demand > 10) && 
	   (info->hv_supply.measured < info->hv_supply_m.measured))) {
	if (info->hv_supply.measured > info->highest_demand) {
	  // measured value is less than 3V from 
	  if (info->hv_supply.measured -info->highest_demand < 3.0f) {
	    cm_msg(MLOG,"","%s: Measured HV (%f V) of \"HV set\" is close to largest "
		   "demand value %d V", info->settings.name, info->hv_supply.measured,
		   info->highest_demand);
	    cm_msg_flush_buffer();
	  }
	} else if (info->nsettled > 0) {
	  cm_msg(MLOG,"","%s: Measured HV (%f V) of \"HV set\" is less than largest "
		 "demand value %d V", info->settings.name, info->hv_supply.measured,
		 info->highest_demand);
	  cm_msg_flush_buffer();
	}
      } 
      // HV set changed?
      if (info->hv_supply.demand != info->hv_supply_m.demand) {    
	// NIY check demand values _USet of all HV channels to be below demand
	// of HV set demand
      }
    }
    info->lasthvsupplytime = ss_time();
  }

  // periodically (every minute) check 
  if (nowtime < info->lastnodeinfotime) 
    info->lastnodeinfotime = nowtime -SCSHV20_DELTA_TIME_NODEINFO;

  if ((nowtime - info->lastnodeinfotime)> SCSHV20_DELTA_TIME_NODEINFO) {
    if (scshv20_read_node_info(info) == FE_SUCCESS) {
      if (info->pon) scshv20_handle_pon(info);
    }
    info->lastnodeinfotime = ss_time();
  }

  cm_msg_flush_buffer();

  if (info->node_vars[channel].cached) {
    *pvalue = info->node_vars[channel].uread;
    info->node_vars[channel].cached = 0;
    return FE_SUCCESS;
  }
  
  // read voltage and current at the same time
  if (info->fd < 0) return FE_SUCCESS;

  size = sizeof(buffer);
  status = mscb_read_range(info->fd, (unsigned short) (info->settings.node_addr),
			   (unsigned char)(channel*SCSHV20_NCHVARS+SCSHV20_UREAD), 
			   (unsigned char)(channel*SCSHV20_NCHVARS+SCSHV20_IREAD), buffer, &size);
  if (status != MSCB_SUCCESS) {
    info->errcount++;
    if (info->errcount < SCSHV20_MAX_ERROR_LOG) {
      cm_msg(MERROR, "scshv20_get", "%s: Cannot access MSCB SCSHV20 address \"%d\". "
	     "Check power, node addresses and connection.", info->settings.name, 
	     info->settings.node_addr);
      cm_msg_flush_buffer();
    }
    return FE_SUCCESS;      
  }
  
  // decode variables from buffer
  if (size == 3*sizeof(float)) {
    pbuf = buffer;
    DWORD_SWAP(pbuf);
    info->node_vars[channel].uread = *((float *) pbuf);
    pbuf += sizeof(float); 
    // skip _Umax
    pbuf += sizeof(float);
    DWORD_SWAP(pbuf);
    info->node_vars[channel].iread = *((float *) pbuf);
  } else {
    cm_msg(MERROR, "scshv20_get","%s: Returned buffer size (%d) <> expected size %d "
	   "bytes! Buffer is discarded!", info->settings.name, size, 3*(INT)sizeof(float));
    cm_msg_flush_buffer();
    return FE_ERR_HW;
  }

  *pvalue = info->node_vars[channel].uread;


#ifdef MIDEBUG1
  cm_msg(MLOG,"","--scshv20_get(HV channel=%d, value=%f)", 
	 channel+info->settings.odb_offset, *pvalue);
#endif
  return FE_SUCCESS;
}

//----------------------------------------------------------------------------
/*!
 * <p>sets the current limit [uA] of a HV channel of the SCSHV20's.
 *
 * <p><b>return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure.
 * \param channel is the HV channel number
 * \param limit is the current limit value
 */
INT scshv20_set_current_limit(SCSHV20_INFO *info, INT channel, float limit)
{
  INT   status;
  DWORD nowtime, difftime;
  float mscb_value;

  //#ifdef MIDEBUG1
  cm_msg(MLOG,"","++scshv20_set_current_limit(HV channel=%d, MSCB node=%d, limit=%f)", 
	 channel+info->settings.odb_offset, info->settings.node_addr, limit);
  cm_msg_flush_buffer();
  //#endif
  if ( info->startup_error ) {
    ss_sleep(10);
    return FE_SUCCESS;
  }

  // error timeout facility
  nowtime = ss_time();
  difftime = nowtime - info->lasterrtime;
  if ( difftime >  SCSHV20_DELTA_TIME_ERROR ) {
    info->errcount = 0;
    info->lasterrtime = ss_time();
  }

  if (!info->settings.readonly) {
    if (limit > info->hv_supply.current_limit) {
      cm_msg(MLOG,"","%s: current limit _Umax (%f uA) of HV channel %d is larger "
	     "than the maximum allowed current limit %f", info->settings.name, limit, 
	     channel+info->settings.odb_offset, info->hv_supply.current_limit);
      cm_msg_flush_buffer();
    }

    // when not connected try to force reconnect 
    if (info->fd < 0) {
      int itries;
      itries = 0;
      do {
	itries++;
	info->errcount = SCSHV20_MAX_ERROR_RECONNECT + 1;
      } while ((scshv20_read_all(info, channel) != FE_SUCCESS)&&
	       (itries < 4));
    }

    if ( info->fd >= 0) {
      // set current limit value
      mscb_value = limit; // uA -> uA
      status=mscb_write(info->fd, (unsigned short) (info->settings.node_addr), 
			(unsigned char) (channel*SCSHV20_NCHVARS+SCSHV20_IMAX), &mscb_value, 4);
      if (status != MSCB_SUCCESS) {
        cm_msg(MERROR,"scshv20_set_current_limit","%s: Status %d writing current "
	       "limit _Imax (%f uA) of HV channel %d to node address %d",info->settings.name,
	       status, mscb_value, 
	       channel+info->settings.odb_offset, info->settings.node_addr);
      }
    } else {
      cm_msg(MERROR,"scshv20_set_current_limit","%s: Not able to set current limit!",
	     info->settings.name);
    }
  } else {
    cm_msg(MLOG, "", "scshv20_set_current_limit: %s : **** READONLY **** flag! NOT "
	   "setting current limit of HV channel %d to %f uA", 
	   info->settings.name, channel+info->settings.odb_offset, limit);
  }

#ifdef MIDEBUG1
  cm_msg(MLOG,"","--scshv20_set_current_limit()");
#endif
  cm_msg_flush_buffer();
  return FE_SUCCESS;
}

//----------------------------------------------------------------------------
/*!
 * <p>sets the voltage limit [V] of a HV channel of the SCSHV20's.
 *
 * <p><b>return:</b> FE_SUCCESS</p>
 *
 * \param info is a pointer to the DD specific info structure.
 * \param channel is the HV channel number
 * \param limit is the voltage limit value
 */
INT scshv20_set_voltage_limit(SCSHV20_INFO *info, INT channel, float limit)
{
  INT   status;
  DWORD nowtime, difftime;
  float mscb_value;

  //#ifdef MIDEBUG1
  cm_msg(MLOG,"","++scshv20_set_voltage_limit(HV channel=%d, MSCB node=%d, limit=%.3f)",
	 channel+info->settings.odb_offset, info->settings.node_addr, limit);
  cm_msg_flush_buffer();
  //#endif
  if ( info->startup_error ) {
    ss_sleep(10);
    return FE_SUCCESS;
  }

  // error timeout facility
  nowtime = ss_time();
  difftime = nowtime - info->lasterrtime;
  if ( difftime >  SCSHV20_DELTA_TIME_ERROR ) {
    info->errcount = 0;
    info->lasterrtime = ss_time();
  }

  if (!info->settings.readonly) {
    // check with value of HV set
    if (limit > info->hv_supply.voltage_limit) {
      cm_msg(MLOG,"","%s: Voltage limit _Umax (%f V) of HV channel %d is larger "
	     "than the maximum voltage limit %f", info->settings.name, limit, 
	     channel+info->settings.odb_offset, info->hv_supply.voltage_limit);
      cm_msg_flush_buffer();
    }

    // when not connected try to force reconnect 
    if (info->fd < 0) {
      int itries;
      itries = 0;
      do {
	itries++;
	info->errcount = SCSHV20_MAX_ERROR_RECONNECT + 1;
      } while ((scshv20_read_all(info, channel) != FE_SUCCESS)&&
	       (itries < 4));
    }

    if ( info->fd >= 0) {
      // set voltage limit value
      mscb_value = limit; // V -> V
      status=mscb_write(info->fd, (unsigned short) (info->settings.node_addr), 
			(unsigned char) (channel*SCSHV20_NCHVARS+SCSHV20_UMAX), &mscb_value, 4);
      if (status != MSCB_SUCCESS) {
        cm_msg(MERROR,"scshv20_set_voltage_limit","%s: Status %d writing voltage "
	       "limit _Umax (%f V) of HV channel %d to node address %d", info->settings.name,
	       status, mscb_value, 
	       channel+info->settings.odb_offset, info->settings.node_addr);
      }
    } else {
      cm_msg(MERROR,"scshv20_set_voltage_limit","%s: Not able to set voltage limit!",
	     info->settings.name);
    }
  } else {
    cm_msg(MLOG, "", "scshv20_set_voltage_limit: %s : **** READONLY **** flag! NOT "
	   "setting voltage limit _Umax of HV channel %d  at node address %d to %f V", 
	   info->settings.name, channel+info->settings.odb_offset,info->settings.node_addr, 
	   limit);
  }
#ifdef MIDEBUG1
  cm_msg(MLOG,"","--scshv20_set_voltage_limit()");
#endif
  cm_msg_flush_buffer();
  return FE_SUCCESS;
}

//----------------------------------------------------------------------------
//---- device driver entry point ---------------------------------------------
//----------------------------------------------------------------------------
INT scshv20(INT cmd, ...)
{
  va_list argptr;
  HNDLE   hKey;
  INT     channel, status;
  float   value, *pvalue;
  DWORD  *pstatus;
  SCSHV20_INFO *info;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

#ifdef MIDEBUG2
  cm_msg(MLOG,"","++scshv20(cmd=%d)", cmd);
#endif

  switch (cmd) {
  case CMD_INIT:
    {
      hKey = va_arg(argptr, HNDLE);
      SCSHV20_INFO **pinfo = va_arg(argptr, SCSHV20_INFO**);
      channel = va_arg(argptr, INT);
      status = scshv20_init(hKey, pinfo, channel);
    }
    break;

  case CMD_EXIT:
    info = va_arg(argptr, SCSHV20_INFO*);
    status = scshv20_exit(info);
    break;

  case CMD_SET:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    value  = (float) va_arg(argptr, double);
    if (value != info->node_vars[channel].uset) // only set when changed
      status = scshv20_set(info, channel, value);
    break;

  case CMD_GET:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    status = scshv20_get(info, channel, pvalue); // does periodic checks
    break;

  case CMD_GET_DEMAND:
  case CMD_GET_DEMAND_DIRECT:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = info->node_vars[channel].uset; // V -> V
    break;

  case CMD_GET_CURRENT:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = info->node_vars[channel].iread; // uA -> uA
    break;

  case CMD_GET_LABEL:
    break;

  case CMD_SET_LABEL:
    break;

  case CMD_SET_CURRENT_LIMIT:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    value = (float) va_arg(argptr, double);
    if (value != info->node_vars[channel].imax) // only set when changed
      status = scshv20_set_current_limit(info, channel, value);
    break;

  case CMD_SET_VOLTAGE_LIMIT:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    value = (float) va_arg(argptr, double);
    if (value != info->node_vars[channel].umax) // only set when changed
      status = scshv20_set_voltage_limit(info, channel, value);    
    break;
      
  case CMD_GET_VOLTAGE_LIMIT:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float *);
    if (pvalue) *pvalue = info->node_vars[channel].umax; // V -> V
    break;
    
  case CMD_GET_THRESHOLD:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = 0.001f;
    break;
      
  case CMD_GET_THRESHOLD_CURRENT:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = 0.001f;
    break;
      
  case CMD_GET_THRESHOLD_ZERO:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = 0.002f;
    break;
      
  case CMD_GET_CURRENT_LIMIT:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = info->node_vars[channel].imax; // uA -> uA 
    break;    
    
  case CMD_SET_RAMPUP:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    value = (float) va_arg(argptr, double);
    break;    
    
  case CMD_SET_RAMPDOWN:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    value = (float) va_arg(argptr, double);
    break;    
    
  case CMD_GET_RAMPUP:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = 0.f;
    break;    
    
  case CMD_GET_RAMPDOWN:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = 0.f;
    break;    
        
  case CMD_SET_TRIP_TIME:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    value = (float) va_arg(argptr, double);
    break;    
    
  case CMD_GET_TRIP_TIME:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pvalue = va_arg(argptr, float*);
    if (pvalue) *pvalue = 0.f;
    break;    
        
  case CMD_START:
    status = FE_SUCCESS;
    break;

  case CMD_STOP:
    status = FE_SUCCESS;
    break;

  case CMD_GET_STATUS:
    info = va_arg(argptr, SCSHV20_INFO*);
    channel = va_arg(argptr, INT);
    pstatus = va_arg(argptr, DWORD *);
    if (pstatus) *pstatus = (DWORD) info->node_vars[channel].ret_status;
    status = FE_SUCCESS;
    break;

  default:
    cm_msg(MERROR, "scshv20 device driver", "Received unknown command %d", cmd);
    status = FE_ERR_DRIVER;
    break;
  }

  va_end(argptr);

#ifdef MIDEBUG2
  cm_msg(MLOG,"","--scshv20()");
  cm_msg_flush_buffer();
#endif
  return status;
}

//----------------------------------------------------------------------------
// end -----------------------------------------------------------------------
//----------------------------------------------------------------------------

