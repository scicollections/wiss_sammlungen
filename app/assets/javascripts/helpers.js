// only functions without side effects

function makeErrorAlerter(msg) {
  return function(err) {
    if (err.responseText != null && err.responseText != " ") {
      var errJson = tryParseJSON(err.responseText);
      if(errJson && errJson['msg'] != null){
        alert(msg + ": " + errJson["msg"]);
      }else{
        alert(msg + ": " + err.responseText);
      }
    } else {
      alert(msg);
    }
  }
}

// when applying the following functions to link-doms, remove hrefs
// link_to "Neu", 'javascript:;'
// OR
// content_tag "a","Neu", class: "js-show-new-modal", title: "Neue Seite erstellen"

function disableLink(dom){
  dom.addClass('disabled');
  // add Spinner
  var spinner = new Spinner(spinnerOptions).spin(dom[0]);
  dom.spinner = spinner;
  // store and remove click events
  if (jQuery._data(dom[0], 'events') != undefined){
    var clickEvent = jQuery._data(dom[0], 'events').click;
    jQuery._data(dom[0], 'events').click = null;
    dom.clickEvent = clickEvent;
  }
  
  // save href
  dom.saved_href = dom.attr("href");
  dom.removeAttr("href");
  
  dom.prop("disabled","true");
}

function enableLink(dom){
  dom.removeClass('disabled');
  //remove spinner
  if(dom.spinner){
    dom.spinner.stop();
    dom.spinner = null;
  }
  dom.find("div.spinner").remove();
  // restore events
  if(dom.clickEvent != null){
    jQuery._data(dom[0], 'events').click = dom.clickEvent;
  }
  
  //restore href if neccessary
  if(dom.saved_href != null){
    dom.attr('href',dom.saved_href);
  }
  dom.removeProp("disabled");
}


var spinnerOptions = {
  lines: 15, // The number of lines to draw
  length: 5, // The length of each line
  width: 3, // The line thickness
  radius: 5, // The radius of the inner circle
  scale: 1, // Scales overall size of the spinner
  corners: 1, // Corner roundness (0..1)
  color: '#1f2d54', // #rgb or #rrggbb or array of colors
  opacity: 0.25, // Opacity of the lines
  rotate: 0, // The rotation offset
  direction: 1, // 1: clockwise, -1: counterclockwise
  speed: 1, // Rounds per second
  trail: 40, // Afterglow percentage
  fps: 20, // Frames per second when using setTimeout() as a fallback for CSS
  zIndex: 2e9, // The z-index (defaults to 2000000000)
  className: 'spinner', // The CSS class to assign to the spinner
  top: '10px', // Top position relative to parent
  left: '50%', // Left position relative to parent
  shadow: false, // Whether to render a shadow
  hwaccel: false, // Whether to use hardware acceleration
  position: 'relative' // Element positioning
}

function tryParseJSON (jsonString){
    try {
        var o = JSON.parse(jsonString);

        // Handle non-exception-throwing cases:
        // Neither JSON.parse(false) or JSON.parse(1234) throw errors, hence the type-checking,
        // but... JSON.parse(null) returns null, and typeof null === "object", 
        // so we must check for that, too. Thankfully, null is falsey, so this suffices:
        if (o && typeof o === "object") {
            return o;
        }
    }
    catch (e) { }

    return false;
};