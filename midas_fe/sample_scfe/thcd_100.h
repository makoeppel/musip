/*---------------------------------------------------------------------

  Name:         thcd_100.h
  Created by:   Andreas Suter 2015/05/08

  Contents:     device driver for the THCD-100 Hastings Flow Monitor

---------------------------------------------------------------------*/

/*---- device driver declaration -----------------------------------*/

/*!
 * <p>THCD-100 Hastings flow monitor device driver (DD) input part. It is handling the communication
 * between the THCD-100 and midas.
 */
INT thcd_100_in(INT cmd, ...);

/*!
 * <p>THCD-100 Hastings flow monitor device driver (DD) output part. It is handling the communication
 * between the THCD-100 and midas.
 */
INT thcd_100_out(INT cmd, ...);
