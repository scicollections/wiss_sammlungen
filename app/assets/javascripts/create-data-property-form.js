function CreateDataPropertyForm(dom, modal, predicate) {
  // I. Define variables and alias `this` as `self` if necessary

  var input = dom.find("input");
  var submitBtn = dom.find("button[type='submit']");

  // When weak individuals can have cardMany properties, I'll need to load this class in
  // WeakIndividual. In that case, add a weakIndividual parameter here, and define subject
  // as `weakIndividual || modal.individual()` like in Property.
  var subject = modal.individual();

  // II. Publish functions and provide getters and setters
  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    dom.submit(function(event) {
      event.preventDefault();
      submit();
    });

    // TODO Or should we use keyup like in Property? And/or timer?
    input.on("input", validate);
  }

  // Erstellung einer Daten-Property
  function submit() {
    var val = input.val();

    // do nothing when no input value
    if (val == undefined || val == "" || val == null) {
      return;
    }

    $.ajax({
      url: "/update/property",
      method: "POST",
      dataType: "json",
      data: {
        value: val,
        predicate: predicate,
        individual_id: subject.id(),
        inline_predicate: modal.predicate(),
        inline_individual_id: modal.individual().id(),
      },
      success: function(data) {
        modal.insertPropertyDiv($(data.edit_html), data.revision_id);
        modal.setRevisionMessage(data.revision_message);
        modal.individual().replacePropertyGroupDiv($(data.inline_html));
        input.val("").focus();
      },
      error: makeErrorAlerter("Property konnte nicht erstellt werden")
    });
  }

  // Checks whether the data in the form would create a valid property (i.e. dry-run creation).
  function validate() {
    $.ajax({
      url: "/validate/property",
      method: "GET",
      data: {
        value: input.val(),
        predicate: predicate,
        individual_id: subject.id(),
        inline_predicate: modal.predicate(),
        inline_individual_id: modal.individual().id()
      },
      success: function(data) {
        if (data.valid) {
          input.css("color", "green");
          // enable submit button
          submitBtn.attr('disabled', false);
        }
        else {
          input.css("color", "red");
          // disable submit button
          submitBtn.attr('disabled', true);
        }
        // add message notification
        modal.setRevisionMessage(data.revision_message);
      }
    });
  }
}
