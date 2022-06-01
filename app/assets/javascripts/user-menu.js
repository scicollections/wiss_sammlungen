function UserMenu(dom) {
  // I. Define variables and alias `this` as `self` if necessary

  var showNewModalBtn = dom.find(".js-show-new-modal");

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    showNewModalBtn.click(function(event) {
      event.preventDefault();
      disableLink(showNewModalBtn);
      new NewModal(showNewModalBtn);
    });

    // attach current-tab highlighters; these highlighters are just responsible for the
    // *immediate* click-feedback, they are not necessarily necessary, after page
    // refresh the correct tab will be higlighted anyway
    $(".js-user-menu a.js-tab").click(function(){
      $(".js-user-menu .js-tab").removeClass("umenu-tab-active");
      $(this).addClass("umenu-tab-active");
    });
  }
}
