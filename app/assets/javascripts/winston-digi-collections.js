function WinstonDigiCollections(dom) {
  // I. Define variables and alias `this` as `self` if necessary
  

  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    dom.find('a[data-toggle="tab"]').on('shown.bs.tab', redrawCharts);
    
    dom.find("#subjects-modal").on("shown.bs.modal", redrawModalChart);
  }
  
  
  function redrawCharts(e){
    var tabId = e.target.getAttribute("href");
    var activeTab = dom.find(tabId);
    var highchartContainer = activeTab.find("div[id*=chart-]");
    highchartContainer.highcharts().reflow();
  }
  
  function redrawModalChart(e){
    var modal = dom.find("#subjects-modal");
    var highchartContainer = modal.find("div[id*=chart-]");
    highchartContainer.highcharts().reflow();
  }

}
