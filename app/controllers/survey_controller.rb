class SurveyController < ApplicationController
  FROM = Maya::Application::APP_CONFIG["support_mail"]

  before_action :set_campaign
  before_action :check_for_manager, only: [:dashboard, :multiple_invite, :inviteform, :user_events_list, :memo_modal, :changed_predicates, :statistics]
  before_action :check_for_survey_member, only: [:home, :clarify, :check_data, :keep_in_touch]
  before_action :check_member_or_manager, only: [:show_form,:empty_table_row]

  class SurveyError < StandardError; end
  
  DASHBOARDFILTER = {
    initial: "Nicht eingeladen",
    active: "Aktiv",
    invited: "Eingeladen",
    in_progress: "Erster Zugriff",
    done: "Fertig gemeldet",
    completed: "Abgeschlossen"
  }

  def home
    raise ErrorController::Forbidden unless current_user.current_survey_participant?

    if @campaign.at_least_status? current_user, :done
      redirect_to "/survey/checkdata"
      return
    end
    page_title @campaign.name

    @survey_individuals = []
    @campaign.resolve_indis_for_user(current_user).each do |indi|
      indi_hash = {
        individual: indi,
        edited: !Revision.where(user_id: current_user.id, campaign_slug: @campaign.slug, subject_id: indi.id).empty?
      }
      @survey_individuals.push(indi_hash)
    end

    @user_menu_tab_surveyhome_active = true

    @at_least_one_revision = !Revision.where(user_id: current_user.id, campaign_slug: @campaign.slug).empty?

    @inviter_email = @campaign.get_user_inviter_email current_user
    @inviter_name = @campaign.get_user_inviter_name current_user
  end

  def dashboard
    @user_menu_tab_surveydashboard_active = true
    unless @campaign
      session[:managing_a_survey] = nil
      redirect_to("/", notice: "Es gibt keine aktive Umfrage") and return 
    end
    
    page_title @campaign.name

    filter = params[:filter]
    group = params[:group]
    filter = "initial" if filter.blank?
    group = @campaign.targetclass if group.blank?
    @filter = filter
    @group = group

    @page = params[:page] ? params[:page].to_i : 0
    @searchterm = params[:searchterm]
    if @searchterm && @searchterm.to_s.length > 0
      @filter = :all
    end

    session[:managing_a_survey] = true

    opts= {filter: @filter, page: @page, searchterm: @searchterm}
    @addressees = @campaign.addressees(opts)

    if request.xhr?
      render partial: "/survey/addressee_list"
    else
      render "dashboard"
    end
  end

  # POST /survey/memo
  def create_memo
    campaign_slug = params[:campaign_slug] ? params[:campaign_slug] : Campaign.current.slug
    text = params[:text]
    headline = params[:headline]

    memo_text = text

    target_user = params[:user_id] ? User.find(params[:user_id]) : current_user

    redirection_target = params[:redirect_to] ? params[:redirect_to] : stored_location_for(:user)

    _,_,memo,_,_ = IndividualManager.create_weak_individual target_user, target_user.person, "has_memo", "memo_subject", headline
    PropertyManager.set_property target_user, memo, "text", memo_text, rev: nil,
                            check_permissions: true, hide_on_global_list: false,
                            occured_at_id: nil, campaign_slug: campaign_slug


    redirect_to redirection_target
  end

  # POST /survey/event
  def create_event
    event_action = params[:event_action]
    campaign_slug = params[:campaign]
    person_id = params[:person].to_i
    individual_id = params[:individual].to_i
    override_daily_limit = params.dig("override-daily-limit")
    opts = {}
    opts[:form] = params[:form]
    opts[:override_daily_limit] = override_daily_limit
    # either for managers or active survey participants updating their own records
    unless (current_user.at_least? :manager) ||
      ((event_action == "i_am_done") && (current_user.individual_id == person_id))
      raise ErrorController::Forbidden
    end

    begin
      create_event_helper campaign_slug, event_action, person_id, opts
    rescue SurveyError => e
      render json:{
        message: e.message
      }, :status => 422
      return
    end

    if params[:redirect_url]
      redirect_to(params[:redirect_url])
    else
      render json:{
        html: render_to_string(
          partial: "survey/surveyuserstatus",
          locals: {
            person: Individual.find(person_id),
            campaign: Campaign.get(campaign_slug),
            showEventList: true,
            individual: Individual.find_by_id(individual_id)
          }
        )
      }
    end

  end

  def multiple_invite
    if params[:person_ids].blank?
      render json:{
        message: "Es wurden keine Personen ausgewählt"
      }, :status => 400
      return
    end

    event_action = params[:event_action]
    campaign_slug = params[:campaign_slug]
    person_ids = params[:person_ids].collect {|id| id.to_i}


    persons = Person.where(id: person_ids)
    failed_persons = []
    updated_persons = []
    persons.each do |person|
      form = {
        email: person.safe_value("email"),
        subject: "Einladung zur Umfrage – #{Campaign.get(campaign_slug).name}",
        from: [current_user.person.safe_values("email").select{|mail| mail.include? "hu-berlin.de"},
                  current_user.person.safe_values("email").select{|mail| !mail.include? "hu-berlin.de"},
                  "support@wissenschaftliche-sammlungen.de"].flatten.first
      }
      begin
        create_event_helper campaign_slug, event_action, person.id, {form: form}
      rescue Error => e
        failed_persons.push({person_id: person.id, name: person.label, message: e.message})
      else
        updated_persons.push(person)
      end

    end

    surveyuserstatuspartials = {}
    updated_persons.each do |person|

      surveyuserstatuspartials[person.id] = render_to_string partial: 'surveyuserstatus',
      locals: {
        person: person,
        campaign: Campaign.get(campaign_slug),
        showEventList: true
      }
    end

    render json:{
      html_partials: surveyuserstatuspartials,
      error_list: failed_persons
    }

  end

  def user_events_list
    campaign_slug = params[:campaign]
    user = Person.find(params[:person].to_i).user

    render json:{
      html: render_to_string(
        partial: "survey/usereventslist",
        locals: {
          user: user,
          campaign: Campaign.get(campaign_slug)
        }
      )
    }
  end

  # get 'survey/join/:survey_token'
  def join
    survey_token = params[:survey_token]
    user = User.find_by(survey_token: survey_token)
    

    # if there is no current survey redirect 
    if !@campaign
      if user && user.at_least?(:member)
        sign_in(user, scope: :user)
        redirect_to("/users/home", notice: "Die Umfrage ist bereits beendet.") and return
      else
        redirect_to(controller: "survey", action: "inactive", survey_token: survey_token) and return
      end
    end
    
    raise ErrorController::Forbidden unless user && user.current_survey_participant?
    sign_in(user, scope: :user)
    if @campaign.at_most_status?(current_user, :invited)
      # log accesses only if user has not already signalled "i am done"
      SurveyEvent.create_event user, "access", Campaign.current.slug, user.id
    end
    redirect_to "/survey/home"
  end
  
  # get 'survey/inactive'
  def inactive
    survey_token = params[:survey_token]
    @user = User.find_by(survey_token: survey_token)
    page_title "Umfrage abgelaufen"
  end

  def inviteform
    individual_id = params[:individual_id]
    @individual = Individual.find(individual_id)
    raise UserError, "Nur Personen können eingeladen werden" unless @individual.is_a?(Person)

    raise UserError, "Keine E-Mail-Adresse vorhanden. Bitte E-Mail-Adresse als Property hinzufügen" unless @individual.email_value.present?

    emails = @individual.email_value
    # remove non-distinct emails from the possible invitation emails
    @emails = emails.select do |email|
      # but do not consider the address, that is contained in the user record of
      # the user-to-be; this is the case if a Person is invited multiple times.
      # In this case a user with the questionable email-address exists, but this
      # case may not be considered as non-distinct email-address
      already_created_user = User.where(individual_id: params[:individual_id]).first
      if User.where(email: email).empty?
        true
      elsif already_created_user.present?
        if already_created_user.email.downcase == email.downcase
          true
        else
          false
        end
      end
    end

    urlprefix = request.env['rack.url_scheme']+ "://" + request.env['HTTP_HOST']

    # Warum geht das nicht, wenn ich es oben als "@from" deklariere?
    @from = FROM

    if params[:event_action] == "invite"
      @modal_title = "Person zu Umfrage einladen"
      @message = @campaign.invite_message current_user, @individual, urlprefix: urlprefix
      @subject = "Portal \"Wissenschaftliche Sammlungen\" – Umfrage"
      # collect non distinct if any to display warning-message
      @non_distinct_emails = emails - @emails

      render "survey/invite", layout: "modal"
    elsif params[:event_action] == "remind"
      @modal_title = "Person an Umfrage erinnern"
      @message = @campaign.remind_message current_user, @individual, urlprefix: urlprefix
      @subject = "Portal \"Wissenschaftliche Sammlungen\" – Erinnerung"
      @non_distinct_emails = []
      @emails = emails
      render "survey/invite", layout: "modal"
    end
  end

  # GET /survey/clarify
  def clarify
  end

  # POST /survey/clarify
  def process_clarify
    email = params[:email]
    name = params[:name]
    text = params[:text]

    # Stellvertreter_in oder neue_r Ansprechpartner_in?
    if params[:surrogat_mode] == "commissioned"
      headline = "Stellvertreter_in"
    else
      headline = "Neue_r Ansprechpartner_in / Neue Zuständigkeit"
    end

    # create surrogate memo
    memo_text = "#{headline}:\r\nName: #{name}\r\nEmail: #{email}\r\nWeitere Informationen: #{text}"
    target_user = params[:user_id] ? User.find(params[:user_id]) : current_user
    _,_,memo,_,_ = IndividualManager.create_weak_individual target_user, target_user.person, "has_memo", "memo_subject", headline
    PropertyManager.set_property target_user, memo, "text", memo_text, rev: nil,
                            check_permissions: true, hide_on_global_list: false,
                            occured_at_id: nil, campaign_slug: Campaign.current.slug

    if params[:surrogat_mode] == "commissioned"
      redirect_to "/survey/home", notice: "Vielen Dank! Sie können nun gerne mit der Bearbeitung der Umfrage fortfahren."
    else params[:surrogat_mode] == "new_responsibility"

      # prevent from further survey participating
      SurveyEvent.create_event current_user, "block", @campaign.slug, current_user.id

      # send email to inviting manager
      invited_from = @campaign.get_user_inviter(target_user).email
      postoffice = PostOffice.new
      mail = Mail.new(from: FROM,
                      to: postoffice.to_address(invited_from),
                      subject: "Neue Zuständigkeit (#{target_user.person.inline_label})",
                      body: memo_text+"\nNotiz im Portal: https://portal.wissenschaftliche-sammlungen.de/Person/#{target_user.person.id}#notes"
                      )
      mail.deliver

      sign_out current_user

      redirect_to "/", notice: "Vielen Dank! Wir werden uns in Kürze mit Ihnen in Verbindung setzen."
    end

  end

  def check_data

    @user_menu_tab_surveyhome_active = true
    page_title @campaign.name
    @inviter_email = @campaign.get_user_inviter_email current_user
    @inviter_name = @campaign.get_user_inviter_name current_user


    if @campaign.at_most_status? current_user, :in_progress
      SurveyEvent.create_event current_user, "i_am_done", @campaign.slug, current_user.id
      # clean up user input async
      Thread.report_on_exception = true
      t = Thread.new do
        File.open(Rails.root.join("tmp","after_survey_cleanup.lock"), File::RDWR|File::CREAT, 0644) do |f|
          begin
            # Auf Lockfile warten
            Timeout::timeout(5*60) { f.flock(File::LOCK_EX) }
          rescue Timeout::Error => e
            Logger.warn("Couldn't acquire exclusive lock (Timeout of 5 min reached)")
          else
            ActiveRecord::Base.connection_pool.with_connection do |con|
              indi_ids = Revision.where(user_id: current_user.id, campaign_slug: @campaign.slug).pluck(:subject_id).uniq - [nil]

              for indi_id in indi_ids
                indi = Individual.find(indi_id)
              end
            end
          end
        end
      end
    end
  end


  # GET /survey/form/:indivdual_id
  def show_form
    redirect_to("/", notice: "Die Umfrage ist bereits beendet.") and return unless @campaign
    
    @glass = Glass.new(self, survey: true)
    @record = Individual.find(params[:individual_id])
    page_title @record.label
    raise ErrorController::Forbidden unless current_user.can_edit_individual?(@record)
    
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    render "form"
  end

  # PUT /survey/transform_account
  def transform_account
    user = User.find_by(survey_token: params[:survey_token]) || current_user
    if user == User.anonymous_user
      raise UserError, "Benutzer_in nicht gefunden."
    end
    email                 = params[:user][:email]
    password              = params[:user][:password]
    password_confirmation = params[:user][:password_confirmation]

    if password != password_confirmation
      user.errors.add(:base, "Passwörter stimmen nicht überein" )
    end

    user.email = email
    user.password = password
    user.role = "member"

    user.invited_by = SurveyEvent.where(action: "invite",target_user_id: user.id).first.user_id

    if user.errors.empty? && user.save
      Revision.create(user_id: user.id,
                      subject_id: user.person.id,
                      subject_type: user.person.type,
                      subject_label: user.person.label,
                      action: "join",
                      campaign_slug: @campaign.try(:slug))
      # @user variable only neccessary for mail text
      @user = user
      # Registrierungsbestätigung verschicken
      postoffice = PostOffice.new
      mail = Mail.new(from: user.invitation_from,
                      to: postoffice.to_address(email),
                      bcc: FROM,
                      subject: "Willkommen beim Portal #{t "maya_title_inline"}",
                      body: render_to_string("users/mails/registration_confirmation.text",
                                             layout: false))
      mail.deliver
      sign_in(@user, :bypass => true)
      redirect_to "/users/home"
    else
      
      if @campaign
        @user_menu_tab_surveyhome_active = true
        page_title @campaign.name
        render "survey/check_data"
      else
        page_title "Umfrage abgelaufen"
        render "survey/inactive"
      end
    end
  end

  # GET /survey/changed_predicates
  def changed_predicates
    if @campaign
      roles = User::ROLES
      index = roles.index(:manager)
      # exluding changes made by maangers/admins
      managing_roles = roles[index..roles.length-1].collect{|r| r.to_s}
      managing_user_ids = User.where(role: managing_roles).pluck :id


      indi_id = params[:indi_id].to_i
      # to include also changes not made in survey form but the normal maya interface during the campaign:
      list_of_predicates = Revision.where("subject_id = ? AND created_at >= ? AND created_at <= ?", indi_id,@campaign.begin,@campaign.end).where.not(user_id: managing_user_ids)
                          .collect {|rev| rev.predicate}.uniq
      render json: {predicates: list_of_predicates}
    else
      render json: {predicates: []}
    end
  end
  
  # GET /survey/stats
  def statistics
    page_title "Statistiken"
    
    persons_in_initial_state = []
    
    # hash of all user events (as list) grouped by target user
    events_per_user = UserEvent.where(campaign_slug: @campaign.slug, action: Campaign::ACTIONASSIGN.keys)
                    .group_by(&:target_user_id)
    
    # provides the most recent status related user event for every user participating in the survey
    relevant_events = UserEvent.where(campaign_slug: @campaign.slug, action: Campaign::ACTIONASSIGN.keys)
                    .group_by(&:target_user_id).collect{|list| list[1].last}
    
    
    # build data grouped by inviting managers
    event_hshs = []
    events_per_user.values.each do |event_list|
      ev_hsh = {
        manager_id: event_list.first.user_id,
        manager_name: User.find(event_list.first.user_id).name,
        target_user_id: event_list.first.target_user_id,
        last_action: event_list.last.action,
        status: Campaign::ACTIONASSIGN[event_list.last.action.to_sym]
      }
      event_hshs.append(ev_hsh)
    end
    
    # localize statuses
    
    
    @numbers_by_managers = {}
    @manager_chart_data = [] 
    event_hshs.group_by{|eventhsh| eventhsh[:manager_id]}.each do |manager_id, event_list|
      @numbers_by_managers[manager_id] = event_list.group_by{|eventhsh| eventhsh[:status]}.transform_values{|v| v.length}  
      
      charthsh = {name: User.find(manager_id).person.label, data: @numbers_by_managers[manager_id]}
      @manager_chart_data.append(charthsh)
    end
    
    
    
    # global: all users by status
    @numbers_by_status = event_hshs.group_by{|eventhsh| eventhsh[:status]}.transform_values{|v| v.length}
    total_participant_count = @numbers_by_status.values.sum
    initial_count = @campaign.resolve_addressees_for_indis.uniq.size - total_participant_count
    
    @numbers_by_status[:initial] = initial_count
    # bring @numbers_by_status in the right order
    tmp_numbers_by_status = {}
    Campaign::ACTIONASSIGN.values.each do |status|
      tmp_numbers_by_status[status] = @numbers_by_status[status] ||= 0
    end
    @numbers_by_status = tmp_numbers_by_status
    
    @cnumbers_by_status = {}
    # stats for indis
    Campaign::ACTIONASSIGN.values.each do |status|
      @cnumbers_by_status[status] = @campaign.count_survey_targets(status) 
    end
    
  end

  private
    def set_campaign
      if params[:slug].present?
        @campaign = Campaign.get(params[:slug])
      elsif Campaign.current.present?
        @campaign = Campaign.current
      end
    end

    # Raises Error if current_user isn't manager
    def check_for_manager
      raise ErrorController::Forbidden unless current_user.at_least? :manager
    end

    # Raises Error if current_user isn't a survey member or if he'd been blocked
    def check_for_survey_member
      unless UserEvent.where(target_user_id: current_user.id, campaign_slug: @campaign.slug).exists?
        raise ErrorController::Forbidden
      end
      if UserEvent.where(target_user_id: current_user.id, campaign_slug: @campaign.slug, action: "block").exists?
        raise ErrorController::Forbidden
      end
    end

    def check_member_or_manager
      if current_user.at_least? :manager

      else
        unless UserEvent.where(target_user_id: current_user.id, campaign_slug: @campaign.slug).exists?
          raise ErrorController::Forbidden
        end
        if UserEvent.where(target_user_id: current_user.id, campaign_slug: @campaign.slug, action: "block").exists?
          raise ErrorController::Forbidden
        end
      end
    end
    
    def events_group_by_status eventlist
      hsh_by_status = {}
      eventlist.each do |event|
        inviting_manager = User.find(event.user_id)
        target_user = User.find(event.target_user_id)
        status = Campaign::ACTIONASSIGN[event.action.to_sym]
      
        if hsh_by_status[status]
          hsh_by_status[status].append(event)
        else
          hsh_by_status[status] = [event]
        end
      end
      return hsh_by_status
    end


    # @param campaign_slug slug of campaign
    # @param event_action action to create event with. See {Campaign::ACTIONASSIGN campaign actions (and corresponding statuses)}
    # @param person_id ID of the person aligned to user to create an event for
    # @param opts May contain email related information, such as `opts[:form][:email]`, `opts[:form][:text_body]`, `opts[:form][:subject]`, `opts[:form][:from]`
    def create_event_helper campaign_slug, event_action, person_id, opts={}
      # if there is no user linked with the person, one has to be created
      person = Person.find person_id
      target_user = User.find_by individual_id: person_id
      
      # EXTRACT information from mail modal if available
      # include inviting user's name in from unless the from address is set to support@wiss...
      if opts[:form]
        if opts[:form][:from].blank?
          from = "\"#{t 'support_mail_from'}\" <#{FROM}>"
        else
          from_name = I18n.transliterate(current_user.to_s)
          from = "\"#{from_name}\" <#{opts[:form][:from]}>"
        end
        email = opts[:form][:email]
      end
      email ||= person.safe_value("email")
      
      if !target_user && (event_action == "invite" || event_action == "complete")
        # only check for duplicate email-addresses if this is the first invitation for the user
        raise UserError, "Diese E-Mail ist schon vergeben" if User.where(email: email).any?
        target_user = User.new(
          name: (person.safe_value "name"),
          first_name: (person.safe_value "first_name"),
          role: "survey_participant",
          individual_id: person_id,
          email: email,
          invitation_from: from
        )
        if target_user.invalid?
          err_messages = target_user.errors.messages
          err_messages.delete(:password) # unset password is allowed for survey participants
          unless err_messages.blank?
            err_string = ""
            err_string = err_messages.keys.collect{|key| I18n.t(key)+": "+err_messages[key].join(", ")}.join("\n")
            raise UserError, err_string
          end
        end
        target_user.save(validate: false)
      end

      if event_action == "invite" || event_action == "remind"
        
        raise UserError, "Nur Personen können eingeladen werden" unless person.is_a?(Person)
        raise UserError, "Bitte eine E-Mail-Adresse angeben" if email.blank?

        # check for invitations/reminders at the same day
        if target_user.present? && !opts[:override_daily_limit]
          end_of_today = Date.today.to_time.in_time_zone('Europe/Berlin').end_of_day
          beginning_of_today = Date.today.to_time.in_time_zone('Europe/Berlin').beginning_of_day
          today_actions = UserEvent.where(target_user_id: target_user.id)
              .where("created_at >= ? and created_at <= ? and (action = 'invite' OR action = 'remind')", beginning_of_today, end_of_today)
          unless today_actions.blank?
            raise SurveyError, "Nur eine Einladung/Erinnerung pro Tag pro Person möglich!"
          end
        end

        urlprefix = request.env['rack.url_scheme']+ "://" + request.env['HTTP_HOST'] #to display correct urls in emails

        

        if event_action == "invite"

          token = SecureRandom.hex
          # prepare invitation message
          invite_message = @campaign.invite_message current_user, person, urlprefix: urlprefix
          if opts[:form][:text_body]
            subject = opts[:form][:subject]
            invite_message = opts[:form][:text_body].gsub("SURVEY_TOKEN",token)
          else
            invite_message = invite_message.gsub("SURVEY_TOKEN",token)
            subject = "Portal \"Wissenschaftliche Sammlungen\" – Umfrage"
          end
          message = invite_message

          target_user.update({
            survey_token: token,
            survey_invitation_date: DateTime.now,
            survey_invitation_mail: invite_message
          })
        elsif event_action == "remind"
          token = target_user.survey_token
          remind_message = @campaign.remind_message current_user, person, urlprefix: urlprefix

          if opts[:form][:text_body]
            subject = opts[:form][:subject]
            remind_message = opts[:form][:text_body].gsub("SURVEY_TOKEN",token)
          else
            remind_message = remind_message.gsub("SURVEY_TOKEN",token)
            subject = "Portal \"Wissenschaftliche Sammlungen\" – Erinnerung"
          end
          message = remind_message
        else
          raise "No valid Action for multiple survey participant invite/remind"
        end

        postoffice = PostOffice.new

        mail = Mail.new
        mail.charset = 'UTF-8'
        mail.content_transfer_encoding="8bit"
        mail.from = from
        mail.to = postoffice.to_address (email) #email # TODO change for production
        mail.bcc = FROM
        mail.subject = subject
        mail.body = message
        begin
          mail.deliver
        rescue Net::SMTPSyntaxError
          # Unfortunately there is a bug in the Mail-Gem: German Umlauts are not supported in the FROM
          # field. See https://github.com/mikel/mail/issues/39
          raise %(
            Sending invitation mail failed. Probably because the FROM field contains unsupported
            characters (e.g. "äöü").
          ).squish
        end
      end

      # create the Survey Event
      SurveyEvent.create_event current_user, event_action, campaign_slug ,target_user.id
    end



end
