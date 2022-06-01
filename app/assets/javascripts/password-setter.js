function PasswordSetter(dom) {
  // I. Define variables and alias `this` as `self` if necessary


  // II. Publish functions and provide getters and setters



  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    dom.find("#user_password").complexify({}, complexifyCallback);
    dom.find("#user_password_confirmation").keyup(confirmationCallback);
  }

  function complexifyCallback(valid, complexity) {
    var bar = dom.find(".progress-bar");
    var note = dom.find(".length-note");
    if (dom.find("#user_password").val().length >= 6) {
      note.hide();
      bar.show();
      var percent = Math.round(complexity) + "%";
      bar.css("width", percent);
      bar.html("Stärke: " + percent);
    } else {
      note.show();
      bar.hide();
    }
    confirmationCallback();
  }

  function confirmationCallback() {
    var current_password_input = dom.find("#user_current_password");
    var password_input = dom.find("#user_password");
    var password = password_input.val();
    var confirmation = dom.find("#user_password_confirmation").val();
    var btn = dom.find("input[type=submit]");
    var note = dom.find(".sameness-note");
    if (password_input.closest(".field").hasClass("optional") && password.length == 0) {
      btn.removeAttr("disabled");
    } else if (password.length >= 6 && password == confirmation) {
      btn.removeAttr("disabled");
      note.hide();
    } else {
      btn.attr("disabled", "disabled");
      note.show();
    }
  }
}

