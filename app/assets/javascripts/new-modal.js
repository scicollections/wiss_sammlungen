function NewModal(showNewModalBtn) {
  // I. Define variables and alias `this` as `self` if necessary

  // This is not a manager object, as in `modal = new NewModal();`, but a jQuery object, as in
  // `modal = $(".modal");`.
  var modal;
  var createIndividualButton;

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    $.get("/new", function(html) {
      modal = $(html);
      createIndividualButton = modal.find("button.js-create-individual");
      
      // This will attach it to the body and call `modal("show")`.
      new BasicModal(modal);

      new RangeFilter(modal.find(".range"), modal.find("input.range-filter"));

      modal.find(".js-indi-typeselect").click(function() {
        selectType($(this).val(), $(this).html());
      });

      modal.find("#js-selected-type-div .js-back-to-typeselection").click(unselectType);

      modal.find("form").submit(preventEmptyLabel);
    }).fail(function(){
      makeErrorAlerter("Modal konnte nicht geladen werden");
    }).always(function(){
      enableLink(showNewModalBtn);
    });
    
  }

  function selectType(type, translatedType) {
    modal.find("#typeselect").val(type);
    modal.find("#js-selected-type-div .js-selected-type").html(translatedType);
    // Suchbox leeren und keyup-event triggern, damit der Eventhandler für den range-filter anspringt
    modal.find("#js-typeselect-container input.range-filter").val("").keyup();
    // Typ-Auswahl ausblenden
    modal.find("#js-typeselect-container").hide();
    // Ausgewählten Typ-Container einblenden
    modal.find("#js-selected-type-div").show();

    if (type == "Person") {
      modal.find(".person-fields").show();
      modal.find(".label-field").hide();
    } else {
      modal.find(".person-fields").hide();
      modal.find(".label-field").show();
    }

    modal.find(".js-create-individual").prop('disabled', false);
  }

  function unselectType() {
    // Submit-Button disabeln
    modal.find(".js-create-individual").prop('disabled', true);
    // Typauswahl einblenden
    modal.find("#js-typeselect-container").show();
    // gewählten Typ leeren
    modal.find("#typeselect").val("");
    modal.find("#js-selected-type-div .js-selected-type").html("Typ");
    // und ausblenden
    modal.find("#js-selected-type-div").hide();
    // Falls Person angewählt war, wieder das label-field anzeigen
    modal.find(".person-fields").hide();
    modal.find(".label-field").show();
  }

  function preventEmptyLabel(event) {
    disableLink(createIndividualButton);
    // Verhindere, dass Individuals mit leerem Label erstellt werden.
    // Ansonsten das reguläre Event stattfinden lassen (nicht verhindern).
    if (modal.find("#typeselect").val() == "Person") {
      if (modal.find("input[name=name]").val().trim() == "" &&
          modal.find("input[name=first_name]").val().trim() == "") {
        event.preventDefault();
        alert("Bitte geben sie einen Namen an.");
        enableLink(createIndividualButton);
      }
    } else {
      if (modal.find("input[name=label]").val().trim() == "") {
        event.preventDefault();
        alert("Bitte geben sie eine Bezeichnung an.");
        enableLink(createIndividualButton);
      }
    }
  }
}
