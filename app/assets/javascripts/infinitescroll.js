function InfiniteScroll(dom, options) {
  // I. Define variables and alias `this` as `self` if necessary
  var search_navDiv = dom.find(".search_nav");

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    if (options == undefined){
      options = {};
    }
    options['padding'] = 100;
    options['nextSelector'] = '.search_nav a:first';
    
    // only load jscroll, if there is more than one page
    if (search_navDiv.length) {
      dom.jscroll(options);
    }
    
  }


}