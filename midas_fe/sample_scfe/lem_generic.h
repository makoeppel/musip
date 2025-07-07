/********************************************************************\

  Name:         lem_generic.h
  Created by:   Stefan Ritt
                adopted by Andreas Suter and Thomas Prokscha to have
                a forced update every minute even if the value did
                not change. 

  Contents:     Generic Class Driver header file

\********************************************************************/

/* class driver routines */
INT cd_gen(INT cmd, PEQUIPMENT pequipment);
INT cd_gen_read(char *pevent, int);
