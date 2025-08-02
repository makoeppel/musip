/*---------------------------------------------------------------------

  Name:         scshv20.h
  Created by:   Zaher Salman

  Contents:     MIDAS device driver declaration for the MSCB high voltage
                dividers scshv20 (PHV8_600VLC).


---------------------------------------------------------------------*/

/*---- device driver declaration -----------------------------------*/

/*!
 * <p>Device driver for the voltage supply (typically up to 150V max.300V) 
 * for the APD's. It has up to 20 channels and is operated via 
 * MSCB bus master (Node 0 scshv20) attached to the network 
 * -> MSCB<name> is the name of Node 0
 * -> specifying the slot number of the scshv20 as Node address
 * -> scshv20 channel numbers and names are 00-19
 */
INT scshv20(INT cmd, ...);
