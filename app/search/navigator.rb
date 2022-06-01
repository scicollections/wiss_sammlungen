# Navigator
class Navigator
  attr_reader :query, :category, :filter, :anchor,
    :is_first, :is_last, :hit

  def initialize session
    params = session[:last_search] || {}
    @query = params[:query] || ""
    @category = params[:cat_filter] || [:collection]
    @filter = params[:facet_filter] || {}

    @hit = session[:result_num] || 0
    @is_first = @hit == 0
    @is_last = @hit + 1 == params[:hits]

    @anchor = "hit_#{(hit.to_i) > 1 ? (hit.to_i) -1 : -1}"
  end

  # Get route for a specific hit.
  #
  # @param num [Integer] The index of the hit.
  # @param scope [Symbol] The current user's role.
  #
  # @return [String] The route for the hit, if one exists for the given index.
  # @return [nil] Otherwise.
  def get_route num, scope = :public
    s = Searcher.new
    s.configure query: @query, from: num, size: 1, cat_filter: @category, facet_filter: @filter, scope: scope
    s.execute
    r = s.results.first

    r ? "/#{r[:klass]}/#{r[:id]}?hit=#{num}" : nil
  end
end
