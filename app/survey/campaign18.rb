# this campaign class is for testing only
class Campaign18 < Campaign

  PAGELENGTH = 50
  
  set_targetclass "SciCollection"
  set_path_to_people :curator, :curator
  set_path_to_indis :curated_collection, :curated_collection
  set_begin Time.new(2018, 11, 20)
  set_end Time.new(2019, 12, 31)
  set_name "Umfrage 2019"

end
