require 'securerandom' # for api key generation

# Represents user with login credentials (as opposed to a Maya Person).
class User < ApplicationRecord
  # The available user roles.
  ROLES = %i(
    public
    survey_participant
    member
    manager
    admin
  )

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Die Person, zu der dieser User gehört.
  belongs_to :person, foreign_key: "individual_id", class_name: "Individual", required: false
  
  has_many :user_events, foreign_key: "target_user_id"

  # allow destruction of User only if no revisions are caused by it 
  def destroy
    if Revision.where(user_id: self.id).where.not(action: "join").count > 0
      raise ForbiddenAction, "Users must not be destroyed. Although Users are not Individuals like you and me it is wrong to destroy them. If you are a monster and want to kill this User anyways, please contact your database administrator ;)"
    end
    # destroy related user events
    UserEvent.where(target_user_id: self.id).destroy_all
    # destroy join/accept invite revision
    Revision.where(action: "join").destroy_all
    super
  end

  def to_s
    return person.label if person

    str = email
    str = name unless name.blank?
    str = first_name[0] + ". " + str if !first_name.blank? && first_name.length > 0
    str = str[0..13] + "..." if str.length > 16
    str
  end

  # @note Roles are handled as symbols, just like actions.
  def role
    super.to_sym
  end

  # Determine whether the user can view `individual`. The user needs to have at least the role
  # in `individual.visibility`. Quoting the documentation of {Individual#visibility}:
  #
  # > {include:Individual#visibility}
  #
  # @param individual [Individual]
  # @return [Boolean]
  def can_view_individual? individual
    at_least?(individual.visibility)
  end

  # Determine whether the user can create a new instance of `individual_class`. For weak
  # individuals, it's only required that the user is at least a member. For strong individuals,
  # the user needs to have at least the role required by `access_rule`s.
  #
  # @param individual_class [Class]
  # @return [Boolean]
  def can_create_individual? individual_class
    if individual_class.weak?
      at_least?(:survey_participant)
    else
      at_least?(individual_class.minimum_role_required(:create))
    end
  end

  # Determine whether the user can edit `individual`. First, the individual needs to be visible to
  # the user. The further conditions depend on whether the individual is weak or strong. For strong
  # individuals there are three ways to get edit permission (any one of them is sufficient):
  #
  # - The user has at least the role requried by `access_rule`.
  # - The user's person is connected to the individual via a `can_edit` property.
  # - `user.person.automatically_editable` includes `individual`. Quoting the documentation of
  #   {Person#automatically_editable}:
  #     > {include:Person#automatically_editable}
  #
  # For weak individuals, it is sufficient to be able to edit at least one of the individual's
  # owners.
  #
  # @param individual [Individual]
  # @return [Boolean]
  def can_edit_individual? individual
    # Users can't edit individuals they can't view.
    return false unless can_view_individual?(individual)

    if individual.weak?
      # Wenn man einen weak Individual bearbeiten möchte, dann darf man das genau dann,
      # wenn man einen der Owners bearbeiten darf. So darf man zB Curatorships
      # bearbeiten, für die man die Sammlung bearbeiten darf (zB weil man dort als Curator
      # eingetragen ist, möglicherweise in einem anderen Curatorship).
      individual.owners.any? { |indi, _| can_edit_individual?(indi) }
    else
      # Hole zunächst die Mindest-Rolle, die die Individual-Klasse für die Bearbeitung fordert.
      min_role_by_class = individual.class.minimum_role_required(:edit)

      # Man kann die Edit-Erlaubnis auf drei Arten bekommen, wobei eine ausreicht.
      # (1) Man hat die von der Klasse geforderte Rolle.
      usual_permissions = at_least?(min_role_by_class) ||
        # (2) Man hat das Edit-Recht explizit zugewiesen bekommen.
        (person && person.explicitly_editable?(individual)) ||
        # (3) Das Individual gehört zu denen, die automatisch bearbeitbar sind.
        (person && person.automatically_editable.include?(individual))
        
      # Prevent survey participants to edit individuals after they're marked as completed
      if usual_permissions && role == :survey_participant 
        return false if Campaign.current.nil? # survey participants may not edit indis when there's no campaign
        return Campaign.current.at_most_status? self, :done
      else
        return usual_permissions
      end
    end
  end

  # Determine whether the user can delete the individual. Persons that are connected with a user
  # cannot be deleted at all. Other than that, the user needs to have at least the role required by
  # `access_rule`.
  #
  # @param individual [Individual]
  # @return [Boolean]
  def can_delete_individual? individual
    # Hier zählt nur die Mindest-Rolle, die die Individual-Klasse fordert.
    min_role_by_class = individual.class.minimum_role_required(:delete)
    at_least?(min_role_by_class)
  end

  # Determine whether the user can see a property. The property can either be given as an actual
  # Property instance, or as a "possible" property via the keyword arguments "subject", "predicate"
  # and optionally "objekt".
  #
  # To be visible to the user, the property has to fulfill ALL of the following conditions:
  #
  # - The user can view the subject.
  # - If there is an objekt, the user needs to be able to see it.
  # - If there is a predicate level visibility setting (`visible_for` option in `property` method),
  #   the user has to fulfil it. (This condition is ignored for the user's person's own `can_edit`
  #   properties.)
  #
  # @param property [Property]
  # @param subject [Individual]
  # @param predicate [String]
  # @param objekt [Individual]
  #
  # @return [Boolean]
  def can_view_property? property=nil, subject: nil, predicate: nil, objekt: nil
    if property
      predicate = property.predicate
      subject = property.subject
      objekt = property.objekt if property.objekt?
    end

    unless subject && predicate
      raise StandardError, "User#can_view_property? needs at least a subject and a predicate."
    end

    # Need to be able to view the subject individual.
    return false unless can_view_individual?(subject)

    # If we have an objekt, it needs to be visible to the user.
    if objekt
      return false unless can_view_individual?(objekt)
    end

    # If there is a predicate level visibility setting, the user has to fulfill that. But there is
    # an exception: The predicate level setting does not apply to the user's person own "can_edit"
    # properties.
    unless predicate == "can_edit" && subject == person
      if r = subject.class.visible_for(predicate)
        return false unless at_least?(r)
      end
    end

    true
  end

  # Determine whether the user can edit the property. The property can either be given as an actual
  # Property instance, or as a "possible" property via the keyword arguments "subject", "predicate"
  # and optionally "objekt".
  #
  # To be editable by the user, the property has to fulfill ALL of the following conditions:
  #
  # - The subject needs to be editable.
  # - The property needs to be visibile.
  # - If there is a predicate level requirement, the user needs to fulfill it.
  #
  # @param property [Property]
  # @param subject [Individual]
  # @param predicate [String]
  # @param objekt [Individual]
  #
  # @note For properties, "edit" also includes "create" and "delete".
  def can_edit_property? property=nil, subject: nil, predicate: nil, objekt: nil
    if property
      predicate = property.predicate
      subject = property.subject
      objekt = property.objekt if property.objekt?
    end

    unless subject && predicate
      raise StandardError, "User#can_edit_property? needs at least a subject and a predicate."
    end
    # virtual properties are not editable
    return false if subject.class.predicates[predicate][:virtual]
    # The subject needs to be editable.
    permission = can_edit_individual?(subject)

    # The property needs to be visibile.
    permission = permission && can_view_property?(property, subject: subject, predicate: predicate, objekt: objekt)

    # If there is a predicate level requirement, the user needs to fulfill it.
    if r = subject.class.editable_for(predicate)
      permission = permission && at_least?(r)
    end

    permission = permission || (can_edit_individual?(subject) && current_survey_participant?)
    
  end

  # Determine whether the user can do the action. This method should be used for actions that don't
  # concern a specific individual, like :invite_user. It checks whether the user has the role
  # required by the `access_rule`s specified in {Individual}.
  #
  # @param action [String] For example :invite_user.
  def can? action
    raise "Bitte Symbole für die Actions benutzen" unless action.is_a? Symbol

    # Bei Individual sind die Rechte für solche Actions angegeben, die sich nicht unbedingt auf
    # ein konkretes Individual beziehen (zB das Ansehen bestimmter Bereiche der Anwendung oder
    # :invite_user).
    at_least?(Individual.minimum_role_required(action))
  end

  # Determine whether the user can see the revision. Managers can see all revisions, even if the
  # subject doesn't exist anymore. The public, i.e. non-registered users can't see any revisions.
  # The following logic concerns all other users, i.e. members. The revision is invisible if the
  # individual or the property's subject don't exist anymore.
  #
  # For individual revisions, the user needs to be able to see the individual.
  #
  # For property revisions, the user needs to be able to see the property, as if actually existed.
  # See {User#can_view_property?} for what that means. However, {User#can_view_property?} assumes
  # that all the individuals involved still exist. Above, we have already required the subject's
  # existance. In contrast, the objekt's (`new_objekt` or `old_objekt`) existance can't be
  # guaranteed. If it does exist, we require visibility to the user. If it doesn't exist, we check
  # that the user has at least the role required in
  # `{old,new}_objekt_last_visibility_before_deletion`. This field is set for all relevant revisions
  # by {IndividualManager.delete_individual} when individuals are deleted.
  #
  # For other revisions, we only require that the user can see the individual concerned.
  #
  # @param rev [Revision]
  def can_view_revision? rev
    # Managers can see all revisions.
    return true if at_least?(:manager)

    # The public can't see any revisions.
    return false if public?

    # We don't show revisions to members if the subject individual doesn't exist anymore.
    # (This clause is also why we need to return early for managers.)
    return false unless rev.individual

    if rev.individual_revision?
      can_view_individual?(rev.individual)
    elsif rev.property_revision?
      # Need to be able to see all objekts.
      %w(old new).each do |str|
        # Check if {old,new}_objekt_id is set, i.e. whether there is (supposed to be) such an objekt.
        if rev.send("#{str}_objekt_id")
          if objekt = rev.send("#{str}_objekt")
            # Check visibility of the objekt if it still exists.
            return false unless can_view_individual?(objekt)
          else
            # Check last visibility if the objekt has already been deleted.
            if rev.send("#{str}_objekt_last_visibility_before_deletion")
              return false unless at_least?(rev.send("#{str}_objekt_last_visibility_before_deletion"))
            else
              # legacy data: for old revisions "new/old_objekt_last_visiblity_before_deletion has not been set"
              return true
            end
          end
        end
      end
      # Lastly, check if the member would have been able to see a corresponding property. Don't
      # include the objekt here, because we have dealt with that already.
      can_view_property?(subject: rev.subject, predicate: rev.predicate)
    else
      # It's a "misc" revision. Show these to members iff they can see the individual.
      can_view_individual?(rev.subject)
    end
  end

  # Determine whether the user has at least the required role.
  #
  # @param required_role [Symbol] The minimum role required.
  #
  # @return [Boolean]
  def at_least? required_role
    my_index = ROLES.index(role)
    required_index = ROLES.index(required_role.to_sym)

    my_index && required_index && my_index >= required_index
  end
  
  # class method for required role checks
  # @param role [Symbol] The role to be checked
  # @param required_role [Symbol] The required (minimum) role
  # @return [Boolean]
  def self.at_least? role, required_role
    my_index       = ROLES.index(role)
    required_index = ROLES.index(required_role)

    my_index && required_index && my_index >= required_index
  end

  # Definiere Methoden wie "current_user.member?"
  ROLES.each do |r|
    define_method "#{r}?" do
      role == r
    end
  end

  # Ein Benutzer, der benutzt wird, wenn kein Benutzer eingeloggt ist
  def self.anonymous_user
    @anonymous_user ||= where(email: "anonymous@kwus.org").first || create_anonymous_user
  end

  # @return [Boolean] Whether the registration process is complete.
  def registration_complete?
    # betrachte den Registrierungsvorgang als beendet sobald ein Passwort gesetzt wurde
    self.encrypted_password.present?
  end

  # @return [Boolean] Whether the invited person has already clicked the link.
  def clicked_invitation_link?
    self.clicked_invitation_link
  end

  # @return The datetime of the request of name action if this user's person has property
  #   `request_#{action}` pointing to individual, nil otherwise.
  def requested action, individual
    unless self.person.present?
      raise ErrorController::UserWithoutPerson, "current_user #{cur}:#{cur.id} has no associated Person"
    end
    requests = self.person.send("request_#{action}")
    if !requests.nil? && !requests.empty?
      requests.each do |prop|
        indi = prop.value
        if indi == individual
          return prop.created_at.to_datetime
        end
      end
    end
    nil
  end

  # @return [User] which invited this user
  def invited_by_user
    self.class.find(invited_by) if invited_by
  end
  
  def current_survey_status
    if Campaign.current
      return Campaign.current.user_status self
    else
      return nil
    end
  end
  
  # @return [List] of all campaign classes the user participates in 
  def campaigns
    campaign_slugs = user_events.select(:campaign_slug).distinct.collect &:campaign_slug
    campaign_slugs.map{|slug| Campaign.get slug}
  end
  
  # @param campaign Campaign class
  # @return [Boolean] whether this user is participating in the given campaign
  def survey_participant? campaign
    return campaign && Campaign.subclasses.include?(campaign) && 
          UserEvent.where(target_user_id: id, campaign_slug: campaign.slug).pluck(:action).include?("invite")
  end
  
  # @return [Boolean] whether this user is participating in the current campaign
  def current_survey_participant?
    survey_participant? Campaign.current
  end
  
  # @return [Boolean] whether this user is participating **and active** (not completed) in the current campaign
  def current_survey_active_participant?
    return false unless Campaign.current
    events = UserEvent.where(target_user_id: id, campaign_slug: Campaign.current.slug, action: "invite")
    completed_events = UserEvent.where(target_user_id: id, campaign_slug: Campaign.current.slug, action: "i_am_done")
    return events.length > 0 && completed_events.length == 0
  end
  
  # @return [Boolean] whether user has been invited and not completed in current campaign
  def current_survey_incomplete_participant?
    events = UserEvent.where(target_user_id: id, campaign_slug: Campaign.current.slug)
    return events.pluck(:action).include?("invite") && !events.pluck(:action).include?("complete")
  end
  
  # @return [Boolean] whether this user has completed the current campaign
  def current_survey_done?
    UserEvent.where(target_user_id: id, campaign_slug: campaign.slug).pluck(:action).include?("i_am_done")
  end
  
  def devise_mailer
    MayaUserMailer
  end
  
  def rss_token
    if read_attribute(:rss_token).nil?
      update rss_token: SecureRandom.alphanumeric(16)
    end
    return read_attribute(:rss_token)
  end

  def api_key
    if key = self[:api_key]
      return key
    else
      key = SecureRandom.alphanumeric(16)
      self[:api_key] = key
      self.save
      return key
    end
  end

  # ensure user account is active (a person indi is assigned)
  def active_for_authentication?  
    super && individual_id
  end  
  
  def inactive_message   
    individual_id ? super : :deleted_account  
  end  

  private

  def self.create_anonymous_user
    u = new(email: "anonymous@kwus.org", name: "Anonymous", role: "public")
    u.save(validate: false)
    u
  end
end
