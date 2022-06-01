// There are two kinds of edit modals:
// (1) for objekt properties (two columns)
// (2) for non-objekt properties (one column)
// TODO Remove data-predicate from modal HTML or remove predicate argument
function EditModal(dom, individual, predicate) {
  // I. Define variables and alias `this` as `self` if necessary

  var self = this;

  var requestQueue = new RequestQueue();

  var revisionMessageDiv = dom.find(".revision-message");

  // Use :first to only get the *direct* properties div. Some properties with weak objekts will
  // have another properties div inside of them.
  var directPropertiesDiv = dom.find(".properties:first");

  // The list of direct properties
  var properties = [];

  var isCardOnePredicate = dom.data("cardinality-one");
  var isCardManyPredicate = !isCardOnePredicate;
  var isSelectOptionPredicate = dom.data("select-option-type");

  // An objekt predicate is a predicate that will produce objekt properties.
  //
  // TODO There should be more direct way to determine this
  var isObjektPredicate = dom.find(".left-column").length > 0;
  var isDataPredicate = !isObjektPredicate;

  if (isObjektPredicate) {
    var leftCol = dom.find(".left-column");
    var rightCol = dom.find(".right-column");
    var addBtn = dom.find(".add-property-btn");
    var replaceBtn = dom.find(".replace-property-btn");

    var weakType = dom.data("weak-type");

    // A weak objekt predicate is a predicate that will produce objekt properties with weak
    // objekts, i.e. objekts that are weak individuals.
    var isWeakObjektPredicate = weakType != "";
    var isStrongObjektPredicate = !isWeakObjektPredicate;

    if (isWeakObjektPredicate) {
      var rangePredicate = dom.data("range-predicate");

      var isSingleOwnerWeakObjektPredicate = rangePredicate == "";
      var isDoubleOwnerWeakObjektPredicate = !isSingleOwnerWeakObjektPredicate;
      // TODO DigitalReproduction will count as double owner here, but that is not true:
      // it is single owner (DigitalCollection), but it has another fill_on_create property
      // (DigitalReproductionType). Currently this isn't problematic as far as the edit modal
      // JavaScript is concerned, but note that it is not strictly correct.
    }
  }
  // NB if isObjektPredicate is false, then referencing both isWeakObjektPredicate and
  // isStrongObjektPredicate will yield `undefined`, which is falsy, i.e. it can be used in if
  // expression. This means that there will be NO reference error. This same is true for
  // isSingleOwnerWeakObjektPredicate and isDoubleOwnerWeakObjektPredicate.

  // Loading spinner options
  var spinnerOptions = {
    lines: 13, // The number of lines to draw
    length: 20, // The length of each line
    width: 10, // The line thickness
    radius: 30, // The radius of the inner circle
    corners: 1, // Corner roundness (0..1)
    rotate: 0, // The rotation offset
    direction: 1, // 1: clockwise, -1: counterclockwise
    color: '#000', // #rgb or #rrggbb or array of colors
    speed: 1, // Rounds per second
    trail: 60, // Afterglow percentage
    shadow: false, // Whether to render a shadow
    hwaccel: false, // Whether to use hardware acceleration
    className: 'spinner', // The CSS class to assign to the spinner
    zIndex: 2e9, // The z-index (defaults to 2000000000)
    top: '70px', // Top position relative to parent
    left: '50%' // Left position relative to parent
  };

  // II. Publish functions and provide getters and setters

  this.individual = function() { return individual; };
  this.predicate = function() { return predicate; };
  this.isDoubleOwnerWeakObjektPredicate = function() { return isDoubleOwnerWeakObjektPredicate; };
  this.rangePredicate = function() { return rangePredicate; };
  this.insertPropertyDiv = insertPropertyDiv;
  this.removeProperty = removeProperty;
  this.setRevisionMessage = setRevisionMessage;
  this.displayError = displayError;
  this.unselectAll = unselectAll;
  this.display = display;
  this.queuedAjax = queuedAjax;

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    // This will attach it to the body and call `modal("show")`.
    new BasicModal(dom);

    // Specify individual_id in query because weak objekt property divs can have child properties,
    // and we don't want to include those here. They have a different subject, so we won't catch
    // them in our query.
    directPropertiesDiv.find(".property[data-individual-id="+individual.id()+"]").each(function() {
      properties.push(new Property($(this), self));
    });

    if (isObjektPredicate) {
      showCorrectButton();
      addBtn.click(add);
      replaceBtn.click(replace);
    }

    if (isDataPredicate && isCardManyPredicate) {
      new CreateDataPropertyForm(dom.find("form.create-property"), self, predicate);
    }
    
    if (isSelectOptionPredicate){
      new SelectOptionForm(dom.find("div.properties"), self, predicate);
    }

    // Blende Revision Message im Modal Footer aus, sobald ein Input Element den Fokus verliert
    dom.focusout(emptyRevisionMessage);

    dom.on("hidden.bs.modal", function () {
      // in case an email-address was added to a Person:
      if ((predicate == "email" || predicate == "visible_for") && individual.recordClass() == "Person") {
        individual.reloadInviteStatus();
      } else if (individual.recordClass() == "ConceptScheme" && predicate == "hierarchical") {
        // hard reload after editing ConceptScheme.hierarchical since the
        // display of ConceptScheme.has_concept depends on it
        location.reload();
      } else if(predicate == "year_of_death"){
        //hard reload, so info_text is set correctly
        Turbolinks.visit(location.toString());
      } else if( ["label","title","name","first_name"].includes(predicate) ){
        // updating the title in the html meta section if neccessary
        var newLabel = $('.individual-title * .property').html();
        var newtitle = newLabel + " • " + document.title.split("•")[1];
        document.title = newtitle;
      }
    });

    dom.find('a.info-helper-modal').click(function(){
      dom.find('.js-info-text-modal').slideToggle();
      dom.find( "a.info-helper-modal" ).toggleClass("info-helper-active");
    });
  }

  function showCorrectButton() {
    if (!isObjektPredicate) {
      console.log("This should only be called for objekt modals!");
      return;
    }

    if (isCardOnePredicate && properties.length > 0) {
      addBtn.hide();
      replaceBtn.show();
    } else {
      addBtn.show();
      replaceBtn.hide();
    }
  }

  // Returns the property
  function insertPropertyDiv(div, revisionId) {
    directPropertiesDiv.append(div);
    var prop = new Property(div, self,null, revisionId);
    properties.push(prop);

    if (isObjektPredicate) {
      showCorrectButton();
    }

    return prop;
  }

  // This removes the property from the properties array, and does the necessary dom changes
  // outside of the (now removed) property div.
  function removeProperty(prop, keepForm) {
    var index = properties.indexOf(prop);
    if (index > -1) { // This should always be the case, but just to be sure...
      properties.splice(index, 1);
    }

    if (isObjektPredicate) {
      showCorrectButton();

      // We usually want to empty the right column, because it might display the details of the
      // property we just deleted. But if this call comes from WeakIndividual#handleBaseProperty,
      // we want to keep it.
      if (!keepForm) {
        rightCol.empty();
      }
    }
  }

  // Zeigt im Footer eines Modals str an; falls ein focus_element gesetzt ist, dann
  // wird die Nachricht ausgeblendet, sobald dieses Element den Fokus verliert.
  // TODO Sagen, wer sich um das ausblenden kümmert
  function setRevisionMessage(str) {
    if (str.length > 90) {
      // Dies ist ein Workaround um sehr lange Revisionsnachrichten, wie sie bei
      // SciCollection#description vorkommen. Das ist natürlich keine richtige Lösung;
      // vielleicht allgemein auf die Anzeige der Revisionsnachrichten verzichten?
      str = "Die Änderungen wurden gespeichert.";
    }
    revisionMessageDiv.html(str).stop().css("opacity", 1).show();
  }

  function emptyRevisionMessage() {
    revisionMessageDiv.empty();
  }

  function displayError(data) {
    if (data.responseJSON) {
      if (data.responseJSON.errors) {
        setRevisionMessage(data.responseJSON.errors.join("<br>"));
      } else {
        setRevisionMessage("Die Änderungen konnten leider nicht gespeichert werden.");
      }
    } else if ($("body").data("rails-env") == "development") {
      setRevisionMessage("(Development): Turn off 'consider_all_requests_local' to display error messages.")
    }
  }

  function replace() {
    disableLink(replaceBtn);
    if (properties.length != 1) {
      // This should never be the case if the replaceBtn is visible, but be sure just in case.
      console.log("The replace button is visible, but there is not exactly one property. " +
        "This means that something is wrong, so I won't do anything.");
      return;
    }

    properties[0].remove(function(){
      add();
      enableLink(replaceBtn);
    });
  }

  function add() {
    unselectAll();
    var spinner = (new Spinner(spinnerOptions)).spin(rightCol[0]);
    disableLink(addBtn);
    if (isStrongObjektPredicate) {
      // Strong-Individuals die an dieser Stelle nicht bearbeitet werden sollen
      // Zum Beispiel Concept
      $.get("/edit/range", { individual_id: individual.id(), predicate: predicate }, function(html) {
        new CreateObjektPropertyForm($(html), self);
      }).fail(makeErrorAlerter("Die Range konnte nicht geladen werden")).always(function(){
        enableLink(addBtn);
      });
    }

    if (isDoubleOwnerWeakObjektPredicate) {
      // Weak-Individuals, für die es ein weiteres Strong-Individual gibt
      // Zum Beispiel Curatorship
      $.get("/edit/range", { type: weakType, predicate: rangePredicate }, function(html) {
        new CreateObjektPropertyForm($(html), self);
      }).fail(makeErrorAlerter("Die Range konnte nicht geladen werden")).always(function(){
        enableLink(addBtn);
      });
    }

    if (isSingleOwnerWeakObjektPredicate) {
      // Weak-Individuals, deren Properties an dieser Stelle bearbeitet werden können
      // Zum Beispiel WebResource
      $.get("/edit/weak_individual_form", { type: weakType }, function(html) {
        new WeakIndividual($("<div>" + html + "</div>"), self);
      }).fail(makeErrorAlerter("Konnte das Formular nicht laden")).always(function(){
        enableLink(addBtn);
      });
    }
  }

  // Evtl. bestehende Auswahl aufheben
  function unselectAll() {
    dom.find(".selected").removeClass("selected");
  }

  // To displays things in the right column
  function display(div) {
    rightCol.html(div);
  }

  // This function lives in EditModal (as opposed to, say, Maya), so that the queue can be reset
  // by closing and reopening the modal, if somehow a request never finishes.
  function queuedAjax(closure) {
    requestQueue.add(closure);
  };
}
