function SelectOptionForm(dom, modal, predicate){
  
  // I. Define variables and alias `this` as `self` if necessary

  // Something we can call .id() on
  var subject = modal.individual();


  
  // II. Publish functions and provide getters and setters
  // III. Call initialisation function(s)

  init();
  
  // IV. Define functions

  function init() {
    dom.find("input.select-option-checkbox").change(submit);
  }
  
  // Erstellung einer Daten-Property
  function submit() {
    var checkbox = $(this);
    var value = checkbox.val();
    var checked = checkbox.prop( "checked" );
    
    var propertydiv = checkbox.closest("div.property");
    var propertyid = propertydiv.data("id");

    if(checked){
      // create
      $.ajax({
        url: "/update/property",
        method: "POST",
        dataType: "json",
        data: {
          value: value,
          predicate: predicate,
          individual_id: subject.id(),
          inline_predicate: modal.predicate(),
          inline_individual_id: modal.individual().id(),
        },
        success: function(data) {
          
          modal.setRevisionMessage(data.revision_message);
          modal.individual().replacePropertyGroupDiv($(data.inline_html));
          propertydiv.data("id",data.id);
          
          // in case of checkbox 'none' -> deselect others
          if (value == "none" && checkbox.attr("type") == "checkbox"){
            var others = dom.find("input[type=checkbox][value!=none]:checked");
            others.prop("checked", false);
            others.change();
          }else if (value != "none" && checkbox.attr("type") == "checkbox"){
            var nonebox = dom.find("input[type=checkbox][value=none]:checked");
            nonebox.prop("checked", false);
            nonebox.change();
          }
        },
        error: makeErrorAlerter("Property konnte nicht erstellt werden")
      });
    }else{
      $.ajax({
        url: "/update/property",
        method: "DELETE",
        dataType: "json",
        data: {
          value: value,
          predicate: predicate,
          individual_id: subject.id(),
          inline_predicate: modal.predicate(),
          inline_individual_id: modal.individual().id(),
          id: propertyid
        },
        success: function(data) {
         
          modal.setRevisionMessage(data.revision_message);
          modal.individual().replacePropertyGroupDiv($(data.inline_html));
        },
        error: makeErrorAlerter("Property konnte nicht gelöscht werden")
      });
      
    }
  }

}