function Maya(options) {
  // I. Define variables and alias `this` as `self` if necessary

  // It's actually a word! https://en.wiktionary.org/wiki/terminatable
  var terminatables = [];

  // II. Publish functions and provide getters and setters

  this.terminate = terminate;
  this.autoSaveInterval = function() { return options.autoSaveInterval || 500; }; // Milliseconds

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    initNProgress();
    newIfExists(UserMenu, $(".js-user-menu"));
    newIfExists(QuicksearchBox, $(".quicksearch-box"));
    newIfExists(Home, $('.container-user'));
    newIfExists(Individual, $(".glass-individual"),$('.js-individual-menu'));
    newIfExists(Internalsearch, $(".container-internal-search"));
    newIfExists(Discover, $(".container-discover"));
    newIfExists(Discover, $(".container-global-revisions"));
    newIfExists(SurveyDashboard, $(".container-survey-dashboard"));
    newIfExists(SurveyForm, $(".container-survey-form"));
    // Setting password when creating or altering an account
    newIfExists(PasswordSetter, $('.js-edit-user'));
    newIfExists(WinstonSubjects, $('.container-winston-subjects'));
    newIfExists(WinstonUniversity, $('.container-winston-university'));
    newIfExists(WinstonStates, $('.container-winston-states'));
    newIfExists(WinstonGlobal, $('.container-winston-global'));
    newIfExists(WinstonDigiCollections, $('.container-winston-digital-collections'));
    newIfExists(LeafletHelper, $('.leaflet-helper'));
  }

  function terminate() {
    // unbind only click events of class 'maya'. For now they're only in discover.js
	  // Unbinding all click events disturbs some bootstrap functionality like the dropdown handler
	  $(document).unbind("click.maya");

    $(window).unbind('.jscroll');
    $(document).off("keydown.ctrlb");
  }

  function newIfExists(constructFunc, dom, param1, param2, param3, param4, param5, param6, param7, param8){
    if (dom.length) {
      return new constructFunc(dom, param1, param2, param3, param4, param5, param6, param7, param8);
    }
  }

  function initNProgress() {
    /**
     * Initialise nprogress indicator for turbolinks.
     * https://github.com/rstacruz/nprogress
     */
    NProgress.configure({ trickleRate: 0.2, trickleSpeed: 500 });
    $(document).on('page:fetch turbolinks:request-start', function() {
      NProgress.start();
    });
    $(document).on('page:receive turbolinks:request-end', function() {
      NProgress.set(0.7);
    });
    $(document).on('page:change turbolinks:load', function() {
      NProgress.done();
    });
    $(document).on('page:restore turbolinks:request-end turbolinks:before-cache', function() {
      NProgress.remove();
    });
  }
}
