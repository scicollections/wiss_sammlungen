// dom - Can be just the weak individual form, or a property div.
// baseProperty - See comment for handleBaseProperty. Can be undefined.
function WeakIndividual(dom, modal, baseProperty) {
  // I. Define variables and alias `this` as `self` if necessary
  var self = this;

  // This can be undefined or null while the weak individual is not saved
  var id;

  // We need to keep track of our properties to be able to tell them all to forget their
  // revision ids.
  var properties = [];

  // II. Publish functions and provide getters and setters

  // It is important that anybody who uses this id gets it via this function, because it can
  // change during the lifetime of this object! This is because the weak individual can be
  // destroyed on the server when the label gets empty, and created again (with another id) when
  // the label is non-empty again. During that time, the weak individual form DOM on the client
  // side stays the same!
  this.id = function() { return id; };

  var complexProperty = dom.hasClass("complex-property");

  this.addProperty = addProperty;
  this.removeProperty = removeProperty;
  this.handleBaseProperty = handleBaseProperty;
  this.complexProperty = function() { return complexProperty; };
  this.predicate = function() { return dom.data("predicate"); };
  this.baseProperty = function() { return baseProperty; };

  // III. Call initialisation function(s)
  init();

  // IV. Define functions
  function init() {
    if (dom.hasClass("property")) {
      // The property's objekt id is this weak individual's id.
      id = dom.data("objekt-id");

      dom.addClass("expanded");
    }

    if (!complexProperty){
      modal.display(dom);
    }

    // Can use "find" here because there won't be another level of nesting property divs.
    dom.find(".property:not(.complex-property):not(.complex-property .property)").each(function() {
      properties.push(new Property($(this), modal, self));
    });
    if(complexProperty){
      dom.find(".property").each(function(){
        properties.push(new Property($(this), modal, self));
      });
    }
    dom.find(".property.complex-property:not(.complex-property .property)").each(function() {
      new WeakIndividual($(this), modal, self);
    });
    
    if(!complexProperty){
      dom.find("input:visible:first").focus();
    }

    // In case of one or more contained range(s), attach event handlers
    dom.find(".create-objekt-property").each(function() {
      new CreateObjektPropertyForm($(this), modal, self);
    });

    // NB In the future, create data property forms could also be needed for weak individuals.
    // This is not supported at the moment.
  }

  function addProperty(prop) {
    properties.push(prop);
  }

  function removeProperty(prop) {
    var index = properties.indexOf(prop);
    if (index > -1) { // This should always be the case, but just to be sure...
      properties.splice(index, 1);
    }
  }

  // Für ein Property von einem weak Individual (zB URL von WebResource) bezeichne ich
  // das Property, das das weak Individual mit dem strong Individual verbindet, als
  // "Base-Property". Die folgende Methode kümmert sich um den Fall, dass sich etwas an dem
  // Base-Property ändert als Resultat davon, dass man das weak-Individual-Property ändert.
  // Zum Beispiel muss das Base-Property (das in der linken Spalte angezeigt wird) ausgeblendet
  // werden, wenn durch das leeren der URL das weak Individual nun ein leeres Label hätte.
  //
  // Diese Methode greift auf folgende Felder von data zu:
  // - data.base_property_removed (in diesem Fall entfernen)
  // - data.base_property (in diesem Fall hinzufügen)
  // - data.subject_label (in diesem Fall aktualisieren)
  function handleBaseProperty(data) {
    // do not try to alter baseProeprty for complexProperty (nested weaks)
    if(!complexProperty){ 
      if (data.base_property_removed) {
        // Dies ist der Fall, dass das Subject gelöscht wurde.
        // In dem Fall den Eintrag in der linken Spalte entfernen.
        baseProperty.removeDom();
        modal.removeProperty(baseProperty, true);

        // Außerdem müssen wir alle Revision-Ids zurücksetzen, weil wir die alten Revisionen
        // nicht mehr verändern wollen.
        $.each(properties, function() {
          this.resetRevisionId();
        });

        // Goodbye base property, you have served us well!
        baseProperty = null;
        id = null;
      } else if (data.base_property) {
        // Dies ist der Fall, dass das Subject (ein weak Individual) und das verbindende
        // Property (das "Base-Property") neu erstellt wurden.
        // Daher die ID speichern und das Property in der linken Spalte anzeigen.
        var div = $(data.base_property);
        id = div.data("objekt-id");
        baseProperty = modal.insertPropertyDiv(div);
      } else if (data.subject_label) {
        // In diesem Fall bloß das Label in der linken Spalte aktualisieren
        baseProperty.setLabel(data.subject_label);
      }
    }else{
      if (data.base_property_removed) {
        
        dom.data("objektId","");
        id = undefined;
        properties.forEach(function(prop){
          prop.id = undefined;
        })
      }
    }
  }
}
