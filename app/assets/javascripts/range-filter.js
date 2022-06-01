// range - some div that includes .js-range-filter-target child divs
// input - an input element
function RangeFilter(range, input) {
  // III.

  init();

  // IV.

  function init() {
    input.keyup(applyFilter);
    input.focus();
  }

  function applyFilter() {
    var filterStr = input.val().trim();
    var lowerFilterStr = filterStr.toLowerCase();
    var tokens = lowerFilterStr.split(" ");
    var toShow = [];
    var toHide = [];
    var directHits = [];
    var notDirectHits = [];
    range.find(".js-range-filter-target").each(function(index, btn) {
      var label = $(btn).text().toLowerCase();
      var labelAndRelated = $(btn).data("filter-text").toLowerCase();
      var allTokensMatchLabel = true;
      var allTokensMatchLabelAndRelated = true;
      $.each(tokens, function(i, token) {
        if (label.indexOf(token) == -1) {
          allTokensMatchLabel = false;
        }
        if (labelAndRelated.indexOf(token) == -1) {
          allTokensMatchLabelAndRelated = false;
        }
      });
      // Zeige einen Eintrag nur dann, wenn alle Tokens des Filter-Strings darin vorkommen.
      if (allTokensMatchLabelAndRelated) {
        toShow.push(btn);
      } else {
        toHide.push(btn);
      }
      // Hebe ihn hervor, wenn alle Tokens im Text vorkommen (aber nur, wenn wir in
      // Hierachie sind).
      if (btn.className.indexOf("level") > -1 && allTokensMatchLabel && filterStr.trim() != "") {
        directHits.push(btn);
      } else {
        notDirectHits.push(btn);
      }
    });
    $(toShow).show();
    $(toHide).hide();
    $(notDirectHits).removeClass("direct-hit");
    $(directHits).addClass("direct-hit");
  }
}
