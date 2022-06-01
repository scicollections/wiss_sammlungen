function DerefPlaceholder(dom) {
  // I. Define variables and alias `this` as `self` if necessary
  var property_id = dom.data("property");
  var indi_id = dom.data("individual");


  var spinnerOptions = {
    lines: 15, // The number of lines to draw
    length: 8, // The length of each line
    width: 5, // The line thickness
    radius: 8, // The radius of the inner circle
    scale: 5, // Scales overall size of the spinner
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

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    url = "/individual/"+indi_id+"/dereferenced_data/"+property_id
    var spinner = new Spinner(spinnerOptions).spin(dom[0]);
    $.get(url,function(data){
      dom.html(data);
      
      dom.find(".leaflet-helper").each(function(){
        dom.find("div.spinner").remove();
        new LeafletHelper($(this));
      })
    });
  }


}
