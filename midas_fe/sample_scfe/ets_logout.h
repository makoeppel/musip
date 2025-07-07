/********************************************************************\

  Name:         ets_logout.h
  Created by:   Andreas Suter   2005/04/19

  Contents:     declaration of a routine to logout out a specific port
                of the ets terminal server.

\********************************************************************/

#ifndef _ETS_LOGOUT_
#define _ETS_LOGOUT_

int ets_logout(void *info, int wait, int detailed_msg);

#endif // _ETS_LOGOUT_
