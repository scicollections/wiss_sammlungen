function DictTimer() {

  this.set = set;
  this.clear = clear;
  
  var dict = {};

  function set(fn, interval, key) {
    clear(key);
    var id = window.setTimeout(fn, interval);
    dict[key]=id;
  }

  function clear(key) {
    var id = dict[key];
    if (id) {
      window.clearTimeout(id);
      dict[key] = null;
    }
  }
}
