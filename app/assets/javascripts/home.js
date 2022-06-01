function Home(dom) {
  // I. Define variables and alias `this` as `self` if necessary
  // enable tooltips
  // display tooltips differently on narrow screens
  var my = "left center",
    at = "right center";
  if (window.innerWidth < 992) {
    my = "bottom center";
    at = "top center";
  }

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    // collapsing itself is done via bootstrap, this handler additionally exchanges
    // the expand button for a link to the revisions tab
    dom.find(".js-collapse-user-revisions").on("click", function(div) {
      console.log("swap");
      var swap = $(this).data("alt-text");
      $(this).data("alt-text", $(this).html());
      $(this).html(swap);
    });

    // this assumes, that a div with class .js-tooltip is followed by a (possibly hidden)
    // div with class .tooltip-content which contains two subdivs with classes
    // tooltip-title and tooltip-text containing the actual html-code of the tooltip
    // devise login fields tooltip
    dom.find(".js-tooltip").each(function() {
      $(this).qtip({
        style: { classes: "qtip-bootstrap log-in-fields-predicate-tooltip" },
        content: {
          title: $(this).next('.tooltip-content').find('.tooltip-title'),
          text: $(this).next('.tooltip-content').find('.tooltip-text')
        },
        position: {
          my: my,
          at: at,
          viewport: $(window),
          adjust: {
            method: 'shift'
          }
        },
        show: 'focus',
        hide: 'unfocus'
      });
    });
  }


}

