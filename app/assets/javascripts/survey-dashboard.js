function SurveyDashboard(dom) {
  // I. Define variables and alias `this` as `self` if necessary

  var self = this;
  var campaign_slug = dom.data('campaign_slug');
  var group = getParameterByName("group");
  var filter = getParameterByName("filter");
  
  // II. Publish functions and provide getters and setters
  
  this.replacePersonRecord = replacePersonRecord;

  // III. Call initialisation function(s)

  init();


  // IV. Define functions

  function init() {
    dom.find('.person-record').each(function(){
      new PersonRecord($(this),campaign_slug,self);
    });
    dom.find("input.checkbox-invite:checked").prop("checked",null);
    dom.find("input.checkbox-remind:checked").prop("checked",null);
    
    dom.find(".dashboard-list").jscroll({
      nextSelector: 'a.nextselector:last',
      callback: function(){
        var addedContent = $(this);
        addedContent.find(".person-record").each(function(){
          new PersonRecord($(this),campaign_slug,self);
        });
      }
    });
    
    dom.find('button.multiaction-button').click(function(){
      var button = $(this);
      disableLink(button);
      var person_ids = [];
      var action = $(this).data("action");
      dom.find('input.checkbox-'+action+':checked').each(function(){
        var person_id = parseInt($(this).attr('id').split("_")[2]);
        person_ids.push(person_id);
      });
      
      $.ajax({
        url: "/survey/multiple_invite",
        method: "post",
        dataType: "json",
        data: {
          person_ids: person_ids,
          event_action: action,
          campaign_slug: campaign_slug
        }
      }).done(function(data){  
        for (var person_id_string in data["html_partials"]){
          var person_id = parseInt(person_id_string);
          var html =  data["html_partials"][person_id_string];       
          replacePersonRecord(person_id,html);
        }
        var error_message = "";
        for (var index in data["error_list"]){
          var person = data["error_list"][index];
          error_message += person["name"] + " - " + person["message"] +"\n";
        }
        if(error_message != ""){
          alert(error_message);
        }
        dom.find("input.checkbox-"+action+":checked").prop("checked",null);
      }).fail(function(jqXHR, textStatus){
        if (jqXHR.responseJSON['message']){
          alert(jqXHR.responseJSON['message']);
        } else {
          alert("Beim Sammel-Benachrichtigen ist ein Fehler aufgetreten. Ist mit dieser Person eine Email-Adresse verknüpft?");
        }
      }).always(function(){
        enableLink(button);
      });
    });

  }
  
  function replacePersonRecord(personId, html){
    var newDiv = $(html);
    new PersonRecord(newDiv,campaign_slug,self);
    var oldDiv = dom.find(".person-record[data-person_id="+personId+"]");
    oldDiv.replaceWith(newDiv);
    dom.find(".person-record[data-person_id="+personId+"]").addClass("recently-updated");
      
  }
  
  function getParameterByName(name, url) {
      if (!url) url = window.location.href;
      name = name.replace(/[\[\]]/g, "\\$&");
      var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
          results = regex.exec(url);
      if (!results) return null;
      if (!results[2]) return '';
      return decodeURIComponent(results[2].replace(/\+/g, " "));
  }
  
}
