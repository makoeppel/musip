/********************************************************************\

  Name:         sps_tcpip.cxx
  Created by:   Andreas Suter (based on Stefan Ritt's tcpip.c)

  Contents:     TCP/IP socket communication routines

\********************************************************************/

#include "midas.h"
#include "msystem.h"

#define SPS_CONNECT_TIMEOUT 5.0 /// connect timeout [s]

static int debug_last = 0, debug_first = TRUE;

typedef struct {
   char host[256];
   int port;
   int debug;
} SPS_TCPIP_SETTINGS;

const char *sps_tcpip_settings_str = 
"Host = STRING : [256] myhost.my.domain\n\
Port = INT : 23\n\
Debug = INT : 0\n\
";

typedef struct {
   SPS_TCPIP_SETTINGS settings;  /// host specific settings
   int fd;                       /// device handle for socket device
} SPS_TCPIP_INFO;

/*----------------------------------------------------------------------------*/

void sps_tcpip_debug(SPS_TCPIP_INFO * info, char *dbg_str)
{
   FILE *f;
   int delta;

   if (debug_last == 0)
      delta = 0;
   else
      delta = ss_millitime() - debug_last;
   debug_last = ss_millitime();

   f = fopen("sps_tcpip.log", "a");

   if (debug_first)
      fprintf(f, "\n==== new session =============\n\n");
   debug_first = FALSE;
   fprintf(f, "{%d} %s\n", delta, dbg_str);

   if (info->settings.debug > 1)
      printf("{%d} %s\n", delta, dbg_str);

   fclose(f);
}

/*------------------------------------------------------------------*/

int sps_tcpip_open(char *host, int port)
{
   struct sockaddr_in bind_addr;
   struct hostent *phe;
   int status, fd, opt, on;
   fd_set fdset;
   struct timeval tv;
   socklen_t len;

#ifdef OS_WINNT
   {
      WSADATA WSAData;

      // Start windows sockets
      if (WSAStartup(MAKEWORD(1, 1), &WSAData) != 0)
         return RPC_NET_ERROR;
   }
#endif

   // create a new socket for connecting to remote server
   fd = socket(AF_INET, SOCK_STREAM, 0);
   if (fd == -1) {
      perror("sps_tcpip_open: socket");
      return fd;
   }

   // tell the system to reuse the socket
   on = 1;
   setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));

   // let OS choose any port number
   memset(&bind_addr, 0, sizeof(bind_addr));
   bind_addr.sin_family = AF_INET;
   bind_addr.sin_addr.s_addr = 0;
   bind_addr.sin_port = 0;

   status = bind(fd, (const sockaddr*) &bind_addr, sizeof(bind_addr));
   if (status < 0) {
      perror("sps_tcpip_open:bind");
      return fd;
   }

   // connect to remote node
   memset(&bind_addr, 0, sizeof(bind_addr));
   bind_addr.sin_family = AF_INET;
   bind_addr.sin_addr.s_addr = 0;
   bind_addr.sin_port = htons((short) port);

#ifdef OS_VXWORKS
   {
      INT host_addr;

      host_addr = hostGetByName(host);
      memcpy((char *) &(bind_addr.sin_addr), &host_addr, 4);
   }
#else
   phe = gethostbyname(host);
   if (phe == NULL) {
     printf("\nsps_tcpip_open: unknown host name %s\n", host);
     return fd;
   }
   memcpy((char *) &(bind_addr.sin_addr), phe->h_addr, phe->h_length);
#endif

   // connect in non-blocking mode
   opt = fcntl(fd, F_GETFL, NULL);
   if (opt < 0) {
     perror("\nsps_tcpip_open: couldn't get fd flags");
     return -1;
   }
   opt |= O_NONBLOCK;
   if (fcntl(fd, F_SETFL, opt) < 0) {
     perror("\nsps_tcpip_open: couldn't set fd flags");
   }

   status = connect(fd, (const sockaddr*) &bind_addr, sizeof(bind_addr));

   if (status < 0) {
     if (errno == EINPROGRESS) {
       // start timeout
       FD_ZERO(&fdset);
       FD_SET(fd, &fdset);

       // wait for connection
       tv.tv_sec = (int)(SPS_CONNECT_TIMEOUT);
       tv.tv_usec = (int)(SPS_CONNECT_TIMEOUT-tv.tv_sec)*1000000;

       while ((status = select(fd+1, NULL, &fdset, NULL, &tv)) < 0) {
         if (errno != EINTR) {
           perror("\nsps_tcpip_open:connect timeout");
           return -1;
         }
       }

       if (status == 0) {
         errno = ETIMEDOUT;
         return -1;
       }

       // get backgound error status
       len = sizeof(status);
       if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &status, &len) < 0) {
         perror("\nsps_tcpip_open:connect, getsockopt failed");
         closesocket(fd);
         return -1;
       }
       if (status) {
         errno = status;
//         perror("\nsps_tcpip_open:connect, background connect failed");
         closesocket(fd);
         return -1;
       }
     } else {
       errno = status;
       perror("\nsps_tcpip_open:connect failed");
       return -1;
     }
   }

   // connected, set socket back to blocking
   opt &= ~O_NONBLOCK;
   if (fcntl(fd, F_SETFL, opt) < 0) {
     perror("\nsps_tcpip_open:connect, failed to set back to blocking");
     return -1;
   }

   return fd;
}

/*----------------------------------------------------------------------------*/

int sps_tcpip_exit(SPS_TCPIP_INFO * info)
{
   closesocket(info->fd);

   return SUCCESS;
}

/*----------------------------------------------------------------------------*/

int sps_tcpip_write(SPS_TCPIP_INFO * info, char *data, int size)
{
   int i;

   if (info->settings.debug) {
      char dbg_str[256];

      sprintf(dbg_str, "write: ");
      for (i = 0; (int) i < size; i++)
         sprintf(dbg_str + strlen(dbg_str), "%X ", data[i]);

      sps_tcpip_debug(info, dbg_str);
   }

   i = send(info->fd, data, size, 0);

   return i;
}

/*----------------------------------------------------------------------------*/

int sps_tcpip_read(SPS_TCPIP_INFO *info, char *data, int size, int millisec)
{
  fd_set readfds;
  struct timeval timeout;
  int i, status, n;

  n = 0;
  memset(data, 0, size);

  do {
      if (millisec > 0) {
         FD_ZERO(&readfds);
         FD_SET(info->fd, &readfds);

         timeout.tv_sec = millisec / 1000;
         timeout.tv_usec = (millisec % 1000) * 1000;

         do {
            status = select(info->fd+1, (fd_set *) &readfds, NULL, NULL, (timeval *) &timeout);

            // if an alarm signal was cought, restart select with reduced timeout
            if (status == -1 && timeout.tv_sec >= WATCHDOG_INTERVAL / 1000)
               timeout.tv_sec -= WATCHDOG_INTERVAL / 1000;

         } while (status == -1); // dont return if an alarm signal was cought

         if (!FD_ISSET(info->fd, &readfds))
           break;
      }

      i = recv(info->fd, data + n, size - n, 0);

      if (i <= 0)
         break;

      n += i;

      if (n >= size)
         break;

   } while (1);

   if (info->settings.debug) {
      char dbg_str[256];

      sprintf(dbg_str, "read: ");

      if (n == 0)
         sprintf(dbg_str + strlen(dbg_str), "<TIMEOUT>");
      else
         for (i = 0; i < n; i++)
            sprintf(dbg_str + strlen(dbg_str), "%X ", data[i]);

      sps_tcpip_debug(info, dbg_str);
   }

   return n;
}

/*----------------------------------------------------------------------------*/

int sps_tcpip_puts(SPS_TCPIP_INFO * info, char *str)
{
   int i;

   if (info->settings.debug) {
      char dbg_str[256];

      sprintf(dbg_str, "puts: %s", str);
      sps_tcpip_debug(info, dbg_str);
   }

   i = send(info->fd, str, strlen(str), 0);
   if (i < 0)
      perror("sps_tcpip_puts");

   return i;
}

/*----------------------------------------------------------------------------*/

int sps_tcpip_gets(SPS_TCPIP_INFO * info, char *str, int size, char *pattern, int millisec)
{
   fd_set readfds;
   struct timeval timeout;
   int i, status, n;

   n = 0;
   memset(str, 0, size);

   do {
      if (millisec > 0) {
         FD_ZERO(&readfds);
         FD_SET(info->fd, &readfds);

         timeout.tv_sec = millisec / 1000;
         timeout.tv_usec = (millisec % 1000) * 1000;

         do {
            status = select(FD_SETSIZE, (fd_set*) &readfds, NULL, NULL, (timeval*) &timeout);

            // if an alarm signal was cought, restart select with reduced timeout
            if (status == -1 && timeout.tv_sec >= WATCHDOG_INTERVAL / 1000)
               timeout.tv_sec -= WATCHDOG_INTERVAL / 1000;

         } while (status == -1);        // dont return if an alarm signal was cought

         if (!FD_ISSET(info->fd, &readfds))
            break;
      }

      i = recv(info->fd, str + n, 1, 0);

      if (i <= 0)
         break;

      n += i;

      if (pattern && pattern[0])
         if (strstr(str, pattern) != NULL)
            break;

      if (n >= size)
         break;

   } while (1);

   if (info->settings.debug) {
      char dbg_str[256];

      sprintf(dbg_str, "gets [%s]: ", pattern);

      if (str[0] == 0)
         sprintf(dbg_str + strlen(dbg_str), "<TIMEOUT>");
      else
         sprintf(dbg_str + strlen(dbg_str), "%s", str);

      sps_tcpip_debug(info, dbg_str);
   }

   return n;
}

/*----------------------------------------------------------------------------*/

int sps_tcpip_init(HNDLE hkey, SPS_TCPIP_INFO **pinfo)
{
  HNDLE hDB, hkeybd;
  INT size, status;
  SPS_TCPIP_INFO *info;

  /* allocate info structure */
  info = (SPS_TCPIP_INFO*) calloc(1, sizeof(SPS_TCPIP_INFO));
  *pinfo = info;

  cm_get_experiment_database(&hDB, NULL);

  /* create SPS TCPIP settings record */
  status = db_create_record(hDB, hkey, "BD", sps_tcpip_settings_str);
  if (status != DB_SUCCESS)
     return FE_ERR_ODB;

  db_find_key(hDB, hkey, "BD", &hkeybd);
  size = sizeof(info->settings);
  db_get_record(hDB, hkeybd, &info->settings, &size, 0);

  /* open port */
  info->fd = sps_tcpip_open(info->settings.host, info->settings.port);
  if (info->fd < 0)
     return FE_ERR_HW;

  return SUCCESS;
}

/*----------------------------------------------------------------------------*/

INT sps_tcpip(INT cmd, ...)
{
   va_list argptr;
   HNDLE hkey;
   INT status, size, timeout;
   SPS_TCPIP_INFO *info;
   char *str, *pattern;

   va_start(argptr, cmd);
   status = FE_SUCCESS;

   switch (cmd) {
   case CMD_INIT: {
        hkey = va_arg(argptr, HNDLE);
        SPS_TCPIP_INFO **pinfo = va_arg(argptr, SPS_TCPIP_INFO**);
        status = sps_tcpip_init(hkey, pinfo);
      }
      break;

   case CMD_EXIT:
      info = va_arg(argptr, SPS_TCPIP_INFO*);
      status = sps_tcpip_exit(info);
      break;

   case CMD_NAME:
      info = va_arg(argptr, SPS_TCPIP_INFO*);
      str = va_arg(argptr, char *);
      strcpy(str, "sps_tcpip");
      break;

   case CMD_WRITE:
      info = va_arg(argptr, SPS_TCPIP_INFO*);
      str = va_arg(argptr, char *);
      size = va_arg(argptr, int);
      status = sps_tcpip_write(info, str, size);
      break;

   case CMD_READ:
      info = va_arg(argptr, SPS_TCPIP_INFO*);
      str = va_arg(argptr, char *);
      size = va_arg(argptr, INT);
      timeout = va_arg(argptr, INT);
      status = sps_tcpip_read(info, str, size, timeout);
      break;

   case CMD_PUTS:
      info = va_arg(argptr, SPS_TCPIP_INFO*);
      str = va_arg(argptr, char *);
      status = sps_tcpip_puts(info, str);
      break;

   case CMD_GETS:
      info = va_arg(argptr, SPS_TCPIP_INFO*);
      str = va_arg(argptr, char *);
      size = va_arg(argptr, INT);
      pattern = va_arg(argptr, char *);
      timeout = va_arg(argptr, INT);
      status = sps_tcpip_gets(info, str, size, pattern, timeout);
      break;

   case CMD_DEBUG:
      info = va_arg(argptr, SPS_TCPIP_INFO*);
      status = va_arg(argptr, INT);
      ((SPS_TCPIP_INFO *) info)->settings.debug = status;
      break;
   }

   va_end(argptr);

   return status;
}
