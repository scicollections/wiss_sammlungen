// This is for behaviour that all modals share
function BasicModal(dom) {
  // III.

  init();

  // IV.

  function init() {
    $("body").append(dom);
    dom.modal("show");

    dom.on("keydown", function(e) {
      if (e.keyCode == 27) {
        // dismiss modal on Esc
        dom.modal("hide");
      }
    });

    dom.on("shown.bs.modal", function() {
      dom.find(".form-control:visible:first").focus();
    });

    dom.on("hidden.bs.modal", function () {
      // hide all tooltips
      $('.js-tooltip').qtip('hide');

      // Entferne das Modal aus dem DOM, da sonst die Tabs verwirrt sind.
      dom.remove();
    });
  }
}
