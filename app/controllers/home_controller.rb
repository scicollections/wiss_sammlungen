# Home (Startseite)
class HomeController < ApplicationController
  # @action GET
  # @url /
  def index
    # Spreadsheets
    if home_params['spreadsheet'].to_s.length >  0
      flash.now[:notice] = (Spreadsheet.compile params['spreadsheet'].to_s).html_safe
    end
    # Zufaellige Sammlung
    @search = Searcher.new
    @random_individuals = Individual
      .where(type: ["SciCollection","CollectionActivity","Organisation","Subject","ObjectGenre","DigitalCollection"])
      .where(visible_for_cache: [nil, :public])
      .order("RAND()")
      .first(1)
    render "index", layout: "home"
  end

  def info
    page_title "Über uns"
    render "info", layout: "application"
  end

  def credits
    page_title "Mitwirkende"
    render "credits", layout: "application"
  end
  
  def licenses
    page_title "Lizenzen"
    render "licenses", layout: "application"
  end

  def revisions
    # public User dürfen gar keine Revisions einsehen, member User nur die Revisionen
    # von bestimmten Individuals
    if current_user.public? || (current_user.member? && home_params[:individual_id].nil?)
      raise ErrorController::Forbidden
    end

    page_title "Änderungen"
    # highlight revisions tab in user menu
    @user_menu_tab_revisions_active = true

    @search = RevisionSearcher.new
    @search.configure user: current_user, indi: home_params[:individual_id], filter: home_params[:f]
    @search.add_filter(home_params[:afk], home_params[:afv]) if home_params[:afk]
    @search.remove_filter(home_params[:rfk], home_params[:rfv]) if home_params[:rfk]
    @search.configure from: home_params[:p] if home_params[:p]
    @search.execute

    if request.xhr?
      # Wir sind entweder auf der Revisionsliste eines Individuals, oder der Benutzer hat
      # auf der globalen Revisionsliste einen Filter benutzt.
      render "revisions/_revision_results", layout: false
    else
      render "revisions/revisions", layout: "application"
    end
  end
  
  def api_index
    page_title "Schnittstellen"
  end
  
  
  def rss
    # identify user
    @user = User.find_by rss_token: params[:token]
    
    if @user.blank? || !@user.at_least?(:manager)
      raise ErrorController::Forbidden
    end
    
    @feedauthor = "Koordinierungsstelle für Wissenschaftliche Universitätssammlungen"
    @feedupdate = Time.now
    @feedabout = "https://portal.wissenschaftliche-sammlungen.de/revision/rss"
    @feedtitle = "KWUS Portal Aktualisierung"
    
    # Revision visibility depends on user role
    # therefore caching is based on the user role and the updated_at of Revision.last
    userrole  = @user.role
    cachedate = Revision.last.updated_at.to_date.to_s
    
    @items = []
    @items = Rails.cache.fetch("/revisions/rss/items/#{userrole}-#{cachedate}", :expires_in => 12.hours) do

      search = RevisionSearcher.new
      search.configure user: @user, size: 100
      search.execute
      return unless search.has_results
      revisionlist = search.results
    
    
      revisions_occuring_at_related = revisionlist.select{|rev| !rev.occured_at_related_strong_individual_id.nil?}
      revisionlist = revisionlist.select{|rev| rev.occured_at_related_strong_individual_id.nil?}
    
      revs_by_indi = revisionlist.group_by(&:subject_id)
    
      # reassign revisions of weak indis to a strong indi 
      revisions_occuring_at_related.each do |rev|
        indi_id = rev.occured_at_related_strong_individual_id
        (revs_by_indi[indi_id] ||= []) << rev
      end
    
      # take care of revisions without subject_id
      revs_by_indi[nil].each do |rev|
        indi_id = rev.new_individual_id || rev.individual_id || rev.old_invididual_id
        if indi_id
          revs_by_indi[indi_id] ||= []
          revs_by_indi[indi_id] << rev
        end
      end
      revs_by_indi.delete(nil)
    
      revs_by_indi_and_day = {}
    
      revs_by_indi.each do |indi_id, revs|
        indi = Individual.find_by_id(indi_id)
        indilabel = indi.inline_label if indi
        if indilabel.blank?
          indilabel = revs.last.subject_label ? revs.last.subject_label : "TODO"
        end
      
        indilink = indi.try(:purl) || "https://#{Maya::Application.config.mailhost["production"]}/individual/#{indi_id}"
      
        revs_by_day = revs.group_by {|rev| rev.created_at.to_date.to_s}
        revs_by_day.each do |datestr, revs2|
          date = revs2.first.created_at.to_date
          title = "#{indilabel} (#{I18n.l(date)})"
          revs_by_indi_and_day[title] = {revisions: revs2, indi: indi, title: title, date: date, indilink: indilink}
        end
      end
    
      revs_by_indi_and_day.each do |indi_id, revshash|
        revs = revshash[:revisions]
        indi = revshash[:indi]
        link = revshash[:indilink]
        title = revshash[:title]
     
        # keep only the latest revision for a property
        revs.uniq! {|rev| rev.property_id}
        revs.sort_by! {|rev| rev.id}
      
        
        updated = revs.max_by(&:created_at).created_at
        uuid = "#{indi_id}-#{updated.to_date.to_s}" # uuid has the form: "123345-2020-03-25"
      
        content = "<ul>"
        revision_strings = revs.map{|rev| "<li>#{rev.to_html_compact}</li>"}
        content += revision_strings.join() + "</ul>"
        content += "<hr><br>.to_s<br><ul>"
        revision_strings = revs.map{|rev| "<li>#{rev.to_s}</li>"}
        content += revision_strings.join() + "</ul>"
      
        @items.push({
          title: title,
          link: link,
          content: content,
          updated: updated,
          uuid: uuid
        })
    
      end
      @items.sort_by! { |hsh| hsh[:updated] }
      @items
    end

    
    respond_to do |format|
      format.atom {render "revisions/atom_feed", layout: false}
      format.rss  {render "revisions/rss_feed", layout: false}
      
    end
    
  end
  
  private
    def home_params
      params.permit!
      return params.to_h
    end
end
