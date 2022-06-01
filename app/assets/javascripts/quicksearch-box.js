function QuicksearchBox(dom) {
  // I. Define variables and alias `this` as `self` if necessary

  var input = dom.find("#quicksearch");

  // TODO Check whether I can remove commented code
  var options = {
    // minLength: 3, # defaults to 1, refers only to rendering, search request threshold is set independently
    highlight: true,
    hint: true,
    minLength: 3
    /* override default class names, src: https://github.com/twitter/typeahead.js/blob/master/doc/jquery_typeahead.md#class-names
    classNames: {
      input: 'quicksearch-input'
    }
    */
  };

  // https://github.com/twitter/typeahead.js/blob/master/doc/jquery_typeahead.md#datasets
  var dataset = {
    name: 'quicksearch',
    // displayKey: 'label',
    display: '{{label}}, {{id}}',
    source: source,
    /* due to a bug in typeahead.js it is (for now) necessary to set limit to
      Infinity and limit the amount of displayed results on server-side,
      see: https://github.com/twitter/typeahead.js/issues/1232 */
    limit: Infinity,
    templates: {
      empty: "",
      suggestion: function(suggestion) {
        return '<div><a href="'+suggestion.link+'">'+suggestion.label+'</a></div>\n';
      },
      footer: fullTextSearch,
      empty: fullTextSearch
    }
  };

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    input.typeahead(options, dataset);

    // on focus of an item show the label in the input
    input.on('typeahead:cursorchange', function(event, suggestion) {
      if (suggestion != undefined) {
        input.val(suggestion.label);
      }
    });

    // on select of an item open the respective individual view
    input.on('typeahead:select', function(event, suggestion) {
      Turbolinks.visit(suggestion.link);
    });
    
    input.on('keypress', function(event){
      if (event.key == "Enter"){
        var searchterm = input.val();
        Turbolinks.visit("/discover/?q="+searchterm);
      }
    })
  }

  function source(query, syncResults, asyncResults) {
    var url = "/quicksearch?q=" + query;
    $.getJSON(url, function(data) {
      asyncResults(data);
    });
  }

  function fullTextSearch(ar) {
    return "<div class='tt-footer'><a href='/discover/?q=" + ar.query + "'>Nach <b>" + ar.query + "</b> im Volltext suchen</a></div>"
  }
}
