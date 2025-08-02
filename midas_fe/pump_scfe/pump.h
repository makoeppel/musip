/*---------------------------------------------------------------------

  Name:         pump.h
  Created by:   Andreas Suter 2016/10/18

  Contents:     pump vacuum controller

---------------------------------------------------------------------*/

#define PUMP_IN_VARS  10   //!< number of input variables
#define PUMP_OUT_VARS  1   //!< number of output variables

/*---- device driver declaration -----------------------------------*/

//---------------------------------------------------------------------------------
/*!
 * <p>pump vacuum controller device driver (read routines) entry function.
 * Establishes the communication with the SPS controll unit of the PUMP (QSM610-612)
 * and reads the state of the pumps, valves, and the pressure values.
 */
INT pump_in(INT cmd, ...);  // read routines
INT pump_out(INT cmd, ...);  // write routines

