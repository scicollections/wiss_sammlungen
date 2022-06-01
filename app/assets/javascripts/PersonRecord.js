function PersonRecord(dom,campaignSlug,surveyDashboard) {
  // I. Define variables and alias `this` as `self` if necessary

  var self = this;
  var personId = dom.data('person_id');
  
  // initially not present
  var userId = dom.data("user_id");
  
  var individual_id = dom.data("individual_id");
  
  // II. Publish functions and provide getters and setters
  


  // III. Call initialisation function(s)

  init();


  // IV. Define functions

  function init() {
    
    dom.find('button.survey-invite').click(openInviteModalHandler);
    dom.find('button.survey-remind').click(openInviteModalHandler);
    
    dom.find('button.survey-complete').click(function(){
      sendAction("complete", campaignSlug, personId);
    });
    dom.find('button.show-interactions-btn').click(function(){
      showInteractions(campaignSlug,personId);
    });
    
    dom.find(".survey-note").click(function(event){
      // dummy individual as we don't want to replace anything and have no property group
      var individual = {};
      individual.id = function(){
        return personId;
      };
      individual.recordClass = function(){
        return "Person";
      };
      individual.replacePropertyGroupDiv = function(){};
      individual.setVisibility = function(){};
      
      $.get("/edit", { predicate: "has_memo", individual_id: personId }, function(html) {
        new EditModal($(html), individual, "has_memo");
      }).fail(function(){
        makeErrorAlerter("Modal konnte nicht geladen werden");
      }).always(function(){
      });

      // Ist nötig, da in dem Div möglicherweise ein Link steht.
      event.preventDefault();
    });
    
  }

  
  function sendAction(action,campaign,personId){
    $.ajax({
      url: "/survey/event",
      method: "post",
      dataType: "json",
      data: {
        person: personId,
        event_action: action,
        campaign: campaign,
        individual: individual_id
      }
    }).done(function(data){  
      surveyDashboard.replacePersonRecord(personId,data['html']);
    }).error(function(data){
      
    }).fail(function(jqXHR, textStatus){
      if(jqXHR.responseJSON){
        alert(jqXHR.responseJSON["message"]);
      }else{
        alert("Beim Einladen ist ein Fehler aufgetreten. Ist mit dieser Person eine Email-Adresse verknüpft?");
      }
      //console.log(jqXHR);
    }); 
  }
  
  function openInviteModalHandler(event){
    event.preventDefault();
    var btn = $(this);
    var action= btn.data("action");
    
    postData = {};
    if(action == "invite-override"){
      if (confirm("Sicher, dass eine erneute Einladung gesendet werden soll?")){
        postData['override-daily-limit'] = true;
        action = "invite";
      }else{
        return;
      }
    }
    
    $.get("/survey/inviteform", { individual_id: personId, event_action: action}, function(html) {
      modal = $(html);
      $("body").append(modal);
      modal.modal("show");
      // attach event handler for invite-modal submit button
      modal.find("form").submit(function(event) {
        event.preventDefault();
        // disable submit button
        modal.find("form").find("[type='submit']").attr("disabled", true);
         
        var formArray = modal.find("form").serializeArray();
        var formObj = {};
        formArray.forEach(function(obj){
          // We don’t escape the key '__proto__'
          // which can cause problems on older engines
          formObj[obj['name']] = obj['value'];
        });
        postData['form'] = formObj;
        postData['person'] = personId;
        postData['event_action'] = action;
        postData['campaign'] = campaignSlug;
        postData['individual'] = individual_id;
        $.post("/survey/event", postData)
          .done(function(data) {
            // hide modal and button for instant ui feedback
            modal.modal("hide");
            btn.hide();
            // additionally reload page to refresh invite status view
            surveyDashboard.replacePersonRecord(personId,data['html']);
            // remove delete button
            $(".js-individual-menu [data-method='delete']").remove();
          }).error(function(data){
            alert(data.responseJSON["message"]);
          }).fail(function(error) {
            // display error massage
            // TODO user-friendly error messages (e.g. for validation issues)
            console.log(error.responseJSON);
          });
      });
    }).fail(makeErrorAlerter("Konnte Invite-Modal nicht anzeigen"));
  }
  
  
  
}
