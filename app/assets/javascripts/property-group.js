function PropertyGroup(dom, individual, predicate) {
  // I. Define variables and alias `this` as `self` if necessary

  var editable = dom.hasClass("editable");

  // These will only exist for collapsed property groups
  var toggleCollapseBtn = dom.find(".js-collapse-property-group"); // TODO Rename class to "toggle"
  var collapseTarget = dom.find(toggleCollapseBtn.data("target"));
  var sortmode = toggleCollapseBtn.data("sortmode");

  // Loading spinner for property group expansion
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

  // II. Publish functions and provide getters and setters

  this.predicate = function() { return predicate; }; // Used by Individual
  this.replaceWith = replaceWith; // Used by Individual#deploy
  this.enableTooltip = enableTooltip;
  this.disableTooltip = disableTooltip;

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    dom.click(clickHandler);

    toggleCollapseBtn.click(toggleCollapse);

    // Enable tooltips on external-link icons
    dom.find(".linker").tooltip();
    
    // individual property hover info tooltips
    // $(".glass-individual .row .js-tooltip").each(function() {
    dom.find(".js-tooltip").each(function() {
      attachInfoTooltip(this);
    });
  }

  function clickHandler(event) {
    if (individual.editMode() && editable) {
      disableLink(dom);
      $.get("/edit", { predicate: predicate, individual_id: individual.id() }, function(html) {
        new EditModal($(html), individual, predicate);
      }).fail(function(){
        makeErrorAlerter("Modal konnte nicht geladen werden");
      }).always(function(){
        enableLink(dom);
      });

      // Ist nötig, da in dem Div möglicherweise ein Link steht.
      event.preventDefault();
    }
  }

  function replaceWith(newDom) {
    // Hiding any tooltips that might still be visible, because they might get orphaned if
    // they belong to the DOM part that will be replaced.
    $(".tooltip").hide();

    dom.replaceWith(newDom);
  }

  function toggleCollapse() {
    // Don't toggle in edit mode
    if (individual.editMode()) {
      return;
    }

    if (!collapseTarget.hasClass("synced")) {
      var spinner = new Spinner(spinnerOptions).spin(collapseTarget[0]);
      $.get(location.pathname, { expand: predicate, sortmode: sortmode }, function(html) {
        spinner.stop();
        collapseTarget.html(html);
        collapseTarget.addClass("synced");
        // attach tooltip eventhandlers
        collapseTarget.find(".js-tooltip").each(function() {
          attachInfoTooltip(this);
        });
      }).fail(makeErrorAlerter("Konnte Eigenschaften nicht laden."));
    }

    var swap = toggleCollapseBtn.data("alt-text");
    toggleCollapseBtn.data("alt-text", toggleCollapseBtn.html());
    toggleCollapseBtn.html(swap);

    collapseTarget.collapse("toggle");
  }

  function enableTooltip() {
    if (editable) {
      dom.tooltip("enable");
    }
  }

  function disableTooltip() {
    dom.tooltip("disable");
  }
  


  // used to add info tooltip behaviour to properties on individual pages
  function attachInfoTooltip(elem) {
    // anchor the tooltip on surrounding div, if present
    var target;
    if ($(elem).closest('.js-tooltip-anchor').length == 1) {
      target = $(elem).closest('.js-tooltip-anchor');
    }
    else {
      target = elem;
    }

    $(elem).qtip({
      content: {
        text: $(elem).next('.tooltip-content')
      },
      position: {
        my: 'top left',
        at: 'bottom left',
        adjust: {
          x: 10,
          method: 'shift'
        },
        target: target,
        viewport: $(window)
      },
      show: {
        event: 'click',
        delay: 0
      },
      hide: {
        event: 'unfocus'
      },
      style: {
        /* hide debatable speech-bubble -> anchor connector tip */
        tip: false,
        classes: 'qtip-bootstrap individual-predicate-tooltip'
      }
    });
  }
}
