function WinstonSubjects(dom) {
  // I. Define variables and alias `this` as `self` if necessary


  // II. Publish functions and provide getters and setters

  // III. Call initialisation function(s)

  init();

  // IV. Define functions

  function init() {
    
    dom.find("#subject-collapse-btn").click(function(){
      dom.find("#subject-collapse-div").toggle();
    });
    
    dom.find("#subjectlist * input.search").bind("change keyup",filterList);
    

    var map = new WinstonMap($("#map"),"subjects",$("#subjectlist"));
    dom.find("#map-subject-select input").change(function(){
      var selected = [];
      dom.find("input[name=subject]:checked").each(function(){
        selected.push($(this).val());
      });
      map.updateMap("subjects",selected);
    });

  }
  
  function filterList(){
        var searchstr = $(this).val().trim();
        if(searchstr == ""){
          dom.find("#map-subject-select div.radio").show();
        }else{
          dom.find("#map-subject-select div.radio").hide();
          dom.find("#map-subject-select div.radio").each(function(){
            var subjstr = $(this).find("span.subjectLabel").html();
            var subjchk = $(this).find("input[name=subject]").is(":checked");
            if (subjchk || subjstr.toLowerCase().includes(searchstr.toLowerCase())){
              $(this).show();
            }
          });
        
        }
      }


}
