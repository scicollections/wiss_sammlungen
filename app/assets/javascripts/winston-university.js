function WinstonUniversity(dom) {
  // I. Define variables and alias `this` as `self` if necessary


  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {

    // initialize uni attribute-qtips
    dom.find('#collections .winston-attr-qtip').qtip({
      style: { classes: 'test-tooltip'},
      position: {
        at: 'middle center',
        my: 'middle right',
        adjust: {
          x: -10,
          y: 0
        }
      }
    });

  }


}
