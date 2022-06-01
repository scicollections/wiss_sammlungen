module DiscoverHelper
  # @param search [Searcher]
  def search_url search
    url_for(controller: "discover", categories: search.cat_filter.map(&:to_s).join(","), q: search.q, lq: search.q, f: search.facet_filter)
  end

  # @param search [Searcher]
  def terms search
    search.facets[@key][:terms]
  end
end
