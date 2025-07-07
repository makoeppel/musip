/********************************************************************\

  Name:         tcpip_rs232.cxx
  Created by:   Stefan Ritt
		Thomas Prokscha: in tcpip_puts: skip sending of '\0'
		which may produce errors with the serial device.

  Contents:     TCP/IP socket communication routines

\********************************************************************/

#include "midas.h"
#include "msystem.h"

static int debug_last = 0, debug_first = TRUE;

typedef struct {
  char host[256];
  int  port;
  int  debug;
} TCPIP_RS232_SETTINGS;

#define TCPIP_RS232_SETTINGS_STR "\
Host = STRING : [256] myhost.my.domain\n\
Port = INT : 23\n\
Debug = INT : 0\n\
"

typedef struct {
  TCPIP_RS232_SETTINGS settings;
  int fd;                        /* device handle for socket device */
} TCPIP_RS232_INFO;

/*----------------------------------------------------------------------------*/

void tcpip_rs232_debug(TCPIP_RS232_INFO *info, char *dbg_str)
{
  FILE *f;
  int delta;

  if (debug_last == 0)
    delta = 0;
  else
    delta = ss_millitime() - debug_last;
  debug_last = ss_millitime();

  f = fopen("tcpip_rs232.log", "a");

  if (debug_first)
    fprintf(f, "\n==== new session =============\n\n");
  debug_first = FALSE;
  fprintf(f, "{%d} %s\n", delta, dbg_str);

  if (info->settings.debug > 1)
    printf("{%d} %s\n", delta, dbg_str);

  fclose(f);
}

/*------------------------------------------------------------------*/

int tcpip_rs232_open(char *host, int port)
{
  struct sockaddr_in   bind_addr;
  struct hostent       *phe;
  int                  status, fd;

#ifdef OS_WINNT
  {
  WSADATA WSAData;

  /* Start windows sockets */
  if ( WSAStartup(MAKEWORD(1,1), &WSAData) != 0)
    return RPC_NET_ERROR;
  }
#endif

  /* create a new socket for connecting to remote server */
  fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd == -1)
    {
    perror("tcpip_rs232_open: socket");
    return fd;
    }

  /* let OS choose any port number */
  memset(&bind_addr, 0, sizeof(bind_addr));
  bind_addr.sin_family      = AF_INET;
  bind_addr.sin_addr.s_addr = 0;
  bind_addr.sin_port        = 0;

  status = bind(fd, (const sockaddr*)&bind_addr, sizeof(bind_addr));
  if (status < 0)
    {
    perror("tcpip_rs232_open:bind");
    return fd;
    }

  /* connect to remote node */
  memset(&bind_addr, 0, sizeof(bind_addr));
  bind_addr.sin_family      = AF_INET;
  bind_addr.sin_addr.s_addr = 0;
  bind_addr.sin_port        = htons((short) port);

#ifdef OS_VXWORKS
  {
  INT host_addr;

  host_addr = hostGetByName(host);
  memcpy((char *)&(bind_addr.sin_addr), &host_addr, 4);
  }
#else
  phe = gethostbyname(host);
  if (phe == NULL)
    {
    printf("\ntcpip_rs232_open: unknown host name %s\n", host);
    return -1;
    }
  memcpy((char *)&(bind_addr.sin_addr), phe->h_addr, phe->h_length);
#endif

#ifdef OS_UNIX
  do
    {
    status = connect(fd, (const sockaddr*) &bind_addr, sizeof(bind_addr));

    /* don't return if an alarm signal was cought */
    } while (status == -1 && errno == EINTR); 
#else
  status = connect(fd, (void *) &bind_addr, sizeof(bind_addr));
#endif  

  if (status != 0)
    {
    perror("tcpip_rs232_open:connect");
    return -1;
    }

  return fd;
}

/*----------------------------------------------------------------------------*/

int tcpip_rs232_exit(TCPIP_RS232_INFO *info)
{
  closesocket(info->fd);

  return SUCCESS;
}

/*----------------------------------------------------------------------------*/

int tcpip_rs232_write(TCPIP_RS232_INFO *info, char *data, int size)
{
  int i;
 
  if (info->settings.debug)
    {
    char dbg_str[256];

    sprintf(dbg_str, "write: ");
    for (i=0 ; (int)i<size ; i++)
      sprintf(dbg_str+strlen(dbg_str), "%X ", data[i]);

    tcpip_rs232_debug(info, dbg_str);
    }
 
  i = send(info->fd, data, size, 0);

  return i;
}

/*----------------------------------------------------------------------------*/ 

int tcpip_rs232_read(TCPIP_RS232_INFO *info, char *data, int size, int millisec)
{
  fd_set         readfds;
  struct timeval timeout;
  int            i, status, n;

  n = 0;
  memset(data, 0, size);

  do
    {
    if (millisec > 0)
      {
      FD_ZERO(&readfds);
      FD_SET(info->fd, &readfds);

      timeout.tv_sec  = millisec / 1000;
      timeout.tv_usec = (millisec % 1000) * 1000;

      do
	      {
	      status = select(FD_SETSIZE, &readfds, NULL, NULL, &timeout);

	      /* if an alarm signal was cought, restart select with reduced timeout */
	      if (status == -1 && timeout.tv_sec >= WATCHDOG_INTERVAL / 1000)
          timeout.tv_sec -= WATCHDOG_INTERVAL / 1000;

	      } while (status == -1); /* dont return if an alarm signal was cought */

      if (!FD_ISSET(info->fd, &readfds))
        break;
      }

    i = recv(info->fd, data+n, 1, 0);

    if (i<=0)
      break;

    n++;

    if (n >= size)
      break;

    } while (1); /* while (buffer[n-1] && buffer[n-1] != 10); */

  if (info->settings.debug)
    {
    char dbg_str[256];

    sprintf(dbg_str, "read: ");

    if (n == 0)
      sprintf(dbg_str+strlen(dbg_str), "<TIMEOUT>");
    else
      for (i=0 ; i<n ; i++)
        sprintf(dbg_str+strlen(dbg_str), "%X ", data[i]);

    tcpip_rs232_debug(info, dbg_str);
    }

  return n;
}

/*----------------------------------------------------------------------------*/

int tcpip_rs232_puts(TCPIP_RS232_INFO *info, char *str)
{
  int i;
 
  if (info->settings.debug)
    {
    char dbg_str[256];

    sprintf(dbg_str, "puts: %s, strlen = %d", str, (int)strlen(str)); 
    tcpip_rs232_debug(info, dbg_str);
    }

//  i = send(info->fd, str, strlen(str)+1, 0);
  i = send(info->fd, str, strlen(str), 0);
  if (i < 0) 
    perror("tcpip_rs232_puts");

  return i;
}

/*----------------------------------------------------------------------------*/ 

int tcpip_rs232_gets(TCPIP_RS232_INFO *info, char *str, int size, char *pattern, int millisec)
{
  fd_set         readfds;
  struct timeval timeout;
  int            i, status, n;

  n = 0;
  memset(str, 0, size);

  do
  {
    if (millisec > 0)
      {
      FD_ZERO(&readfds);
      FD_SET(info->fd, &readfds);

      timeout.tv_sec  = millisec / 1000;
      timeout.tv_usec = (millisec % 1000) * 1000;

      do
	      {
	      status = select(FD_SETSIZE, &readfds, NULL, NULL, &timeout);

	      /* if an alarm signal was cought, restart select with reduced timeout */
	      if (status == -1 && timeout.tv_sec >= WATCHDOG_INTERVAL / 1000)
          timeout.tv_sec -= WATCHDOG_INTERVAL / 1000;

	      } while (status == -1); /* dont return if an alarm signal was cought */

      if (!FD_ISSET(info->fd, &readfds))
        break;
      }

    i = recv(info->fd, str+n, 1, 0);

    if (i<=0)
      break;

    n += i;

    if (pattern && pattern[0])
      if (strstr(str, pattern) != NULL)
        break;

    if (n >= size)
      break;

  } while (1); /* while (buffer[n-1] && buffer[n-1] != 10); */

  if (info->settings.debug)
    {
    char dbg_str[256];

    sprintf(dbg_str, "gets [%s]: ", pattern);

    if (str[0] == 0)
      sprintf(dbg_str+strlen(dbg_str), "<TIMEOUT>");
    else
      sprintf(dbg_str+strlen(dbg_str), "%s", str);

    tcpip_rs232_debug(info, dbg_str);
    }
 
  return n;
}

/*----------------------------------------------------------------------------*/

int tcpip_rs232_init(HNDLE hkey, TCPIP_RS232_INFO **pinfo)
{
  HNDLE         hDB, hkeybd;
  INT           size, status;
  TCPIP_RS232_INFO *info;

  /* allocate info structure */
  info = (TCPIP_RS232_INFO*)calloc(1, sizeof(TCPIP_RS232_INFO));
  *pinfo = info;

  cm_get_experiment_database(&hDB, NULL);

  /* create TCPIP_RS232 settings record */
  status = db_create_record(hDB, hkey, "BD", TCPIP_RS232_SETTINGS_STR);
  if (status != DB_SUCCESS)
    return FE_ERR_ODB;

  db_find_key(hDB, hkey, "BD", &hkeybd);
  size = sizeof(info->settings);
  db_get_record(hDB, hkeybd, &info->settings, &size, 0);
 
  /* open port */
  info->fd = tcpip_rs232_open(info->settings.host, info->settings.port);
  if (info->fd < 0)
    return FE_ERR_HW;

  return SUCCESS;
}

/*----------------------------------------------------------------------------*/

INT tcpip_rs232(INT cmd, ...)
{
  va_list    argptr;
  HNDLE      hkey;
  INT        status, size, timeout;
  TCPIP_RS232_INFO *info;
  char       *str, *pattern;

  va_start(argptr, cmd);
  status = FE_SUCCESS;

  switch (cmd) {
    case CMD_INIT:
      {
        hkey = va_arg(argptr, HNDLE);
        TCPIP_RS232_INFO **pinfo = va_arg(argptr, TCPIP_RS232_INFO **);
        status = tcpip_rs232_init(hkey, pinfo);
      }
      break;

    case CMD_EXIT:
      info = va_arg(argptr, TCPIP_RS232_INFO *);
      status = tcpip_rs232_exit(info);
      break;

    case CMD_NAME:
      info = va_arg(argptr, TCPIP_RS232_INFO *);
      str = va_arg(argptr, char *);
      strcpy(str, "tcpip_rs232");
      break;

    case CMD_WRITE:
      info = va_arg(argptr, TCPIP_RS232_INFO *);
      str = va_arg(argptr, char *);
      size = va_arg(argptr, int);
      status = tcpip_rs232_write(info, str, size);
      break;

    case CMD_READ:
      info = va_arg(argptr, TCPIP_RS232_INFO *);
      str = va_arg(argptr, char *);
      size = va_arg(argptr, INT);
      timeout = va_arg(argptr, INT);
      status = tcpip_rs232_read(info, str, size, timeout);
      break;

    case CMD_PUTS:
      info = va_arg(argptr, TCPIP_RS232_INFO *);
      str = va_arg(argptr, char *);
      status = tcpip_rs232_puts(info, str);
      break;

    case CMD_GETS:
      info = va_arg(argptr, TCPIP_RS232_INFO *);
      str = va_arg(argptr, char *);
      size = va_arg(argptr, INT);
      pattern = va_arg(argptr, char *);
      timeout = va_arg(argptr, INT);
      status = tcpip_rs232_gets(info, str, size, pattern, timeout);
      break;

    case CMD_DEBUG:
      info = va_arg(argptr, TCPIP_RS232_INFO *);
      status = va_arg(argptr, INT);
      ((TCPIP_RS232_INFO*)info)->settings.debug = status;
      break;
    }

  va_end(argptr);

  return status;
}
