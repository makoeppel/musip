/********************************************************************\

  Name:         ets_logout.cxx
  Created by:   Andreas Suter   2005/04/19

  Contents:     Routine to logout out a specific port of the
                ets terminal server.

\********************************************************************/

#include <cstdio>
#include <cstring>
#include <unistd.h>

#include "midas.h"

#include "tcpip_rs232.h"
#include "ets_logout.h"

typedef struct {
  char host[256];
  int  port;
  int  debug;
} TCPIP_RS232_SETTINGS;

typedef struct {
  TCPIP_RS232_SETTINGS settings;
  int fd;                        //!< device handle for socket device 
} TCPIP_RS232_INFO;

extern int tcpip_rs232_open(char *host, int port);
extern int tcpip_rs232_exit(TCPIP_RS232_INFO *info);
extern int tcpip_rs232_puts(TCPIP_RS232_INFO *info, char *str);
extern int tcpip_rs232_gets(TCPIP_RS232_INFO *info, char *str, int size, char *pattern, int millisec);

//----------------------------------------------------------------------------
/*!
 * <p>The 'string' returned by the ets is not a C like string, since it contains characters '\\0'!!<br>
 * str, originating from the command 'show ports 18 status' (18 is the portnumber an can be any
 * of the 32 ports of the rs232 terminal server) should look like
 *
 * <pre>
 * Port 18: Username:                   Physical Port 18 (Idle)
 * 
 *  Access:                  Dynamic    Current Service:             None
 *  Status:                     Idle    Current Node:                None
 *  Sessions:                      0    Current Port:                None
 * 
 *  Input/Output Flow Ctrl:   No/ No    DSR/DTR/CTS/RTS:   No/Yes/Yes/Yes
 * 
 * 
 * Local_34>>
 * </pre>
 *
 * <p><b>return:</b>
 *  - 1 (true), if the port is 'Idle'
 *  - 0 (false), otherwise
 *
 * \param str  return string from the ets of the command 'show ports xx status', where 'xx' is the port number 
 * \param size size of the return string
 */
int ets_logout_successfull(char *str, int size)
{
  int  i, j;
  int  success = 1;
  char buffer[512], *pbuf, subbuf[512];
  
  // init buffer
  memset(buffer, 0, sizeof(buffer));
  pbuf = &buffer[0];
  
  // first remove all '\0' from str
  j=0;
  for (i=0; i<size; i++) {
    if (str[i] != 0) {
      buffer[j] = str[i];
      j++;
    }
  } 
  
  // since buffer is now a c-string, str
  pbuf = strstr(buffer, "Status:");
  if (pbuf == 0) // couldn't find status, i.e. something is very bad :-( 
    return 0;
  
  // isolate sub-string which contains the information
  memset(subbuf, 0, sizeof(subbuf));  
  strncpy(subbuf, pbuf, 32);

  // check is port is Idle
  if (strstr(subbuf, "Idle"))
    success = 1;
  else 
    success = 0;
             
  return success;
}

//------------------------------------------------------------------------
/*!
 * <p>This routine connects to the rs232 terminal server and logouts the
 * port specified in the ETS_INFO structure. It is needed since the
 * rs232 terminal server sometimes is blocking a port (reason: unkown).
 *
 * <p><b>return:</b>
 *  - 1 (true), if OK
 *  - 0 (false), if a problem occured
 *
 * \param info structure containing data in form of the ETS_INFO structure.
 * \param wait waiting timer in (us) between commands.
 * \param detailed_msg flag indicating if detailed messages shall be sent to MIDAS (cm_msg)
 */
int ets_logout(void *info, int wait, int detailed_msg)
{
  TCPIP_RS232_INFO *bd_info;
  int  status;
  char cmd[32], str[1024];
  int  done, count = 0, wait_time = wait; 
  int  success = 1;
  
  bd_info = (TCPIP_RS232_INFO *)info;

  do {  
    // port 23 for telnet
    bd_info->fd = tcpip_rs232_open(bd_info->settings.host, 23);
    if (bd_info->fd <= 0) 
      return 0;
  
    // send logout commands
    usleep(wait_time);
    strcpy(cmd, "\r\n");  
    tcpip_rs232_puts(bd_info, cmd);
    strcpy(cmd, "Username>");
    status = tcpip_rs232_gets(bd_info, str, sizeof(str), cmd, 1000);
  
    usleep(wait_time);
    strcpy(cmd, "s\r\n");  
    tcpip_rs232_puts(bd_info, cmd);
    strcpy(cmd, ">");
    status = tcpip_rs232_gets(bd_info, str, sizeof(str), cmd, 1000);
  
    usleep(wait_time);
    strcpy(cmd, "su\r\n");  
    tcpip_rs232_puts(bd_info, cmd);
    strcpy(cmd, ">");
    status = tcpip_rs232_gets(bd_info, str, sizeof(str), cmd, 1000);
  
    usleep(wait_time);
    strcpy(cmd, "system\r\n");  
    tcpip_rs232_puts(bd_info, cmd);
    strcpy(cmd, ">>");
    status = tcpip_rs232_gets(bd_info, str, sizeof(str), cmd, 1000);
  
    usleep(wait_time);
    sprintf(cmd, "logout port %d\r\n", bd_info->settings.port-4000);
    tcpip_rs232_puts(bd_info, cmd);
    strcpy(cmd, ">>");
    status = tcpip_rs232_gets(bd_info, str, sizeof(str), cmd, 1000);
  
    usleep(wait_time);
    sprintf(cmd, "show ports %d status\r\n", bd_info->settings.port-4000);
    tcpip_rs232_puts(bd_info, cmd);
    strcpy(cmd, ">>");
    status = tcpip_rs232_gets(bd_info, str, sizeof(str), cmd, 1000);
  
    if (ets_logout_successfull(str, status)) {
      done = 1;
    } else { 
      done = 0;
      count++;
      wait_time += 1e4; // increase wait time inbetween sending commands by 10(ms)
    }
      
    usleep(wait_time);
    sprintf(cmd, "logout \r\n");
    tcpip_rs232_puts(bd_info, cmd);
    
    tcpip_rs232_exit(bd_info);

  } while (!done && (count < 5)); // try maximal 5 times
  
  if (detailed_msg) {
    if (count < 5) {
      success = 1;
      cm_msg(MINFO,  "ets_logout", "ets_logout: logged out port %d of ets %s", 
             bd_info->settings.port, bd_info->settings.host);
    } else {
      success = 0;
      cm_msg(MERROR, "ets_logout", "ets_logout: couldn't logout port %d of ets %s", 
             bd_info->settings.port, bd_info->settings.host);
    }
  }

  return success;
}
