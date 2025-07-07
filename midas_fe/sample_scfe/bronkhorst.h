/********************************************************************\

  Name:         bronkhorst.h
  Created by:   Andreas Suter 2003/09/12

  Contents:     bronkhorst He flowmeter driver

\********************************************************************/

/*---- device driver declaration -----------------------------------*/
/*!
 * <p>bronkhorst device driver (DD) for <b>reading</b>. It is handling the communication
 * between the bronkhorst mass flow meter and midas.
 */
INT bh_flow_in(INT cmd, ...);

/*!
 * <p> bronkhorst device driver (DD) for <b>setting values</b>. It is handling the
 * communication between the bronkhorst mass flow meter and midas.
 */
INT bh_flow_out(INT cmd, ...);
