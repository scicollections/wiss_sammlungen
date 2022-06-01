# This class shall be seen as an abstract class.
# Therefore all methods in this class should raise a NotImplementedError. Excluded are some static methods like 'all' and 'current'
# Campaigns have to be subclasses of this class and implement the methods listed here.
# 

class Campaign

  # list of statuses a survey participant can adopt
  STATUSES = %i(
    initial
    blocked
    invited
    in_progress
    done
    completed
  )
  
  # list of event actions and their corresponding statuses
  ACTIONASSIGN = {
    block: :blocked,
    invite: :invited,
    remind: :invited,
    access: :in_progress,
    i_am_done: :done,
    complete: :completed,
    add_to_survey: :initial
  }
  
  # @return [List] a list of all Campaign classes
  def self.all
    self.descendants
  end
  
  # @return [List] a list of running and upcoming Campaign classes
  def self.all_current_and_future
    all.select{|campaign|campaign.end >= DateTime.now}
  end
  
  # @return [Class] current campaign if there is one, else `nil`
  def self.current
    now = Time.now
    campaign = "Campaign18".constantize
    if campaign.begin <= now and campaign.end >= now
      return campaign
    else
      return nil
    end
  end
  
  # @param slug [String] slug to specify campaign
  # @return [Campaign] given its slug
  def self.get slug
    return slug.constantize
  end
  
  # @param user [User] 
  # @return [Symbol] status of user for this campaign
  def self.user_status user
    return :initial if user.blank?
    
    event = last_status_user_event(user)
    if event.blank?
      return :initial
    else
      return ACTIONASSIGN[event.action.to_sym]
    end
    
  end
  
  # @param user [User]
  # @return [Hash] of states the given user has for all existing campaigns 
  def self.campaigns_and_states_for_user user
    states = Hash[Campaign.all_current_and_future.collect {|campaign| [campaign.slug, :initial]}]
    return states if user == nil
    user.user_events.group_by(&:campaign_slug).each do |campaign_slug, user_events|
      if user_events
        states[campaign_slug] = ACTIONASSIGN[user_events.last.action.to_sym]
      else
        states[campaign_slug] = :initial
      end
    end
    states
  end
  
  # @param indis [Array<Individual>] list of individuals that are survey targets
  # @return [Hash] of states the given indidivuals has in all campaigns
  def self.campaigns_and_states_for_indis indis
    campaigns = Campaign.all_current_and_future
    states = Hash[campaigns.collect {|campaign| [campaign.slug, STATUSES[0] ]}]
    
    people  = campaigns.collect{|c| c.resolve_addressees_for_indis(indis)}.flatten.uniq
    users = people.collect &:user
    user_states = users.collect{|user| campaigns_and_states_for_user(user)}
    user_states.each do |user_state|
      # use highest user/curator's state as sci_coll state
      campaigns.each do |campaign|
        slug = campaign.slug
        if campaign.higher_status?(user_state[slug], states[slug])
          states[slug] = user_state[slug]
        end
      end
    end
    states
  end
  
  # Returns statuses escpecially to be interpreted by ui (text and css). E.g. returns invited-overdue when user was invited for 28 days without taking any action.
  # @param [User] user
  # @return [Symbol] returns the given user's css status for this campaign  
  def self.userstatus_css_class user
    event = last_status_user_event(user)
    if event.action == "remind"
      return :reminded
    elsif event
      status = ACTIONASSIGN[event.action.to_sym]
      if status == :invited
        
        days_since_invite = ((Time.zone.now - event.created_at).to_i / 86400) 
        return (days_since_invite > 28) ? "invited-overdue" : "invited"
      else
        return status
      end
    else
      return :initial
    end
  end
  
  # @param [User] user
  # @return [SurveyEvent] the most recent event which determines the user's survey status 
  def self.last_status_user_event user
    return nil if user.blank?
    SurveyEvent.where(campaign_slug: slug,target_user_id: user.id,action: Campaign::ACTIONASSIGN.keys)
          .order("created_at DESC").limit(1).first
  end
  
  # Determines whether the given user has at **least** a given survey status. See {Campaign::STATUSES}
  # @param [User] user
  # @param [Symbol] required_status
  # @return [Boolean]
  def self.at_least_status? user, required_status
    raise "Bitte Status als Symbol übergeben" unless required_status.is_a? Symbol

    my_index = STATUSES.index(self.user_status(user))
    required_index = STATUSES.index(required_status)

    my_index && required_index && my_index >= required_index
  end
  
  # Determines whether the given user has at **most** a given survey status. See {Campaign::STATUSES}
  # @param [User] user
  # @param [Symbol] acceptable_status
  # @return [Boolean]
  def self.at_most_status? user, acceptable_status
    raise "Bitte Status als Symbol übergeben" unless acceptable_status.is_a? Symbol

    my_index = STATUSES.index(self.user_status(user))
    required_index = STATUSES.index(acceptable_status)

    my_index && required_index && my_index <= required_index
  end
  
  # @param [Symbol] status1 first survey status
  # @param [Symbol] status2 second survey status
  # @return [Boolean] whether status1 is a higher survey state than status2
  def self.higher_status? status1, status2
    index1 = STATUSES.index(status1)
    index2 = STATUSES.index(status2)

    index1 && index2 && index1 > index2
  end
  
  def self.get_next_higher_status status
    my_index = STATUSES.index(status.to_sym)
    if my_index < STATUSES.size
      STATUSES[my_index+1]
    else
      nil
    end
  end
  
  def self.get_higher_statuses status
    my_index = STATUSES.index(status.to_sym)
    if my_index < STATUSES.size
      STATUSES[my_index+1..STATUSES.size]
    else
      []
    end
  end
  
  # @param opts [Hash]
  # return [Array<Hash>] list of elasticsearch result hashes
  def self.index_targets opts
    filter = opts[:filter].try(:to_sym) || :initial
    
    conf = {
      query: opts[:searchterm],
      mode: :surveycounter,
      scope: :manager,
      klass_filter: targetclass,
      campaign_slug: slug
    }
    if (filter == :active)
      conf[:survey_status_exclude] = [:initial,:completed]
    elsif (filter != :all)
      conf[:survey_status] = filter
    end
    if opts[:page]
      conf[:from] = opts[:page] * 50
    else
      conf[:size] = 10000
    end
    
    search = Searcher.new
    search.configure conf
    search.execute
    
    return search.results
  end
  
  # @return [Array] the list of all users automatically listed as addressees, e.g. curators of SciCollections
  def self.addressees opts
    results = index_targets(opts)

    indi_ids = results.collect{|hash| hash[:id]}

    indis = Individual.where(id: indi_ids).order("inline_label ASC")
    return indis.collect{|indi| {individual: indi, persons: resolve_addressees_for_indis([indi]), status: :initial}}
  end
  
  # @param [Symbol] state survey state to be used as a filter
  # @return [Integer] number of survey targets with given class and survey status
  def self.count_survey_targets state
    return index_targets({mode: :surveycounter, filter: state}).size ||= 0
  end
  
  # @param [User] sender_user sender of the invitation
  # @param [Person] person addressee 
  # @return [String] html of invitation message
  def self.invite_message sender_user, person, urlprefix: nil
    html = SurveyController.render(
      partial: 'survey/'+slug+'/mail_texts/invite',
      formats: [:text], 
      handlers: [:erb], 
      locals: {person: person, sender_user: sender_user, urlprefix: urlprefix}
    )
  end
  # @param [User] sender_user sender of the reminder message
  # @param [Person] person addressee 
  # @return [String] html of reminder message
  def self.remind_message sender_user, person, urlprefix: nil
    html = SurveyController.render(
      partial: 'survey/'+slug+'/mail_texts/remind',
      formats: [:text], 
      handlers: [:erb], 
      locals: {person: person, sender_user: sender_user, urlprefix: urlprefix}
    )
  end
  
  # provides the manager who invited a given user
  # @param [User] user who is an addressee in the campaign
  # @return [User] the manager who invited the given user
  def self.get_user_inviter user
    return nil unless user
    SurveyEvent.where(campaign_slug: slug,target_user_id: user.id,action: "invite")
          .order("created_at DESC").limit(1).first.try(:user)
  end
  
  # provides the manager's name who invited a given user
  # @param [User] user who is an addressee in the campaign
  # @return [String] manager's name or *Support*
  def self.get_user_inviter_name user
    if (inviter = get_user_inviter user).is_a? User
      inviter.to_s
    else
      "Support"
    end
  end
  
  def self.get_user_inviter_email user
    if (inviter = get_user_inviter user).is_a? User
      inviter.email
    else
      "support@wissenschaftliche-sammlungen.de"
    end
  end
  
  # resolves the addressees for given individuals in a survey context
  # @param path [Array<Symbol>] path of methods to get from an individual to a person
  # @param indis [Array<Individual>] individuals to start resolving with. nil means all
  # @param start [Boolean] recursive anchor
  # @return [Array<People>] list of addressees (Instances of {Person})
  def self.resolve_addressees path, indis=[], start=false
    if path.empty?
      return indis
    elsif start
      indis = indis.blank? ? targetclass.constantize.all : indis
      return resolve_addressees path, indis
    else
      indis = indis.collect{|indi| indi.try("#{path.first.to_s}_value")}
      return resolve_addressees path[1..], indis.flatten
    end
  end
  
  # Wrapper for 'resolve_addressees'
  # @param indis [Array<Individual>] individuals to start resolving with. nil means all
  # @return [Array<People>] list of addressees (Instances of {Person})
  def self.resolve_addressees_for_indis indis=nil
    return resolve_addressees(path_to_people,indis,true)
  end
  
  
  # @param path [Array<Symbol>]
  # @param person [Person] person that is responsible for individuals to be resolved by this method
  # @param indis [Array<Individual>] recursive accumulator
  # @return [Individual] list of individuals the person is responsible for (in survey context)
  def self.resolve_indis path, person, indis=[]
    if path.empty?
      return indis
    elsif person.present?
      return resolve_indis(path,nil,[person])
    else
      indis = indis.collect{|indi| indi.try("#{path.first.to_s}_value")}
      return resolve_indis(path[1..],nil,indis.flatten)
    end
  end
  
  # wrapper for 'resolve_indis'
  # @param user [User]
  # @return [Individual]
  def self.resolve_indis_for_user user
    person = Individual.find user.individual_id
    return resolve_indis(path_to_indis, person, [])
  end
  
  # wrapper for 'resolve_indis'
  # @param person [Person]
  # @return [Individual]
  def self.resolve_indis_for_person person
    return resolve_indis(path_to_indis, person, [])
  end
  
  # a unique string identifier e.g. "campa17"
  # @return [String] slug (the unique identifier string)
  def self.slug
    return self.to_s
  end
    
  def self.surveymapping
    @surveymapping ||= {}
  end

  # specify targets and their path to person indis (and therefore users) 

  def self.set_begin date
    set_surveymapping :begin, date
  end
  
  def self.set_end date
    set_surveymapping :end, date
  end
  
  def self.set_name name
    set_surveymapping :name, name
  end
  
  def self.begin
    raise NotImplementedError unless surveymapping[:begin]
    surveymapping[:begin]
  end
  
  def self.name
    raise NotImplementedError unless surveymapping[:name]
    surveymapping[:name]
  end
  
  def self.end
    raise NotImplementedError unless surveymapping[:end]
    surveymapping[:end]
  end

  def self.set_targetclass klassname
    set_surveymapping :class, klassname
  end
  
  def self.set_path_to_people *args
    set_surveymapping :path_to_people, args
  end
  
  def self.set_path_to_indis *args
    set_surveymapping :path_to_indis, args
  end

  def self.targetclass
    raise NotImplementedError unless surveymapping[:class]
    surveymapping[:class]
  end
  
  def self.path_to_people
    raise NotImplementedError unless surveymapping[:path_to_people]
    surveymapping[:path_to_people]
  end
  
  def self.path_to_indis
    raise NotImplementedError unless surveymapping[:path_to_indis]
    surveymapping[:path_to_indis]
  end
  
  private

  def self.set_surveymapping key, args
    @surveymapping ||= {}
    @surveymapping[key] = args
  end

  def self.add_surveymapping key, args
    @surveymapping ||= {}
    @surveymapping[key] ||= []
    @surveymapping[key] << args
  end
  
end
