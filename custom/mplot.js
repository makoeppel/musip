//
// Name:         mplot.js
// Created by:   Stefan Ritt
//
// Contents:     JavaScript graph plotting routines
//
// Note: please load midas.js, mhttpd.js and control.js before mplot.js
//

/** 
 * Default parameters for the MPlotGraph constructor
 * These parameters control the formatting of the whole graph (figure)
 * Only a subset of the below keys are needed to be passed to the MPlotGraph constructor. The rest are taken as below. 
 */
let defaultGraphColor = [                   // color sequence when adding plots
   "#00AAFF", "#FF9000", "#FF00A0", "#00C030",
   "#A0C0D0", "#D0A060", "#C04010", "#807060",
   "#F0C000", "#2090A0", "#D040D0", "#90B000",
   "#B0B040", "#B0B0FF", "#FFA0A0", "#A0FFA0"
];

// Have a CVD friendly colour palette for 2D plots (Crameri, F. (2018a), Scientific colour maps. Zenodo.
// http://doi.org/10.5281/zenodo.1243862): lajolla colour palette
let colorPalette = [
    'color(srgb 0.098791 0.099669 0.000088)',
    'color(srgb 0.102398 0.100814 0.002016)',
    'color(srgb 0.105856 0.102014 0.003932)',
    'color(srgb 0.109170 0.103273 0.005840)',
    'color(srgb 0.112474 0.104439 0.007746)',
    'color(srgb 0.115773 0.105695 0.009656)',
    'color(srgb 0.119086 0.106937 0.011760)',
    'color(srgb 0.122370 0.108079 0.013670)',
    'color(srgb 0.125765 0.109344 0.015595)',
    'color(srgb 0.129083 0.110536 0.017532)',
    'color(srgb 0.132479 0.111731 0.019486)',
    'color(srgb 0.135832 0.112947 0.021462)',
    'color(srgb 0.139249 0.114096 0.023462)',
    'color(srgb 0.142721 0.115314 0.025492)',
    'color(srgb 0.146188 0.116556 0.027555)',
    'color(srgb 0.149714 0.117765 0.029655)',
    'color(srgb 0.153215 0.119010 0.031796)',
    'color(srgb 0.156820 0.120223 0.033961)',
    'color(srgb 0.160419 0.121466 0.036412)',
    'color(srgb 0.164141 0.122736 0.038709)',
    'color(srgb 0.167834 0.124034 0.041058)',
    'color(srgb 0.171613 0.125365 0.043253)',
    'color(srgb 0.175448 0.126668 0.045600)',
    'color(srgb 0.179347 0.128031 0.047889)',
    'color(srgb 0.183292 0.129370 0.050218)',
    'color(srgb 0.187338 0.130777 0.052456)',
    'color(srgb 0.191398 0.132157 0.054749)',
    'color(srgb 0.195552 0.133574 0.057052)',
    'color(srgb 0.199759 0.135025 0.059373)',
    'color(srgb 0.204093 0.136445 0.061524)',
    'color(srgb 0.208438 0.137979 0.063852)',
    'color(srgb 0.212867 0.139428 0.066100)',
    'color(srgb 0.217399 0.141015 0.068401)',
    'color(srgb 0.221979 0.142548 0.070615)',
    'color(srgb 0.226668 0.144129 0.072894)',
    'color(srgb 0.231424 0.145750 0.075110)',
    'color(srgb 0.236255 0.147356 0.077324)',
    'color(srgb 0.241152 0.148993 0.079626)',
    'color(srgb 0.246126 0.150675 0.082053)',
    'color(srgb 0.251203 0.152365 0.084452)',
    'color(srgb 0.256313 0.154101 0.086925)',
    'color(srgb 0.261529 0.155889 0.089444)',
    'color(srgb 0.266808 0.157647 0.092067)',
    'color(srgb 0.272159 0.159456 0.094750)',
    'color(srgb 0.277620 0.161336 0.097443)',
    'color(srgb 0.283142 0.163196 0.100219)',
    'color(srgb 0.288738 0.165057 0.103107)',
    'color(srgb 0.294406 0.167020 0.106026)',
    'color(srgb 0.300173 0.168975 0.108981)',
    'color(srgb 0.306035 0.170932 0.112027)',
    'color(srgb 0.311930 0.172936 0.115071)',
    'color(srgb 0.317951 0.174991 0.118267)',
    'color(srgb 0.324033 0.177046 0.121403)',
    'color(srgb 0.330210 0.179135 0.124669)',
    'color(srgb 0.336449 0.181231 0.127997)',
    'color(srgb 0.342792 0.183380 0.131345)',
    'color(srgb 0.349191 0.185585 0.134755)',
    'color(srgb 0.355681 0.187779 0.138191)',
    'color(srgb 0.362234 0.189962 0.141663)',
    'color(srgb 0.368872 0.192199 0.145203)',
    'color(srgb 0.375570 0.194487 0.148714)',
    'color(srgb 0.382348 0.196763 0.152311)',
    'color(srgb 0.389208 0.199025 0.155973)',
    'color(srgb 0.396126 0.201339 0.159588)',
    'color(srgb 0.403111 0.203702 0.163305)',
    'color(srgb 0.410167 0.206055 0.167007)',
    'color(srgb 0.417279 0.208396 0.170707)',
    'color(srgb 0.424448 0.210766 0.174453)',
    'color(srgb 0.431694 0.213130 0.178213)',
    'color(srgb 0.438972 0.215530 0.181919)',
    'color(srgb 0.446327 0.217923 0.185715)',
    'color(srgb 0.453734 0.220327 0.189437)',
    'color(srgb 0.461197 0.222709 0.193178)',
    'color(srgb 0.468712 0.225073 0.196918)',
    'color(srgb 0.476277 0.227476 0.200586)',
    'color(srgb 0.483887 0.229823 0.204310)',
    'color(srgb 0.491568 0.232214 0.207943)',
    'color(srgb 0.499268 0.234569 0.211570)',
    'color(srgb 0.507032 0.236904 0.215121)',
    'color(srgb 0.514841 0.239198 0.218665)',
    'color(srgb 0.522691 0.241494 0.222129)',
    'color(srgb 0.530585 0.243739 0.225557)',
    'color(srgb 0.538526 0.245982 0.228915)',
    'color(srgb 0.546498 0.248220 0.232200)',
    'color(srgb 0.554505 0.250369 0.235417)',
    'color(srgb 0.562556 0.252534 0.238525)',
    'color(srgb 0.570622 0.254658 0.241596)',
    'color(srgb 0.578732 0.256723 0.244541)',
    'color(srgb 0.586863 0.258774 0.247442)',
    'color(srgb 0.595019 0.260780 0.250209)',
    'color(srgb 0.603195 0.262762 0.252927)',
    'color(srgb 0.611383 0.264701 0.255529)',
    'color(srgb 0.619582 0.266626 0.258022)',
    'color(srgb 0.627779 0.268526 0.260449)',
    'color(srgb 0.635979 0.270408 0.262772)',
    'color(srgb 0.644165 0.272236 0.264987)',
    'color(srgb 0.652346 0.274100 0.267119)',
    'color(srgb 0.660500 0.275957 0.269192)',
    'color(srgb 0.668632 0.277791 0.271140)',
    'color(srgb 0.676724 0.279653 0.273014)',
    'color(srgb 0.684764 0.281520 0.274801)',
    'color(srgb 0.692762 0.283434 0.276532)',
    'color(srgb 0.700683 0.285371 0.278167)',
    'color(srgb 0.708537 0.287376 0.279741)',
    'color(srgb 0.716305 0.289458 0.281228)',
    'color(srgb 0.723970 0.291602 0.282691)',
    'color(srgb 0.731535 0.293812 0.284053)',
    'color(srgb 0.738987 0.296143 0.285370)',
    'color(srgb 0.746299 0.298576 0.286641)',
    'color(srgb 0.753474 0.301124 0.287867)',
    'color(srgb 0.760502 0.303810 0.289058)',
    'color(srgb 0.767360 0.306647 0.290172)',
    'color(srgb 0.774048 0.309620 0.291279)',
    'color(srgb 0.780555 0.312723 0.292319)',
    'color(srgb 0.786871 0.316022 0.293327)',
    'color(srgb 0.792976 0.319454 0.294303)',
    'color(srgb 0.798871 0.323061 0.295249)',
    'color(srgb 0.804548 0.326810 0.296165)',
    'color(srgb 0.809995 0.330734 0.297055)',
    'color(srgb 0.815214 0.334831 0.297889)',
    'color(srgb 0.820195 0.339049 0.298716)',
    'color(srgb 0.824940 0.343407 0.299513)',
    'color(srgb 0.829449 0.347900 0.300265)',
    'color(srgb 0.833714 0.352506 0.300996)',
    'color(srgb 0.837741 0.357235 0.301703)',
    'color(srgb 0.841532 0.362040 0.302385)',
    'color(srgb 0.845096 0.366931 0.303044)',
    'color(srgb 0.848438 0.371886 0.303681)',
    'color(srgb 0.851566 0.376920 0.304295)',
    'color(srgb 0.854494 0.381975 0.304888)',
    'color(srgb 0.857225 0.387073 0.305464)',
    'color(srgb 0.859779 0.392203 0.306015)',
    'color(srgb 0.862161 0.397340 0.306537)',
    'color(srgb 0.864380 0.402483 0.307036)',
    'color(srgb 0.866454 0.407633 0.307521)',
    'color(srgb 0.868402 0.412782 0.308001)',
    'color(srgb 0.870213 0.417898 0.308478)',
    'color(srgb 0.871931 0.423001 0.308939)',
    'color(srgb 0.873540 0.428101 0.309379)',
    'color(srgb 0.875064 0.433164 0.309804)',
    'color(srgb 0.876507 0.438212 0.310225)',
    'color(srgb 0.877887 0.443229 0.310636)',
    'color(srgb 0.879200 0.448215 0.311034)',
    'color(srgb 0.880462 0.453182 0.311418)',
    'color(srgb 0.881681 0.458116 0.311798)',
    'color(srgb 0.882852 0.463019 0.312180)',
    'color(srgb 0.883997 0.467910 0.312564)',
    'color(srgb 0.885105 0.472767 0.312945)',
    'color(srgb 0.886191 0.477603 0.313322)',
    'color(srgb 0.887249 0.482417 0.313691)',
    'color(srgb 0.888294 0.487206 0.314051)',
    'color(srgb 0.889321 0.491971 0.314404)',
    'color(srgb 0.890332 0.496706 0.314759)',
    'color(srgb 0.891333 0.501443 0.315120)',
    'color(srgb 0.892326 0.506138 0.315483)',
    'color(srgb 0.893303 0.510831 0.315840)',
    'color(srgb 0.894281 0.515501 0.316190)',
    'color(srgb 0.895249 0.520158 0.316534)',
    'color(srgb 0.896210 0.524808 0.316878)',
    'color(srgb 0.897169 0.529444 0.317222)',
    'color(srgb 0.898117 0.534052 0.317567)',
    'color(srgb 0.899069 0.538669 0.317912)',
    'color(srgb 0.900015 0.543262 0.318255)',
    'color(srgb 0.900957 0.547848 0.318598)',
    'color(srgb 0.901898 0.552429 0.318940)',
    'color(srgb 0.902840 0.557003 0.319282)',
    'color(srgb 0.903774 0.561563 0.319625)',
    'color(srgb 0.904711 0.566120 0.319970)',
    'color(srgb 0.905648 0.570671 0.320313)',
    'color(srgb 0.906580 0.575224 0.320652)',
    'color(srgb 0.907514 0.579777 0.320985)',
    'color(srgb 0.908445 0.584316 0.321317)',
    'color(srgb 0.909375 0.588853 0.321654)',
    'color(srgb 0.910310 0.593404 0.321998)',
    'color(srgb 0.911239 0.597943 0.322345)',
    'color(srgb 0.912171 0.602489 0.322690)',
    'color(srgb 0.913105 0.607042 0.323029)',
    'color(srgb 0.914040 0.611586 0.323367)',
    'color(srgb 0.914970 0.616139 0.323706)',
    'color(srgb 0.915902 0.620702 0.324049)',
    'color(srgb 0.916845 0.625260 0.324396)',
    'color(srgb 0.917784 0.629830 0.324746)',
    'color(srgb 0.918718 0.634415 0.325101)',
    'color(srgb 0.919662 0.638998 0.325460)',
    'color(srgb 0.920604 0.643592 0.325826)',
    'color(srgb 0.921555 0.648201 0.326200)',
    'color(srgb 0.922507 0.652822 0.326584)',
    'color(srgb 0.923462 0.657468 0.326981)',
    'color(srgb 0.924416 0.662121 0.327392)',
    'color(srgb 0.925379 0.666780 0.327822)',
    'color(srgb 0.926347 0.671471 0.328275)',
    'color(srgb 0.927318 0.676184 0.328757)',
    'color(srgb 0.928297 0.680911 0.329270)',
    'color(srgb 0.929285 0.685678 0.329814)',
    'color(srgb 0.930283 0.690460 0.330396)',
    'color(srgb 0.931285 0.695281 0.331033)',
    'color(srgb 0.932296 0.700132 0.331753)',
    'color(srgb 0.933319 0.705021 0.332557)',
    'color(srgb 0.934357 0.709951 0.333431)',
    'color(srgb 0.935409 0.714920 0.334417)',
    'color(srgb 0.936478 0.719941 0.335521)',
    'color(srgb 0.937557 0.725011 0.336755)',
    'color(srgb 0.938655 0.730132 0.338153)',
    'color(srgb 0.939775 0.735308 0.339755)',
    'color(srgb 0.940913 0.740544 0.341539)',
    'color(srgb 0.942077 0.745845 0.343556)',
    'color(srgb 0.943262 0.751218 0.345825)',
    'color(srgb 0.944473 0.756645 0.348394)',
    'color(srgb 0.945709 0.762144 0.351264)',
    'color(srgb 0.946974 0.767714 0.354472)',
    'color(srgb 0.948266 0.773354 0.358043)',
    'color(srgb 0.949586 0.779063 0.362002)',
    'color(srgb 0.950938 0.784838 0.366377)',
    'color(srgb 0.952312 0.790667 0.371170)',
    'color(srgb 0.953719 0.796554 0.376445)',
    'color(srgb 0.955147 0.802494 0.382156)',
    'color(srgb 0.956597 0.808479 0.388366)',
    'color(srgb 0.958072 0.814491 0.395050)',
    'color(srgb 0.959559 0.820530 0.402205)',
    'color(srgb 0.961064 0.826587 0.409861)',
    'color(srgb 0.962575 0.832640 0.417961)',
    'color(srgb 0.964092 0.838685 0.426519)',
    'color(srgb 0.965612 0.844713 0.435518)',
    'color(srgb 0.967132 0.850700 0.444911)',
    'color(srgb 0.968639 0.856648 0.454686)',
    'color(srgb 0.970133 0.862544 0.464801)',
    'color(srgb 0.971612 0.868368 0.475238)',
    'color(srgb 0.973070 0.874110 0.485938)',
    'color(srgb 0.974498 0.879773 0.496891)',
    'color(srgb 0.975902 0.885348 0.508061)',
    'color(srgb 0.977278 0.890823 0.519386)',
    'color(srgb 0.978614 0.896200 0.530851)',
    'color(srgb 0.979924 0.901469 0.542424)',
    'color(srgb 0.981192 0.906636 0.554064)',
    'color(srgb 0.982426 0.911693 0.565746)',
    'color(srgb 0.983617 0.916646 0.577452)',
    'color(srgb 0.984777 0.921492 0.589147)',
    'color(srgb 0.985893 0.926235 0.600822)',
    'color(srgb 0.986977 0.930880 0.612445)',
    'color(srgb 0.988017 0.935424 0.624015)',
    'color(srgb 0.989027 0.939877 0.635493)',
    'color(srgb 0.989999 0.944235 0.646891)',
    'color(srgb 0.990934 0.948505 0.658185)',
    'color(srgb 0.991836 0.952694 0.669370)',
    'color(srgb 0.992705 0.956799 0.680431)',
    'color(srgb 0.993538 0.960832 0.691381)',
    'color(srgb 0.994334 0.964785 0.702202)',
    'color(srgb 0.995098 0.968676 0.712897)',
    'color(srgb 0.995829 0.972501 0.723465)',
    'color(srgb 0.996528 0.976256 0.733910)',
    'color(srgb 0.997193 0.979964 0.744228)',
    'color(srgb 0.997826 0.983613 0.754434)',
    'color(srgb 0.998426 0.987220 0.764524)',
    'color(srgb 0.998993 0.990779 0.774513)',
    'color(srgb 0.999523 0.994303 0.784423)',
    'color(srgb 1.000000 0.997796 0.794247)'
];

let defaultGraphParam = {

   type: undefined,        // one of "scatter", "histogram", "colormap", "bar"
   showMenuButtons: true,  // if false hide menu buttons
   mouseWheelZoom: true,   // if false disable mouse scroll zoom

   floating: false,        // true if in a floating dialog box

   // general colors
   color: {
      background: "#FFFFFF",  // background, default is white
      axis: "#808080",        // axes lines and ticks color
      grid: "#D0D0D0",        // grid lines color
      label: "#404040",       // colors of the axis labels
   },

   title: {
      color: "#000000",    
      backgroundColor: "#808080",
      textSize: 16,        // font size
      text: ""             // text content for the title
   },

   legend: {
      show: true,
      color: "#D0D0D0",
      backgroundColor: "#FFFFFF",
      textColor: "#404040",
      textSize: 12
   },

   barWidth: 0.3,          // width of the bars in a bar plot [0, 1], where 1 fills the entire space between points

   stats: {                // the following are set by calcStats
      show: true,    
      names: [],           // names of the various stats, varies by plot type
      values: []
   },

   xAxis: {
      type: "numeric",     // One of "numeric", "datetime", "category", "datetime"
      log: false,          // logscale if true
      min: undefined,      // axis limits
      max: undefined,      // axis limits
      grid: true,          // if true extend tick marks into a grid
      textSize: 16,        // size of the axis tick mark lables
      title: { 
         text: "",         // axis label text
         textSize: 16      // font size of the axis label text
      }
   },

   yAxis: {                // This axis is always "numeric"
      log: false,          // logscale if true
      min: undefined,      // axis limits
      max: undefined,      // axis limits
      grid: true,          // if true extend tick marks into a grid
      textSize: 16,        // size of the axis tick mark lables
      title: {             
         text: "",         // axis label text
         textSize: 16      // font size of the axis label text
      }
   },

   zAxis: {                // This axis is always "numeric"
      show: true,          // logscale if true
      min: undefined,      // axis limits
      max: undefined,      // axis limits
      textSize: 16,        // size of the axis tick mark lables
      title: {
         text: "",         // axis label text 
         textSize: 16      // font size of the axis label text
      }
   },

   plot: []               // this array holds the parameters for each plot (dataset). See defaultPlotParam
};

/**
 * Default parameters for the MPlotGraph.addPlot() function
 * These parameters control the formatting for each plot (read: dataset) added into the graph
 * Only a subset of the below keys are needed to be passed to the addPlot function. The rest are taken as below. 
 */
let defaultPlotParam = {
   type: "scatter",  // One of "scatter", "histogram", "colormap", "bar"
   odbPath: "",      // path in the ODB to the directory with the data. Prefix to the below paths. 

   xPath: "",        // ODB path to x data
   yPath: "",        // ODB path to y data
   zPath: "",        // ODB path to z data
   xErrorPath: "",   // ODB path to x error data
   yErrorPath: "",   // ODB path to y error data

   label: "",        // label for this plot
   alpha: 1,         // transparency [0,1]. Zero is completely transparent. 
   zeroColor: undefined, // color used for colormaps with contents < 0.5

   nx: 0,            // number of x points
   ny: 0,            // number of y points
   xData: [],        // data array x values
   yData: [],        // data array y values
   zData: [],        // data array z values
   xErrorData: [],   // data array x errors   
   yErrorData: [],   // data array y errors

   xMin: undefined,  // drawing limits
   xMax: undefined,  // drawing limits
   yMin: undefined,  // drawing limits
   yMax: undefined,  // drawing limits

   marker: {         // marker properties at each point
      draw: true,    // if false, don't draw the markers
      lineColor: "",  // color of the marker border. See defaultGraphParam.color.data for colors
      fillColor: "",  // color of the fill. See defaultGraphParam.color.data for colors
      style: "circle", // One of "none", "circle", "square", "diamond", "pentagon", "triangle-up", "triangle-down", "triangle-left", "triangle-right", "cross", "plus"
      size: 10,         
      lineWidth: 2   // marker border width
   },

   line: {           // properties for lines interconnecting points
      draw: true,    // if false don't draw the line
      fill: false,   // fill the space below th eline
      color: "",     // color of the line. See defaultGraphParam.color.data for colors
      style: "solid",// One of "none", "solid", "dashed", "dotted"
      width: 2       // line width
   }
};

/**Initialize <div> elements of class "mplot". 
 * Loads the data into the graphs
 * Can only be called after all data has been created
 */
function mplot_init() {

   // go through all data-name="mplot" tags
   let mPlot = document.getElementsByClassName("mplot");

   for (let i = 0; i < mPlot.length; i++)
      mPlot[i].mpg = new MPlotGraph(mPlot[i]);

   loadMPlotData();

   window.addEventListener('resize', windowResize);
}

function profile(flag) {
   if (flag === true || flag === undefined) {
      console.log("");
      profile.startTime = new Date().getTime();
      return;
   }

   let now = new Date().getTime();
   console.log("Profile: " + flag + ": " + (now-profile.startTime) + "ms");
   profile.startTime = new Date().getTime();
}

/** Resize all mplot objects as defined by their class */
function windowResize() {
   let mPlot = document.getElementsByClassName("mplot");
   for (const m of mPlot)
      m.mpg.resize();
}

function isObject(item) {
   return (item && typeof item === 'object' && !Array.isArray(item));
}

String.prototype.stripZeros = function () {
   let s = this.trim();
   if (s.search("[.]") >= 0) {
      let i = s.search("[e]");
      if (i >= 0) {
         while (s.charAt(i - 1) === "0") {
            s = s.substring(0, i - 1) + s.substring(i);
            i--;
         }
         if (s.charAt(i - 1) === ".")
            s = s.substring(0, i - 1) + s.substring(i);
      } else {
         while (s.charAt(s.length - 1) === "0")
            s = s.substring(0, s.length - 1);
         if (s.charAt(s.length - 1) === ".")
            s = s.substring(0, s.length - 1);
      }
   }
   return s;
};

CanvasRenderingContext2D.prototype.drawLine = function (x1, y1, x2, y2) {
   this.beginPath();
   this.moveTo(x1, y1);
   this.lineTo(x2, y2);
   this.stroke();
};

/** Recursively merge object keys from source into target. Modifies in-place.
 * @param {object} target the object to make new keys or overwrite existing ones
 * @param {object} source the object from which the keys are copied
 * @returns {object} the target with the new keys
 */
function deepMerge(target, source) {
   for (let key in source) {
      if (source.hasOwnProperty(key)) {
         if (isObject(source[key])) {
            if (!target[key]) Object.assign(target, { [key]: {} });
            deepMerge(target[key], source[key]);
         } else {
            Object.assign(target, { [key]: source[key] });
         }
      }
   }
   return target;
}

/** Load data from the ODB for all HTML elements with the mplot class name */
function loadMPlotData() {

   // go through all data-name="mplot" tags
   let mPlot = document.getElementsByClassName("mplot");

   let v = [];
   for (const mp of mPlot) {
      for (const pl of mp.mpg.param.plot) {
         if (pl.odbPath === undefined || pl.odbPath === "")
            continue;

         let name = pl.label;
         if (name === "")
            name = mp.id;

         if ((pl.type === "scatter" || pl.type === "histogram") &&
            (pl.yPath === undefined || pl.yPath === null || pl.yPath === "")) {
            mp.mpg.error ="Invalid Y data \"" + pl.yPath + "\" for " + pl.type + " plot \"" + name+ "\"";
            mp.mpg.draw();
            pl.invalid = true;
            continue;
         }

         if ((pl.type === "colormap") &&
            (pl.zPath === undefined || pl.zPath === null || pl.zPath === "")) {
            mp.mpg.error = "Invalid Z data \"" + pl.zPath + "\" for colormap plot \"" + name + "\"";
            mp.mpg.draw();
            pl.invalid = true;
            continue;
         }

         if (pl.odbPath.slice(-1) !== '/')
            pl.odbPath += '/';

         if (pl.xPath !== undefined && pl.xPath !== null && pl.xPath !== "")
            v.push(pl.odbPath + pl.xPath);
         if (pl.yPath !== undefined && pl.yPath !== null && pl.yPath !== "")
            v.push(pl.odbPath + pl.yPath);
         if (pl.zPath !== undefined && pl.zPath !== null && pl.zPath !== "")
            v.push(pl.odbPath + pl.zPath);
         if (pl.xErrorPath !== undefined && pl.xErrorPath !== null && pl.xErrorPath !== "")
            v.push(pl.odbPath + pl.xErrorPath);
         if (pl.yErrorPath !== undefined && pl.yErrorPath !== null && pl.yErrorPath !== "")
            v.push(pl.odbPath + pl.yErrorPath);
      }
   }

   mjsonrpc_db_get_values(v).then( function(rpc) {

      let mPlot = document.getElementsByClassName("mplot");
      let i = 0;
      let iGraph = 0;
      for (let mp of mPlot) {
         for (let plt of mp.mpg.param.plot) {
            if (!plt.odbPath === undefined || plt.odbPath === "" || plt.invalid)
               continue;

            let name = plt.label;
            if (name === "")
               name = mp.id;

            if (plt.xPath !== undefined && plt.xPath !== null && plt.xPath !== "") {
               plt.xData = rpc.result.data[i++];
               if (plt.xData === null)
                  mp.mpg.error = "Invalid X data \"" + plt.xPath + "\" for plot \"" + name + "\"";
               if (Array.isArray(plt.xData) && plt.xData.length > 0 &&
                  plt.xData.every(item => typeof item === "string")) {

                  // switch plot to category plot if sting array found for x-data
                  plt.type = "bar";
                  plt.marker = undefined;
                  mp.mpg.param.xAxis.type = "category";
               }
            }
            if (plt.yPath !== undefined && plt.yPath !== null && plt.yPath !== "") {
               plt.yData = rpc.result.data[i++];
               if (plt.yData === null)
                  mp.mpg.error = "Invalid Y data \"" + plt.yPath + "\" for plot \"" + name + "\"";
            }
            if (plt.zPath !== undefined && plt.zPath !== null && plt.zPath !== "") {
               plt.zData = rpc.result.data[i++];
               if (plt.zData === null)
                  mp.mpg.error = "Invalid Z data \"" + plt.zPath + "\" for plot \"" + name + "\"";
            }
            if (plt.xErrorPath !== undefined && plt.xErrorPath !== null && plt.xErrorPath !== "") {
               plt.xErrorData = rpc.result.data[i++];
               if (plt.xErrorData === null)
                  mp.mpg.error = "Invalid X error data \"" + plt.xErrorPath + "\" for plot \"" + name + "\"";
            }
            if (plt.yErrorPath !== undefined && plt.yErrorPath !== null && plt.yErrorPath !== "") {
               plt.yErrorData = rpc.result.data[i++];
               if (plt.yErrorData === null)
                  mp.mpg.error = "Invalid Y error data \"" + plt.yError + "\" for plot \"" + name + "\"";
            }

            if ((plt.type === "scatter" || plt.type === "histogram" || plt.type === "bar") &&
               mp.mpg.error === null) {
               // generate X data for histograms and category plots
               if (plt.xData === undefined || plt.xData.length === 0 || plt.type === "bar") {
                  if (plt.type === "scatter") {
                     // scatter plot goes from 0 ... N
                     plt.xMin = 0;
                     plt.xMax = plt.yData.length;
                     plt.xData = Array.from({length: plt.yData.length}, (v, i) => i);
                  } else if (plt.type === "histogram") {
                     // histogram goes from -0.5 ... N-0.5 to have bins centered over bin x-value
                     plt.xMin = -0.5;
                     plt.xMax = plt.yData.length - 0.5;

                     let dx = (plt.xMax - plt.xMin) / plt.yData.length;
                     let x0 = plt.xMin + dx / 2;
                     plt.xData = Array.from({length: plt.yData.length}, (v, i) => x0 + i * dx);
                  } else if (plt.type === "bar") {
                     plt.xMin = 0;
                     plt.xMax = plt.xData.length;
                  }
               } else {
                  plt.xMin = Math.min(...plt.xData);
                  plt.xMax = Math.max(...plt.xData);
               }

               plt.yMin = Math.min(...plt.yData);
               plt.yMax = Math.max(...plt.yData);

               if (plt.type === "bar")
                  plt.yMin = 0;
            }

            if (plt.type === "colormap" && mp.mpg.error === null) {
               plt.zMin = Math.min(...plt.zData.filter(v=>!isNaN(v)));
               plt.zMax = Math.max(...plt.zData.filter(v=>!isNaN(v)));

               if (plt.xMin === undefined) {
                  plt.xMin = -0.5;
                  plt.xMax = plt.nx - 0.5;
               }
               if (plt.yMin === undefined) {
                  plt.yMin = -0.5;
                  plt.yMax = plt.ny - 0.5;
               }

               let dx = (plt.xMax - plt.xMin) / plt.nx;
               let x0 = plt.xMin + dx/2;
               plt.xData = Array.from({length: plt.nx}, (v,i) => x0 + i*dx);

               let dy = (plt.yMax - plt.yMin) / plt.ny;
               let y0 = plt.yMin + dy/2;
               plt.yData = Array.from({length: plt.ny}, (v,i) => y0 + i*dy);
            }

            iGraph++;
         }
      }

      for (const mp of mPlot) {
         if (!mp.mpg.blockAutoScale)
            mp.mpg.calcMinMax();
         mp.mpg.redraw();
      }

      // refresh data once per second
      window.setTimeout(loadMPlotData, 1000);

   }).catch( (error) => {
      dlgAlert(error)
   });
}

LN10 = 2.302585094;
LOG2 = 0.301029996;
LOG5 = 0.698970005;

/* Begin ptimeToLabel format options */
let poptions1 = {
   timeZone: 'UTC',
   day: '2-digit', month: 'short', year: '2-digit',
   hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit'
};

let poptions2 = {
   timeZone: 'UTC',
   day: '2-digit', month: 'short', year: '2-digit',
   hour12: false, hour: '2-digit', minute: '2-digit'
};

let poptions3 = {
   timeZone: 'UTC',
   day: '2-digit', month: 'short', year: '2-digit',
   hour12: false, hour: '2-digit', minute: '2-digit'
};

let poptions4 = {
   timeZone: 'UTC',
   day: '2-digit', month: 'short', year: '2-digit'
};

let poptions5 = {
   timeZone: 'UTC',
   hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit'
};

let poptions6 = {
   timeZone: 'UTC',
   hour12: false, hour: '2-digit', minute: '2-digit'
};

let poptions7 = {
   timeZone: 'UTC',
   hour12: false, hour: '2-digit', minute: '2-digit'
};

let poptions8 = {
   timeZone: 'UTC',
   day: '2-digit', month: 'short', year: '2-digit',
   hour12: false, hour: '2-digit', minute: '2-digit'
};

let poptions9 = {
   timeZone: 'UTC',
   day: '2-digit', month: 'short', year: '2-digit'
};
/* End ptimeToLabel format options */

/** Convert time in seconds to a human-readable string
 * @param {number} sec number of seconds
 * @param {number} base chooses which display option to use on conversion
 * @param {bool} forceDate if true force showing the date, else can show only time
 * @returns {string} human-readable datetime as a string 
 */
function ptimeToLabel(sec, base, forceDate) {
   let d = mhttpd_get_display_time(sec).date;

   if (forceDate) {
      if (base < 60) {
         return d.toLocaleTimeString('en-GB', poptions1);
      } else if (base < 600) {
         return d.toLocaleTimeString('en-GB', poptions2);
      } else if (base < 3600 * 24) {
         return d.toLocaleTimeString('en-GB', poptions3);
      } else {
         return d.toLocaleDateString('en-GB', poptions4);
      }
   }

   if (base < 60) {
      return d.toLocaleTimeString('en-GB', poptions5);
   } else if (base < 600) {
      return d.toLocaleTimeString('en-GB', poptions6);
   } else if (base < 3600 * 3) {
      return d.toLocaleTimeString('en-GB', poptions7);
   } else if (base < 3600 * 24) {
      return d.toLocaleTimeString('en-GB', poptions8);
   } else {
      return d.toLocaleDateString('en-GB', poptions9);
   }
}

function checkPlotType(type) {
   return type === "histogram" || type === "bar" || type === "scatter" ||
      type === "colormap";
}

function mpgDialog(p) {
   let width = window.innerWidth-200;
   let height = window.innerHeight-200;

   let dlgFrame = document.createElement("div");
   dlgFrame.className = "dlgFrame";
   dlgFrame.style.zIndex = "30";
   dlgFrame.style.backgroundColor = "white";
   dlgFrame.style.overflow = "hidden";
   dlgFrame.style.width = width + "px";
   dlgFrame.style.height = height + "px";
   dlgFrame.style.minWidth = "100px"; // overwrite max-content
   dlgFrame.style.minHeight = "50px"; // overwrite max-content
   dlgFrame.shouldDestroy = true;

   let dlgTitle = document.createElement("div");
   dlgTitle.className = "dlgTitlebar";
   dlgTitle.id = "dlgMessageTitle";
   dlgTitle.innerText = p.param?.title?.text;
   dlgFrame.appendChild(dlgTitle);
   document.body.appendChild(dlgFrame);
   dlgShow(dlgFrame);

   let dlgPanel = document.createElement("div");
   dlgPanel.className = "dlgPanel";
   dlgPanel.style.flex = "1 1 auto";
   dlgPanel.style.width = (width - 2) + "px";
   dlgPanel.style.height = (height - dlgTitle.clientHeight - 2) + "px";
   dlgPanel.style.minWidth = "";  // overwrite max-content
   dlgPanel.style.minHeight = ""; // overwrite max-content
   dlgPanel.style.padding = "0";
   dlgPanel.style.border = "";
   dlgPanel.style.backgroundColor = "transparent";
   dlgFrame.appendChild(dlgPanel);

   p.param.floating = true;
   dlgPanel.mpg = new MPlotGraph(dlgPanel, p.param);
   dlgPanel.mpg.param.title.text = ""; // title is shown in the dialog title instead
   dlgPanel.mpg.param.floating = true;
   dlgPanel.mpg.canvas.width = parseInt(dlgPanel.style.width);
   dlgPanel.mpg.canvas.height = parseInt(dlgPanel.style.height);
   dlgPanel.mpg.canvas.style.border = "none";
   dlgPanel.mpg.calcMinMax();
   dlgPanel.mpg.draw();

   new ResizeObserver(() => {
      const rect = dlgFrame.getBoundingClientRect();
      dlgPanel.style.width = (rect.width - 4) + "px";
      dlgPanel.style.height = (rect.height - dlgTitle.clientHeight - 4) + "px";

      window.setTimeout(() => {
         dlgPanel.mpg.canvas.width = parseInt(dlgPanel.style.width);
         dlgPanel.mpg.canvas.height = parseInt(dlgPanel.style.height);
         dlgPanel.mpg.redraw();
      }, 10);
   }).observe(dlgFrame);
}

/** Umbrella figure object containing the axes, buttons, and all plots.
 * MPlotGraph redraws all contained elements upon any change to the figure (zoom, pan, new line, etc).
 * For most drawing applications you will need only draw, and addPlot or setData.
 */
class MPlotGraph{

   /**
    * @constructor
    * @param {Object} divElement HTML div element to place the plot into
    * @param {Object} graphParam JS object with keys a subset of {@link defaultGraphParam}, controls plot display style. 
    * @example 
    * let graph = MPlotGraph();
    * graph.addPlot({xData:[1,2,3], yData:[4,5,6]});
    * graph.draw();
    */
   constructor(divElement, graphParam) {

      if (divElement === undefined || divElement === null) {
         dlgAlert("MPlot constructor called without valid divElement");
         return;
      }

      // save parameters from <div>
      this.parentDiv = divElement;
      this.divParam = divElement.innerHTML;
      divElement.innerHTML = "";
      
      // if absent, generate random string (5 char) to give an id to parent element
      if (!this.parentDiv.id)
         this.parentDiv.id = (Math.random() + 1).toString(36).substring(7);

      // default parameters
      this.param = JSON.parse(JSON.stringify(defaultGraphParam)); // deep copy
      
      // overwrite default parameters from <div> text body
      try {
         if (this.divParam.includes('{')) {
            let p = JSON.parse(this.divParam);
            this.param = deepMerge(this.param, p);
         }
      } catch (error) {
         this.parentDiv.innerHTML = "<pre>" + this.divParam + "</pre>";
         dlgAlert(error);
         return;
      }
      
      // obtain parameters form <div> attributes ---

      // data-odb-path
      if (this.parentDiv.dataset.odbPath)
         this.param.odbPath = this.parentDiv.dataset.odbPath;
      
      // data-type
      if (this.parentDiv.dataset.type)
         this.param.type = this.parentDiv.dataset.type;

      // data-title
      if (this.parentDiv.dataset.title)
         this.param.title.text = this.parentDiv.dataset.title;

      // data-x/y/z-text
      if (this.parentDiv.dataset.xText)
         this.param.xAxis.title.text = this.parentDiv.dataset.xText;
      if (this.parentDiv.dataset.yText)
         this.param.yAxis.title.text = this.parentDiv.dataset.yText;
      if (this.parentDiv.dataset.zText)
         this.param.zAxis.title.text = this.parentDiv.dataset.zText;

      // data-x/y
      if (this.parentDiv.dataset.x || this.parentDiv.dataset.xError) {
         if (this.param.plot.length === 0)
            this.param.plot.push(JSON.parse(JSON.stringify(defaultPlotParam)));
         this.param.plot[0].odbPath = this.param.odbPath;
         this.param.plot[0].type = "scatter";
      }

      if (this.parentDiv.dataset.x)
         this.param.plot[0].xPath = this.parentDiv.dataset.x;
      if (this.parentDiv.dataset.y)
         this.param.plot[0].yPath = this.parentDiv.dataset.y;
      
      // data-x/y-error
      if (this.parentDiv.dataset.xError)
         this.param.plot[0].xError = this.parentDiv.dataset.xError;
      if (this.parentDiv.dataset.yError)
         this.param.plot[0].yError = this.parentDiv.dataset.yError;

      // data-x/y/z-min/max
      if (this.parentDiv.dataset.xMin)
         this.param.xAxis.min = parseFloat(this.parentDiv.dataset.xMin);
      if (this.parentDiv.dataset.xMax)
         this.param.xAxis.max = parseFloat(this.parentDiv.dataset.xMax);
      if (this.parentDiv.dataset.yMin)
         this.param.yAxis.min = parseFloat(this.parentDiv.dataset.yMin);
      if (this.parentDiv.dataset.yMax)
         this.param.yAxis.max = parseFloat(this.parentDiv.dataset.yMax);
      if (this.parentDiv.dataset.zMin)
         this.param.zAxis.min = parseFloat(this.parentDiv.dataset.zMin);
      if (this.parentDiv.dataset.zMax)
         this.param.zAxis.max = parseFloat(this.parentDiv.dataset.zMax);

      // data-x/y/z-log
      if (this.parentDiv.dataset.xLog)
         this.param.xAxis.log = this.parentDiv.dataset.xLog === "true" || this.parentDiv.dataset.xLog === "1";
      if (this.parentDiv.dataset.yLog)
         this.param.yAxis.log = this.parentDiv.dataset.yLog === "true" || this.parentDiv.dataset.yLog === "1";
      if (this.parentDiv.dataset.zLog) {
         this.param.zAxis.log = this.parentDiv.dataset.zLog === "true" || this.parentDiv.dataset.zLog === "1";
         if (this.param.zAxis.log) {
            if (this.param.zAxis.min < 1E-20)
               this.param.zAxis.min = 1E-20;
            if (this.param.zAxis.max < 1E-18)
               this.param.zAxis.max = 1E-18;
         }
      }
      
      // data-h
      if (this.parentDiv.dataset.h) {
         if (this.param.plot.length === 0)
            this.param.plot.push(JSON.parse(JSON.stringify(defaultPlotParam)));
         this.param.plot[0].odbPath = this.param.odbPath;
         this.param.plot[0].type = "histogram";
         this.param.plot[0].yPath = this.parentDiv.dataset.h;
         this.param.plot[0].line.color = "#404040";
         this.param.plot[0].marker.draw = false;
         if (!this.parentDiv.dataset.x) {
            this.param.plot[0].xMin = this.param.xAxis.min;
            this.param.plot[0].xMax = this.param.xAxis.max;
         }
      }
      
      // data-z
      if (this.parentDiv.dataset.z) {
         if (this.param.plot.length === 0)
            this.param.plot.push(JSON.parse(JSON.stringify(defaultPlotParam)));
         this.param.plot[0].odbPath = this.param.odbPath;
         this.param.plot[0].type = "colormap";
         this.param.plot[0].showZScale = true;
         this.param.plot[0].zeroColor = this.parentDiv.dataset.zeroColor;
         this.param.plot[0].zPath = this.parentDiv.dataset.z;
         this.param.plot[0].xMin = this.param.xAxis.min;
         this.param.plot[0].xMax = this.param.xAxis.max;
         this.param.plot[0].yMin = this.param.yAxis.min;
         this.param.plot[0].yMax = this.param.yAxis.max;
         this.param.plot[0].zMin = this.param.zAxis.min;
         this.param.plot[0].zMax = this.param.zAxis.max;
         this.param.plot[0].nx = parseInt(this.parentDiv.dataset.nx);
         this.param.plot[0].ny = parseInt(this.parentDiv.dataset.ny);
         if (this.param.plot[0].nx === undefined) {
            dlgAlert("\"data-nx\" missing for colormap mplot <div>");
            return;
         }
         if (this.param.plot[0].ny === undefined) {
            dlgAlert("\"data-ny\" missing for colormap mplot <div>");
            return;
         }
      }
      
      // data-label
      if (this.parentDiv.dataset.label)
         this.param.plot[0].label = this.parentDiv.dataset.label;

      // data-line-width
      if (this.parentDiv.dataset["line-width"])
         this.param.plot[0].line.width = this.parentDiv.dataset["line-width"];

      // data-bar-width
      if (this.parentDiv.dataset["bar-width"])
         this.param.barWidth = this.parentDiv.dataset["bar-width"];
      
      // data-marker
      if (this.parentDiv.dataset["marker-style"])
         this.param.plot[0].marker.style = this.parentDiv.dataset["marker-style"];

      // data-x<n>/y<n>/label<n>/alpha<n>/marker<n>
      for (let i=1, index=0 ; i<16 ; i++, index++) {
         if (this.parentDiv.dataset["y"+i]) { // use y here since bar plot could only have "data-x"
            if (i > this.param.plot.length)
               this.param.plot.push(JSON.parse(JSON.stringify(defaultPlotParam)));
            this.param.plot[index].odbPath = this.param.odbPath;
            this.param.plot[index].marker.lineColor = defaultGraphColor[index];
            this.param.plot[index].marker.fillColor = defaultGraphColor[index];
            this.param.plot[index].line.color = defaultGraphColor[index];

            if (this.parentDiv.dataset["x" + i])
               this.param.plot[index].xPath = this.parentDiv.dataset["x" + i];
            else
               // copy from first plot if we only have "data-x"
               this.param.plot[index].xPath = this.param.plot[0].xPath;

            if (this.parentDiv.dataset["y" + i])
               this.param.plot[index].yPath = this.parentDiv.dataset["y" + i];
            if (this.parentDiv.dataset["x" + i + "Error"])
               this.param.plot[index].xErrorPath = this.parentDiv.dataset["x" + i + "Error"];
            if (this.parentDiv.dataset["y" + i + "Error"])
               this.param.plot[index].yErrorPath = this.parentDiv.dataset["y" + i + "Error"];
            if (this.parentDiv.dataset["label" + i])
               this.param.plot[index].label = this.parentDiv.dataset["label" + i];
            if (this.parentDiv.dataset["alpha" + i])
               this.param.plot[index].alpha = parseFloat(this.parentDiv.dataset["alpha" + i]);
            if (this.parentDiv.dataset["line" + i + "-width"])
               this.param.plot[index].line.width = parseFloat(this.parentDiv.dataset["line" + i + "-width"]);
            if (this.parentDiv.dataset["line" + i + "-style"])
               this.param.plot[index].line.style = this.parentDiv.dataset["line" + i + "-style"];
            if (this.parentDiv.dataset["marker" + i + "-style"])
               this.param.plot[index].marker.style = this.parentDiv.dataset["marker" + i + "-style"];
         }
      }

      // data-h<n>
      for (let i=1, index=0 ; i<16 ; i++, index++) {
         if (this.parentDiv.dataset["h"+i]) {
            this.param.plot.push(JSON.parse(JSON.stringify(defaultPlotParam)));
            this.param.plot[index].odbPath = this.param.odbPath;
            this.param.plot[index].marker.lineColor = defaultGraphColor[index];
            this.param.plot[index].marker.fillColor = defaultGraphColor[index];
            this.param.plot[index].line.color = defaultGraphColor[index];
            
            this.param.plot[index].type = "histogram";
            this.param.plot[index].yPath = this.parentDiv.dataset["h"+i];

            this.param.plot[index].xMin = this.param.xAxis.min;
            this.param.plot[index].xMax = this.param.xAxis.max;

            if (this.parentDiv.dataset["label"+i])
               this.param.plot[index].label = this.parentDiv.dataset["label"+i];
         }
      }
      
      // data-xaxis-type
      if (this.parentDiv.dataset["x-type"])
         this.param.xAxis.type = this.parentDiv.dataset["x-type"];
      
      // data-overlay
      if (this.parentDiv.dataset.overlay) {
         this.param.overlay = this.parentDiv.dataset.overlay;
         if (this.param.overlay.indexOf('(') !== -1) // strip any '('
            this.param.overlay = this.param.overlay.substring(0, this.param.overlay.indexOf('('));
         }

      // data-event
      if (this.parentDiv.dataset.event) {
         this.param.event = this.parentDiv.dataset.event;
         if (this.param.event.indexOf('(') !== -1) // strip any '('
         this.param.event = this.param.event.substring(0, this.param.event.indexOf('('));
      }
      
      // data-stats
      if (this.parentDiv.dataset.stats)
         this.param.stats.show = (this.parentDiv.dataset.stats === "1");
      
      // set parameters from constructor
      if (graphParam)
         deepMerge(this.param, graphParam);

      // check plot type
      for (const p of this.param.plot) {
         if (!checkPlotType(p.type))
            throw new Error(`mplot.js: Unknown plot type "${p.type}"`);
      }

      // dragging
      this.drag = {
         active: false,
         sxStart: 0,
         syStart: 0,
         xStart: 0,
         yStart: 0,
         xMinStart: 0,
         xMaxStart: 0,
         yMinStart: 0,
         yMaxStart: 0,
      };
      
      // axis zoom
      this.zoom = {
         x: {active: false},
         y: {active: false}
      };
      
      // marker
      this.marker = {active: false};
      this.blockAutoScale = false;

      this.error = null;

      // buttons
      this.button = [
         {
            src: "maximize.svg",
            title: "Maximize this plot",
            click: function (t) {
               mpgDialog(t);
            }
         },
         {
            src: "menu.svg",
            title: "Show / hide legend",
            click: function (t) {
               t.param.legend.show = !t.param.legend.show;

               let nLabel = 0;
               for (const g of t.param.plot)
                  if (g.label && g.label !== "")
                     nLabel++;
               if (nLabel === 0)
                  dlgAlert("No plot labels defined");

               t.redraw();
            }
         },
         {
            src: "stats.svg",
            title: "Show / hide statistics",
            click: function (t) {
               t.param.stats.show = !t.param.stats.show;
               t.redraw();
            }
         },
         {
            src: "rotate-ccw.svg",
            title: "Reset histogram axes",
            click: function (t) {
               t.resetAxes();
            }
         },
         {
            src: "download.svg",
            title: "Download image/data...",
            click: function (t) {
               if (t.downloadSelector.style.display === "none") {
                  t.downloadSelector.style.display = "block";
                  let w = t.downloadSelector.getBoundingClientRect().width;
                  t.downloadSelector.style.left = (t.canvas.getBoundingClientRect().x + window.scrollX +
                  t.width - 26 - w) + "px";
                  t.downloadSelector.style.top = (t.canvas.getBoundingClientRect().y + window.scrollY +
                     this.y1) + "px";
                     t.downloadSelector.style.zIndex = "32";
                  } else {
                     t.downloadSelector.style.display = "none";
               }
            }
         },
      ];

      // remove maximize button if we are floating
      if (this.param.floating)
         this.button.shift();

      this.button.forEach(b => {
         b.img = new Image();
         b.img.src = "icons/" + b.src;
      });

      this.createDownloadSelector();

      // mouse event handlers
      divElement.addEventListener("mousedown", this.mouseEvent.bind(this), true);
      divElement.addEventListener("dblclick", this.mouseEvent.bind(this), true);
      divElement.addEventListener("mousemove", this.mouseEvent.bind(this), true);
      divElement.addEventListener("mouseup", this.mouseEvent.bind(this), true);
      divElement.addEventListener("wheel", this.mouseEvent.bind(this), true);
      
      // Keyboard event handler (has to be on the window!)
      window.addEventListener("keydown", this.keyDown.bind(this));
      
      // create canvas
      this.canvas = document.createElement("canvas");
      this.canvas.style.border = "1px solid black";
      
      if (parseInt(this.parentDiv.style.width) > 0)
         this.canvas.width = parseInt(this.parentDiv.style.width);
      else
         this.canvas.width = 500;
      if (parseInt(this.parentDiv.style.height) > 0)
         this.canvas.height = parseInt(this.parentDiv.style.height);
      else
         this.canvas.height = 300;
      
      divElement.appendChild(this.canvas);
   }

   /** Add a plot to the graph
    * Plot drawing info is stored in the MPlotGraph.param.plot array. Parameters 
    * can be modified in realtime by editing this array directly
    * @param {Object} plotParam subset of keys from the {@link defaultPlotParam} object
    * @returns {int} index of the plot added in the MPlotGraph.param.plot array
    * @example let index = plt.addPlot({xData:[1,2,3], yData:[4,5,6], yErrorData=[1,1,2]});
    */
   addPlot(plotParam) {
      this.param.plot.push(JSON.parse(JSON.stringify(defaultPlotParam)));
      let index = this.param.plot.length - 1;
      let g = this.param.plot[index];
      g.type = "scatter";
      g.marker.lineColor = defaultGraphColor[index];
      g.marker.fillColor = defaultGraphColor[index];
      g.line.color = defaultGraphColor[index];

      // merge optional paramters
      if (plotParam) {
         deepMerge(g, plotParam);

         if (plotParam.xData || plotParam.yData || plotParam.zData)
            this.setData(index, plotParam.xData, plotParam.yData, plotParam.zData);
      }

      return index;
   }

   findPlot(label) {
      let index = -1;
      if (typeof label === "string") {
         for (const [i,p] of this.param.plot.entries()) {
            if (p.label === label) {
               index = i;
               break;
            }
         }
         if (index === -1) {
            alert("Plot \"" + label + "\" not found");
            return -1;
         }
      } else
         index = label;

      if (index < 0 || index > this.param.plot.length) {
         alert("Invalid index \"" + index + "\"");
         return -1;
      }

      return index;
   }

   /** Modify an exising plot
    * Plot drawing info is stored in the MPlotGraph.param.plot array. Parameters
    * can be modified in realtime by editing this array directly
    * @param {int/string} label to the plot array [0...n-1] or label name of plot
    * @param {Object} plotParam subset of keys from the {@link defaultPlotParam} object
    * @example plt.modifyPlot(0, {label:"Modified plot", line: {color: "red"}} );
    */
   modifyPlot(label, plotParam) {
      let index = this.findPlot(label);
      deepMerge(this.param.plot[index], plotParam);
   }

   /** Delete an exising plot
    * @param {int/string} label to the plot array [0...n-1] or label name of plot
    * @example plt.deletePlot(0);
    */
   deletePlot(label) {
      let index = this.findPlot(label);
      this.param.plot.splice(index, 1);
   }

   /** Make a download selection menu */
   createDownloadSelector () {

      // download selector
      let downloadSelId = this.parentDiv.id + "downloadSel";
      if (document.getElementById(downloadSelId)) document.getElementById(downloadSelId).remove();
      this.downloadSelector = document.createElement("div");
      this.downloadSelector.id = downloadSelId;
      this.downloadSelector.style.display = "none";
      this.downloadSelector.style.position = "absolute";
      this.downloadSelector.style.backgroundColor = "#FFFFFF";
      this.downloadSelector.style.borderRadius = "0";
      this.downloadSelector.style.border = "2px solid #808080";
      this.downloadSelector.style.margin = "0";
      this.downloadSelector.style.padding = "0";

      this.downloadSelector.style.left = "100px";
      this.downloadSelector.style.top = "100px";

      let table = document.createElement("table");
      let mhg = this;

      let row = document.createElement("tr");
      let cell = document.createElement("td");
      cell.style.padding = "0";
      let link = document.createElement("a");
      link.href = "#";
      link.innerHTML = "CSV";
      link.title = "Download data in Comma Separated Value format";
      link.onclick = function () {
         mhg.downloadSelector.style.display = "none";
         mhg.download("CSV");
         return false;
      }.bind(this);
      cell.appendChild(link);
      row.appendChild(cell);
      table.appendChild(row);

      row = document.createElement("tr");
      cell = document.createElement("td");
      cell.style.padding = "0";
      link = document.createElement("a");
      link.href = "#";
      link.innerHTML = "PNG";
      link.title = "Download image in PNG format";
      link.onclick = function () {
         mhg.downloadSelector.style.display = "none";
         mhg.download("PNG");
         return false;
      }.bind(this);
      cell.appendChild(link);
      row.appendChild(cell);
      table.appendChild(row);

      this.downloadSelector.appendChild(table);
      document.body.appendChild(this.downloadSelector);
   }

   /** Handle key events
    * @param {Object} e keydown event with properties key, metaKey, ctrlKey, target, etc
    */
   keyDown(e) {
      if (e.key === "r" && !e.ctrlKey && !e.metaKey) {  // 'r' key

         // don't grab key if we are in an input field
         if (e.target.tagName === "INPUT")
            return;

         this.resetAxes();
         e.preventDefault();
      }
   }

   /** Set the data for the mplot
    * For new applications please use addPlot
    * @param {int} index Choose which graph to modify 0...n-1. Stored in the MPlotGraph.param.plot array 
    * @param {float[]} x X values
    * @param {float[]} y Y values
    * @param {float[]} z Z values
    */
   setData(index, x, y, z) {

      if (index > this.param.plot.length) {
         dlgAlert("Wrong index \"" + index + "\" for graph \""+ this.param.title.text +"\"<br />" +
            "New index must be \"" + this.param.plot.length + "\"");
         return;
      }

      let g = this.param.plot[index];

      g.odbPath = ""; // prevent loading of ODB data

      // check plot type
      if (!checkPlotType(g.type))
         throw new Error(`mplot.js: Unknown plot type "${g.type}"`);

      if (g.type === "histogram") {
         g.line.color = "#404040";
         g.marker.draw = false;
         // generate X data for histograms
         if (g.xMin === undefined || g.xMax === undefined) {
            g.xMin = -0.5;
            g.xMax = g.yData.length - 0.5;
         }
         let dx = (g.xMax - g.xMin) / g.yData.length;
         let x0 = g.xMin + dx/2;
         if (g.xData === undefined || g.xData === null || g.xData.length === 0)
            g.xData = Array.from({length: g.yData.length}, (v,i) => x0 + i*dx);

         g.yData = y;

         g.yMin = Math.min(...g.yData);
         g.yMax = Math.max(...g.yData);
      }

      else if (g.type === "bar") {
         g.xData = x;
         g.yData = y;

         g.xMin = 0;
         g.xMax = x.length;
         g.yMin = 0;
         g.yMax = Math.max(...g.yData);
      }

      else if (g.type === "scatter" ) {
         g.xData = x;
         g.yData = y;
         g.xMin = Math.min(...g.xData);
         g.xMax = Math.max(...g.xData);
         g.yMin = Math.min(...g.yData);
         g.yMax = Math.max(...g.yData);
      }

      else if (g.type === "colormap") {
         g.zData = z;
         g.zMin = Math.min(...g.zData.filter(v=>!isNaN(v)));
         g.zMax = Math.max(...g.zData.filter(v=>!isNaN(v)));

         if (g.xMin === undefined) {
            g.xMin = -0.5;
            g.xMax = g.nx - 0.5;
         }
         if (g.yMin === undefined) {
            g.yMin = -0.5;
            g.yMax = g.ny - 0.5;
         }

         let dx = (g.xMax - g.xMin) / g.nx;
         let x0 = g.xMin + dx/2;
         g.xData = Array.from({length: g.nx}, (v,i) => x0 + i*dx);

         let dy = (g.yMax - g.yMin) / g.ny;
         let y0 = g.yMin + dy/2;
         g.yData = Array.from({length: g.ny}, (v,i) => y0 + i*dy);
      }

      if (!this.blockAutoScale) {
         this.calcMinMax();
      }
      
      this.redraw();
   }

   /** Resize canvas and redraw */
   resize() {
      this.canvas.width = this.parentDiv.clientWidth;
      this.canvas.height = this.parentDiv.clientHeight;
      this.redraw();
   }

   /** Redraw the graph */
   redraw() {
      let f = this.draw.bind(this);
      window.requestAnimationFrame(f);
   }

   /** Convert data coordinates to screen coordinates x axis */
   xToScreen(x) {
   
      if (this.param.xAxis.log) {
         if (x <= 0)
            return this.x1;
         else
            return this.x1 + (Math.log(x) - Math.log(this.xMin)) /
               (Math.log(this.xMax) - Math.log(this.xMin)) * (this.x2 - this.x1);
      }
      return this.x1 + (x - this.xMin) / (this.xMax - this.xMin) * (this.x2 - this. x1);
   }
   
   /** Convert data coordinates to screen coordinates y axis */
   yToScreen(y) {
      if (this.param.yAxis.log) {
         if (y <= 0)
            return this.y1;
         else
            return this.y1 - (Math.log(y) - Math.log(this.yMin)) /
               (Math.log(this.yMax) - Math.log(this.yMin)) * (this.y1 - this.y2);
      }
      return this.y1 - (y - this.yMin) / (this.yMax - this.yMin) * (this.y1 - this. y2);
   }

   /** Convert screen coordinates to data coordinates x axis */
   screenToX(x) {
      if (this.param.xAxis.log) {
         let xl = (x - this.x1) / (this.x2 - this.x1) * (Math.log(this.xMax)-Math.log(this.xMin)) + Math.log(this.xMin);
         return Math.exp(xl);
      }
      return (x - this.x1) / (this.x2 - this.x1) * (this.xMax - this.xMin) + this.xMin;
   };

   /** Convert screen coordinates to data coordinates y axis */
   screenToY(y) {
      if (this.param.yAxis.log) {
         let yl = (this.y1 - y) / (this.y1 - this.y2) * (Math.log(this.yMax)-Math.log(this.yMin)) + Math.log(this.yMin);
         return Math.exp(yl);
      }
      return (this.y1 - y) / (this.y1 - this.y2) * (this.yMax - this.yMin) + this.yMin;
   };

   /** Calculate the min/max of each axis */
   calcMinMax() {

      if (this.param.plot.length === 0)
         return;

      // simple nx / ny for colormaps
      if (this.param.plot[0].type === "colormap") {
         this.nx = this.param.plot[0].nx;
         this.ny = this.param.plot[0].ny;

         if (this.param.zAxis.min !== undefined)
            this.zMin = this.param.zAxis.min;
         else
            this.zMin = this.param.plot[0].zMin;

         if (this.param.zAxis.max !== undefined)
            this.zMax = this.param.zAxis.max;
         else
            this.zMax = this.param.plot[0].zMax;

         if (this.param.zAxis.log) {
            if (this.zMin < 1E-20)
               this.zMin = 1E-20;
            if (this.zMax < 1E-18)
               this.zMax = 1E-18;
         }

         this.xMin = this.param.plot[0].xMin;
         this.xMax = this.param.plot[0].xMax;
         this.yMin = this.param.plot[0].yMin;
         this.yMax = this.param.plot[0].yMax;

         this.xMin0 = this.xMin;
         this.xMax0 = this.xMax;
         this.yMin0 = this.yMin;
         this.yMax0 = this.yMax;
         return;
      }

      // determine min/max of overall plot
      let xMin = this.param.plot[0].xMin;
      for (const g of this.param.plot)
         if (g.xMin < xMin)
            xMin = g.xMin;
      if (this.param.xAxis.min !== undefined)
         xMin = this.param.xAxis.min;

      let xMax = this.param.plot[0].xMax;
      for (const g of this.param.plot)
         if (g.xMax > xMax)
            xMax = g.xMax;
      if (this.param.xAxis.max !== undefined)
         xMax = this.param.xAxis.max;

      let yMin = this.param.plot[0].yMin;
      for (const g of this.param.plot)
         if (g.yMin < yMin)
            yMin = g.yMin;
      if (this.param.yAxis.min !== undefined)
         yMin = this.param.yAxis.min;

      let yMax = this.param.plot[0].yMax;
      for (const g of this.param.plot)
         if (g.yMax > yMax)
            yMax = g.yMax;
      if (this.param.yAxis.max !== undefined)
         yMax = this.param.yAxis.max;

      // avoid min === max
      if (xMin === xMax) { xMin -= 0.5; xMax += 0.5; }
      if (yMin === yMax) { yMin -= 0.5; yMax += 0.5; }

      // add 5% on each side
      let dx = (xMax - xMin);
      let dy = (yMax - yMin);
      if (this.param.plot[0].type !== "histogram" && this.param.plot[0].type !== "bar") {
         if (this.param.xAxis.min === undefined)
            xMin -= dx / 20;
         if (this.param.xAxis.max === undefined)
            xMax += dx / 20;
         if (this.param.yAxis.min === undefined)
            yMin -= dy / 20;
      }
      if (this.param.yAxis.max === undefined)
         yMax += dy / 20;

      this.xMin = xMin;
      this.xMax = xMax;
      this.yMin = yMin;
      this.yMax = yMax;

      this.xMin0 = xMin;
      this.xMax0 = xMax;
      this.yMin0 = yMin;
      this.yMax0 = yMax;
   }

   /** Calculate the stats to display in the graph 
    * These are stored in MPlotGraph.param.stats. See also defaultGraphParam
   */
   calcStats() {
      this.stats = {};
      let g = this.param.plot[0];

      if (g.type === "scatter") {
         this.stats.name = ["Entries", "Mean X", "Std Dev X", "Mean Y", "Std Dev Y"];

         this.stats.value = Array(5).fill(0);
         let n = this.param.plot[0].xData.length;

         if (n > 1) {
            let mean = g.xData.reduce((sum, x) => sum + x, 0) / n;
            let variance = g.xData.reduce((sum, x) => sum + (x - mean) ** 2, 0) / (n - 1);
            let stddev = Math.sqrt(variance);
            this.stats.value[0] = n;
            this.stats.value[1] = Number(mean.toPrecision(6));
            this.stats.value[2] = Number(stddev.toPrecision(6));

            mean = g.yData.reduce((sum, x) => sum + x, 0) / n;
            variance = g.yData.reduce((sum, x) => sum + (x - mean) ** 2, 0) / (n - 1);
            stddev = Math.sqrt(variance);
            this.stats.value[3] = Number(mean.toPrecision(6));
            this.stats.value[4] = Number(stddev.toPrecision(6));
         }
      }

      if (g.type === "histogram") {
         this.stats.name = ["Entries", "Mean", "Std Dev"];
         this.stats.value = Array(3).fill(0);
         let n = g.yData.reduce((sum, y) => sum + y, 0);

         if (n > 1) {
            let sumY = 0;
            let sumXY = 0;
            let sumX2Y = 0;

            for (let i=0 ; i< g.xData.length ; i++) {
               sumY += g.yData[i];
               sumXY += g.xData[i] * g.yData[i];
               sumX2Y += g.xData[i] * g.xData[i] * g.yData[i];
            }

            let mean = sumXY / sumY;
            let variance = sumX2Y / sumY - mean ** 2;
            let stddev = Math.sqrt(variance);
            this.stats.value[0] = Number(n);
            this.stats.value[1] = Number(mean.toPrecision(6));
            this.stats.value[2] = Number(stddev.toPrecision(6));
         }
      }

      if (g.type === "bar") {
         if (g.yData.length > 0) {
            this.stats.name = ["Mean", "Min", "Max"];
            this.stats.value = Array(3).fill(0);
            let mean = g.yData.reduce((sum, y) => sum + y, 0) / g.yData.length;

            this.stats.value[0] = mean.toPrecision(6);
            this.stats.value[1] = Math.min(...g.yData).toPrecision(6);
            this.stats.value[2] = Math.max(...g.yData).toPrecision(6);
         }
      }

      if (g.type === "colormap") {
         this.stats.name = ["Entries", "Mean X", "Mean Y", "Std Dev X", "Std Dev Y"];

         this.stats.value = Array(5).fill(0);

         if (g.nx > 1 && g.ny > 1) {
            let n = 0;

            // calculate x/y values
            let dx = (g.xMax - g.xMin) / this.nx;
            let dy = (g.yMax - g.yMin) / this.ny;

            let xi = Array.from({ length: g.nx }, (_, i) =>
               g.xMin + (i + 0.5) * dx);

            // sum up all columns projected to X-axis
            let sumH = Array(g.nx).fill(0);
            for (let i=0 ; i<g.nx ; i++) {
               for (let j = 0; j < g.ny; j++) {
                  n += g.zData[i + j * g.nx];
                  sumH[i] += g.zData[i + j * g.nx];
               }
            }

            let sumY = 0;
            let sumXY = 0;
            let sumX2Y = 0;

            for (let i=0 ; i< g.nx ; i++) {
               sumY += sumH[i];
               sumXY += xi[i] * sumH[i];
               sumX2Y += xi[i] * xi[i] * sumH[i];
            }

            let mean = sumXY / sumY;
            let variance = sumX2Y / sumY - mean ** 2;
            let stddev = Math.sqrt(variance);
            this.stats.value[0] = Number(n.toPrecision(6));
            this.stats.value[1] = Number(mean.toPrecision(6));
            this.stats.value[3] = Number(stddev.toPrecision(6));

            //----------------------------------------------

            xi = Array.from({ length: g.ny }, (_, i) =>
               g.yMin + (i + 0.5) * dy);

            // sup up all rows projected to Y-axis
            sumH = Array(g.ny).fill(0);
            for (let i=0 ; i<g.ny ; i++) {
               for (let j = 0; j < g.nx; j++) {
                  sumH[i] += g.zData[j + i * g.nx];
               }
            }

            sumY = 0;
            sumXY = 0;
            sumX2Y = 0;

            for (let i=0 ; i< g.ny ; i++) {
               sumY += sumH[i];
               sumXY += xi[i] * sumH[i];
               sumX2Y += xi[i] * xi[i] * sumH[i];
            }

            mean = sumXY / sumY;
            variance = sumX2Y / sumY - mean ** 2;
            stddev = Math.sqrt(variance);
            this.stats.value[2] = Number(mean.toPrecision(6));
            this.stats.value[4] = Number(stddev.toPrecision(6));
         }
      }

   }

   /** Draw a single marker on plot
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {object} p param object from MPlotGraph
    * @param {number} x x coord of marker
    * @param {number} y y coord of marker
    */
   drawMarker(ctx, p, x, y) {
      ctx.strokeStyle = p.marker.lineColor;
      ctx.fillStyle = p.marker.fillColor;

      let size = p.marker.size;
      ctx.lineWidth = p.marker.lineWidth;

      switch(p.marker.style) {
         case "circle":
            ctx.beginPath();
            ctx.arc(x, y, size / 2, 0, 2 * Math.PI);
            ctx.fill();
            ctx.stroke();
            break;
         case "square":
            ctx.fillRect(x - size / 2, y - size / 2, size, size);
            ctx.strokeRect(x - size / 2, y - size / 2, size, size);
            break;
         case "diamond":
            ctx.beginPath();
            ctx.moveTo(x, y - size / 2);
            ctx.lineTo(x + size / 2, y);
            ctx.lineTo(x, y + size / 2);
            ctx.lineTo(x - size / 2, y);
            ctx.lineTo(x, y - size / 2);
            ctx.fill();
            ctx.stroke();
            break;
         case "pentagon":
            ctx.beginPath();
            ctx.moveTo(x + size * 0.00, y - size * 0.50);
            ctx.lineTo(x + size * 0.48, y - size * 0.16);
            ctx.lineTo(x + size * 0.30, y + size * 0.41);
            ctx.lineTo(x - size * 0.30, y + size * 0.41);
            ctx.lineTo(x - size * 0.48, y - size * 0.16);
            ctx.lineTo(x + size * 0.00, y - size * 0.50);
            ctx.fill();
            ctx.stroke();
            break;
         case "triangle-up":
            ctx.beginPath();
            ctx.moveTo(x, y - size / 2);
            ctx.lineTo(x + size / 2, y + size / 2);
            ctx.lineTo(x - size / 2, y + size / 2);
            ctx.lineTo(x, y - size / 2);
            ctx.fill();
            ctx.stroke();
            break;
         case "triangle-down":
            ctx.beginPath();
            ctx.moveTo(x, y + size / 2);
            ctx.lineTo(x + size / 2, y - size / 2);
            ctx.lineTo(x - size / 2, y - size / 2);
            ctx.lineTo(x, y + size / 2);
            ctx.fill();
            ctx.stroke();
            break;
         case "triangle-left":
            ctx.beginPath();
            ctx.moveTo(x - size / 2, y);
            ctx.lineTo(x + size / 2, y - size / 2);
            ctx.lineTo(x + size / 2, y + size / 2);
            ctx.lineTo(x - size / 2, y);
            ctx.fill();
            ctx.stroke();
            break;
         case "triangle-right":
            ctx.beginPath();
            ctx.moveTo(x + size / 2, y);
            ctx.lineTo(x - size / 2, y - size / 2);
            ctx.lineTo(x - size / 2, y + size / 2);
            ctx.lineTo(x + size / 2, y);
            ctx.fill();
            ctx.stroke();
            break;
         case "cross":
            ctx.beginPath();
            ctx.moveTo(x - size / 2, y - size / 2);
            ctx.lineTo(x + size / 2, y + size / 2);
            ctx.moveTo(x - size / 2, y + size / 2);
            ctx.lineTo(x + size / 2, y - size / 2);
            ctx.stroke();
            break;
         case "plus":
            ctx.beginPath();
            ctx.moveTo(x - size / 2, y);
            ctx.lineTo(x + size / 2, y);
            ctx.moveTo(x, y + size / 2);
            ctx.lineTo(x, y - size / 2);
            ctx.stroke();
            break;
      }
   }

   /** Draw a single horizontal errorbar on the plot
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {object} p param object from MPlotGraph
    * @param {number} x x coord of bar center (unused)
    * @param {number} y y coord of bar center
    * @param {number} x1 position of the low side error bar enpoint
    * @param {number} x2 position of the high side error bar enpoint
    */
   drawXErrorBar(ctx, p, x, y, x1, x2) {
      let size = p.marker.size / 2;

      ctx.beginPath();
      ctx.moveTo(x1, y);
      ctx.lineTo(x2, y);
      ctx.moveTo(x1, y-size);
      ctx.lineTo(x1, y+size);
      ctx.moveTo(x2, y-size);
      ctx.lineTo(x2, y+size);
      ctx.stroke();
   }

   /** Draw a single vertical errorbar on the plot
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {object} p param object from MPlotGraph
    * @param {number} x x coord of bar center
    * @param {number} y y coord of bar center (unused)
    * @param {number} y1 position of the low side error bar enpoint
    * @param {number} y2 position of the high side error bar enpoint
    */
   drawYErrorBar(ctx, p, x, y, y1, y2) {
      let size = p.marker.size / 2;

      ctx.beginPath();
      ctx.moveTo(x, y1);
      ctx.lineTo(x, y2);
      ctx.moveTo(x-size, y1);
      ctx.lineTo(x+size, y1);
      ctx.moveTo(x-size, y2);
      ctx.lineTo(x+size, y2);
      ctx.stroke();
   }

   /** draw all elements of the graph into the canvas: axes, plots, text, buttons, etc. */
   draw() {
      //profile();
      if (!this.canvas || this.param.plot.length === 0)
         return;

      let ctx = this.canvas.getContext("2d");

      this.width = this.canvas.width;
      this.height = this.canvas.height;

      ctx.fillStyle = this.param.color.background;
      ctx.fillRect(0, 0, this.width, this.height);

      if (this.error !== null) {
         ctx.lineWidth = 1;
         ctx.font = "14px sans-serif";
         ctx.strokeStyle = "#808080";
         ctx.fillStyle = "#808080";
         ctx.textAlign = "center";
         ctx.textBaseline = "middle";
         ctx.fillText(this.error, this.width / 2, this.height / 2);
         return;
      }

      if (this.param.plot[0].xData === undefined) {
         ctx.lineWidth = 1;
         ctx.font = "14px sans-serif";
         ctx.strokeStyle = "#808080";
         ctx.fillStyle = "#808080";
         ctx.textAlign = "center";
         ctx.textBaseline = "middle";
         ctx.fillText("No data-odb-path present and no setData() called", this.width / 2, this.height / 2);
         return;
      }

      if (this.height === undefined || this.width === undefined)
         return;
      if (this.param.plot[0].xMin === undefined || this.param.plot[0].xMax === undefined)
         return;

      ctx.font = this.param.yAxis.textSize + "px sans-serif";

      let axisLabelWidth = this.drawYAxis(ctx, 50, this.height - 25, this.height - 35,
         -4, -7, -10, -12, 0, this.yMin, this.yMax, this.param.yAxis.log, false);

      if (axisLabelWidth === undefined)
         return;

      if (this.param.yAxis.title.text && this.param.yAxis.title.text !== "")
         this.x1 = axisLabelWidth + 5 + 2.5*this.param.yAxis.title.textSize;
      else
         this.x1 = axisLabelWidth + 15;

      this.x2 = this.param.showMenuButtons ? this.width - 30 : this.width - 2;
      if (this.param.zAxis.title.text && this.param.zAxis.title.text !== "")
         this.x2 -= 1.0*this.param.zAxis.title.textSize;

      if (this.param.showMenuButtons === false)
         this.x2 = this.width - 2;

      this.y1 = this.height;
      this.y2 = 6;

      let axisLabelHeight;
      if (this.param.xAxis.type === "category")
         axisLabelHeight = this.drawCAxis(ctx, this.x1, this.y1, this.x2 - this.x1,
            10, 12, this.xMin, this.xMax, this.param.plot[0].xData, false);
      else
         axisLabelHeight = this.param.xAxis.textSize;

      axisLabelHeight += 12; // space for ticks and frame

      if (this.param.xAxis.title.text && this.param.xAxis.title.text !== "")
         this.y1 = this.height - axisLabelHeight - 1.5*this.param.xAxis.title.textSize;
      else
         this.y1 = this.height - axisLabelHeight;

      if (this.param.plot[0].type === "colormap" && this.param.plot[0].showZScale) {
         if (this.zMin === undefined || this.zMax === undefined) {
            this.zMin = 0;
            this.zMax = 1;
         }
         if (this.zMin === this.zMax) {
            this.zMin -= 0.5;
            this.zMax += 0.5;
         }

         ctx.font = this.param.zAxis.textSize + "px sans-serif";
         axisLabelWidth = this.drawYAxis(ctx, this.x2 + 30, this.y1, this.y1 - this.y2,
            4, 7, 10, 12, 0, this.zMin, this.zMax, this.param.zAxis.log, false);
         if (axisLabelWidth === undefined)
            return;

         if (this.param.zAxis.show) {
            let w = 5;  // left gap
            w += 10;    // color bar
            w += 12;    // tick width
            w += 5;

            this.x2 -= axisLabelWidth + w;
            this.param.zAxis.width = axisLabelWidth + w;
         }
      }

      // title
      if (this.param.title.text !== "") {
         ctx.strokeStyle = this.param.color.axis;
         ctx.fillStyle = "#F0F0F0";
         ctx.font = this.param.title.textSize + "px sans-serif";
         let h = this.param.title.textSize * 1.2;
         ctx.strokeRect(this.x1, 6, this.x2 - this.x1, h);
         ctx.fillRect(this.x1, 6, this.x2 - this.x1, h);
         ctx.textAlign = "center";
         ctx.textBaseline = "middle";
         ctx.fillStyle = this.param.title.color;
         ctx.fillText(this.param.title.text, (this.x2 + this.x1) / 2, 6 + h/2);
         this.y2 = 6 + h;
      }

      // draw axis
      ctx.strokeStyle = this.param.color.axis;

      if (this.param.yAxis.log && this.yMin < 1E-20)
         this.yMin = 1E-20;
      if (this.param.yAxis.log && this.yMax < 1E-18)
         this.yMax = 1E-18;

      if (this.param.xAxis.title.text && this.param.xAxis.title.text !== "") {
         ctx.save();
         ctx.fillStyle = this.param.title.color;
         let s = this.param.xAxis.title.textSize;
         ctx.font = s + "px sans-serif";
         ctx.textAlign = "center";
         ctx.textBaseline = "top";
         ctx.fillText(this.param.xAxis.title.text, (this.x1 + this.x2)/2,
            this.y1 + this.param.xAxis.textSize + 10 + this.param.xAxis.title.textSize / 4);
         ctx.restore();
      }

      ctx.font = this.param.xAxis.textSize + "px sans-serif";
      let grid = this.param.xAxis.grid ? this.y2 - this.y1 : 0;

      if (this.param.xAxis.type === "numeric")
         this.drawXAxis(ctx, this.x1, this.y1, this.x2 - this.x1,
            4, 7, 10, 10, grid, this.xMin, this.xMax, this.param.xAxis.log);
      else if (this.param.xAxis.type === "datetime")
         this.drawTAxis(ctx, this.x1, this.y1, this.x2 - this.x1, this.width,
            4, 7, 10, 10, grid, this.xMin, this.xMax);
      else if (this.param.xAxis.type === "category")
         this.drawCAxis(ctx, this.x1, this.y1, this.x2 - this.x1,
            10, 12, this.xMin, this.xMax, this.param.plot[0].xData, true);

      if (this.param.yAxis.title.text && this.param.yAxis.title.text !== "") {
         ctx.save();
         ctx.fillStyle = this.param.title.color;
         let s = this.param.yAxis.title.textSize;
         ctx.translate(s / 2, (this.y1 + this.y2) / 2);
         ctx.rotate(-Math.PI / 2);
         ctx.font = s + "px sans-serif";
         ctx.textAlign = "center";
         ctx.textBaseline = "top";
         ctx.fillText(this.param.yAxis.title.text, 0, 0);
         ctx.restore();
      }

      if (this.param.zAxis.title.text && this.param.zAxis.title.text !== "") {
         ctx.save();
         ctx.fillStyle = this.param.title.color;
         let s = this.param.zAxis.title.textSize;
         ctx.translate(s / 2, (this.y1 + this.y2) / 2);
         ctx.rotate(-Math.PI / 2);
         ctx.font = s + "px sans-serif";
         ctx.textAlign = "center";
         ctx.textBaseline = "middle";
         ctx.fillText(this.param.zAxis.title.text, 0, this.x2 + this.param.zAxis.width);
         ctx.restore();
      }

      ctx.font = this.param.yAxis.textSize + "px sans-serif";
      grid = this.param.yAxis.grid ? this.x2 - this.x1 : 0;
      this.drawYAxis(ctx, this.x1, this.y1, this.y1 - this.y2,
         -4, -7, -10, -12, grid, this.yMin, this.yMax, this.param.yAxis.log, true);

      if (this.param.yAxis.title.text && this.param.yAxis.title.text !== "") {
         ctx.save();
         let s = this.param.yAxis.title.textSize;
         ctx.translate(s / 2, (this.y1 + this.y2) / 2);
         ctx.rotate(-Math.PI / 2);
         ctx.font = s + "px sans-serif";
         ctx.textAlign = "center";
         ctx.textBaseline = "top";
         ctx.fillText(this.param.yAxis.title.text, 0, 0);
         ctx.restore();
      }

      // draw frame
      ctx.strokeStyle = this.param.color.axis;
      ctx.strokeRect(this.x1, this.y1, this.x2-this.x1, this.y2-this.y1);

      // set clipping region not to draw outside axes
      ctx.save();
      ctx.rect(this.x1, this.y2, this.x2 - this.x1, this.y1 - this.y2);
      ctx.clip();

      // draw graphs
      let noData = true;
      for (const [plotIndex,p] of this.param.plot.entries()) {
         if (p.xData === undefined || p.xData === null)
            continue;

         if (p.xData.length > 0)
            noData = false;

         ctx.globalAlpha = p.alpha;

         if (p.type === "scatter") {
            // draw lines
            if (p.line && p.line.draw ||
               p.line && p.line.fill) {

               ctx.fillStyle = p.line.color;
               ctx.strokeStyle = ctx.fillStyle;

               // shaded area
               if (p.line.fill) {
                  ctx.globalAlpha = 0.1;
                  ctx.beginPath();
                  ctx.moveTo(this.xToScreen(p.xData[0]), this.yToScreen(0));
                  for (let i = 0; i < p.xData.length; i++) {
                     let x = this.xToScreen(p.xData[i]);
                     let y = this.yToScreen(p.yData[i]);
                     ctx.lineTo(x, y);
                  }
                  ctx.lineTo(this.xToScreen(p.xData[p.xData.length - 1]), this.yToScreen(0));
                  ctx.lineTo(this.xToScreen(p.xData[0]), this.yToScreen(0));
                  ctx.fill();
                  ctx.globalAlpha = 1;
               }

               // draw line
               if (p.line.draw && p.line.width > 0 && p.line.style !== "none") {
                  ctx.lineWidth = p.line.width;
                  ctx.beginPath();
                  if (p.line.style === "dashed")
                     ctx.setLineDash([5,5]);
                  if (p.line.style === "dotted")
                     ctx.setLineDash([1,10]);
                  for (let i = 0; i < p.xData.length; i++) {
                     let x = this.xToScreen(p.xData[i]);
                     let y = this.yToScreen(p.yData[i]);
                     if (i === 0)
                        ctx.moveTo(x, y);
                     else
                        ctx.lineTo(x, y);
                  }
                  ctx.stroke();
                  ctx.setLineDash([]);
               }
            }

            // draw markers
            if (p.marker && p.marker.draw) {
               for (let i = 0; i < p.xData.length; i++) {

                  let x = this.xToScreen(p.xData[i]);
                  let y = this.yToScreen(p.yData[i]);

                  this.drawMarker(ctx, p, x, y);

                  if (p.xErrorData) {
                     let x1 = this.xToScreen(p.xData[i]-p.xErrorData[i]);
                     let x2 = this.xToScreen(p.xData[i]+p.xErrorData[i]);
                     this.drawXErrorBar(ctx, p, x, y, x1, x2);
                  }

                  if (p.yErrorData) {
                     let y1 = this.yToScreen(p.yData[i]+p.yErrorData[i]);
                     let y2 = this.yToScreen(p.yData[i]-p.yErrorData[i]);
                     this.drawYErrorBar(ctx, p, x, y, y1, y2);
                  }
               }
            }
         }

         else if (p.type === "histogram") {
            let x, y;
            let dx = (p.xMax - p.xMin) / p.xData.length;
            let dxs = dx / (this.xMax - this.xMin) * (this.x2 - this. x1);

            if (p.length < 100)
               ctx.lineWidth = 2;
            else
               ctx.lineWidth = 1;

            ctx.fillStyle = p.line.color;
            ctx.strokeStyle = ctx.fillStyle;

            ctx.beginPath();
            ctx.moveTo(this.xToScreen(p.xData[0])-dxs/2, this.yToScreen(0));
            for (let i = 0; i < p.xData.length; i++) {
               x = this.xToScreen(p.xData[i]);
               y = this.yToScreen(p.yData[i]);
               ctx.lineTo(x-dxs/2, y);
               ctx.lineTo(x+dxs/2, y);
            }
            ctx.lineTo(x+dxs/2, this.yToScreen(0));
            ctx.globalAlpha = 0.2;
            ctx.fill();
            ctx.globalAlpha = 1;
            ctx.stroke();
         }

         else if (p.type === "bar") {
            let x, y;
            let dx = (this.x2 - this. x1) * (this.xMax0-this.xMin0) / (this.xMax-this.xMin) / p.xData.length;

            let totalWidth;
            if (this.param.barWidth)
               totalWidth = dx * this.param.barWidth;
            else
               totalWidth = dx * 0.3;

            let barWidth = totalWidth / this.param.plot.length; // each plot gets a fraction of the bar width
            let offset = plotIndex * barWidth;

            if (p.xData.length < 100)
               ctx.lineWidth = 2;
            else
               ctx.lineWidth = 1;

            ctx.fillStyle = p.line.color;
            ctx.strokeStyle = ctx.fillStyle;

            ctx.beginPath();
            for (let i = 0; i < p.xData.length; i++) {
               x = this.xToScreen(i + 0.5);
               y = this.yToScreen(p.yData[i]);
               ctx.moveTo(x-totalWidth/2+offset, this.yToScreen(0));
               ctx.lineTo(x-totalWidth/2+offset, y);
               ctx.lineTo(x-totalWidth/2+barWidth+offset, y);
               ctx.lineTo(x-totalWidth/2+barWidth+offset, this.yToScreen(0));
               ctx.lineTo(x-totalWidth/2+offset, this.yToScreen(0));
            }
            ctx.globalAlpha = 0.2;
            ctx.fill();
            ctx.globalAlpha = 1;
            ctx.stroke();
         }

         else if (p.type === "colormap") {
            let dx = (p.xMax - p.xMin) / this.nx;
            let dy = (p.yMax - p.yMin) / this.ny;

            let dxs = dx / (this.xMax - this.xMin) * (this.x2 - this. x1);
            let dys = dy / (this.yMax - this.yMin) * (this.y2 - this. y1);

            for (let i=0 ; i<p.ny ; i++) {
               for (let j=0 ; j<p.nx ; j++) {
                  let x = this.xToScreen(j * dx + p.xMin);
                  let y = this.yToScreen(i * dy + p.yMin);
                  let zval = this.param.plot[0].zData[j+i*p.nx];
                  if (isNaN(zval)) {
                     ctx.fillStyle = 'hsl(255, 0%, 50%)';                  
                  } else {
                     let v;
                     if (this.param.zAxis.log) {
                        if (zval <= 0)
                           v = 0;
                        else
                           v = (Math.log(zval) - Math.log(this.zMin)) / (Math.log(this.zMax) - Math.log(this.zMin));
                     } else
                        v = (zval - this.zMin) / (this.zMax - this.zMin);

                     // limit v to 0...1
                     if (v < 0)
                        v = 0;
                     if (v > 1)
                        v = 1;

                     if (zval < 0.5 && this.param.plot[0].zeroColor)
                        ctx.fillStyle = this.param.plot[0].zeroColor;
                     else
                        //ctx.fillStyle = 'hsl(' + Math.floor((1 - v) * 240) + ', 100%, 50%)';
			ctx.fillStyle = colorPalette[Math.floor((1 - v)*255)];
                  }
                  ctx.fillRect(Math.floor(x), Math.floor(y), Math.floor(dxs+1), Math.floor(dys-1));
               }
            }
            //profile("plot");
         }
      }

      ctx.restore(); // remove clipping

      // plot color scale
      if (this.param.plot[0].type === "colormap") {
         if (this.param.plot[0].showZScale) {

            for (let i=0 ; i<100 ; i++) {
               let v = i / 100;
               //ctx.fillStyle = 'hsl(' +
               //   Math.floor(v * 240) + ', 100%, 50%)';
               ctx.fillStyle = colorPalette[Math.floor(v*255)];
               ctx.fillRect(this.x2 + 5, this.y2 + i/100*(this.y1 - this.y2),
                  10, (this.y1 - this.y2) / 100 + 1);
            }

            ctx.lineWidth = 1;
            ctx.strokeStyle = this.param.color.axis;
            ctx.beginPath();
            ctx.rect(this.x2 + 5, this.y2, 10, this.y1 - this.y2);
            ctx.stroke();

            ctx.font = this.param.zAxis.textSize + "px sans-serif";
            ctx.strokeStyle = this.param.color.axis;

            this.drawYAxis(ctx, this.x2 + 15, this.y1, this.y1 - this.y2,
               4, 7, 10, 12, 0, this.zMin, this.zMax, this.param.zAxis.log, true);
         }
      }

      // plot legend
      let nLabel = 0;
      for (const g of this.param.plot)
         if (g.label && g.label !== "")
            nLabel++;

      if (this.param.legend?.show && nLabel > 0) {
         ctx.font = this.param.legend.textSize + "px sans-serif";

         let mw = 0;
         for (const g of this.param.plot) {
            if (ctx.measureText(g.label).width > mw) {
               mw = ctx.measureText(g.label).width;
            }
         }
         let w = 50 + mw + 5;
         let h = this.param.legend.textSize * 1.5;

         ctx.fillStyle = this.param.legend.backgroundColor;
         ctx.strokeStyle = this.param.legend.color;
         ctx.fillRect(this.x1, this.y2, w, h * this.param.plot.length);
         ctx.strokeRect(this.x1, this.y2, w, h  * this.param.plot.length);

         for (const [gi,g] of this.param.plot.entries()) {
            if (g.line && g.line.draw && g.line.width > 0 && g.line.style !== "none") {
               ctx.beginPath();
               ctx.strokeStyle = g.line.color;
               ctx.lineWidth = g.line.width;

               if (g.line.style === "dashed")
                  ctx.setLineDash([5,5]);
               if (g.line.style === "dotted")
                  ctx.setLineDash([1,10]);

               ctx.beginPath();
               ctx.moveTo(this.x1 + 5, this.y2 + gi*h + h/2);
               ctx.lineTo(this.x1 + 35, this.y2 + gi*h + h/2);
               ctx.stroke();

               ctx.setLineDash([]);
            }
            ctx.strokeStyle = g.line.color;
            ctx.lineWidth = g.line.width;
            if (g.marker?.draw)
               this.drawMarker(ctx, g, this.x1 + 20, this.y2 + gi*h + h/2);
            ctx.textAlign = "left";
            ctx.textBaseline = "middle";
            ctx.fillStyle = this.param.color.axis;
            ctx.fillText(g.label, this.x1 + 40, this.y2 + gi*h + h/2);
         }
      }

      this.calcStats();

      // plot statistics
      if (this.param.stats.show && this.stats.name) {
         ctx.font = this.param.legend.textSize + "px sans-serif";

         let mw = 0;
         for (const [si,s] of this.stats.name.entries()) {
            let str = s + "    " + this.stats.value[si].toString();
            if (ctx.measureText(str).width > mw) {
               mw = ctx.measureText(str).width;
            }
         }
         let w = mw + 10;
         let h = this.param.legend.textSize * 1.5;

         ctx.fillStyle = this.param.legend.backgroundColor;
         ctx.strokeStyle = this.param.legend.color;
         ctx.fillRect(this.x2 - w, this.y2, w, h * this.stats.name.length);
         ctx.strokeRect(this.x2 - w, this.y2, w, h  * this.stats.name.length);

         for (const [si,s] of this.stats.name.entries()) {
            ctx.textAlign = "left";
            ctx.textBaseline = "middle";
            ctx.fillStyle = this.param.color.axis;
            ctx.fillText(s, this.x2 - w + 5, this.y2 + si*h + h/2);
            ctx.textAlign = "right";
            let str = this.stats.value[si].toString();
            ctx.fillText(str, this.x2 - 5, this.y2 + si*h + h/2);
         }
      }

      // "empty window" notice
      if (noData) {
         ctx.font = "16px sans-serif";
         let str = "No data available";
         ctx.strokeStyle = "#404040";
         ctx.fillStyle = "#F0F0F0";
         let w = ctx.measureText(str).width + 10;
         let h = 16 + 10;
         ctx.fillRect((this.x1 + this.x2) / 2 - w / 2, (this.y1 + this.y2) / 2 - h / 2, w, h);
         ctx.strokeRect((this.x1 + this.x2) / 2 - w / 2, (this.y1 + this.y2) / 2 - h / 2, w, h);
         ctx.fillStyle = "#404040";
         ctx.textAlign = "center";
         ctx.textBaseline = "middle";
         ctx.fillText(str, (this.x1 + this.x2) / 2, (this.y1 + this.y2) / 2);
         ctx.font = "14px sans-serif";
      }

      // buttons
      if (this.param.showMenuButtons) {
         let y = 0;
         let buttonSize = 20;
         this.button.forEach(b => {

            b.x1 = this.width - buttonSize - 6;
            b.y1 = 6 + y * (buttonSize + 4);
            b.width = buttonSize + 4;
            b.height = buttonSize + 4;
            b.enabled = true;

            ctx.fillStyle = "#F0F0F0";
            ctx.strokeStyle = "#808080";
            ctx.fillRect(b.x1, b.y1, b.width, b.height);
            ctx.strokeRect(b.x1, b.y1, b.width, b.height);
            ctx.drawImage(b.img, b.x1 + 2, b.y1 + 2);

            y++;
         });
      }

      // axis zoom
      if (this.zoom.x.active) {
         ctx.fillStyle = "#808080";
         ctx.globalAlpha = 0.2;
         ctx.fillRect(this.zoom.x.x1, this.y2, this.zoom.x.x2 - this.zoom.x.x1, this.y1 - this.y2);
         ctx.globalAlpha = 1;
         ctx.strokeStyle = "#808080";
         ctx.drawLine(this.zoom.x.x1, this.y1, this.zoom.x.x1, this.y2);
         ctx.drawLine(this.zoom.x.x2, this.y1, this.zoom.x.x2, this.y2);
      }
      if (this.zoom.y.active) {
         ctx.fillStyle = "#808080";
         ctx.globalAlpha = 0.2;
         ctx.fillRect(this.x1, this.zoom.y.y1, this.x2 - this.x1, this.zoom.y.y2 - this.zoom.y.y1);
         ctx.globalAlpha = 1;
         ctx.strokeStyle = "#808080";
         ctx.drawLine(this.x1, this.zoom.y.y1, this.x2, this.zoom.y.y1);
         ctx.drawLine(this.x1, this.zoom.y.y2, this.x2, this.zoom.y.y2);
      }

      // marker
      if (this.marker.active) {

         // round marker
         if (this.param.plot[0].type !== "colormap") {
            ctx.beginPath();
            ctx.globalAlpha = 0.1;
            ctx.arc(this.marker.sx, this.marker.sy, 10, 0, 2 * Math.PI);
            ctx.fillStyle = "#000000";
            ctx.fill();
            ctx.globalAlpha = 1;

            ctx.beginPath();
            ctx.arc(this.marker.xs, this.marker.sy, 4, 0, 2 * Math.PI);
            ctx.fillStyle = "#000000";
            ctx.fill();
         }

         ctx.strokeStyle = "#A0A0A0";
         ctx.drawLine(this.marker.sx, this.y1, this.marker.sx, this.y2);
         ctx.drawLine(this.x1, this.marker.sy, this.x2, this.marker.sy);

         // text label
         ctx.font = "12px sans-serif";
         ctx.textAlign = "left";
         let s;
         if (this.parentDiv.dataset.tooltip) {
            let f = this.parentDiv.dataset.tooltip;
            if (f.indexOf('(') !== -1) // strip any '('
               f = f.substring(0, f.indexOf('('));

            s = eval(f + "(this)");
         } else {
            if (this.param.plot[0].type === "bar")
               s = this.marker.x + " / " +
                  this.marker.y.toPrecision(6).stripZeros();
            else
               s = this.marker.x.toPrecision(6).stripZeros() + " / " +
                  this.marker.y.toPrecision(6).stripZeros();
            if (this.param.plot[0].type === "colormap")
               s += ": " + (this.marker.z === null ? "null" : this.marker.z.toPrecision(6).stripZeros());
         }
         let w = ctx.measureText(s).width + 6;
         let h = ctx.measureText("M").width * 1.2 + 6;
         let x = this.marker.mx + 10;
         let y = this.marker.my - 20;

         // move marker inside if outside plotting area
         if (x + w >= this.x2)
            x = this.marker.sx - 10 - w;

         ctx.strokeStyle = "#808080";
         ctx.fillStyle = "#F0F0F0";
         ctx.textBaseline = "middle";
         ctx.fillRect(x, y, w, h);
         ctx.strokeRect(x, y, w, h);
         ctx.fillStyle = "#404040";
         ctx.fillText(s, x + 3, y + h / 2);
      }

      // call optional user overlay function
      if (this.param.overlay) {

         // set default text
         ctx.textAlign = "left";
         ctx.textBaseline = "top";
         ctx.fillStyle = "black";
         ctx.strokeStyle = "black";
         ctx.font = "12px sans-serif";

         eval(this.param.overlay + "(this, ctx)");
      }

      //profile("end");
   }

   /** Draw the xaxis as "numeric" 
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {number} x1 coordinate position of the axis on screen
    * @param {number} y1 coordinate position of the axis on screen
    * @param {number} width width of the axis, likely also the width of the plot
    * @param {number} minor step between minor ticks 
    * @param {number} major step between major ticks 
    * @param {string} text 
    * @param {string} label
    * @param {bool} grid if true draw grid lines over minor ticks
    * @param {number} ymin low limit of the axis
    * @param {number} ymax high limit of the axis 
    * @param {bool} logaxis if true draw axis on a log scale (base 10)
    */
   drawXAxis(ctx, x1, y1, width, minor, major, text, label, grid, xmin, xmax, logaxis) {
      var dx, int_dx, frac_dx, x_act, label_dx, major_dx, x_screen, maxwidth;
      var tick_base, major_base, label_base, n_sig1, n_sig2, xs;
      var base = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000];

      if (xmin === undefined || xmax === undefined || isNaN(xmin) || isNaN(xmax))
         return;

      if (xmax <= xmin || width <= 0)
         return;

      ctx.textAlign = "center";
      ctx.textBaseline = "top";

      if (logaxis) {

         dx = Math.pow(10, Math.floor(Math.log(xmin) / Math.log(10)));
         if (isNaN(dx) || dx === 0) {
            xmin = 1E-20;
            dx = 1E-20;
         }
         label_dx = dx;
         major_dx = dx * 10;
         n_sig1 = 4;

      } else { // linear axis ----

         // use 10 as min tick distance
         dx = (xmax - xmin) / (width / 10);

         int_dx = Math.floor(Math.log(dx) / LN10);
         frac_dx = Math.log(dx) / LN10 - int_dx;

         if (frac_dx < 0) {
            frac_dx += 1;
            int_dx -= 1;
         }

         tick_base = frac_dx < LOG2 ? 1 : frac_dx < LOG5 ? 2 : 3;
         major_base = label_base = tick_base + 1;

         // rounding up of dx, label_dx
         dx = Math.pow(10, int_dx) * base[tick_base];
         major_dx = Math.pow(10, int_dx) * base[major_base];
         label_dx = major_dx;

         do {
            // number of significant digits
            if (xmin === 0)
               n_sig1 = 0;
            else
               n_sig1 = Math.floor(Math.log(Math.abs(xmin)) / LN10) - Math.floor(Math.log(Math.abs(label_dx)) / LN10) + 1;

            if (xmax === 0)
               n_sig2 = 0;
            else
               n_sig2 = Math.floor(Math.log(Math.abs(xmax)) / LN10) - Math.floor(Math.log(Math.abs(label_dx)) / LN10) + 1;

            n_sig1 = Math.max(n_sig1, n_sig2);

            // toPrecision displays 1050 with 3 digits as 1.05e+3, so increase precision to number of digits
            if (Math.abs(xmin) < 100000)
               n_sig1 = Math.max(n_sig1, Math.floor(Math.log(Math.abs(xmin)) / LN10) + 1);
            if (Math.abs(xmax) < 100000)
               n_sig1 = Math.max(n_sig1, Math.floor(Math.log(Math.abs(xmax)) / LN10) + 1);

            // determination of maximal width of labels
            let str = (Math.floor(xmin / dx) * dx).toPrecision(n_sig1);
            let ext = ctx.measureText(str);
            maxwidth = ext.width;

            str = (Math.floor(xmax / dx) * dx).toPrecision(n_sig1).stripZeros();
            ext = ctx.measureText(str);
            maxwidth = Math.max(maxwidth, ext.width);
            str = (Math.floor(xmax / dx) * dx + label_dx).toPrecision(n_sig1).stripZeros();
            maxwidth = Math.max(maxwidth, ext.width);

            // increasing label_dx, if labels would overlap
            if (maxwidth > 0.5 * label_dx / (xmax - xmin) * width) {
               label_base++;
               label_dx = Math.pow(10, int_dx) * base[label_base];
               if (label_base % 3 === 2 && major_base % 3 === 1) {
                  major_base++;
                  major_dx = Math.pow(10, int_dx) * base[major_base];
               }
            } else
               break;

         } while (true);
      }

      x_act = Math.floor(xmin / dx) * dx;

      ctx.strokeStyle = this.param.color.axis;
      ctx.drawLine(x1, y1, x1 + width, y1);

      do {
         if (logaxis)
            x_screen = (Math.log(x_act) - Math.log(xmin)) /
               (Math.log(xmax) - Math.log(xmin)) * width + x1;
         else
            x_screen = (x_act - xmin) / (xmax - xmin) * width + x1;
         xs = Math.floor(x_screen + 0.5);

         if (x_screen > x1 + width + 0.001)
            break;

         if (x_screen >= x1) {
            if (Math.abs(Math.floor(x_act / major_dx + 0.5) - x_act / major_dx) <
               dx / major_dx / 10.0) {

               if (Math.abs(Math.floor(x_act / label_dx + 0.5) - x_act / label_dx) <
                  dx / label_dx / 10.0) {
                  // label tick mark
                  ctx.strokeStyle = this.param.color.axis;
                  ctx.drawLine(xs, y1, xs, y1 + text);

                  // grid line
                  if (grid !== 0 && xs > x1 && xs < x1 + width) {
                     ctx.strokeStyle = this.param.color.grid;
                     ctx.drawLine(xs, y1, xs, y1 + grid);
                  }

                  // label
                  if (label !== 0) {
                     let str = x_act.toPrecision(n_sig1).stripZeros();
                     let ext = ctx.measureText(str);
                     if (xs - ext.width / 2 > x1 &&
                        xs + ext.width / 2 < x1 + width) {
                        ctx.strokeStyle = this.param.color.label;
                        ctx.fillStyle = this.param.color.label;
                        ctx.fillText(str, xs, y1 + label);
                     }
                     let last_label_x = xs + ext.width / 2;
                  }
               } else {
                  // major tick mark
                  ctx.strokeStyle = this.param.color.axis;
                  ctx.drawLine(xs, y1, xs, y1 + major);

                  // grid line
                  if (grid !== 0 && xs > x1 && xs < x1 + width) {
                     ctx.strokeStyle = this.param.color.grid;
                     ctx.drawLine(xs, y1 - 1, xs, y1 + grid);
                  }
               }

               if (logaxis) {
                  dx *= 10;
                  major_dx *= 10;
                  label_dx *= 10;
               }

            } else {
               // minor tick mark
               ctx.strokeStyle = this.param.color.axis;
               ctx.drawLine(xs, y1, xs, y1 + minor);
            }

            if (logaxis) {
               // for log axis, also put grid lines on minor tick marks
               if (grid !== 0 && xs > x1 && xs < x1 + width) {
                  ctx.strokeStyle = this.param.color.grid;
                  ctx.drawLine(xs, y1 - 1, xs, y1 + grid);
               }

               // for log axis, also put labels on minor tick marks
               if (label !== 0) {
                  let str;
                  if (Math.abs(x_act) < 0.001 && Math.abs(x_act) > 1E-20)
                     str = x_act.toExponential(n_sig1).stripZeros();
                  else
                     str = x_act.toPrecision(n_sig1).stripZeros();
                  ext = ctx.measureText(str);
                  if (xs - ext.width / 2 > x1 &&
                     xs + ext.width / 2 < x1 + width &&
                     xs - ext.width / 2 > last_label_x + 5) {
                     ctx.strokeStyle = this.param.color.label;
                     ctx.fillStyle = this.param.color.label;
                     ctx.fillText(str, xs, y1 + label);
                  }

                  last_label_x = xs + ext.width / 2;
               }
            }
         }

         x_act += dx;

         /* suppress 1.23E-17 ... */
         if (Math.abs(x_act) < dx / 100)
            x_act = 0;

      } while (1);
   }

   /** Draw the yaxis as "numeric"
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {number} x1 coordinate position of the axis on screen
    * @param {number} y1 coordinate position of the axis on screen
    * @param {number} height height of the axis, likely also the height of the plot
    * @param {number} minor step between minor ticks 
    * @param {number} major step between major ticks 
    * @param {string} text 
    * @param {string} label
    * @param {bool} grid if true draw grid lines over minor ticks
    * @param {number} ymin low limit of the axis
    * @param {number} ymax high limit of the axis 
    * @param {bool} logaxis if true draw axis on a log scale (base 10)
    * @param {bool} draw if true draw the axis
    */
   drawYAxis(ctx, x1, y1, height, minor, major, text, label, grid, ymin, ymax, logaxis, draw) {
      let dy, int_dy, frac_dy, y_act, label_dy, major_dy, y_screen;
      let tick_base, major_base, label_base, n_sig1, n_sig2, ys;
      let base = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000];

      if (ymin === undefined || ymax === undefined || isNaN(ymin) || isNaN(ymax))
         return;

      if (ymax <= ymin || height <= 0)
         return;

      if (label < 0)
         ctx.textAlign = "right";
      else
         ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      let textHeight = parseInt(ctx.font.match(/\d+/)[0]);

      if (!isFinite(ymax - ymin) || ymax === Number.MAX_VALUE) {
         dy = Number.MAX_VALUE / 10;
         label_dy = dy;
         major_dy = dy;
         n_sig1 = 1;
      } else if (logaxis) {
         dy = Math.pow(10, Math.floor(Math.log(ymin) / Math.log(10)));
         if (isNaN(dy) || dy === 0) {
            ymin = 1E-20;
            dy = 1E-20;
         }
         label_dy = dy;
         major_dy = dy * 10;
         n_sig1 = 4;
      } else {
         // use 6 as min tick distance
         dy = (ymax - ymin) / (height / 6);

         int_dy = Math.floor(Math.log(dy) / Math.log(10));
         frac_dy = Math.log(dy) / Math.log(10) - int_dy;

         if (frac_dy < 0) {
            frac_dy += 1;
            int_dy -= 1;
         }

         tick_base = frac_dy < (Math.log(2) / Math.log(10)) ? 1 : frac_dy < (Math.log(5) / Math.log(10)) ? 2 : 3;
         major_base = label_base = tick_base + 1;

         // rounding up of dy, label_dy
         dy = Math.pow(10, int_dy) * base[tick_base];
         major_dy = Math.pow(10, int_dy) * base[major_base];
         label_dy = major_dy;

         // number of significant digits
         if (ymin === 0)
            n_sig1 = 1;
         else
            n_sig1 = Math.floor(Math.log(Math.abs(ymin)) / Math.log(10)) -
               Math.floor(Math.log(Math.abs(label_dy)) / Math.log(10)) + 1;

         if (ymax === 0)
            n_sig2 = 1;
         else
            n_sig2 = Math.floor(Math.log(Math.abs(ymax)) / Math.log(10)) -
               Math.floor(Math.log(Math.abs(label_dy)) / Math.log(10)) + 1;

         n_sig1 = Math.max(n_sig1, n_sig2);
         n_sig1 = Math.max(1, n_sig1);

         // toPrecision displays 1050 with 3 digits as 1.05e+3, so increase precision to number of digits
         if (Math.abs(ymin) < 100000)
            n_sig1 = Math.max(n_sig1, Math.floor(Math.log(Math.abs(ymin)) /
               Math.log(10) + 0.001) + 1);
         if (Math.abs(ymax) < 100000)
            n_sig1 = Math.max(n_sig1, Math.floor(Math.log(Math.abs(ymax)) /
               Math.log(10) + 0.001) + 1);

         // increase label_dy if labels would overlap
         while (label_dy / (ymax - ymin) * height < 1.5 * textHeight) {
            label_base++;
            label_dy = Math.pow(10, int_dy) * base[label_base];
            if (label_base % 3 === 2 && major_base % 3 === 1) {
               major_base++;
               major_dy = Math.pow(10, int_dy) * base[major_base];
            }
         }
      }

      y_act = Math.floor(ymin / dy) * dy;

      let last_label_y = y1;
      let maxwidth = 0;

      if (draw) {
         ctx.strokeStyle = this.param.color.axis;
         ctx.drawLine(x1, y1, x1, y1 - height);
      }

      do {
         if (logaxis)
            y_screen = y1 - (Math.log(y_act) - Math.log(ymin)) /
               (Math.log(ymax) - Math.log(ymin)) * height;
         else if (!(isFinite(ymax - ymin)))
            y_screen = y1 - ((y_act/ymin) - 1) / ((ymax/ymin) - 1) * height;
         else
            y_screen = y1 - (y_act - ymin) / (ymax - ymin) * height;
         ys = Math.round(y_screen);

         if (y_screen < y1 - height - 0.001 || isNaN(ys))
            break;

         if (y_screen <= y1 + 0.001) {
            if (Math.abs(Math.round(y_act / major_dy) - y_act / major_dy) <
               dy / major_dy / 10.0) {

               if (Math.abs(Math.round(y_act / label_dy) - y_act / label_dy) <
                  dy / label_dy / 10.0) {
                  // label tick mark
                  if (draw) {
                     ctx.strokeStyle = this.param.color.axis;
                     ctx.drawLine(x1, ys, x1 + text, ys);
                  }

                  // grid line
                  if (grid !== 0 && ys < y1 && ys > y1 - height)
                     if (draw) {
                        ctx.strokeStyle = this.param.color.grid;
                        ctx.drawLine(x1, ys, x1 + grid, ys);
                     }

                  // label
                  if (label !== 0) {
                     let str;
                     if (Math.abs(y_act) < 0.001 && Math.abs(y_act) > 1E-20)
                        str = y_act.toExponential(n_sig1).stripZeros();
                     else
                        str = y_act.toPrecision(n_sig1).stripZeros();
                     maxwidth = Math.max(maxwidth, ctx.measureText(str).width);
                     if (draw) {
                        ctx.strokeStyle = this.param.color.label;
                        ctx.fillStyle = this.param.color.label;
                        ctx.fillText(str, x1 + label, ys);
                     }
                     last_label_y = ys - textHeight / 2;
                  }
               } else {
                  // major tick mark
                  if (draw) {
                     ctx.strokeStyle = this.param.color.axis;
                     ctx.drawLine(x1, ys, x1 + major, ys);
                  }

                  // grid line
                  if (grid !== 0 && ys < y1 && ys > y1 - height)
                     if (draw) {
                        ctx.strokeStyle = this.param.color.grid;
                        ctx.drawLine(x1, ys, x1 + grid, ys);
                     }
               }

               if (logaxis) {
                  dy *= 10;
                  major_dy *= 10;
                  label_dy *= 10;
               }

            } else {
               // minor tick mark
               if (draw) {
                  ctx.strokeStyle = this.param.color.axis;
                  ctx.drawLine(x1, ys, x1 + minor, ys);
               }
            }

            if (logaxis) {

               // for log axis, also put grid lines on minor tick marks
               if (grid !== 0 && ys < y1 && ys > y1 - height) {
                  if (draw) {
                     ctx.strokeStyle = this.param.color.grid;
                     ctx.drawLine(x1+1, ys, x1 + grid - 1, ys);
                  }
               }

               // for log axis, also put labels on minor tick marks
               if (label !== 0) {
                  let str;
                  if (Math.abs(y_act) < 0.001 && Math.abs(y_act) > 1E-20)
                     str = y_act.toExponential(n_sig1).stripZeros();
                  else
                     str = y_act.toPrecision(n_sig1).stripZeros();
                  if (ys - textHeight / 2 > y1 - height &&
                     ys + textHeight / 2 < y1 &&
                     ys + textHeight < last_label_y + 2) {
                     maxwidth = Math.max(maxwidth, ctx.measureText(str).width);
                     if (draw) {
                        ctx.strokeStyle = this.param.color.label;
                        ctx.fillStyle = this.param.color.label;
                        ctx.fillText(str, x1 + label, ys);
                     }
                  }

                  last_label_y = ys;
               }
            }
         }

         y_act += dy;

         // suppress 1.23E-17 ...
         if (Math.abs(y_act) < dy / 100)
            y_act = 0;

      } while (1);

      return maxwidth;
   };

   /** Draw the xaxis as "datetime"
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {number} x1 coordinate position of the axis on screen
    * @param {number} y1 coordinate position of the axis on screen
    * @param {number} width width of the axis, likely also the width of the plot
    * @param {number} xr 
    * @param {number} minor step between minor ticks 
    * @param {number} major step between major ticks 
    * @param {string} text 
    * @param {string} label
    * @param {bool} grid if true draw grid lines over minor ticks
    * @param {number} xmin low limit of the axis
    * @param {number} xmax high limit of the axis 
    */   
   drawTAxis(ctx, x1, y1, width, xr, minor, major, text, label, grid, xmin, xmax) {
      const base = [1, 5, 10, 60, 2 * 60, 5 * 60, 10 * 60, 15 * 60, 30 * 60, 3600,
         3 * 3600, 6 * 3600, 12 * 3600, 24 * 3600];

      ctx.textAlign = "left";
      ctx.textBaseline = "top";

      if (xmax <= xmin || width <= 0)
         return;

      /* force date display if xmax not today */
      let d1 = new Date(xmax * 1000);
      let d2 = new Date();
      let forceDate = d1.getDate() !== d2.getDate() || (d2 - d1 > 1000 * 3600 * 24);

      /* use 5 pixel as min tick distance */
      let dx = Math.round((xmax - xmin) / (width / 5));

      let tick_base;
      for (tick_base = 0; base[tick_base]; tick_base++) {
         if (base[tick_base] > dx)
            break;
      }
      if (!base[tick_base])
         tick_base--;
      dx = base[tick_base];

      let major_base = tick_base;
      let major_dx = dx;

      let label_base = major_base;
      let label_dx = dx;

      do {
         let str = ptimeToLabel(xmin, label_dx, forceDate);
         let maxWidth = ctx.measureText(str).width;

         /* increasing label_dx, if labels would overlap */
         if (maxWidth > 0.75 * label_dx / (xmax - xmin) * width) {
            if (base[label_base + 1])
               label_dx = base[++label_base];
            else
               label_dx += 3600 * 24;

            if (label_base > major_base + 1 || !base[label_base + 1]) {
               if (base[major_base + 1])
                  major_dx = base[++major_base];
               else
                  major_dx += 3600 * 24;
            }

            if (major_base > tick_base + 1 || !base[label_base + 1]) {
               if (base[tick_base + 1])
                  dx = base[++tick_base];
               else
                  dx += 3600 * 24;
            }

         } else
            break;
      } while (1);

      let d = new Date(xmin * 1000);
      let tz = d.getTimezoneOffset() * 60;

      let x_act = Math.floor((xmin - tz) / dx) * dx + tz;

      ctx.strokeStyle = this.param.color.axis;
      ctx.drawLine(x1, y1, x1 + width, y1);

      do {
         let xs = ((x_act - xmin) / (xmax - xmin) * width + x1);

         if (xs > x1 + width + 0.001)
            break;

         if (xs >= x1) {
            if ((x_act - tz) % major_dx === 0) {
               if ((x_act - tz) % label_dx === 0) {
                  // label tick mark
                  ctx.strokeStyle = this.param.color.axis;
                  ctx.drawLine(xs, y1, xs, y1 + text);

                  // grid line
                  if (grid !== 0 && xs > x1 && xs < x1 + width) {
                     ctx.strokeStyle = this.param.color.grid;
                     ctx.drawLine(xs, y1, xs, y1 + grid);
                  }

                  // label
                  if (label !== 0) {
                     let str = ptimeToLabel(x_act, label_dx, forceDate);

                     // if labels at edge, shift them in
                     let xl = xs - ctx.measureText(str).width / 2;
                     if (xl < 0)
                        xl = 0;
                     if (xl + ctx.measureText(str).width >= xr)
                        xl = xr - ctx.measureText(str).width - 1;
                     ctx.strokeStyle = this.param.color.label;
                     ctx.fillStyle = this.param.color.label;
                     ctx.fillText(str, xl, y1 + label);
                  }
               } else {
                  // major tick mark
                  ctx.strokeStyle = this.param.color.axis;
                  ctx.drawLine(xs, y1, xs, y1 + major);
               }

               // grid line
               if (grid !== 0 && xs > x1 && xs < x1 + width) {
                  ctx.strokeStyle = this.param.color.grid;
                  ctx.drawLine(xs, y1 - 1, xs, y1 + grid);
               }
            } else {
               // minor tick mark
               ctx.strokeStyle = this.param.color.axis;
               ctx.drawLine(xs, y1, xs, y1 + minor);
            }
         }

         x_act += dx;

      } while (1);
   };

   /** Draw the xaxis as "category"
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {number} x1 coordinate position of the axis on screen
    * @param {number} y1 coordinate position of the axis on screen
    * @param {number} width width of the axis, likely also the width of the plot
    * @param {number} tick height in pixel of tick markers at labels
    * @param {number} label distance of text from axis
    * @param {string} category array of category labels to plot
    * @param {bool} draw if false, only return height of labels
    * @returns {float} maximum height + 2
   */
   drawCAxis(ctx, x1, y1, width, tick, label, xmin, xmax, category, draw) {
     ctx.textBaseline = "middle";
     
      if (width <= 0)
         return;

      ctx.strokeStyle = this.param.color.axis;

      if (draw)
         ctx.drawLine(x1, y1, x1 + width, y1);

      // spacing between ticks needs to scale with the change in the axis limits
      // then rescale to width in screen units
      let dx = (this.xMax0 - this.xMin0) / (xmax - xmin) * width / category.length;
      let maxWidth;
      let maxHeight;
      let angle;
      let x_offset = this.xMin0 - xmin + 0.5; // offset for tick translation

      // determine tick positions
      for (angle = 0 ; angle < 90 ; angle += 10) {
         maxWidth = 0;
         maxHeight = 0;
         for (let i = 0; i < category.length; i++) {
            
            // tick
            let shift = dx * (i + x_offset);
            if (draw && (shift >= 0) && (shift <= width)){
               ctx.drawLine(x1 + shift, y1, x1 + shift, y1 + tick);
            }

            // label
            let w = ctx.measureText(category[i]).width;
            let h = this.param.xAxis.textSize;

            const cos = Math.cos(angle/180*Math.PI);
            const sin = Math.sin(angle/180*Math.PI);

            const width2  = Math.abs(w * cos) + Math.abs(h * sin); 
            const height = Math.abs(w * sin) + Math.abs(h * cos);

            maxWidth = Math.max(maxWidth, width2);
            maxHeight = Math.max(maxHeight, height);
         }

         if (maxWidth * 1.1 < dx)
            break;
      }

      this.param.xAxis.angle = angle;
      var voffset; // vertical offset for text label
      if (draw) {

         // set vertical offset and text alignment based on angle
         if(angle > 20){
            voffset = 0;
            ctx.textAlign = "right";
         } else {
            var voffset = maxHeight / 2;
            ctx.textAlign = "center";
         }

         // set tick labels
         ctx.fillStyle = this.param.color.label; // without this the text color matches the background unless the title is first set

         for (let i = 0; i < category.length; i++) {

            // check if the tick is within axis limits
            let shift = dx * (i + x_offset);
            if((shift >= 0) && (shift <= width)){
               ctx.save();
               ctx.translate(x1 + shift, y1 + label + voffset);
               ctx.rotate(-angle / 180 * Math.PI);
               ctx.fillText(category[i], 0, 0);
               ctx.restore();         
            }
         }
      }

      return maxHeight + 2;
   };

   /** Download the figure as an image or data
    * @param {string} mode either "CSV" | "PNG"
    */
   download(mode) {
      let d = new Date();
      let filename = this.param.title.text + "-" +
         d.getFullYear() +
         ("0" + (d.getUTCMonth() + 1)).slice(-2) +
         ("0" + d.getUTCDate()).slice(-2) + "-" +
         ("0" + d.getUTCHours()).slice(-2) +
         ("0" + d.getUTCMinutes()).slice(-2) +
         ("0" + d.getUTCSeconds()).slice(-2);

      // use trick from FileSaver.js
      let a = document.getElementById('downloadHook');
      if (a === null) {
         a = document.createElement("a");
         a.style.display = "none";
         a.id = "downloadHook";
         document.body.appendChild(a);
      }

      if (mode === "CSV") {
         filename += ".csv";

         let data = "";

         // title
         this.param.plot.forEach(g => {
            if (g.type === "scatter" || g.type === "bar") {
               data += "X,";
               if (g.label === "")
                  data += "Y";
               else
                  data += g.label;
               data += '\n';

               // data
               for (let i = 0; i < g.xData.length; i++) {
                  data += g.xData[i] + ",";
                  data += g.yData[i] + "\n";
               }
               data += '\n';
            }

            if (g.type === "colormap") {
               data += "X  \  Y,";

               // X-header
               for (let i = 0; i < g.nx; i++)
                  data += g.xData[i] + ",";
               data += '\n';

               for (let j = 0; j < g.ny; j++) {
                  data += g.yData[j] + ",";
                  for (let i = 0; i < g.nx; i++)
                     data += g.zData[i + j * g.nx] + ",";
                  data += '\n';
               }
            }
         });

         let blob = new Blob([data], {type: "text/csv"});
         let url = window.URL.createObjectURL(blob);

         a.href = url;
         a.download = filename;
         a.click();
         window.URL.revokeObjectURL(url);
         dlgAlert("Data downloaded to '" + filename + "'");

      } else if (mode === "PNG") {
         filename += ".png";

         let smb = this.param.showMenuButtons;
         this.param.showMenuButtons = false;
         this.draw();

         try {
            let h = this;
            this.canvas.toBlob(function (blob) {
               let url = window.URL.createObjectURL(blob);

               a.href = url;
               a.download = filename;
               a.click();
               window.URL.revokeObjectURL(url);
               dlgAlert("Image downloaded to '" + filename + "'");

               h.param.showMenuButtons = smb;
               h.redraw();

            }, 'image/png');
         } catch (e) {
            dlgAlert("Image download failed: " + e);
            this.param.showMenuButtons = smb;
            this.redraw();
         }
      }

   };

   /** Draw a box encapsulating some text. Width and height are set by the text
    * @param {CanvasRenderingContext2D} ctx canvas context, for example: canvas.getContext("2d")
    * @param {string} text text to include in the box
    * @param {number} x coordinate of box lower left corner 
    * @param {number} y coordinate of box lower left corner 
    */
   drawTextBox(ctx, text, x, y) {
      let line = text.split("\n");

      let mw = 0;
      for (const g of line)
         if (ctx.measureText(g).width > mw)
            mw = ctx.measureText(g).width;
      let w = 5 + mw + 5;
      let h = parseInt(ctx.font) * 1.5;

      let c = ctx.fillStyle;
      ctx.fillStyle = "white";
      ctx.fillRect(x, y, w, h * line.length);
      ctx.fillStyle = c;
      ctx.strokeRect(x, y, w, h * line.length);

      for (let i=0 ; i<line.length ; i++)
         ctx.fillText(line[i], x+5, y +  + 0.2*h + i*h);
   }

   /** Handle mouse events
    * @param {Object} e mouse event object, specifies type, buttons
    */
   mouseEvent(e) {
      // execute callback if registered
      if (this.param.event) {

         if (this.param.plot[0].type === "colormap") {
            // pass plot column/row to callback
            let x = this.screenToX(e.offsetX);
            let y = this.screenToY(e.offsetY);
            let xMin = this.param.plot[0].xMin;
            let xMax = this.param.plot[0].xMax;
            let yMin = this.param.plot[0].yMin;
            let yMax = this.param.plot[0].yMax;
            let dx = (xMax - xMin) / this.nx;
            let dy = (yMax - yMin) / this.ny;
            if (x > this.xMin && x < this.xMax && y > this.yMin && y < this.yMax &&
               x > xMin && x < xMax && y > yMin && y < yMax) {
               let ix = Math.floor((x - xMin) / dx);
               let iy = Math.floor((y - yMin) / dy);

               let flag = eval(this.param.event + "(e, this, ix, iy)");
               if (flag)
                  return;
            }
         } else {

            // call all other plots only with event and object
            let flag = eval(this.param.event + "(e, this)");
            if (flag)
               return;

         }
      }

      // fix buttons for IE
      if (!e.which && e.button) {
         if ((e.button & 1) > 0) e.which = 1;      // Left
         else if ((e.button & 4) > 0) e.which = 2; // Middle
         else if ((e.button & 2) > 0) e.which = 3; // Right
      }

      let cursor = "";
      let title = "";
      let cancel = false;

      // cancel dragging in case we did not catch the mouseup event
      if (e.type === "mousemove" && e.buttons === 0 &&
         (this.drag.active || this.zoom.x.active || this.zoom.y.active))
         cancel = true;

      if (e.type === "mousedown") {

         this.downloadSelector.style.display = "none";

         // check for buttons
         this.button.forEach(b => {
            if (e.offsetX > b.x1 && e.offsetX < b.x1 + b.width &&
               e.offsetY > b.y1 && e.offsetY < b.y1 + b.width &&
               b.enabled) {
               b.click(this);
            }
         });

         // check for dragging
         if (e.offsetX > this.x1 && e.offsetX < this.x2 &&
            e.offsetY > this.y2 && e.offsetY < this.y1) {
            this.drag.active = true;
            this.marker.active = false;
            this.drag.sxStart = e.offsetX;
            this.drag.syStart = e.offsetY;
            this.drag.xStart = this.screenToX(e.offsetX);
            this.drag.yStart = this.screenToY(e.offsetY);
            this.drag.xMinStart = this.xMin;
            this.drag.xMaxStart = this.xMax;
            this.drag.yMinStart = this.yMin;
            this.drag.yMaxStart = this.yMax;

            this.blockAutoScale = true;
         }

         // check for axis dragging
         if (e.offsetX > this.x1 && e.offsetX < this.x2 && e.offsetY > this.y1) {
            this.zoom.x.active = true;
            this.zoom.x.x1 = e.offsetX;
            this.zoom.x.x2 = undefined;
            this.zoom.x.t1 = this.screenToX(e.offsetX);
         }
         if (e.offsetY < this.y1 && e.offsetY > this.y2 && e.offsetX < this.x1) {
            this.zoom.y.active = true;
            this.zoom.y.y1 = e.offsetY;
            this.zoom.y.y2 = undefined;
            this.zoom.y.v1 = this.screenToY(e.offsetY);
         }

      } else if (cancel || e.type === "mouseup") {

         if (this.drag.active)
            this.drag.active = false;

         if (this.zoom.x.active) {
            if (this.zoom.x.x2 !== undefined &&
               Math.abs(this.zoom.x.x1 - this.zoom.x.x2) > 5) {
               let x1 = this.zoom.x.t1;
               let x2 = this.screenToX(this.zoom.x.x2);
               if (x1 > x2)
                  [x1, x2] = [x2, x1];
               this.xMin = x1;
               this.xMax = x2;
            }
            this.zoom.x.active = false;
            this.blockAutoScale = true;
            this.redraw();
         }

         if (this.zoom.y.active) {
            if (this.zoom.y.y2 !== undefined &&
               Math.abs(this.zoom.y.y1 - this.zoom.y.y2) > 5) {
               let y1 = this.zoom.y.v1;
               let y2 = this.screenToY(this.zoom.y.y2);
               if (y1 > y2)
                  [y1, y2] = [y2, y1];
               this.yMin = y1;
               this.yMax = y2;
            }
            this.zoom.y.active = false;
            this.blockAutoScale = true;
            this.redraw();
         }

      } else if (e.type === "mousemove") {
         if (this.drag.active) {

            // execute dragging
            cursor = "move";

            if (this.param.xAxis.log) {
               let dx = e.offsetX - this.drag.sxStart;

               this.xMin = Math.exp(((this.x1 - dx) - this.x1) / (this.x2 - this.x1) * (Math.log(this.drag.xMaxStart)-Math.log(this.drag.xMinStart)) + Math.log(this.drag.xMinStart));
               this.xMax = Math.exp(((this.x2 - dx) - this.x1) / (this.x2 - this.x1) * (Math.log(this.drag.xMaxStart)-Math.log(this.drag.xMinStart)) + Math.log(this.drag.xMinStart));

               if (this.xMin <= 0)
                  this.xMin = 1E-20;
               if (this.xMax <= 0)
                  this.xMax = 1E-18;
            } else {
               let dx = (e.offsetX - this.drag.sxStart) / (this.x2 - this.x1) * (this.xMax - this.xMin);
               this.xMin = this.drag.xMinStart - dx;
               this.xMax = this.drag.xMaxStart - dx;
            }

            if (this.param.yAxis.log) {
               let dy = e.offsetY - this.drag.syStart;

               this.yMin = Math.exp((this.y1 - (this.y1 - dy)) / (this.y1 - this.y2) * (Math.log(this.drag.yMaxStart)-Math.log(this.drag.yMinStart)) + Math.log(this.drag.yMinStart));
               this.yMax = Math.exp((this.y1 - (this.y2 - dy)) / (this.y1 - this.y2) * (Math.log(this.drag.yMaxStart)-Math.log(this.drag.yMinStart)) + Math.log(this.drag.yMinStart));

               if (this.yMin <= 0)
                  this.yMin = 1E-20;
               if (this.yMax <= 0)
                  this.yMax = 1E-18;
            } else {
               let dy = (this.drag.syStart - e.offsetY) / (this.y1 - this.y2) * (this.yMax - this.yMin);
               this.yMin = this.drag.yMinStart - dy;
               this.yMax = this.drag.yMaxStart - dy;
            }

            this.redraw();

         } else {

            // change cursor to pointer over buttons
            this.button.forEach(b => {
               if (e.offsetX > b.x1 && e.offsetY > b.y1 &&
                  e.offsetX < b.x1 + b.width && e.offsetY < b.y1 + b.height) {
                  cursor = "pointer";
                  title = b.title;
               }
            });

            // execute axis zoom
            if (this.zoom.x.active) {
               this.zoom.x.x2 = Math.max(this.x1, Math.min(this.x2, e.offsetX));
               this.zoom.x.t2 = this.screenToX(e.offsetX);
               this.redraw();
            }
            if (this.zoom.y.active) {
               this.zoom.y.y2 = Math.max(this.y2, Math.min(this.y1, e.offsetY));
               this.zoom.y.v2 = this.screenToY(e.offsetY);
               this.redraw();
            }

            // check if cursor close to plot point
            if (this.param.plot.length > 0) {
               if (this.param.plot[0].type === "scatter" || this.param.plot[0].type === "histogram" ||
               this.param.plot[0].type === "bar") {
                  let minDist = 10000;
                  for (const [pi, p] of this.param.plot.entries()) {
                     if (p.xData === undefined || p.xData === null)
                        continue;

                     for (let i = 0; i < p.xData.length; i++) {
                        let x;
                        if (p.type === "bar")
                           x = this.xToScreen(i + 0.5);
                        else
                           x = this.xToScreen(p.xData[i]);
                        let y = this.yToScreen(p.yData[i]);
                        let d = (e.offsetX - x) * (e.offsetX - x) +
                           (e.offsetY - y) * (e.offsetY - y);
                        if (d < minDist) {
                           minDist = d;
                           this.marker.x = p.xData[i];
                           this.marker.y = p.yData[i];
                           this.marker.sx = x;
                           this.marker.sy = y;
                           this.marker.mx = e.offsetX;
                           this.marker.my = e.offsetY;
                           this.marker.graphIndex = pi;
                           this.marker.index = i;
                        }
                     }
                  }

                  this.marker.active = Math.sqrt(minDist) < 10 && e.offsetX > this.x1 && e.offsetX < this.x2;
               }

               if (this.param.plot[0].type === "colormap") {
                  let x = this.screenToX(e.offsetX);
                  let y = this.screenToY(e.offsetY);
                  let xMin = this.param.plot[0].xMin;
                  let xMax = this.param.plot[0].xMax;
                  let yMin = this.param.plot[0].yMin;
                  let yMax = this.param.plot[0].yMax;
                  let dx = (xMax - xMin) / this.nx;
                  let dy = (yMax - yMin) / this.ny;
                  if (x > this.xMin && x < this.xMax && y > this.yMin && y < this.yMax &&
                     x > xMin && x < xMax && y > yMin && y < yMax) {
                     let i = Math.floor((x - xMin) / dx);
                     let j = Math.floor((y - yMin) / dy);

                     this.marker.x = (i + 0.5) * dx + xMin;
                     this.marker.y = (j + 0.5) * dy + yMin;
                     this.marker.z = this.param.plot[0].zData[i + j * this.nx];

                     this.marker.sx = this.xToScreen(this.marker.x);
                     this.marker.sy = this.yToScreen(this.marker.y);
                     this.marker.mx = e.offsetX;
                     this.marker.my = e.offsetY;
                     this.marker.graphIndex = 0;
                     this.marker.active = true;
                  } else {
                     this.marker.active = false;
                  }
               }

               this.draw();
            }
         }

      } else if (e.type === "wheel" && this.param.mouseWheelZoom) {

         // ignore if outside axis window
         if (e.offsetX < this.x1 || e.offsetX > this.x2 ||
            e.offsetY < this.y2 || e.offsetY > this.y1)
            return;

         let x = this.screenToX(e.offsetX);
         let y = this.screenToY(e.offsetY);
         // Guard against scale <= -1 otherwise this.xMin becomes larger than this.xMax
         let scale = Math.max(e.deltaY * 0.01, -0.9);

         let xMinOld = this.xMin;
         let xMaxOld = this.xMax;
         let yMinOld = this.yMin;
         let yMaxOld = this.yMax;

         if (this.param.xAxis.log) {

            scale *= 10;
            let f = (e.offsetX - this.x1) / (this.x2 - this.x1);

            this.xMax *= 1 + scale * (1 - f);
            this.xMin /= 1 + scale * f;

            if (this.xMax <= this.xMin) {
               this.xMin = xMinOld;
               this.xMax = xMaxOld;
            }

         } else {
            let dx = (this.xMax - this.xMin) * scale;
            let f = (x - this.xMin) / (this.xMax - this.xMin);
            this.xMin = this.xMin - dx * f;
            this.xMax = this.xMax + dx * (1 - f);
         }

         // avoid too high zoom (would kill axis rendering)
         if (this.xMax - this.xMin < 1E-10*(this.xMax0 - this.xMin0)) {
            this.xMin = xMinOld;
            this.xMax = xMaxOld;
         }

         if (this.param.yAxis.log) {

            scale *= 10;
            let f = (e.offsetY - this.y2) / (this.y1 - this.y2);
            let yMinOld = this.yMin;
            let yMaxOld = this.yMax;

            this.yMax *= 1 + scale * f;
            this.yMin /= 1 + scale * (1 - f);

            if (this.yMax <= this.yMin) {
               this.yMin = yMinOld;
               this.yMax = yMaxOld;
            }

         } else {
            let dy = (this.yMax - this.yMin) * scale;
            let f = (y - this.yMin) / (this.yMax - this.yMin);
            this.yMin = this.yMin - dy * f;
            this.yMax = this.yMax + dy * (1 - f);
         }

         // avoid too high zoom (would kill axis rendering)
         if (this.yMax - this.yMin < 1E-10*(this.yMax0 - this.yMin0)) {
            this.yMin = yMinOld;
            this.yMax = yMaxOld;
         }

         this.blockAutoScale = true;

         this.draw();
         e.preventDefault();
      }

      this.parentDiv.title = title;
      this.parentDiv.style.cursor = cursor;
   }

   /** Reset min/max of x and y axes, redraws */
   resetAxes() {
      this.xMin = this.xMin0;
      this.xMax = this.xMax0;
      this.yMin = this.yMin0;
      this.yMax = this.yMax0;
      this.blockAutoScale = false;
      this.redraw();
   }
}
