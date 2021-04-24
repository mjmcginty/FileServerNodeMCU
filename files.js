// This file depends rather heavily on elements within the html file
// that contains it.  These dependencies are resolved when script in
// the container calls fileJsInit().
var CHUNKSIZE = 511
var xhr;
var xhr2;
var files;
var file;
var reader;
var currentFileNdx = -1;
var currentPos = 0;
var currentChunk = 0;
var buf = [];
var urlPrefix;
var option;
var page;
var isESP;

// option possibilities are:
// Overwrite : overwrites file automatically
// Ignore : ignores existing file, setting-up failure
// Abort : aborts transfer, fails with message "exists"
// Backup : renames existing file by renaming with prefix "bu_(incremental_number)_"

// Called by containing page when it loads to initialize element dependencies.
function fileJsInit(obj) {
    page = obj;
}

function sendFiles(fileInputObj) {
    files = fileInputObj.files;
    currentFileNdx = -1;
    xhr = new XMLHttpRequest();
    option = page.optionsListElement.value;
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    sendNextFile();
}

function sendNextFile() {
    currentFileNdx++;
    file = files[currentFileNdx];
    if (file == null)
        return false;
    currentChunk = 0;
    buf = [];
    reader = file.stream().getReader();
    xhr.onreadystatechange = xhrReadyStateChange;
    xhr.open("GET", urlPrefix + "/api/send/" + file.name + "/" + option, true);
    xhr.send();
}

function xhrReadyStateChange() {
    if (xhr.readyState == 4) {
        var freeHeap = xhr.getResponseHeader("FreeHeap");
        if (freeHeap)
            page.heapElement.innerText = freeHeap;

        if (xhr.status > 299) {
            alert("HTTP status " + xhr.status.toString() + " " + xhr.statusText);
            return;
        }
        if ((xhr.responseText.indexOf("success") < 0) && (xhr.status != 100)) {
            alert(xhr.responseText);
            return;
        }

        var respObj = JSON.parse(xhr.responseText);
        isESP = (xhr.getResponseHeader("Server") == "ESPServer");

        // buf is initialized to an empty array in sendNextFile()
        // so it works the first time this function is called
        if (currentPos >= buf.length) {
            var promise = reader.read();
            if (promise == undefined)
                return;
            promise.then(function (value) {
                if ((value == undefined) || (value.value == undefined)) {
                    xhr.onreadystatechange = null;
                    xhr.open("GET", urlPrefix + "/api/persist/" + file.name + "/" + option, false);
                    xhr.send();
                    setTimeout(sendNextFile, 50);
                    getFileList();
                    return;
                }
                if (buf.length)
                    currentChunk++;
                buf = value.value;
                currentPos = 0;
            })
        }

        if (respObj.bytes < file.size) {
            var temp = buf.slice(currentPos, currentPos + CHUNKSIZE);
            currentPos += temp.length;

            xhr.open("POST", urlPrefix + "/api/append/" + file.name + "/" + option, true);
            if (isESP) {
                xhr.send(temp.buffer);
            }
            else {
                var obj = createPostJson(file.name, temp);
                xhr.setRequestHeader("Content-Type", "application/json");
                xhr.send(JSON.stringify(obj));
            }
        }
        if (page.statusElement) {
            var bytesTransferred = (currentChunk * 65536) + currentPos;
            var percentComplete = parseInt((bytesTransferred / file.size) * 100);
            page.statusElement.value = "File: " + (currentFileNdx + 1).toString() + " of " + files.length.toString() + "  " +
                bytesTransferred.toString() + " bytes sent";
            page.progressElement.style.width = percentComplete.toString() + "%";
            page.progressElement.innerText = percentComplete.toString() + "%";
        }

    }
}

function createPostJson(fileName, data) {
    return {
        fileName: fileName,
        data: data
    }
}


function sendCfg() {
    var xhrCfg = new XMLHttpRequest();
    var cfgBuf = page.configElement.value;
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    xhrCfg.onreadystatechange = null;
    xhrCfg.open("GET", urlPrefix + "/api/send/cfg.lua/Overwrite", false);
    xhrCfg.send();
    xhrCfg.open("POST", urlPrefix + "/api/append/cfg.lua/Overwrite", false);
    xhrCfg.send(cfgBuf);
    xhrCfg.open("GET", urlPrefix + "/api/persist/cfg.lua/Overwrite", false);
    xhrCfg.send();
    page.configDiv.style.display = "none";
}

function getCfg() {
    page.configDiv.style.display = "block";
    var xhrCfg = new XMLHttpRequest();
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    xhrCfg.onreadystatechange = null;
    xhrCfg.open("GET", urlPrefix + "/cfg.lua", false);
    xhrCfg.send();
    page.configElement.value = xhrCfg.responseText;
}


function executeSelectedFile() {
    var fileName = page.fileDropdownElement.value;
    doFile(fileName);
}

function editSelectedFile() {
    page.configDiv.style.display = "block";
    var fileName = page.fileDropdownElement.value;
    page.editedFileName.innerText = fileName;
    var xhrCfg = new XMLHttpRequest();
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    xhrCfg.onreadystatechange = null;
    xhrCfg.open("GET", urlPrefix + "/" + fileName, false);
    xhrCfg.send();
    page.configElement.value = xhrCfg.responseText;
}

function saveEditedFile() {
    var xhrCfg = new XMLHttpRequest();
    var cfgBuf = page.configElement.value;
    var fileName = page.fileDropdownElement.value;
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    xhrCfg.onreadystatechange = null;
    xhrCfg.open("GET", urlPrefix + "/api/send/" + fileName + "/Overwrite", false);
    xhrCfg.send();
    xhrCfg.open("POST", urlPrefix + "/api/append/" + fileName + "/Overwrite", false);
    xhrCfg.send(cfgBuf);
    xhrCfg.open("GET", urlPrefix + "/api/persist/" + fileName + "/Overwrite", false);
    xhrCfg.send();
    page.configDiv.style.display = "none";
}


function getFileList() {
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    xhr2 = new XMLHttpRequest();
    xhr2.onreadystatechange = xhrReadyStateChange2;
    xhr2.open("GET", urlPrefix + "/api/list", true);
    xhr2.send();
}

function restartESP() {
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    xhr2 = new XMLHttpRequest();
    xhr2.open("GET", urlPrefix + "/api/restart", false);
    xhr2.send();
}

function doFile(fileName) {
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    xhr2 = new XMLHttpRequest();
    xhr2.open("GET", urlPrefix + "/api/dofile/" + fileName, false);
    xhr2.send();
}



function getheap() {
    if (page) {
        urlPrefix = location.protocol + "//" + page.serverElement.value;
        xhr2 = new XMLHttpRequest();
        xhr2.onreadystatechange = null;
        xhr2.open("GET", urlPrefix + "/api/heap", false);
        xhr2.send();
        page.heapElement.innerText = xhr2.responseText;
    }
}

function updateHeap() {
    window.setTimeout(updateHeap, 60000);
    getheap();
}

//updateHeap();

function xhrReadyStateChange2() {
    if (xhr2.readyState == 4) {
        var freeHeap = xhr2.getResponseHeader("FreeHeap");
        if (freeHeap)
            page.heapElement.innerText = freeHeap;

        var list = JSON.parse(xhr2.responseText);
        for (i = page.fileListElement.childNodes.length - 1; i >= 0; i--) {
            page.fileListElement.removeChild(page.fileListElement.childNodes[i]);
        }
        var tr = document.createElement("tr");
        tr = page.fileListElement.appendChild(tr);
        var th = document.createElement("th");
        th = tr.appendChild(th);
        th.innerText = "File Name";
        th = document.createElement("th");
        th = tr.appendChild(th);
        th.innerText = "Size";

        // enumerate returned objects
        for (i = 0; i < list.length; i++) {
            var item = list[i];

            tr = document.createElement("tr");
            tr = page.fileListElement.appendChild(tr);
            var td = document.createElement("td");
            td = tr.appendChild(td);
            var a = document.createElement("a");
            a.href = item.name;
            a.target = "_blank";
            a.innerText = item.name
            td.appendChild(a);
            td = document.createElement("td");
            td.align = "right";
            td = tr.appendChild(td);
            td.innerText = item.size;
        }
        populateFilesDropdown(list);
    }
}

function populateFilesDropdown(list) {
    for (i = page.fileDropdownElement.childNodes.length - 1; i >= 0; i--) {
        page.fileDropdownElement.removeChild(page.fileDropdownElement.childNodes[i]);
    }

    // enumerate returned objects
    for (i = 0; i < list.length; i++) {
        var item = list[i];
        var optionEl = document.createElement("option");
        optionEl.value = item.name
        optionEl.innerText = item.name
        optionEl = page.fileDropdownElement.appendChild(optionEl);
    }
}

function renameSelectedFile(that) {
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    option = page.optionsListElement.value;
    var oldName = page.fileDropdownElement.value;
    if (page.newNameDivElement.style.display == "none") {
        page.newNameDivElement.style.display = "block";
        page.cancelFileOpBtnElement.style.display = "inline";
        page.deleteFileBtnElement.style.display = "none";
        that.innerText = "Confirm Rename";
        return;
    }
    else {
        that.innerText = "Rename Selected File";
        page.cancelFileOpBtnElement.style.display = "none";
        page.deleteFileBtnElement.style.display = "inline";
    }
    var newName = page.newFileNameInputElement.value;
    if (newName == "") {
        page.newNameDivElement.style.display = "none";
        return;
    }
    xhr3 = new XMLHttpRequest();
    xhr3.open("GET", urlPrefix + "/api/rename/" + oldName + "/" + newName + "/" + option, false);
    xhr3.send();
    page.newNameDivElement.style.display = "none";
    page.newFileNameInputElement.value = "";
    getFileList();
}

function deleteSelectedFile(that) {
    option = page.optionsListElement.value;
    urlPrefix = location.protocol + "//" + page.serverElement.value;
    var name = page.fileDropdownElement.value;

    if (page.deleteConfirmDivElement.style.display == "none") {
        page.deleteConfirmDivElement.style.display = "block";
        page.cancelFileOpBtnElement.style.display = "inline";
        page.renameFileBtnElement.style.display = "none";
        that.innerText = "Confirm Delete";
        return;
    }
    else {
        that.innerText = "Delete Selected File";
        page.cancelFileOpBtnElement.style.display = "none";
        page.renameFileBtnElement.style.display = "inline";
    }

    var appFilesList = ["error404.html", "files.js", "server.lua", "wificfgsvr.lua", "files.html", "help.html", "favicon.ico", "_init.lua", "index.html", "cfg.lua", "init.lua"];
    if (appFilesList.indexOf(name) >= 0) {
        if (!confirm("The file " + name + " is part of the FileMgr application, deleting it may break the app.\r\n\r\nAre you sure?")) {
            page.deleteConfirmDivElement.style.display = "none";
            return;
        }
    }

    xhr3 = new XMLHttpRequest();
    xhr3.open("GET", urlPrefix + "/api/delete/" + name + "/" + option, false);
    xhr3.send();
    getFileList();
    page.deleteConfirmDivElement.style.display = "none";
}

function cancelDeleteRename(that) {
    page.cancelFileOpBtnElement.style.display = "none";
    page.deleteFileBtnElement.innerText = "Delete Selected File";
    page.deleteFileBtnElement.style.display = "inline";
    page.renameFileBtnElement.innerText = "Rename Selected File";
    page.renameFileBtnElement.style.display = "inline";
    page.newNameDivElement.style.display = "none";
    page.deleteConfirmDivElement.style.display = "none";
}

