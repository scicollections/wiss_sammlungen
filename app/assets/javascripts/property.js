// Three dimensions of difference between properties:
// (1) Object vs. non-object TODO Use two classes for these?
// (2) Subject is the modal's individual vs. an associated weak individual ("direct" vs. "indirect")
// (3) Cardinality one vs. many
//
// weakIndividual - Will be undefined if it's a direct property
function Property(dom, modal, weakIndividual,revisionId) {
  var self = this;

  var id = dom.data("id");

  var objektId = dom.data("objekt-id"); // Can be `undefined`
  var objekt = objektId !== undefined; // Whether it's an objekt property or not

  // Something we can call .id() on
  var subject = weakIndividual || modal.individual();

  // Can be different from modal.predicate(), just like the individual id
  var predicate = dom.data("predicate");

  var cardOne = dom.hasClass("cardinality-one");

  var deleteBtn = dom.find(".delete-property");

  var complexProperty = dom.hasClass("complex-property");

  // For auto saving data properties
  var autoSaveTimer = new Timer();

  // These are only for data properties
  var form = dom.children(".details").children("form.update-property");
  var formGroup = form.children(".form-group");
  var input = form.find("input, textarea, select");
  // (Need to set default "" because SLIM will not include empty data attributes.)
  var serverValue = input.data("server-value") || "";
  var pendingSubmission; // To cache what has just been sent to the server

  this.remove = remove; // Used by EditModal#replace
  this.setLabel = setLabel; // Used by WeakIndividual#handleBaseProperty
  this.removeDom = removeDom; // Used (only!) by WeakIndividual#handleBaseProperty
  this.resetRevisionId = resetRevisionId; // Used by WeakIndividual#handleBaseProperty

  init();

  function init() {
    deleteBtn.click(function() {
      // Wrapping this in an anonymous function because "remove" has a callback parameter
      remove();
    });

    // Submit für Daten-Properties
    form.submit(function(event) {
      event.preventDefault();
      updateDataProperty();
    });

    // Objekt-Property-Eintrag in der linken Spalte
    // oder Card-Many Daten-Property
    dom.find("div.summary.editable").click(showPropertyForm);

    // Submit-Trigger für alles außer Date-Ranges
    // Input- und Text-Areas führen nach einem Delay,
    // Fokuswechsel oder Keycode (s.u.) zum Submit der Form
    form.find("input:not(.date), textarea")
      .keyup(setTimerIfChanged)
      .focusout(updateDataProperty)
      .keydown(updateOnCtrlEnter);

    // Submit-Trigger für Date-Ranges
    // Der Bootstrap-Datepicker scheint einen kleinen Bug zu haben. Wenn die Option
    // autoclose auf true gesetzt ist, dann feuert auf dem zugehörigen <input> Element
    // das Event "focusout" noch bevor das Datum ins <input> geschrieben wird. Das führt
    // dazu, dass ein updateDataProperty mit einem leeren Wert abgeschickt wird. Daher werden
    // hier input.date-Elemente seperat behandelt.
    form.find("input.date").change(updateDataProperty);

    // call datepicker() on container .input-daterange to activate date-range logic
    form.find("input.date").datepicker({
      language: "de",
      autoclose: true // close the datepicker immediately when a date is selected.
    });

    // Ändern einer Checkbox führt zum sofortigen Submit
    form.find("input[type=checkbox]").change(updateDataProperty);

    // Ändern einer Auswahlliste führt zum sofortigen Submit
    form.find("select").change(updateDataProperty);

    dom.find("select,input,textarea").focusout(modal.emptyRevisionMessage);
  }

  function setTimerIfChanged() {
    if (input.val() != serverValue) { // we are dirty
      if (!formGroup.hasClass("has-warning")) { // but we say we are clean
        // TODO Nicht nur das Icon anzeigen, sondern irgendwo auch Text,
        // der erklärt, was gerade los ist.
        setStatus("warning");
      }

      // Speichern, wenn x ms lang keine Eingaben
      autoSaveTimer.set(updateDataProperty, maya.autoSaveInterval());
    }
  }

  function updateOnCtrlEnter(e) {
    if (e.keyCode == 13 && (e.metaKey || e.ctrlKey)) {
      // Update on Cmd-Enter bzw. Ctrl-Enter
      updateDataProperty();
    }
  }

  // Nach Auswählen einer Property aus der linken Spalte
  // oder einer bestehenden Card-Many Daten-Property
  function showPropertyForm() {
    if (objekt) {
      // Bei Card-Many Objekt-Properties die Selected-Class tauschen
      modal.unselectAll();
      dom.find(".summary").addClass("selected");

      // Formular für rechte Spalte holen und einbetten
      $.get("/edit/property", { id: id }, function(html) {
        // Using "$(html)" here and not "dom.clone()" because the DOM in the left column will not
        // be kept updated after changes in the right column. So if the user changes sth. on the
        // right, then selects another property on the left, then selects the original one again,
        // their change would not appear.
        // TODO Stop including weak individual forms in property DIVs to make this less
        // surprising. Also use a .weak-individual CSS class to correspond to the JS class.
        new WeakIndividual($(html), modal, self);
      }).fail(makeErrorAlerter("Formular konnte nicht geladen werden."));
    } else {
      // Bei Card-Many Daten-Properties die Form anstelle der Summary einblenden
      dom.addClass("expanded");
    }
    dom.find("input:not(.date):visible:first").focus();
  }

  // Submit einer Änderung an einem Daten-Property (oder Label)
  function updateDataProperty() {
    autoSaveTimer.clear();
    var value = val(input);

    // Setze keine Request ab, wenn der Wert schon auf dem Server ist, oder man gerade
    // kurz vorher einen Request mit dem gleichen Wert gemacht hat.
    if (serverValue == value || pendingSubmission == value) {
      return;
    }
    
    var inline_predicate = modal.predicate();
    var inline_individual_id = modal.individual().id();
    if (weakIndividual && weakIndividual.complexProperty()) {
      var complex_prop_predicate = weakIndividual.predicate();
      var complex_prop_parent_id = weakIndividual.baseProperty().id();
    }

    pendingSubmission = value;

    modal.queuedAjax(function() { return {
      url: (predicate == "label") ? "/update/individual" : "/update/property",
      method: "PUT",
      dataType: "json",
      data: {
        value: value,
        id: id,
        // die nächsten beiden brauchen wir für "text, card:1, leer"
        predicate: predicate,
        individual_id: subject.id(),
        revision_id: revisionId,
        inline_predicate: inline_predicate,
        inline_individual_id: inline_individual_id,
        complex_prop_parent_id: complex_prop_parent_id,
        complex_prop_predicate: complex_prop_predicate
      },
      success: function(data) {
        // TODO Validierung beachten

        pendingSubmission = null;
        serverValue = value;
        setStatus("success"); // TODO check if in der zwischenzeit keine Änderungen
				
				if(data != undefined){
	        id = data.id; // bei "text, card:1, leer"
	        revisionId = data.revision_id;

	        if (weakIndividual) {
	          weakIndividual.handleBaseProperty(data);
	        }

	        modal.setRevisionMessage(data.revision_message);
  
	        modal.individual().replacePropertyGroupDiv($(data.inline_html));
  
  
	        modal.individual().setVisibility(data.visibility);
				}
      },
      error: function(data) {
        pendingSubmission = null;
        modal.displayError(data);
        setStatus("error");
      }
    }; });
  }

  // status - Can be "success", "warning" or "error"
  function setStatus(status) {
    formGroup.removeClass("has-success has-warning has-error").addClass("has-"+status);
  }

  // Calling this "remove" because "delete" is a reserved word
  function remove(successCallback) {
    if (!confirm("Sind sie sicher, dass " + label() + " entfernt werden soll?")) {
      return;
    }

    modal.queuedAjax(function() { return {
      url: "/update/property",
      method: "DELETE",
      dataType: "json",
      data: {
        id: id,
        inline_predicate: modal.predicate(),
        inline_individual_id: modal.individual().id(),
      },
      success: function(data) {
        if (weakIndividual) {
          weakIndividual.removeProperty(self);
          weakIndividual.handleBaseProperty(data);
        } else {
          modal.removeProperty(self);
        }

        if (weakIndividual && cardOne && objekt) {
          // In this case we want to display the range immediately. Example: Address#location
          if (data.range) {
            var range = $(data.range); // TODO Shouldn't this be called "form"?
            new CreateObjektPropertyForm(range, modal, weakIndividual);
            dom.replaceWith(range);
          } else {
            console.log("This is an indirect card-one objekt property, therefore I expected the " +
                        "response to include a range, but it didn't!");
          }
        } else {
          dom.remove();
        }

        modal.setRevisionMessage(data.revision_message);
        modal.individual().replacePropertyGroupDiv($(data.inline_html));

        if (successCallback) {
          // Wird benutzt von dem Replace-Button, der sofort die Range anzeigt.
          successCallback();
        }
      },
      error: makeErrorAlerter("Property konnte nicht gelöscht werden")
    }; });
  }

  // Generalise jQuery's .val() to include checkboxes
  function val(input) {
    if (input.attr("type") == "checkbox") {
      return input.is(":checked") ? "true" : "false";
    } else {
      return input.val();
    }
  }

  function label() {
    return dom.find(".summary-span:first").text();
  }

  // For WeakIndividual#handleBaseProperty
  function setLabel(str) {
    dom.find(".summary-span:first").text(str);
  }

  // Exposing this for WeakIndividual#handleBaseProperty, because there the property will be already
  // destroyed on the server before we learn about it and have to remove its dom.
  function removeDom() {
    dom.remove();
  }

  // For WeakIndividual#handleBaseProperty
  function resetRevisionId() {
    revisionId = null;
  }
}
