function ObjectOptions(dom) {
  // I. Define variables and alias `this` as `self` if necessary
  var permalink = dom.find("#permalink");
  var permaurl = dom.find("#perma-url");
  var options = dom.find("#options");
  var optionspalette = dom.find("#options-palette");

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init(){
    // for now there are now option-palettes in our codebase
    options.click(function() {
      optionspalette.toggle('500', function() {
          // Animation complete
      });
    });

    // hides/shows an images permalink
    permalink.click(function() {
        permaurl.toggle('500', function() {
            // Animation complete
        });
    });
  }

}