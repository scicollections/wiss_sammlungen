# Data Model: Person
class Person < Actor
  property "activity", :objekt, range: "Activity", inverse: "involved_person"
  property "organisation", :objekt, range: "Organisation", inverse: "person"

  # Dieses Property dürfen nur Manager setzen, da sich sonst ein Member zum Curator
  # von beliebigen Sammlungen machen könnte (wodurch er automatisch Edit-Rechte
  # bekäme).
  property "curated_collection", :objekt, range: "Curatorship", inverse: "curator",
    editable_for: :manager

  property "gender", :string, cardinality: 1, options: ["male", "female", "hello"]
  property "title", :string, cardinality: 1, options: ["dr", "prof"], affects_label: true
  property "first_name", :string, cardinality: 1, affects_label: true
  property "name", :string, cardinality: 1, affects_label: true

  property "year_of_death", :integer, cardinality: 1, editable_for: :manager, after_save: :set_death_note, after_destroy: :remove_death_note

  property "invite_mail_footer", :text, cardinality: 1, editable_for: :manager, visible_for: :manager

  property "can_edit", :objekt, range: "Individual",
    editable_for: :manager, visible_for: :manager, inverse: "can_be_edited_by"

  # Diese Properties setzen :member, die zusätzliche Rechte für bestimmte Individuals beantragen möchten
  property "request_publicity", :objekt, range: "Individual", visible_for: :manager
  property "request_edit_privileges", :objekt, range: "Individual", visible_for: :manager

  has_one :user, class_name: "User", foreign_key: "individual_id"
  has_many :user_events, through: :user

  access_rule action: [:edit, :delete], minimum_required_role: :manager
  access_rule action: [:create], minimum_required_role: :member

  # discover:
  category "actor"
  headline :self
  subheadline :organisation
  description :curated_collection, :curated_collection, :inline_label
  description :activity
  separator :description, " - "
  facet :subject,       :curated_collection, :curated_collection, :subject, {include_hidden: [:alt_label, :label_en]}
  facet :genre,         :curated_collection, :curated_collection, :genre, {follow_hierarchy: true, include_hidden: [:alt_label, :label_en]}
  facet :collection,    :curated_collection, :curated_collection
  facet :livingbeing,   :curated_collection, :curated_collection, :living_being
  facet :person,        :self
  facet :organisation,  :organisation
  facet :organisation,  :curated_collection, :curated_collection, :has_current_keeper
  facet :organisation,  :activity, :involved_organisation
  facet :activitytype,  :activity, :activity_type
  facet :place,         :address, :location
  facet :place,         :organisation, :location
  facet :place,         :organisation, :address, :location
  facet :place,         :curated_collection, :curated_collection, :location
  facet :place,         :curated_collection, :curated_collection, :address, :location
  facet :state,         :address, :location, :state
  facet :state,         :organisation, :address, :location, :state
  facet :reproduction,  :curated_collection, :curated_collection, :digital_collection, :digital_collection , :reproduction
  facet :organisationtype,    :organisation, :organisation_type
  facet :organisationtype,    :curated_collection, :curated_collection, :has_current_keeper, :organisation_type
  facet :organisationtype,    :activity, :involved_organisation, :organisation_type
  facet :collectiontype,      :curated_collection, :curated_collection, :collection_type
  facet :collectionrole,      :curated_collection, :curated_collection, :role
  facet :vocab,         :same_as

  facet "Email", :email

  # Persons that are connected with a User can be destroyed 
  # If revisions caused by the user exist the user must not be destroyed 
  # (revisions' author must be permanent).
  def destroy
    if self.user.present?
      # allow deletion of a person connected to a user if no revisions where created by this user
      if Revision.where(user_id: self.user.id).where.not(action: "join").count == 0
        # delete user and related user_events (of which the user is target)
        self.user.destroy
      else
        # otherwise: keep user and only delete person
        self.user.update(individual_id: nil)
        
        # At this point, user's name fields have been cleared by set_labels because the
        # IndividualManager destroyed all properties (including name properties).
        # To ensure this destroy method can be used e.g. from console and not only via manager
        # we do not cache the name there but restore them here using revisions.
        last_name = Revision.where(subject_id: self.id, predicate: "name").last.old_data
        last_first_name = Revision.where(subject_id: self.id, predicate: "first_name").last.old_data
        self.user.update(name: last_name)             if self.user.name.empty?
        self.user.update(first_name: last_first_name) if self.user.first_name.empty?
      end
    end
    
    super
  end

  # (see Individual#sort_label)
  def sort_value
    inline_label
  end

  # (see Individual#facet_value)
  def facet_value
    inline_label
  end
  
  def index_value
    inline_label
  end

  # Get all individuals that this person may edit implicitly. Edit rights are implied for:
  #
  # * the Person itself
  # * SciCollections via 'curated_collection'
  # * Activitys via 'activity'
  # * Organisations with OrganisationType not "Univerisität", "Hochschule",
  #   "Kunst- oder Musikhochschule" via 'organisation'
  # * for Organisations of OrganisationType "Sammlungskoordination" via
  #     'organisation'
  #     * SciCollections via 'associated_collection' of this
  #       Sammlungskoordination
  #     * for Organisations of OrganisationType "Universität" via
  #       'related_actor' of this Sammlungskoordination
  #          * SciCollections via 'current_keeper' of this Universität
  #          * SciCollections via 'associated_collection' of this Universität
  #
  # @return [Array<Individual>]
  def automatically_editable
    return @automatically_editable if @automatically_editable

    uni_type = OrganisationType.where(label: 'Universität').first
    koord_type = OrganisationType.where(label: 'Sammlungskoordination').first

    raise "Organisation type(s) missing!" if uni_type.nil? || koord_type.nil?

    arr = [self]
    arr += curated_collection_value.map(&:curated_collection_value)
    arr += activity_value
    arr += organisation_value.reject { |x| not x.allows_automatic_editing? }

    koords = organisation_value.select { |x| x.organisation_type_value.include?(koord_type) }
    koords.each do |k|
      arr += k.associated_collection_value
      unis = k.related_actor_value.select { |x| x.is_a?(Organisation) && x.organisation_type_value.include?(uni_type) }
      unis.each do |u|
        arr += u.current_keeper_value
        arr += u.associated_collection_value
      end
    end

    @automatically_editable = arr.compact.uniq

    # Note: We could add a variant of this called "automatically_editable?(individual)" that
    # re-implements the above logic, but will only do the necessary checks w.r.t the passed
    # individual, which will be much faster. This doesn't seem necessary at the moment, though.
  end

  # @return [Boolean] Whether the person can explicitly edit the individual.
  def explicitly_editable? indi
    # Get all ids, because this will usually be called often, namely when showing ranges.
    @can_edit_ids ||= can_edit.pluck(:objekt_id)
    @can_edit_ids.include?(indi.id)
  end

  # Get all Persons that are allowed to edit this Person, which is the Person itself.
  #
  # @return [Array<Person>]
  def automatically_editable_by
    # all Persons may edit themselves
    [self]
  end

  # Gib eine Liste von Individuals zurück, die ein mit dieser Person verknüpfter
  # User implizit (automatically_editable) als auch explizit (can_edit Properties)
  # bearbeiten darf.
  #
  # @return [Array<Individual>] An array of individuals sorted by their label.
  def editable_individuals
    # explizit bearbeitbare Individuals (über eine can_edit-Property definiert)
    exp_ed = self.can_edit.collect{|prop| prop.value}
    # implizit bearbeitbare Individuals
    imp_ed = automatically_editable
    # join Lists, remove duplicates
    exp_ed.concat(imp_ed).uniq.sort{|x,y| x.label <=> y.label}
  end

  # @return [Array<Integer>] The IDs of all individuals this person can edit.
  def all_editable_individual_ids
    # TODO Die weak indis fehlen (gesetzt den Fall, dass in Revisionsfilter auch die weak
    # tyes auftauchen sollen)
    automatically_editable.map(&:id) + can_edit.pluck(:objekt_id)
  end

  include HomeHelper
  # @example
  #   Prof. XXX Name -> Sehr geehrte(r) Professor/Professorin Name
  # @example
  #   Dr. XXX Name -> Sehr geehrte(r) Dr. Name
  #
  # @return [String] A salutation in german + shortened version of the Person's possibly numerous
  #   titles (gendered correctly).
  def mail_salutation
    gender = self.safe_value "gender"
    greeting_hash = {
      female_sal: "Sehr geehrte Frau",
      male_sal: "Sehr geehrter Herr"
    }
    sal = greeting_hash.fetch("#{gender}_sal".to_sym, "Hallo")
    if self.safe_value("title") == "prof"
      sal += " #{t_gender "prof", gender}"
    elsif self.safe_value("title") == "dr"
      sal += " #{t_gender "dr", gender}"
    else
      sal += " #{self.safe_value('first_name').strip}"
    end

    "#{sal} #{self.safe_value('name').strip}"
  end
  
  def survey_states
    if user && Campaign.current
      campaign_states = Campaign.current.campaigns_and_states_for_user(self.user)
      campaign_states.collect{|slug,status| {slug: slug, status: status}}
    else
      nil
    end
  end

  private

  def set_labels
    new_label = [
      I18n.t( safe_value("title", false), default: ""),
      safe_value("first_name", false),
      safe_value("name", false)
    ].compact.join(" ")
    # only set new label if it contains anything to avoid setting an empty
    # new_label
    self.label = new_label.present? ? new_label : self.label

    new_inline_label = [
      safe_value("name", nil),
      [
        I18n.t( safe_value("title", nil), default: ""),
        safe_value("first_name", nil)
      ].compact.join(" ")
    ].reject { |c| c.nil? || c.empty? }.join(", ")
    # only set new inline_label if it contains anything to avoid setting an
    # empty new_inline_label
    self.inline_label = new_inline_label.present? ? new_inline_label : self.label

    if u = self.user
      u.update(first_name: safe_value("first_name"), name: safe_value("name"))
    end
  end
  
  def set_death_note prop
    if info_text
      info_text.value = "Diese Person ist #{prop.value} verstorben."
      info_text.save!
    else
      create_info_text!(value: "Diese Person ist #{prop.value} verstorben.")
    end
  end
  
  def remove_death_note prop
    info_text.destroy
  end
end
