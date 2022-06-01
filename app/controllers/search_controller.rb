# Interne Suche
class SearchController < ApplicationController
  # Users must authenticate
  before_action :authenticate_user!

  # @action GET
  # @url /search
  # @url /search/:filter
  def index
    @search = Searcher.new

    # highlight search tab in user menu
    @user_menu_tab_search_active = true

    conf = {
      query: params[:q],
      mode: :quicksearch,
      scope: current_user.role
    }

    if params[:filter]
      klass_filter = params[:filter].split(";").first
      role_filter = params[:filter].split(";").second

      conf[:klass_filter] = klass_filter.split(",") if klass_filter
      conf[:role_filter] = role_filter.split(",") if role_filter
    end

    @search.configure conf

    session[:quicksearch] = "/search/#{params[:klass]};#{params[:role]}?q=#{params[:q]}"

    if request.xhr?
      @search.configure from: params[:p] if params[:p]
      @search.execute
      if params.has_key? :extended
        render partial: "extended_results"
      else
        render partial: "results"
      end
    else
      page_title "Interne Suche: #{@search.q}"
      @search.configure from: 0
      @search.configure size: params[:p].to_i + @search.size if params[:p]
      @search.execute
      if @search.fallback
        logger.error "Internal Search fails. ElasticSearch is not available"
        # it's neccessary to store the return value in 'mailer'. If not, no emails are sent. 
        # This could be the result of async mail delivery in another thread
        mailer = ErrorMailer.report_search_error request.env, @search.fb_exception, @search
        logger.info "ErrorMailer Object is " + mailer.to_s
        #renders "_noresults.html.slim" in _extended_results.html.slim if @search.fallback == true
      end
    end
  end
end
