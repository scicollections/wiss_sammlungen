module SearchHelper
  def internal_search_url(search, add_klass_filter: nil, remove_klass_filter: nil,
                          add_role_filter: nil, remove_role_filter: nil)
    klass_filter = search.klass_filter
    klass_filter += [add_klass_filter] unless add_klass_filter.nil?
    klass_filter -= [remove_klass_filter] unless remove_klass_filter.nil?

    role_filter = search.role_filter
    role_filter += [add_role_filter] unless add_role_filter.nil?
    role_filter -= [remove_role_filter] unless remove_role_filter.nil?

    url_for(controller: "search",
            filter: "#{klass_filter.map(&:to_s).join(",")};#{role_filter.map(&:to_s).join(",")}")
  end
end
