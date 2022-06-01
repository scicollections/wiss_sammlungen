function Discover(dom) {
  // I. Define variables and alias `this` as `self` if necessary

  var infiniteScrollObj;

  var filterListOptions = {
    valueNames: ["criteria-item"],
    listClass: "filterbox-range",
    searchClass: "criteria-filter",
    sortClass: "criteria-sort",
    page: 2000
  };

  var filterList;

  var searchresultsDiv = dom.find(".searchresults");
  var search_navDiv = dom.find(".search_nav");

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    dom.find(".criteria").bind("click.maya",openFacetBox);
    dom.find(".facet").bind("click.maya",loadFacetFilter);

    // Close a facet box when clicking somewhere else
    $('body').bind("click.maya",closeOpenBox);
    infiniteScrollObj = new InfiniteScroll(dom.find(".searchresults"), {callback: highlight});
    dom.find('.info-helper-discover-result-types').bind("click.maya", function(){
      $('.js-info-text-discover-result-types').slideToggle();
      $( "a.info-helper-discover-result-types" ).toggleClass("info-helper-active");
    });
    highlight();
    
  }
  
  function highlight(){
    var searchterm = dom.find(".app-searchbox input[name=q]").val();
    if (searchterm && searchterm.replace(/^\s+|\s+$/g, '') !== ""){
      dom.find('#searchresults').highlight(searchterm);
    }
  }

  function checkForActiveFacet() {
    // search for elements with criteria and active class
    // if at least one is found, return the facet name, else return 0
    var activeFacet = dom.find(".criteria.active");
    if (activeFacet.length != 0) {
      var pos = activeFacet.attr("id").indexOf("_")+1;
      var facetName = activeFacet.attr("id").substring(pos);
      return facetName;
    } else {
      return 0;
    };
  }

  function loadFacetFilter() {
    facet = this.dataset.key;
    url = this.dataset.url;
    if(url){
      $.get(url,function(data){
        dom.find("#moreCriteria_"+facet).html(data);
        initializeFilterList(facet);
      });
    }else{
      setTimeout(function() { initializeFilterList(facet); }, 5);
    }
  }

  function initializeFilterList(facet) {
    filterList = new List("moreCriteria_"+facet, filterListOptions);
    toggleFacetBox(facet);

    // info texts
    dom.find(".info-helper-discover-facets-"+facet).click(function(){
      dom.find('.js-info-text-discover-facets-'+facet).slideToggle();
      dom.find( "a.info-helper-discover-facets"+facet ).toggleClass("info-helper-active");
    });
  }

  function toggleFacetBox(facet) {
    // is another facet open? close that first
    var other = checkForActiveFacet()
    if (other != 0 && other != facet) {
      toggleFacetBoxUnchecked(other);
    }

    // now toggle the requested facet
    toggleFacetBoxUnchecked(facet);
  }

  function toggleFacetBoxUnchecked(facet) {
    // get elements for facet
    var toggler = dom.find("#toggleCriteria_" + facet);
    var search = dom.find("#filterCriteria_" + facet);

    // toggle visibility of facet box
    dom.find("#moreCriteria_"+facet).toggle();

    // toggle active-class of facet toggler
    if (toggler.hasClass("active")) {
      toggler.removeClass("active");
    } else {
      toggler.addClass("active");
      search.focus();
    }
  }

  function openFacetBox(e) {
    //check if any facet-box is opened
    var facetName = checkForActiveFacet();
    if (facetName != 0) {
      // if the click was outside of the toggler or box itself, close the box
      if (e.target.id != "moreCriteria_"+facetName
          && !dom.find("#moreCriteria_"+facetName).find(e.target).length
          && e.target.id != "toggleCriteria_"+facetName
          && !dom.find("#toggleCriteria_"+facetName).find(e.target).length) {
        toggleFacetBoxUnchecked(facetName);
      };
    };
  }

  function closeOpenBox(e){
    var facetName = checkForActiveFacet();
    var targetObj = dom.find(e.target);
    var ancestorObj = dom.find("#moreCriteria_"+facetName);
    var clickedInFacet = ancestorObj.has(targetObj).length;

    if (facetName != 0 && !clickedInFacet){
      toggleFacetBoxUnchecked(facetName);
    }
    
  }
}
