function SurveyFormPredicate(dom, survey_form) {
  // I. Define variables and alias `this` as `self` if necessary

  var self = this;
  
  var campaignSlug = survey_form.campaignSlug();
  var individual_id = survey_form.individualId();
  var predicate = dom.data("predicate");


  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();
  

  // IV. Define functions

  function init() {
    dom.find("input.select-option-checkbox").change(submit);
    dom.find("input[type=radio]").change(submit);
    dom.find("textarea").change(submit_data);
    dom.find("input.form-control").change(submit_data);
  }
  
  // radio or checkbox properties
  function submit() {
    dom.find("span.glyphicon-ok").hide();
    
    var checkbox = $(this);
    var value = checkbox.val();
    var checked = checkbox.prop( "checked" );
    var propertyid = checkbox.data("id");
    var revision_id = checkbox.data("revision_id");

    if(checked){
      // create
      $.ajax({
        url: "/update/property",
        method: "POST",
        dataType: "json",
        data: {
          value: value,
          predicate: predicate,
          individual_id: individual_id,
          inline_predicate: predicate,
          inline_individual_id: individual_id,
          campaign_slug: campaignSlug,
          //revision_id: revision_id
        },
        success: function(data) {
          dom.find("span.glyphicon-ok").show();
          checkbox.data("revision_id",data.revision_id);
          checkbox.data("id",data.id);
            
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
          individual_id: individual_id,
          id: propertyid,
          inline_predicate: predicate,
          inline_individual_id: individual_id,
          campaign_slug: campaignSlug,
          //revision_id: revision_id
        },
        success: function(data) {
         
          dom.find("span.glyphicon-ok").show();
          
        },
        error: makeErrorAlerter("Property konnte nicht gelöscht werden")
      });
      
    }
  }
  
  // data properties
  function submit_data() {
    dom.find("span.glyphicon-ok").hide();
    
    var input = $(this);
    var value = input.val();
    var propertyid = input.data("id");
    var revision_id = input.data("revision_id");

    if(value.trim() != ""){
      // create
      $.ajax({
        url: "/update/property",
        method: "POST",
        dataType: "json",
        data: {
          value: value,
          predicate: predicate,
          individual_id: individual_id,
          inline_predicate: predicate,
          inline_individual_id: individual_id,
          campaign_slug: campaignSlug,
          revision_id: revision_id
        },
        success: function(data) {
          
          dom.find("span.glyphicon-ok").show();
          input.data("revision_id",data.revision_id);
        },
        error: makeErrorAlerter("Property konnte nicht erstellt werden")
      });
    }else{
      // delete
      $.ajax({
        url: "/update/property",
        method: "DELETE",
        dataType: "json",
        data: {
          value: value,
          predicate: predicate,
          individual_id: individual_id,
          id: propertyid,
          inline_predicate: predicate,
          inline_individual_id: individual_id,
          campaign_slug: campaignSlug,
          revision_id: revision_id
        },
        success: function(data) {
         
          dom.find("span.glyphicon-ok").show();
        },
        error: makeErrorAlerter("Property konnte nicht gelöscht werden")
      });
      
    }
  }
}
