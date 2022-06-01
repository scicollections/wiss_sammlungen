function Internalsearch(dom) {
  // I. Define variables and alias `this` as `self` if necessary
  var searchresultsDiv = dom.find(".searchresults");
  var search_navDiv = dom.find(".search_nav");
  var searchformDiv = dom.find("#searchform");
  var searchinputForm = dom.find("#searchinput");
  var extendedresultsDiv = dom.find("#extended-results");
  var infiniteScrollObject;

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    searchinputForm.on('input', instantSearch);
    infiniteScrollObject = new InfiniteScroll(dom.find(".searchresults"));
  }

  // Implements the Search-As-You-Type functionality for the internal search
  function instantSearch() {
    var url = searchformDiv.attr("action");
    var data = {q: searchinputForm.val(), extended: true };
    $.get(url, data).done(function(data){
      extendedresultsDiv.html(data);
      
      // we have to reload searchresultsObj because the corresponding Div
      // has been replaced in the previos line
      infiniteScrollObject = new InfiniteScroll(dom.find("#searchresults"), {callback: highlight});
      highlight();

    });
  }
  
  function highlight(){
    var searchterm = searchinputForm.val();
    if (searchterm.replace(/^\s+|\s+$/g, '') !== ""){
      dom.find("#searchresults").highlight(searchterm);
    }
  }


}
