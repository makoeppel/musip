/********************************************************************\

  Name:         LakeShore340.h
  Created by:   Andreas Suter 2003/10/22
  Modified by:  Zaher Salman 30 Mar 2026

  Contents:     Channel Access device driver function declarations

\********************************************************************/

/*---- device driver declaration -----------------------------------*/
/*!
 * <p> LakeShore 340 device driver (DD). It is handling the communication
 * between the LS340 and midas.
 *
 * <p>LS340_in is the part, which handles the communication LS340->MIDAS
 *
 * <p><b>RS232:</b> 19200 baud, 8 data bits, 1 stop bit, no parity bit,
 * no hardware protocol, no software protocol,
 * termination: \ r\\n (CR LF)
 *
 * <p>Device Driver info structure entries are organized as:
 * <pre>
 *  info
 *    |___ ls340_odb_names
 *    |      |
 *    |      |__ ls_name
 *    |      |__ names_in
 *    |      |__ names_out
 *    |
 *    |___ ls340_settings
 *           |
 *           |__ intern
 *           |     |__ detailed_messages
 *           |     |__ ets_in_use
 *           |     |__ no_connection
 *           |     |__ reconnect_timeout
 *           |     |__ read_timeout
 *           |     |__ read_raw_data
 *           |     |__ odb_offset
 *           |     |__ odb_ouput
 *           |     |__ remote
 *           |     |__ no_of_senors
 *           |
 *           |__ loop1
 *           |     |__ ctrl_ch
 *           |     |__ setpoint_limit
 *           |     |__ max_current_tag
 *           |     |__ max_heater_range
 *           |     |__ heater_resitance
 *           |
 *           |__ sensor
 *           |     |__ datetime
 *           |     |__ type
 *           |     |__ channel
 *           |     |__ name
 *           |     |__ raw_value
 *           |
 *           |__ zone
 *                 |__ zone1
 *                 |__ zone2
 *                 |__ zone3
 *                 |__ zone4
 *                 |__ zone5
 *                 |__ zone6
 *                 |__ zone7
 *                 |__ zone8
 *                 |__ zone9
 *                 |__ zone10
 * </pre>
 *
 * - ls340_odb_names: stores the Input/Output Names which are default to the equipment
 *                   e.g. 'Remote (1/0)'
 *     - ls_name:      global label for this equipment (e.g. Moderator)
 *     - names_in:     array with required default input names
 *     - names_out:    array with required default output names
 *
 *  - ls340_settings:  keeps configuration settings, etc.
 *     - intern:           private variables
 *        - ets_in_use:    flag showing if the ets rs232 terminal server is used (1=yes/0=no)
 *        - reconnection_timeout: timeout in (sec) after which a reconnection attempt is made 
 *        - odb_offset:    odb offset for the 'set point' within the output variables.
 *                         Needed by the forced update routine.
 *        - odb_output:    odb output variable path. Needed by the forced update routine.
 *        - remote:        stores if the LS340 is computer controlled of not
 *        - no_of_sensors: # used sensors. Max. possible are 10, A and B are internal to the LS340
 *                         C1-C4 and D1-D4 are coming from the LS3468 input card
 *                         The C/D blocks can only handle one type of sensor each at the time
 *                         i.e. if C1 is a PT100, C2-C4 only can be PT100 as well.
 *     - loop1:        keeps control loop1 related stuff
 *        - ctrl_ch:         which channel is used for the controll loop1
 *        - setpoint_limit:  maximal allowed setpoint
 *        - max_current_tag: limits the max. current for the heater,
 *                         1->0.25A, 2->0.5A, 3->1.0A, 4->2.0A
 *        - max_heater_range: upper limit for the heater range, i.e. the
 *                           the demand heater range must be between >= 0 and <= max_heater_range
 *                           (see LakeShore340 manual, 6-9, 9-27)
 *        - heater_resitance: resistance of the loop1 heater. It is only used to compare with the
 *                           readback value of the LS340. If these value differ more than 2 Ohm,
 *                           an error message is sent out.
 *     - sensor:       info related to the sensors
 *        - datetime:        current date and time, see LakeShore340 manual, p.9-30
 *        - type:            1-12, see LakeShore340 manual, p.9-33 (1 -Si diode, 8 - Cernox)
 *        - curve:           calibration curve, see LakeShore340 manual, p.9-33
 *        - channel:         A, B, C1-C4, D1-D4
 *        - name:            name for each channel
 *        - raw_value:       raw input values, see LakeShore340 manual, p.9-42
 *
 *     - zone: zone1 to zone10 are the zone setting strings see LakeShore340 manual, p.9-42
 *             the zone strings have the syntax: loop, zone, top_temp, P, I, D, man_out, range
 */
INT ls340_in(INT cmd, ...);
/*!
 * <p> LakeShore 340 device driver (DD). It is handling the communication
 * between the LS340 and midas.
 *
 * <p>LS340_out is the part, which handles the communication LS340<-MIDAS
 */
INT ls340_out(INT cmd, ...);
