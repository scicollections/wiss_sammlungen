function WinstonGlobal(dom) {
  // I. Define variables and alias `this` as `self` if necessary


  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    var map = new WinstonMap($("#map"),"coll_count");
    // set first button enabled
    dom.find('#map-buttons button').first().click();
    // register button event handlers so they can access the loaded data
    dom.find('#map-buttons button').click(function(){
      map.updateMap(dom.find(this).attr("id"),null)
    });

  }


}
