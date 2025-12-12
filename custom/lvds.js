//var canvas = document.querySelector('canvas');
//var cc = canvas.getContext('2d');

// color https://venngage.com/tools/accessible-color-palette-generator
const green = "#044018";
const lightgreen = "#90ee90";
const red = "#61154e";
const lightred = "#ffcccb";


const nfebs = N_FEBS;
const maxlinks = MAX_LVDS_LINKS_PER_FEB;
const numvals = 12;

var febcell = [[],[],[],[],[]];

var psls = [];
var psls_last = [];
var linkmask = [];
var febmask = [];
var invertmask = [];

function init(){
    for(let i=0; i < MAX_N_SWITCHINGBOARDS; i++){
        psls.push(new Array());
        psls_last.push(new Array());
        linkmask.push(new Array());
        febmask.push(new Array());
        invertmask.push(new Array());
        for(let j=0; j < nfebs[i]; j++){
            psls[i].push(new Array());
            psls_last[i].push(new Array());
            linkmask[i].push(new Array());
            invertmask[i].push(new Array());
            febmask[i].push(0);
            for(let k=0; k < maxlinks; k++){
                psls[i][j].push(new Array());
                psls_last[i][j].push(new Array());
                linkmask[i][j].push(false);
                invertmask[i][j].push(false);
                for(let l=0; l < numvals+2; l++){
                    psls[i][j][k].push(0);
                    psls_last[i][j][k].push(0);
                }
            }
        }
    }

    mjsonrpc_db_get_values(["/Equipment/Quads/Settings/DAQ/Links"]).then(function(rpc) {    
            make_feb_table(rpc.result.data);
            set_active_links(rpc.result.data);
     }).catch(function(error) {
        mjsonrpc_error_alert(error);
     });

    mjsonrpc_db_get_values(["/Equipment/Quads/Variables/PCLS"]).then(function(rpc) {        
        if(rpc.result.data[0]){
            update_pcls(rpc.result.data[0]);
        }
    }).catch(function(error) {
        mjsonrpc_error_alert(error);
    });
}

function format_feb_cell(cell){
    cell.style.backgroundColor = lightgreen;
    cell.style.textAlign = "center";
    cell.style.width = "100px";
    cell.style.height = "30 px";
    cell.style.color = "blue";
}

function format_feb_cell_bad(cell){
    cell.style.backgroundColor = lightred;
    cell.style.textAlign = "center";
    cell.style.width = "100px";
    cell.style.height = "30 px";
    cell.style.color = "blue";
}

function format_feb_cell_disabled(cell){
    cell.style.textAlign = "center";
    cell.style.width = "100px";
    cell.style.height = "30 px";
    cell.style.color = "black";
}

function set_active_links(valuex){
    var valid = [false, false, false, false];
    console.log('links', valuex);
    if(valuex[0]){
        var val_central = valuex[0];
        if(typeof valuex[0] === 'string')
            val_central = JSON.parse(valuex[0]);
        valid[0] = true;
    }
    if(valid[0]){
        for(var i=0; i < nfebs[0]; i++){
            console.log(val_central)
            mask = BigInt(val_central["lvdslinkmask"][i]);
            inv  = BigInt(val_central["lvdslinkinvert"][i]);
 
            for(var j =0; j < maxlinks; j++){
                linkmask[0][i][j] = mask & (1n << BigInt(j));
                invertmask[0][i][j] = inv & (1n << BigInt(j));
            }
        }
    }   

    for(let i=0; i < MAX_N_SWITCHINGBOARDS; i++){
        for(let j=0; j < nfebs[i]; j++){
            for(let k=0; k < maxlinks; k++){
                if(psls[i][j][k][0] && linkmask[i][j][k] == false){
                    row_inactive(psls[i][j][k]);
                }
            }
        }
    }
}

function row_inactive(row){
    for(let i=0; i < numvals+2; i++){
        row[i].style.backgroundColor ="lightgray";
        row[i].style.color = "black";
    }
}

function make_feb_table(valuex){
    var valid = [false, false, false];
    if(valuex[0]){
        console.log("lllll");
        var val_central = valuex[0];
        if(typeof valuex[0] === 'string')
            val_central = JSON.parse(valuex[0]);
        valid[0] = true;
    }

    let allfebtable = document.getElementById('allfebtable');

    for(let irow = 0; irow < Math.max.apply(Math, nfebs); irow++){
        let row = allfebtable.insertRow();    
        if(irow < nfebs[0]){
            febcell[0][irow] = row.insertCell();
            console.log(val_central);
            if(valid[0] && val_central['lvdslinkmask'][irow]>0){
                format_feb_cell(febcell[0][irow]);
                febmask[0][irow] = true;
            } else {
                format_feb_cell_disabled(febcell[0][irow]);
                febmask[0][irow] = false;
            }
            febcell[0][irow].onclick = function() {dlgShow('febDetails'+irow);};
            let name = "Undef.";
            make_link_dialog(0, 36, irow, irow, name);
            let text1 = document.createTextNode(name); 
            febcell[0][irow].appendChild(text1);   
        } else {
            febcell[0][irow] = row.insertCell();
        }
    }
}

let tableInitialised = false;

function make_link_dialog(index, nlinks, _id, febrow, _febname){
    let top = document.getElementById('top');
    let bod = document.getElementById('mybody');
    let div = document.createElement('div');
    
    div.classList.add('dlgFrame');
    div.id ='febDetails' +_id;

    let title = document.createElement('div');
    title.classList.add('dlgTitlebar');
    let titletext = document.createTextNode("LVDS Link Details");
    title.appendChild(titletext);
    div.appendChild(title);

    let panel = document.createElement('div');
    panel.classList.add('dlgPanel');

    let table = document.createElement('table');
    table.classList.add('mtable');

    let rh = table.insertRow();
    let c1 = document.createElement('th');
    c1.innerHTML = _id;
    rh.appendChild(c1);

    let c2 = document.createElement('th');
    c2.innerHTML = _febname;
    c2.colSpan = 13;
    rh.appendChild(c2);

    let rh2 = table.insertRow();
    let h1 = document.createElement('th');
    h1.innerHTML = "Link";
    rh2.appendChild(h1);
    let h2 = document.createElement('th');
    h2.innerHTML = "Phi";
    rh2.appendChild(h2);
    let h3 = document.createElement('th');
    h3.innerHTML = "z";
    rh2.appendChild(h3);
    let h4 = document.createElement('th');
    h4.innerHTML = "Locked";
    rh2.appendChild(h4);
    let h5 = document.createElement('th');
    h5.innerHTML = "Ready";
    rh2.appendChild(h5);
    let h6 = document.createElement('th');
    h6.innerHTML = "DPA";
    rh2.appendChild(h6);
    let h7 = document.createElement('th');
    h7.innerHTML = "Alignments";
    rh2.appendChild(h7);
    let h8 = document.createElement('th');
    h8.innerHTML = "Phase";
    rh2.appendChild(h8);
    let h9 = document.createElement('th');
    h9.innerHTML = "Out of Phase";
    rh2.appendChild(h9);
    let h10 = document.createElement('th');
    h10.innerHTML = "Disparity Err";
    rh2.appendChild(h10);
    let h11 = document.createElement('th');
    h11.innerHTML = "8b10b Err";
    rh2.appendChild(h11);
    let h12 = document.createElement('th');
    h12.innerHTML = "Hits";
    rh2.appendChild(h12);
    let h13 = document.createElement('th');
    h13.innerHTML = "Active";
    rh2.appendChild(h13);
    let h14 = document.createElement('th');
    h14.innerHTML = "Inverted";
    rh2.appendChild(h14);

    panel.appendChild(table);
    div.appendChild(panel);

    top.insertBefore(div,bod);

    tableInitialised = true;
}

init();

function formatRow(row, last, active, status, disp, err, nhits, inverted){
    var ok = true;
    var goodcolour = "green";
    var badcolour  = "red";
    if(!active){
        goodcolour = "lightgreen";
        badcolour  = "lightpink";
    }

    if(status & (1<<31))
        row[3].style.backgroundColor = goodcolour;
    else {
        row[3].style.backgroundColor = badcolour;
        ok = false;
    }

    if(status & (1<<30))
        row[4].style.backgroundColor = goodcolour;
    else {
        row[4].style.backgroundColor = badcolour;
        ok = false;
    }

    if(status & (1<<29))
        row[5].style.backgroundColor = goodcolour;
    else {
        row[5].style.backgroundColor = badcolour;   
        ok = false;   
    }

    var alignments =    (status >> 22)&0x3F; 
    row[6].innerHTML= alignments;
    row[6].style.color = (alignments - last[6] > 0)? badcolour : goodcolour;
    if (alignments - last[6] > 0) ok = false;
    last[6] = alignments;

    row[7].innerHTML= (status >> 20)&0x3;
    last[7]=  (status >> 20)&0x3;

    var outofphase = status & 0xFFFF;
    row[8].innerHTML= Number(outofphase).toPrecision(5);
    row[8].style.color = (outofphase > 0)? badcolour : goodcolour;
    if (outofphase > 0) ok = false;
    last[8] = outofphase;

    row[9].innerHTML=Number(disp).toPrecision(5);
    row[9].style.color = (disp - last[9] > 0)? badcolour : goodcolour;
    if (disp - last[9] > 0) ok = false;
    last[9] = disp;

    row[10].innerHTML=Number(err).toPrecision(5);
    row[10].style.color = (err - last[10] > 0)? badcolour : goodcolour;
    if (err - last[10] > 0) ok = false;
    last[10] = err;
    row[11].innerHTML=Number(nhits).toPrecision(5);
    last[11] = nhits;
    if(active)
        row[12].innerHTML="Y";
    else
        row[12].innerHTML="N";

    if(inverted)
        row[13].innerHTML="Y";
    else
        row[13].innerHTML="N";    

    return ok || (!active);
}

function update_pcls(valuex){
    if (!tableInitialised)
        return;

    var value = valuex;
    if(typeof valuex === 'string')
        value = JSON.parse(valuex);
    
    var offset = 0;
    for(let j=0; j < nfebs[0]; j++){
        var febindex = value[offset];
        var nlinks = value[offset+1];
        var febok = true;
        if(j!=febindex){
            continue; // not all FEBs are necessarily in the bank
        }
        for(var l=0; l < nlinks; l++){
            var status = value[offset+2+4*l];
            var disp   = value[offset+2+4*l+1];
            var err    = value[offset+2+4*l+2];
            var nhits  = value[offset+2+4*l+3];
            febok = formatRow(psls[0][j][l], psls_last[0][j][l], linkmask[0][j][l], status, disp, err, nhits, invertmask[0][j][l]) && febok;
        }
        if(febmask[0][j]){ 
            if(febok)
                format_feb_cell(febcell[0][j]);
            else
                format_feb_cell_bad(febcell[0][j]);
        } else {
            format_feb_cell_disabled(febcell[0][j]);
        }

        offset += 2 + nlinks*4;
        if(offset >= value.length)
            break;
    }   
}
