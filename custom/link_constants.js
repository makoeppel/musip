/* This is a javascript translation of link_constant.h */


/* Maximum number of  switching boards */
const MAX_N_SWITCHINGBOARDS = 1;

/* Maximum number of links per switching board */
const MAX_LINKS_PER_SWITCHINGBOARD = 4;

/* Maximum number of FEBs per switching board */
const MAX_FEBS_PER_SWITCHINGBOARD = 4;

/* Maximum number of frontenboards */
const MAX_N_FRONTENDBOARDS = 4;

/* Number of FEBs in final system */
const N_FEBS = [4];

/* Number of Pixel FEBs in final system */
const N_PIXELFEBS = [2];

/* FEB starting number per switching board */
const FEBOFFSET = [0]; 

/* Maximum number of incoming LVDS data links per FEB */
const MAX_LVDS_LINKS_PER_FEB = 24;

const N_FEBS_TOTAL = N_FEBS[0];

/* Identification of FEB by subsystem */
const FEBTYPE = {QuadModule: 6};

/* Sorter has maximum 12 inputs for pixel 3 for tile, 2 for scifi */
const N_SORTER_INPUTS = [12];