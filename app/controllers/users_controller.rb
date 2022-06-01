class UsersController < ApplicationController
  # Default From address is the support email.
  FROM = Maya::Application::APP_CONFIG["support_mail"]

  # @action GET
  # @url /users/:id
  #
  # Render a user's page (which is very minimal at the moment).
  #
  # @arg id [Integer] The user's ID.
  def show
    raise ErrorController::Forbidden unless current_user.at_least? :manager
    @user = User.find(params[:id])

    render "show"
  end

  # @action GET
  # @url /users/new
  #
  # Render the invite modal.
  #
  # @arg individual_id [Integer] The ID of the person to be invited.
  #
  # @raise [UserError] If individual isn't a Person.
  # @raise [UserError] If person has no email.
  def new
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
    # collect non distinct if any to display warning-message
    @non_distinct_emails = emails - @emails

    # Warum geht das nicht, wenn ich es oben als "@from" deklariere?
    @from = FROM

    @modal_title = "Neuen Benutzer einladen"

    render "users/invite", layout: "modal"
  end

  # @action GET
  # @url /users/home
  #
  # Render the current user's home page.
  def home
    if current_user.role == :public
      redirect_to "/users/sign_in"
    elsif current_user.role == :member
      # Member-spezifische Einträge von users/home

      # Ein Hash (bzw. Liste aus Listen) mit Typ als Schlüssel und Listen der Individuals, die der
      # Benuzter bearbeiten darf als Werte; alphabetisch sortiert nach den Schlüsseln;
      @editables_hash = current_user.person.editable_individuals
        .select{|indi| current_user.can_view_individual? indi}.group_by(&:type).sort

      # Letzte 50 Revisionen vom User
      @revisions = Revision.where(user: current_user)
        .order("revisions.id DESC")
        .limit(50)
    end

    # highlight home tab in user menu
    @user_menu_tab_home_active = true
  end

  # @action GET
  # @url /users/invite_status
  #
  # Render some HTML that shows a person's invite status (i.e. whether they are already a member,
  # whether they can be invited, etc.).
  #
  # @arg person_id [Integer] The person's ID.
  def invite_status
    @record = Person.find(params[:person_id])
    if current_user.can?(:invite_user)
      render partial: "users/invite_status"
    else
      # dont do anything, just okeh
      render body: nil, status: :ok
    end
  end

  # @action GET
  # @url /users/show_recent_invite
  #
  # Render a modal showing the most recent invite (content and metadata) sent to a user.
  #
  # @arg individual_id [Integer] The user's *individual* ID.
  #
  # @raise [UserError] If the individual has no associated user.
  def show_recent_invite
    @modal_title = "Zuletzt versendete Einladung"
    individual_id = params[:individual_id]
    @user = User.where(individual_id: individual_id).first
    raise UserError, "Kein mit Individual-ID #{individual_id} assoziierter User vorhanden" unless @user.present?

    @from = @user.invitation_from
    @to = @user.invitation_to
    @date = @user.invitation_date
    @subject = @user.invitation_subject
    @body = @user.invitation_mail

    render "users/show_invite", layout: "modal"
  end

  # @action POST
  # @url /users/send_invite
  #
  # Create a user account for a Person individual and send an email to the user-to-be to invite
  # them to join.
  #
  # (Will be called from the invite modal via AJAX.)
  #
  # @arg individual_id [Integer] The Person's ID.
  # @arg email [String] The user's email address.
  # @arg from [String] The email address used in the email's "From:" field.
  # @arg subject [String] The email's subject.
  # @arg text_body [String] The email's body.
  def send_invite
    raise ErrorController::Forbidden unless current_user.can?(:invite_user)
    postoffice = PostOffice.new

    individual_id = params[:individual_id]
    indi = Individual.find(params[:individual_id])
    raise UserError, "Nur Personen können eingeladen werden" unless indi.is_a?(Person)

    email = params[:email]
    raise UserError, "Bitte eine E-Mail-Adresse angeben" if email.blank?

    # Recyclen hier die "reset_password_token"-Spalte, die von Devise geliefert wurde.
    token, digested_token = Devise.token_generator.generate(User, :reset_password_token)

    user = User.where(individual_id: individual_id).first
    unless user.present?
      # only check for duplicate email-addresses if this is the first invitation for the user
      raise UserError, "Diese E-Mail ist schon vergeben" if User.where(email: email).any?
      user = User.new
    end
    user.email = email
    user.individual_id = indi.id
    user.name = indi.safe_value "name"
    user.first_name = indi.safe_value "first_name"
    user.role = "member"
    user.save(validate: false)

    # include inviting user's name in from unless the from address is set to support@wiss...
    if params[:from] == FROM
      from = "\"#{t 'support_mail_from'}\" <#{FROM}>"
    else
      from_name = I18n.transliterate(current_user.to_s)
      from = "\"#{from_name}\" <#{params[:from]}>"
    end
    
    mail = Mail.new(from: from,
                    to: postoffice.to_address(email),
                    bcc: FROM,
                    subject: params[:subject],
                    body: params[:text_body].gsub("TOKEN", token))
                    
    mail.charset = "UTF-8"
    mail.content_transfer_encoding="8bit"
    
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

    user.update(invitation_from: from,
                invitation_to: email,
                invitation_subject: params[:subject],
                invitation_date: Time.now,
                invitation_mail: params[:text_body],
                invited_by: current_user.id)
                
    # reset_password_token wird beim saven und updaten genilt
    # deshalb hier nochmal
    user.reset_password_token = digested_token
    user.save(validate: false)

    Revision.create(user_id: current_user.id,
                    subject_id: indi.id,
                    subject_type: indi.type,
                    subject_label: indi.label,
                    action: "send_invite")

    # mit Safari + Apache wird bei Verwendung von 204 bzw. head :no_content
    # z.T. ein Fehler erzeugt, daher antworten wir hier stattdessen mit einem
    # (weniger korrekten) leeren 200er
    # head :no_content
    render body: nil, status: 200
  end

  # @action GET
  # @url /join/:token
  #
  # Render a page where an invited user can specify their password.
  #
  # @arg token [String] The user's join token.
  #
  # @raise [ErrorController::InvalidToken] If the token is invalid.
  def join
    @token = params[:token]

    digested_token = Devise.token_generator.digest(self, :reset_password_token, @token)
    @user = User.where(reset_password_token: digested_token).first
    raise ErrorController::InvalidToken, "Invalid token" unless @user

    @user.clicked_invitation_link = true
    @user.save

    render "users/join"
  end

  # @action PUT
  # @url /join/:token
  #
  # Initially set a user's password to finalize the join process.
  #
  # (We don't use Devise's passwords#update here, because we allow the user to change their
  # email address at this point as well.)
  #
  # @arg token [String] The user's join token.
  # @arg user.email [String] The user's email address.
  # @arg user.password [String] The user's password.
  # @arg user.password_confirmation [String] The user's password again.
  #
  # @raise [ErrorController::InvalidToken] If the token is invalid.
  def update_by_join_token
    postoffice = PostOffice.new
    @token                = params[:token]
    email                 = params[:user][:email]
    password              = params[:user][:password]
    password_confirmation = params[:user][:password_confirmation]

    digested_token = Devise.token_generator.digest(self, :reset_password_token, @token)
    @user = User.where(reset_password_token: digested_token).first
    raise ErrorController::InvalidToken, "Invalid token" unless @user

    if password != password_confirmation
      @user.errors.add(:base, "Passwörter stimmen nicht überein" )
    end

    @user.email = email
    @user.password = password
    @user.reset_password_token = nil

    if @user.errors.empty? && @user.save
      sign_in(@user)

      Revision.create(user_id: current_user.id,
                      subject_id: current_user.person.id,
                      subject_type: current_user.person.type,
                      subject_label: current_user.person.label,
                      action: "join")

      # Registrierungsbestätigung verschicken
      mail = Mail.new(from: @user.invitation_from,
                      to: postoffice.to_address(email),
                      bcc: FROM,
                      subject: "Willkommen beim Portal #{t "maya_title_inline"}",
                      body: render_to_string("users/mails/registration_confirmation.text",
                                             layout: false))
      mail.deliver

      redirect_to "/users/home"
    else
      render "users/join"
    end
  end

  # @action POST
  # @url /users/request_action
  #
  # Request something for an individual as a member.
  #
  # @arg request_action [String] The name of the requested thing (e.g. "publicity" or
  #   "edit_privileges").
  # @arg individual_id [Integer] The ID of the individual the thing is requested for.
  #
  # @raise [ForbiddenAction] if the requested thing isn't recognized.
  def request_action
    @action = "request_#{params[:request_action]}"
    raise ForbiddenAction unless Person.predicates.keys.include? @action
    postoffice = PostOffice.new

    @record = Individual.find(params[:individual_id])

    # Create a Property.
    # TODO Use PropertyManager after discussion about:
    # - Intended that no inverse predicate?
    # - Aren't the action revisions sufficient?
    current_user.person.send(@action).create!(value: @record)

    Revision.create(user_id: current_user.id,
                    subject_id: @record.id,
                    subject_type: @record.type,
                    subject_label: @record.label,
                    action: @action)

    @user = current_user
    @recipients = Maya::Application::APP_CONFIG["report_mails"]
    Thread.new do
      logger.info "Notifying #{@recipients} via mail of #{@action} by #{@user}."
      @recipients.each do |recipient|
        mail = Mail.new(
          from: FROM,
          to: postoffice.to_address(recipient),
          subject: "#{t @action, scope: :actions} #{@record.label}(#{@record.id})",
          body: render_to_string("users/mails/request.text", layout: false))
        mail.deliver
        logger.info "Sent mail to #{recipient}"
      end
      # every thread opens its own db connection
      ActiveRecord::Base.connection.close
    end
    render json: {
      status: 200
    }
  end

  # @action GET
  # @url /users/quickguide
  #
  # Render the quick guide.
  def quickguide
    raise ErrorController::Forbidden unless current_user.at_least? :survey_participant
  end

  # @action GET
  # @url /users/privacy
  #
  # Render the privacy info page.
  def privacy
    raise ErrorController::Forbidden unless current_user.at_least? :member
  end
end
