function SurveyFormTableRow(dom, survey_form, predicateDom) {
  // I. Define variables and alias `this` as `self` if necessary

  var self = this;
  
  var campaignSlug = survey_form.campaignSlug();
  var individual_id = survey_form.individualId();
  var predicate = dom.data("predicate");
  var property_id = dom.data("id");
  var objekt_id = dom.data("objekt-id");
  var row_id = dom.data("objekt-id");
  var rowDom = dom;


  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();
  

  // IV. Define functions
  
  function init(){
    dom.find("div.weak-table-cell").each(function(){new SurveyFormTableCell($(this))});
    dom.find("button.delete-property-btn").click(remove);
  }
  
  // Remove a weak individual row
  function remove(event) {
    console.log(event);
    if (!confirm("Sind sie sicher, dass diese Zeile entfernt werden soll?")) {
      return;
    }
    event.preventDefault();
    survey_form.displayStatus("hide",predicateDom);
    $.ajax({
      url: "/update/property",
      method: "DELETE",
      dataType: "json",
      data: {
        id: property_id,
        inline_predicate: predicate,
        inline_individual_id: individual_id,
        campaign_slug: campaignSlug
      },
      success: function(data) {
        dom.remove();
        survey_form.displayStatus("ok",predicateDom);
      },
      error: makeErrorAlerter("Property konnte nicht gelöscht werden")
    });
  }
  

  // V. Inner classes
  
  // Class/Function for weak individual row
  function SurveyFormTableCell(dom){
    // I. Define variables and alias `this` as `self` if necessary

    var self = this;
  
    // For auto saving data properties
    var autoSaveDictTimer = new Timer();
    
    var showHideAnother = false;
		var complexPropertyCell = dom.find(".complex-property").length > 0;

    // II. Publish functions and provide getters and setters
  


    // III. Call initialisation function(s)

    init();
    
    // IV. Define functions

    function init() {
      // input listeners
      dom.find("input.form-control").on('input',setAutoSaveTimerForDataSubmit);
      dom.find("select.form-control").change(submitSelect);
      dom.find("input[type=radio]").change(submitSelect);
      dom.find("input[type=checkbox]").change(submitCheckbox);
      dom.find("textarea").on('input',setAutoSaveTimerForDataSubmit);
      dom.find("div.select-form").each(function(){
        var listId = $(this)[0];
        new List(listId,{valueNames: ["candidateLabel"]})
      });
      
      // Collapse/Expand a long select list
      dom.find("button.collapse-button").click(function(event){
        dom.find("div.select-form").collapse('toggle');
      });
      dom.find("div.select-form").on("hide.bs.collapse",function(){
        var collapseId = $(this).attr('id');
        var collapseButton = dom.find("button.collapse-button");
        collapseButton.find("span.glyphicon").removeClass("glyphicon-chevron-up");
        collapseButton.find("span.glyphicon").addClass("glyphicon-chevron-down");
      });
      dom.find("div.select-form").on("show.bs.collapse",function(){
        var collapseId = $(this).attr('id');
        var collapseButton = dom.find("button.collapse-button");
        collapseButton.find("span.glyphicon").removeClass("glyphicon-chevron-down");
        collapseButton.find("span.glyphicon").addClass("glyphicon-chevron-up");
      });
            
    }
  
    // handle data input
    function submitData() {
      survey_form.displayStatus("hide",predicateDom);
    
      var input = dom.find("input.form-control");
      if(input.size() == 0){
        input =  dom.find("textarea");
      }
      
      
      var value = input.val();
      if(value.trim() != ""){
        // create
        $.ajax({
          url: "/update/property",
          method: "PUT",
          dataType: "json",
          data: getParams(input, dom, value),
          success: function(data) {
          
            setDomIds(input,dom,data);
          },
          error: makeErrorAlerter("Property konnte nicht erstellt werden")
        });
      }else{
        // delete
        $.ajax({
          url: "/update/property",
          method: "DELETE",
          dataType: "json",
          data: getParams(input, dom, value),
          success: function(data) {
         
            setDomIds(input,dom,data,true);
          },
          error: makeErrorAlerter("Property konnte nicht gelöscht werden")
        });
      
      }
    }
  
    // Handle the input for a select field
    function submitSelect() {
      var submitDom = $(this);
			var dataHolderDom = submitDom.closest(".js-data-holder");
    
      if($(this).is('input[type=radio]')){
        if(!$(this).is(':checked')){
          return;
        }else{
          var value = $(this).attr("value");
          var select = $(this).closest('form.list');
          var radio = $(this);
          var val_text = radio.siblings("span").text();
        }
      }else{
        var select = $(this);
        var value = select.find(":selected").data("id");
        var val_text = $(this).text();
      }
      
      var property_predicate = select.data("predicate");
      var propertyid = select.data("id");
			var complex_prop_parent_id = dom.find(".complex-property").data("individual-id");
			var complex_prop_predicate = dom.find(".complex-property").data("predicate");
      
      // for complex property bool
      if(select.length == 0){
        select = $(this).closest('.complex-property');
        property_predicate = $(this).data("predicate");
        propertyid = $(this).data("id");
        objekt_id = select.data("id");
      }
      
    
      
      survey_form.displayStatus("hide",predicateDom);
      
      if(value == "delete"){
        $.ajax({
          url: "/update/property",
          method: "DELETE",
          dataType: "json",
          data: {
            value: value,
            predicate: property_predicate,
            individual_id: individual_id,
            id: propertyid,
            inline_predicate: predicate,
            inline_individual_id: individual_id,
            campaign_slug: campaignSlug
          },
          success: function(data) {
         
            survey_form.displayStatus("ok",predicateDom);
            if(radio){
              var collapseId = radio.closest("div.select-form").attr("id");
              var collapseButton = dom.find("button span.collapse-button-text");
              collapseButton.html(collapseButton.data("originaltext"));
            }
          },
          error: makeErrorAlerter("Eigenschaft konnte nicht gelöscht werden")
        });
      }else{
        $.ajax({
          url: "/update/property",
          method: "POST",
          dataType: "json",
          data: {
            value: value,
            predicate: property_predicate,
            individual_id: objekt_id,
            inline_predicate: predicate,
            inline_individual_id: individual_id,
            campaign_slug: campaignSlug,
            id: propertyid,
		        complex_prop_parent_id: complex_prop_parent_id,
		        complex_prop_predicate: complex_prop_predicate
          },
          success: function(data) {
        
            survey_form.displayStatus("ok",predicateDom);
            if(radio){
              var collapseId = radio.closest("div.select-form").attr("id");
              var collapseButton = dom.find("button span.collapse-button-text");
              collapseButton.html(radio.next().html());
            }
          
          },
          error: makeErrorAlerter("Eigenschaft konnte nicht geändert werden")
        });
      }
      dom.find(".select-form.collapsible").collapse('hide');
  
    
    }
    
    function submitCheckbox() {
      
      survey_form.displayStatus("hide",predicateDom);
    
      var checkbox = dom.find("input[type=checkbox]");
      var value = checkbox.val();
      var checked = checkbox.prop( "checked" );

      if(checked){
        // create
        $.ajax({
          url: "/update/property",
          method: "POST",
          dataType: "json",
          data: getParams(checkbox, dom, checked),
          success: function(data) {
            setDomIds(checkbox,dom,data);
          },
          error: makeErrorAlerter("Property konnte nicht erstellt werden")
        });
      }else{
        $.ajax({
          url: "/update/property",
          method: "DELETE",
          dataType: "json",
          data: getParams(checkbox, dom, null),
          success: function(data) { 
            setDomIds(checkbox,dom,data);
          },
          error: makeErrorAlerter("Property konnte nicht gelöscht werden")
        });
      
      }
    }
  
   
    function setAutoSaveTimerForDataSubmit(){
      autoSaveDictTimer.set(submitData, 700);
    }
    
    function setDomIds(inputDom, cellDom, data, deleted){
      var dataHolder = inputDom.closest(".js-data-holder");
      survey_form.displayStatus("ok",predicateDom);
      
      dataHolder.data("id",data.id);
      dataHolder.data("individual-id",data.subject_id);
      dataHolder.data("revision-id",data.revision_id);
      
      if(data.base_property_removed){
        dataHolderDom.data("individual-id",null);
      }
      if(deleted){
        dataHolder.data("id",null);
      }
    }
    
    function getParams(inputDom, cellDom, value){
      var dataHolder = inputDom.closest(".js-data-holder");
      data = {
        value: value,
				campaign_slug: campaignSlug,
				id: dataHolder.data("id"),
				predicate: dataHolder.data("predicate"),
        individual_id: dataHolder.data("individual-id"),
				revision_id: dataHolder.data("revision-id"),
				inline_predicate: predicate,
				inline_individual_id: individual_id,
				complex_prop_parent_id: cellDom.find(".complex-property").data("individual-id"),
				complex_prop_predicate: cellDom.find(".complex-property").data("predicate")
      }
      
      return data;
    }
    
  }
  
  
}
