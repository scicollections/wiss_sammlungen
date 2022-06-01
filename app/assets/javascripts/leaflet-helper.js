function LeafletHelper(dom) {
  // I. Define variables and alias `this` as `self` if necessary
  var divname = dom.data("divname");
  var lat = dom.data("lat");
  var lon = dom.data("lon");
  var map_zoomlevel = dom.data("map_zoomlevel") || 6;



  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    var map = new L.Map(divname, {
      center: [lat, lon],
      zoom: map_zoomlevel
    });
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map);
    L.marker([lat, lon]).addTo(map)    
  }


}
