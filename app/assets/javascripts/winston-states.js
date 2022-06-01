function WinstonStates(dom) {
  // I. Define variables and alias `this` as `self` if necessary
  var label_expand = "Alle ausklappen";
  var label_collapse = "Alle zuklappen";
  var button = dom.find('#expand-toggle');
  var collapse = true;

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {


    button.html(label_expand);
    // attach clickhandler
    button.click(function() {
      if (collapse)
        expand_all();
      else
        collapse_all();
    });

    // initialize state-level piechart-qtips
    dom.find('.state_panel .state .winston-pie-qtip').qtip({
      style: { classes: 'test-tooltip'},
      position: {
        at: 'middle bottom',
        my: 'top right',
        adjust: {
          x: 0,
          y: 15
        }
      }
    });
    // initialize uni pie-chart
    dom.find('.state_panel .unis .winston-pie-qtip').qtip({
      style: { classes: 'test-tooltip'},
      position: {
        at: 'middle bottom',
        my: 'top right',
        adjust: {
          x: 0,
          y: 15
        }
      }
    });
    // initialize uni attribute-qtips
    dom.find('.state_panel .unis .winston-attr-qtip').qtip({
      style: { classes: 'test-tooltip'},
      position: {
        at: 'middle bottom',
        my: 'top right',
        adjust: {
          x: 0,
          y: 10
        }
      }
    });

    // propagate click event on pies to their containing expanding/collapsing rows
    dom.find('.state_panel .highcharts-container').click(function() {
      dom.find(this).parent().click();
    });

  }

  function collapse_all() {
    collapse = true;
    button.html(label_expand);
    dom.find('.collapse').collapse().collapse('hide');
  }
  function expand_all() {
    collapse = false;
    button.html(label_collapse);
    dom.find('.collapse').collapse('show');
  }

}
