/********************************************************************\

  Name:         LakeShore336.h
  Created by:   Andreas Suter 2019/03/14

  Contents:     device driver function declarations for the LakeShore 336

\********************************************************************/

/*---- device driver declaration -----------------------------------*/
/*!
 * <p> LakeShore 336 device driver (DD). It is handling the communication
 * between the LS336 and midas.
 *
 * <p>LS336_in is the part, which handles the communication LS336->MIDAS
 *
 * <p>The communication is handled via the TCP/IP interface of the LS336
 *
 * <p>Device Driver info structure entries are organized as:
 * <pre>
 *  info
 *    |__ ODB Names
 *    |     |__ LS336 Name
 *    |     |__ Names In
 *    |     |__ Names Out
 *    |
 *    |__ Intern
 *    |     |__ Detailed Messages
 *    |     |__ Read Raw Data
 *    |     |__ ODB Offset
 *    |     |__ ODB Output Path
 *    |     |__ # Sensors
 *    |
 *    |__ Sensors
 *    |     |__ Sensor Type
 *    |     |__ Calibration Curve
 *    |     |__ Channel
 *    |     |__ Sensor Name
 *    |     |__ Raw Input Channel
 *    |
 *    |__ Loop1
 *    |     |__ CTRL_CH
 *    |     |__ Temperature Limit
 *    |     |__ Max. Current Tag
 *    |     |__ Max. User Current
 *    |     |__ Heater Resistance Tag (0=25 Ohm , 1=50 Ohm)
 *    |
 *    |__ Loop2
 *    |     |__ CTRL_CH
 *    |     |__ Temperature Limit
 *    |     |__ Max. Current Tag
 *    |     |__ Max. User Current
 *    |     |__ Heater Resistance Tag (0=25 Ohm , 1=50 Ohm)
 *    |
 *    |__ Zone
 *          |__ Zone
 * </pre>
 *
 * - ODB Names: stores the Input/Output Names which are default to the equipment
 *     - LS336 Name: global label for this equipment (e.g. Moderator)
 *     - Names In:   array with required default input names
 *     - Names Out:  array with required default output names
 *
 * - Intern: private variables
 *     - Detailed Messages: If flag is enabled, much more info is sent to the MIDAS message queue
 *     - Read Raw Data:     If flag is enabled, all sensor readings are recorded - needed for calibration
 *     - ODB Offset:        ODB offset for the 'set point' within the output variables.
 *                          Needed by the forced update routine.
 *     - ODB Output Path:   ODB output variable path. Needed by the forced update routine.
 *     - # Sensors:         Number of used sensors. Max. possible are 8, A-C D1-D5
 *
 * - Sensors:
 *     - Sensor Type:       see INTYPE cmd
 *     - Calibration Curve: see INCRV cmd
 *     - Channel:           internal channel order
 *     - Sensor Name:       Name if the sensor used in the ODB
 *     - Raw Input Channel:
 *
 * - Loop1/2: keeps control loop1 related stuff
 *     - CTRL_CH:           Which channel is used for the controll loop1
 *     - Temperature Limit: Maximal allowed temperature
 *     - Max. Current Tag:  Limits the max. current for the heater (see HTRSET cmd)
 *     - Max. User Current: Upper limit for the output heater current (see HTRSET cmd)
 *     - Heater Resitance Tag: resistance of the loop1 heater. (see HTRSET cmd)
 *
 * - Zone: zone[1..8] (see ZONE cmd)
 */
INT ls336_in(INT cmd, ...);
/*!
 * <p> LakeShore 336 device driver (DD). It is handling the communication
 * between the LS336 and midas.
 *
 * <p>LS336_out is the part, which handles the communication LS336<-MIDAS
 */
INT ls336_out(INT cmd, ...);
