// -*- mode: c -*-
var highlightColor = "#ffff88";
var backgroundColor = "white";
var lineCache;
var classCache;
var previousId;
var previousLineNo;

function initCache () {
    spanCache = document.getElementsByTagName("span");
    lineCache = new Array();
    classCache = new Array();

    var length = spanCache.length;
    for (var i = 0; i < length; i++) {
	var e = spanCache[i];

	// build lineCache
	if (e.className == "line") {
	  lineCache.push(e, e.title);
	}

	// build classCache
	// Use "className" because IE doesn't allow duplicated "id"s.
        var id = e.className;
	if (id) {
	  if (!classCache[id]) {
              classCache[id] = new Array();
	  }
	  classCache[id].push(e);
	}
    }
}

function setHighlight (id, color) {
    var elements = classCache[id];
    var length = elements.length;
    for (var i = 0; i < length; i++) {
	var e = elements[i];
        e.style.backgroundColor = color;
    }
}

function clearHighlight () {
    if (previousId)
        setHighlight(previousId, backgroundColor);
}

function highlight (id) {
    clearHighlight();
    setHighlight(id, highlightColor);
    previousId = id;
    return true;
}

function quotemeta (string) {
    return string.replace(/(\W)/, "\\$1");
}

function isearch (string) {
    var pattern = new RegExp(quotemeta(string), "i");
    var length = lineCache.length;
    for (var i = 0; i < length; i += 2) {
        var e = lineCache[i];
        var title = lineCache[i + 1];
        if (title.match(pattern)) {
            e.style.display = "inline";
        } else {
            e.style.display = "none";
        }
    }
}

function onLineNoClick (e) {
    if (previousLineNo)
        previousLineNo.style.backgroundColor = backgroundColor;
    e.style.backgroundColor = highlightColor;
    previousLineNo = e;
    var length = lineCache.length;
    for (var i = 0; i < length; i += 2) {
	var e = lineCache[i];
        e.style.display = "inline";
    }
}

function passQuery (e) {
    q = document.getElementsByName("q")[0].value;
    if (q) {
        e.href += "?q=" + encodeURIComponent(q) ;
    }
    return true;
}

function initFocus () {
    q = document.getElementsByName("q")[0];
    if (q) { 
        q.focus();
    }
}

//
// aliases
//
function hl (id) {
    highlight(id);
}

function olnc (e) {
    onLineNoClick(e);
}

