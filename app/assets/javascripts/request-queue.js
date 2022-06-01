// Provides a queue for AJAX requests to be made sequentially. We need this because:
//
// Weak individual forms feature implicit creation and deletion of weak individuals. This requires
// that requests made by the properties are queued to avoid the following cases:
//
// - id is null, which indicates that currently no weak individual object exists in the database.
//   One JS property object fires a request without an ID, which leads to creating a DB weak
//   individual. But another JS property object fires another request before the first one
//   completed, thus also without an ID. So the server interprets this as another request to
//   *create* a weak individual, when in reality it was supposed to *update* the one created in
//   the first request.
// - id is set to a non-null value, and a corresponding DB weak individual exists. One JS
//   property fires a request which makes the weak individual have an empty label. This will
//   make the server delete it. But another JS property fires another request before the first
//   one completes. This request will still carry the weak individual id. Thus it will result
//   in a RecordNotFound exception.
//   (Implicitly creating a new weak individual would not be impossible, but it would be awkward
//   on the server side, as the logic required doesn't really fit into UpdateController,
//   PropertyManager nor IndividualManager.)
function RequestQueue() {
  var idle = true;

  // Need to queue closures that return objects instead of objects themselves because we want to
  // pick up the state at request time (not add time).
  // We also don't want to queue functions like "Property.updateDataProperty" or "Property.remove",
  // because then we wouldn't have access to their "complete" callbacks, thus we wouldn't know when
  // the requests finished.
  var requestClosures = [];

  this.add = add;

  function add(requestClosure) {
    requestClosures.push(requestClosure);
    if (idle) {
      next();
    } else {
      console.log("Waiting for another request to finish.")
    }
  }

  function next() {
    idle = false;
    var requestClosure = requestClosures.shift();
    if (requestClosure) {
      var requestObject = requestClosure();

      // If in the future a user of this class starts using the "complete" callback himself, we'd
      // need to use an array here. See http://api.jquery.com/jquery.ajax/#jQuery-ajax-settings
      requestObject.complete = next;

      $.ajax(requestObject);
    } else {
      idle = true;
    }
  }
}
