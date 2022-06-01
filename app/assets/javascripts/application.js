// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery.turbolinks
//= require jquery_ujs
//= require twitter/bootstrap
//= require twitter/typeahead
//= require turbolinks
//
//= require bootstrap-datepicker.min
//= require bootstrap-datepicker.x.de.min
//= require bootstrap-table/bootstrap-table
//= require jquery.complexify.min
//= require jquery.jscroll.min
//= require jquery.qtip.min
//= require jquery.highlight
//= require chartkick
//= require leaflet
//= require kartograph
//= require list.min
//= require nprogress
//= require raphael
//= require spin.min
//
//= require_tree .

var maya;

document.addEventListener("turbolinks:load", function() {
  if (maya) {
    // This will do things like unbind scroll events and stop listening to CTRL-B
    maya.terminate();
  }

  maya = new Maya({
    autoSaveInterval: 2000,
  });
});
