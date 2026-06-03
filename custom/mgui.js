function histList(group = "") {
   mjsonrpc_db_copy(["/History/Display"]).then(function (rpc) {
      let historyDisplay = rpc.result.data[0];
      let groups = Object.keys(historyDisplay);
      let dlgHTML = groups.map(item =>
         `<option value="${item}">${item}</option>`
      ).join('');
      dlgHTML =
         `<select id="histGrps" onchange="histList(this.value)">${dlgHTML}</select>`;
      let groupList;
      group = (group === "") ? groups[0] : group;
      console.log(group);
      groupList = Object.keys(historyDisplay[group]).map(item =>
         `<option value="${item}">${item}</option>`
      ).join('');
      dlgHTML += `<select id ="histList">${groupList}</select>`;
      dlgHTML += `<button class="mbutton" onclick='mhistory_dialog(document.getElementById("histGrps").value,document.getElementById("histList").value)'>Show</button>`;
      let d = dlgGeneral({html: dlgHTML,iddiv: "Histories"});
      //d.classList.remove("dlgFrame");
      document.getElementById("histGrps").value = group;
   });
}
