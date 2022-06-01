function Individual(dom, jsIndividualMenu) {
  // I. Define variables and alias `this` as `self` if necessary

  var self = this;
  var onOffSwitch = $("#myonoffswitch"); // This is a styled checkbox TODO Move into individual div
  var propertyGroups = {};
  var id = dom.data("id");
  var recordClass = dom.data("class");

  var tabs = dom.find(".individual-tab");
  var defaultTab = dom.find(".default-tab");
  var datasetinternalTab = dom.find(".datasetinternal-tab");
  var revisionsTab = dom.find(".revisions-tab");
  var relationsTab = dom.find(".relations-tab");
  var notesTab = dom.find(".notes-tab");
  var settingsTab = dom.find(".settings-tab");
  var manageronlyTab = dom.find(".manageronly.tab");
  var surveyTab = dom.find(".survey-tab");
  var surveyRevisionsTab = dom.find(".surveyrevisions-tab");

  var showDefaultTab = jsIndividualMenu.find(".show-default-tab");
  var showDatasetinternalTab = jsIndividualMenu.find(".show-datasetinternal-tab");
  var showRevisionsTab = jsIndividualMenu.find(".show-revisions-tab");
  var showRelationsTab = jsIndividualMenu.find(".show-relations-tab");
  var showNotesTab = jsIndividualMenu.find(".show-notes-tab");
  var showSettingsTab = jsIndividualMenu.find(".show-settings-tab");
  var showManageronlyTab = jsIndividualMenu.find(".show-manageronly-tab");
  var showSurveyTab = jsIndividualMenu.find(".show-survey-tab");
  var showSurveyRevisionsTab = jsIndividualMenu.find(".show-surveyrevisions-tab");

  var requestPublicityDiv = dom.find(".js-request-publicity");//.first().find('button.request-action');
  var requestPublicityButton = dom.find(".js-request-publicity button");
  var deleteButton = dom.find(".js-delete");
  
  var requestPrivilegesButton = dom.find(".js-request-edit-privileges button");

  var infiniteScrollObj;
  
  // true means, fetchRelations/fetchRevisions will reload the data.
  var refreshRelations = true;
  var refreshRevisions = true;
  var refreshSurvey    = true;
  var refreshSurveyRevisions = true;

  // II. Publish functions and provide getters and setters

  this.replacePropertyGroupDiv = replacePropertyGroupDiv;
  this.editMode = editMode;
  this.setVisibility = setVisibility;
  this.id = function() { return id; };
  this.recordClass = function() {return recordClass; };
  this.reloadInviteStatus = reloadInviteStatus;
  this.replacePersonRecord = replacePersonRecord; //for #survey tab

  // III. Call initialisation function(s)

  init();
  initTabs();

  // IV. Define functions

  function init() {
    if (editMode()) {
      // Browsers will cache the state of checkboxes across reloads if the user has changed that
      // state. We don't want this, instead we want the presence of the "edit-mode" class to be
      // decisive. (The presence of that class, in turn, depends on the presence of the "mode=edit"
      // parameter in the URL.)
      onOffSwitch.prop("checked", true);
      enterEditMode();
    } else {
      onOffSwitch.prop("checked", false);
      leaveEditMode();
    }

    onOffSwitch.click(function() {
      if (onOffSwitch.prop("checked") == true) {
        enterEditMode();
      } else {
        leaveEditMode();
      }
    });

    // experimental hotkey <ctrl>+<b> support for edit-mode
    $(document).on("keydown.ctrlb", function(e) {
      // ctrl+b pressed?
      if (e.which == 66 && e.ctrlKey) {
        e.preventDefault();
        onOffSwitch.click();
      }
    });

    dom.find(".property-group").each(function() {
      var predicate = $(this).data("predicate");
      pg = new PropertyGroup($(this), self, predicate);
      propertyGroups[predicate] = pg;
    });
    dom.find(".object-imagery").each(function(){
      new ObjectOptions($(this));
      var image = $(this).find('.obj-image img');
      if($(image).height() < $(image).width()) {
            $(image).width(900);
      }
      else {
            $(image).height(850);
      }
    });

    dom.find(".invite-user").click(inviteUserButtonClickHandler);
    dom.find(".js-show-recent-invite").click(showRecentInviteClickHandler);
    
    dom.find(".deref-placeholder").each(function(){
      new DerefPlaceholder($(this));
    });

    // handlers for member-request-*-buttons
    requestPublicityButton.click(clickRequestActionHandler);
    requestPrivilegesButton.click(clickRequestActionHandler);
    
    // hides/shows an individuals permalink
    $('span.individual-permalink-button').click(function() {
        $('.individual-permalink').toggle('500', function() {
            // Animation complete
        });
    });
    
    new SurveyForm(notesTab,id, recordClass);
    
    if(surveyTab){
      new PersonRecord(dom.find(".person-record"),surveyTab.data("campaignslug"),self);
    }
    
    // highlight changes from survey if user is manager and flagged
    if($(".highlight-survey-changes").length){
      $.get("/survey/changed_predicates?indi_id="+id, function(data){
        for (var i in data["predicates"]){
          var predicatestr = data["predicates"][i];
          dom.find(".property-group[data-predicate='"+predicatestr+"']").addClass("survey-highlighter");
        }
      });
    }
    
  }

  //
  // Edit-Mode switching
  //

  function editMode() {
    return dom.hasClass("edit-mode");
  }

  function enterEditMode() {
    dom.addClass("edit-mode");

    $.each(propertyGroups, function(predicate, group) {
      group.enableTooltip();
    });

    // TODO Where are these? Can we use `dom.find("...")`?
    // hide infosystem-tooltip-anchors/questionmarks
    $(".js-tooltip").hide();

    requestPublicityDiv.show();
    deleteButton.show();
  }

  function leaveEditMode() {
    dom.removeClass("edit-mode");

    $.each(propertyGroups, function(predicate, group) {
      group.disableTooltip();
    });

    // show infosystem-tooltip-anchors/questionmarks
    $(".js-tooltip").show();

    requestPublicityDiv.hide();
    deleteButton.hide();
  }

  // Updatet die Seite im Hintergrund nachdem in einem Edit-Modal Änderungen
  // vorgenommen wurden.
  //
  // html - The new property group html
  function replacePropertyGroupDiv(div) {
    var predicate = div.data("predicate");
    var neu = new PropertyGroup(div, self, predicate);

    var old = propertyGroups[neu.predicate()];

    old.replaceWith(div);
    propertyGroups[neu.predicate()] = neu;

    refreshRelations = true;
    refreshRevisions = true;

    if ($(div).find("table").length){
      $(div).find("table").bootstrapTable();
    }
    
    if ($(div).find(".leaflet-helper").length){
      new LeafletHelper($(div).find(".leaflet-helper").first());
    }
    $(div).find(".deref-placeholder").each(function(){
      new DerefPlaceholder($(this));
    });
    
  }

  function setVisibility(visibility) {
    // This will often get a null argument, be nice and deal with it.
    if (visibility) {
      $(".glass-individual .user-rights").find(".visibility").hide();
      $(".glass-individual .user-rights").find(".visibility-" + visibility).show();
    }
  }

  function fetchRevisions() {
    var resultsDiv = revisionsTab.find(".searchresults");
    if (refreshRevisions){
      resultsDiv.empty();
      if (NProgress != undefined) { NProgress.start(); }
      $.get("/revisions", { individual_id: id }, function(html) {
        resultsDiv = resultsDiv.replaceWith(html);
        resultsDiv = $(resultsDiv.selector);
        if (NProgress != undefined) { NProgress.done(); }
        refreshRevisions = false;
        infiniteScrollObj = new InfiniteScroll(resultsDiv);
      });
    }
  }

  function fetchRelations() {
    // check if something has changed
    if (refreshRelations) {
      // display waiting animation
      relationsTab.empty();

      if (NProgress != undefined) { NProgress.start(); }
      $.get("/relations", { id: id }, function(html) {
        if (NProgress != undefined) { NProgress.done(); }
        relationsTab.html(html);
        refreshRelations = false;
      });
    }
  }

  function initTabs() {

    var dict = {
      "":{
        "key": "",
        "tab": defaultTab,
        "show": showDefaultTab
      },
      "#datasetinternal":{
        "key": "#datasetinternal",
        "tab": datasetinternalTab,
        "show": showDatasetinternalTab
      },
      "#revisions":{
        "key": "#revisions",
        "tab": revisionsTab,
        "show": showRevisionsTab,
        "function": fetchRevisions
      },
      "#relations":{
        "key": "#relations",
        "tab": relationsTab,
        "show": showRelationsTab,
        "function": fetchRelations
      },
      "#notes":{
        "key": "#notes",
        "tab": notesTab,
        "show": showNotesTab
      },
      "#settings":{
        "key": "#settings",
        "tab": settingsTab,
        "show": showSettingsTab
      },
      "#survey":{
        "key": "#survey",
        "tab": surveyTab,
        "show": showSurveyTab
      },
      "#surveyrevisions":{
        "key": "#surveyrevisions",
        "tab": surveyRevisionsTab,
        "show": showSurveyRevisionsTab,
        "function": fetchSurveyRevisions
      },
      "#manageronly":{
        "key": "#manageronly",
        "tab": manageronlyTab,
        "show": showManageronlyTab
      }
    }

    // React to Hash, which can change the default tab
    // nur wenn andere Tabs existieren (= User hat View-Rechte)
    if (location.hash in dict){
      var currentTab = dict[location.hash].tab;
      var currentShow = dict[location.hash].show;

      if(currentTab[0]){
        tabs.hide();
        currentTab.show();
        if ("function" in dict[location.hash]){
          dict[location.hash].function.call();
        }
        highlightMenuTab(currentShow);
      }
    }

    jsIndividualMenu.find("a").click(function(event){
      var currentShow = $(this);
      var currentHash = currentShow.data("hash");
      if(currentHash in dict){
        window.location.hash = dict[currentHash].key;
        tabs.hide();
        dict[currentHash].tab.show();
        if("function" in dict[currentHash]){
          dict[currentHash].function.call();
        }
        event.preventDefault();
      }
      highlightMenuTab(currentShow);
    });

  }

  function highlightMenuTab(menuButton){
    jsIndividualMenu.find("a").removeClass("imenu-tab-active");
    menuButton.addClass("imenu-tab-active");
  }

  function inviteUserButtonClickHandler(event) {
    event.preventDefault();
    var btn = $(this);


    $.get("/users/new", { individual_id: id}, function(html) {
      modal = $(html);
      $("body").append(modal);
      modal.modal("show");
      // attach event handler for invite-modal submit button
      modal.find("form").submit(function(event) {
        event.preventDefault();
        // disable submit button
        modal.find("form").find("[type='submit']").attr("disabled", true);

        $.post("/users/send_invite", modal.find("form").serialize())
          .done(function() {
            // hide modal and button for instant ui feedback
            modal.modal("hide");
            btn.hide();
            // additionally reload page to refresh invite status view
            reloadInviteStatus();
            // remove delete button
            $(".js-individual-menu [data-method='delete']").remove();
          })
          .fail(function(error) {
            // display error massage
            // TODO user-friendly error messages (e.g. for validation issues)
            alert(error.responseText);
          });
      });
    }).fail(makeErrorAlerter("Konnte Invite-Modal nicht anzeigen"));
  }

  // reload the status of invite-allowance, since it depends on the presence
  // of an email-address in the individual
  function reloadInviteStatus() {
    // retrieve individual id of Person from URL /Person/:id#xyz?blabla
    var person_id = location.pathname.split("/").slice(-1).pop()
    $.get("/users/invite_status", { person_id: person_id }, function(html) {
      dom.find(".js-invite-status-info").html(html);
      dom.find(".js-invite-status-info .invite-user").click(inviteUserButtonClickHandler);
      dom.find(".js-invite-status-info .js-show-recent-invite").click(showRecentInviteClickHandler);
    });
  }

  function showRecentInviteClickHandler(event) {
    event.preventDefault();
    var btn = $(this);


    $.get("/users/show_recent_invite", { individual_id: id }, function(html) {
      modal = $(html);
      $("body").append(modal);
      modal.modal("show");
    }).fail(makeErrorAlerter("Konnte Letze-Einladungs-Modal nicht anzeigen"));
  }

  // triggers a request to /userst/request_action
  // depends on a parent element that has data-request-action set e.g. <button>
  // contained by <div [...] data-request-action="publicity">
  // the value for data-request-action ("publicity" or "edit_privileges")
  // must resemble the suffix a property-name from Person without "request_"
  // (like "request_publicity" or "request_edit_privileges")
  function clickRequestActionHandler() {
    disableLink($(this));
    var request_action = $(this).parent("[data-request-action]").data("request-action");
    // disable button for instant ui-feedback
    $(this).prop("disabled", true);
    var jqxhr = $.post("/users/request_action", { individual_id: self.id(), request_action: request_action}, function() {
      location.reload();
    }).always(function(){
      enableLink($(this));
    });
  }
  
  function fetchSurveyRevisions() {
    var resultsDiv = surveyRevisionsTab.find(".searchresults");
    var campaignSlug = surveyRevisionsTab.data("campaignslug");
    if (refreshSurveyRevisions){
      resultsDiv.empty();
      if (NProgress != undefined) { NProgress.start(); }
      $.get("/revisions?individual_id="+id+"&afk=campaign&afv="+campaignSlug, function(html) {
        resultsDiv.replaceWith(html);
        resultsDiv = $(resultsDiv.selector);
        if (NProgress != undefined) { NProgress.done(); }
        refreshSurvey = false;
        infiniteScrollObj = new InfiniteScroll(resultsDiv);
      });
    }
  }
  
  // necessary for #survey tab. Copy of method in SurveyDashboard
  function replacePersonRecord(personId, html){
    var newDiv = $(html);
    new PersonRecord(newDiv,surveyRevisionsTab.data("campaignslug"),self);
    var oldDiv = dom.find(".person-record[data-person_id="+personId+"]");
    oldDiv.replaceWith(newDiv);
    dom.find(".person-record[data-person_id="+personId+"]").addClass("recently-updated");
      
  }
}
