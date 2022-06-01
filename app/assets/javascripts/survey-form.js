function SurveyForm(dom, individual_id,recordClass) {
  // I. Define variables and alias `this` as `self` if necessary

  var self = this;
  var individual_id = individual_id || dom.data("id");
  var recordClass = recordClass || dom.data("class");
  var campaignSlug = dom.data("campaign");


  // II. Publish functions and provide getters and setters
  this.id = function() { return id; };
  this.recordClass = function() {return recordClass; };
  this.campaignSlug = function() {return campaignSlug; };
  this.individualId = function() {return individual_id; };
  this.displayStatus = displayStatus;

  // III. Call initialisation function(s)

  init();
  

  // IV. Define functions

  function init() {
    if (campaignSlug == ""){
      campaignSlug = undefined;
    }
    
    dom.find(".inline-predicate").not(".weak-table").each(function(){
      new SurveyFormPredicate($(this), self);
    });
    
    dom.find(".inline-predicate.weak-table").each(function(){
      var predicateDom = $(this);
      $(this).find("tr").each(function(){
        new SurveyFormTableRow($(this),self,predicateDom );
      });
      var predicate = $(this).data("predicate");
      
      $(this).find("button.add-property-btn").click(function(){
        displayStatus("hide",predicateDom);
        $.ajax({
          url: "/update/table_row",
          method: "POST",
          dataType: "json",
          data: {
            individual_id: individual_id,
            predicate: predicate
          },
          success: function(data) {
            var newRow = $(data["inline_html"]);
            predicateDom.find("tbody").append(newRow);
            new SurveyFormTableRow(newRow, self,predicateDom);
            displayStatus("ok",predicateDom);
          },
          error: makeErrorAlerter("Zeile konnte nicht erstellt werden")
        });
      });
    });
    
    $('body').bind("click",closeOpenBox);
    
    if(campaignSlug == undefined){
      dom.find("a.btn.btn-success").text("Speichern und schließen")
      dom.find("a.btn.btn-success").click(function(e){
        e.preventDefault();
        window.close();
      })
    }
    
  }
  
  function displayStatus(status,referenceDom){
    referenceDom.find("span.glyphicon.form-control-feedback").hide();
    if (status == "ok"){
      referenceDom.find("span.glyphicon-ok").show();
    }else if(status == "warning"){
      referenceDom.find("span.glyphicon-warning").show();
    }
  }
  
  function closeOpenBox(e){
    var targetObj = dom.find(e.target);
    var ancestorObj = dom.find(".select-form.collapsible.collapse.in");
    var clickedInFacet = ancestorObj.has(targetObj).length;

    if (!clickedInFacet){
      ancestorObj.collapse('hide');
    }
    
  }
  
}
