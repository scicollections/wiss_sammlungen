// weakIndividual - Can be undefined
function CreateObjektPropertyForm(dom, modal, weakIndividual) {
  // I. Define variables and alias `this` as `self` if necessary

  // Something we can call .id() on
  var subject = weakIndividual || modal.individual();

  var predicate = dom.data("predicate");
  var input = dom.find("input.range-filter");
  var cardOne = dom.hasClass("cardinality-one");
  
  // II. Publish functions and provide getters and setters
  // III. Call initialisation function(s)

  init();
  
  // IV. Define functions

  function init() {
    if (!weakIndividual) {
      // If this is for a direct property, we need to ask the modal to display us. (The modal
      // created us, but the modal is lazy. Its display method is exposed anyway, so the modal
      // relies on us to remind it to display us.)
      modal.display(dom);
    }

    new RangeFilter(dom, input);

    dom.find(".existing-individual").click(function(e) {
      e.preventDefault();
      var id = $(this).data("objekt-id");

      // Immediately disable all buttons that represent this individual to avoid duplicate requests
      // in case of a slow server. (There can be relevant buttons other than $(this) when the range
      // is displayed hierarchically.)
      dom
        .find(".existing-individual[data-objekt-id="+id+"]")
        .attr("disabled", "disabled");

      if (weakIndividual) {
        createStrongObjektProperty(id);
      } else {
        if (modal.isDoubleOwnerWeakObjektPredicate()) {
          createDoubleOwnerWeakObjektProperty(id);
        } else {
          createStrongObjektProperty(id);
        }
      }
    });

    dom.find(".js-tooltip").each(attachTooltip);
  }

  function createStrongObjektProperty(objektId) {
    modal.queuedAjax(function() { return {
      url: "/update/property",
      method: "POST",
      dataType: "json",
      data: {
        inline_individual_id: modal.individual().id(),
        inline_predicate: modal.predicate(),
        individual_id: subject.id(),
        predicate: predicate,
        value: objektId,
      },
      success: function(data) {
        if (weakIndividual) {
          var div = $(data.edit_html);
          // For now, on weak individuals, we just swap the property div with the form div each
          // time an objekt property is created or removed. This works, because weak individuals
          // only have cardOne properties at the moment.
          dom.replaceWith(div);
          // Need to register the new property with its subject
          weakIndividual.addProperty(new Property(div, modal, weakIndividual));
          weakIndividual.handleBaseProperty(data);
        } else {
          modal.insertPropertyDiv($(data.edit_html));

          if (cardOne) {
            // cardOne-Ranges are removed immediately
            dom.remove();
          } else {
            // For cardMany (direct) strong objekt properties, re-select the filter input
            input.select().focus();
          }
        }

        modal.setRevisionMessage(data.revision_message);
        modal.individual().replacePropertyGroupDiv($(data.inline_html));
      },
      error: modal.displayError
    }; });
  }

  // TODO Rename to "fill on create" because it's not necessarily double *owner*.
  function createDoubleOwnerWeakObjektProperty(objektId) {
    $.ajax({
      url: "/update/property",
      method: "POST",
      dataType: "json",
      data: {
        inline_individual_id: modal.individual().id(),
        inline_predicate: modal.predicate(),
        predicate: modal.rangePredicate(),
        value: objektId,
      },
      success: function(data) {
        // Left column
        var prop = modal.insertPropertyDiv($(data.base_property));

        // Right column
        new WeakIndividual($(data.base_property), modal, prop);

        modal.setRevisionMessage(data.revision_message);
        modal.individual().replacePropertyGroupDiv($(data.inline_html));
      },
      error: modal.displayError
    });
  }

  /**
   * Attaches the qtips on ranges in edit-modal; they contain the individual-
   * specific info-texts if present; Assumes to be called with context of
   * a dom element, that is followed by an element with class .tooltip-content
   * and with the tooltip content as content ;)
   */
  function attachTooltip() {
    $(this).qtip({
      content: {
        text: $(this).next('.tooltip-content')
      },
      show: {
        delay: 1300
      },
      position: {
        my: 'top left',
        at: 'bottom left',
        adjust: {
          x: 10
        }
      },
      style: {
        classes: 'qtip-bootstrap individual-predicate-tooltip'
      }
    });
  }
}
