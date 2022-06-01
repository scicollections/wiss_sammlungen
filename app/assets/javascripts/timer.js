function Timer() {
  var id;

  this.set = set;
  this.clear = clear;

  function set(fn, interval) {
    clear();
    id = window.setTimeout(fn, interval);
  }

  function clear() {
    if (id != null) {
      window.clearTimeout(id);
      id = null;
    }
  }
}
