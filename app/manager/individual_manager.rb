# Individual Manager
#
# Manages Individuals

# Abbreviations:
#
# - indi: individual
# - pred: predicate
# - prop: property
# - val:  value
# - subj: subject
# - obj:  object
# - rev:  revision
# - inv:  inverse
class IndividualManager
  # Create a new strong individual.
  #
  # @param user [User] The user who wants to perform this action. He/she has to have creation
  #   permissions for the given Individual class and will be referenced in the revision.
  # @param klass [Class, String] The type of which the Individual shall be. This can be either a
  #   subclass of Individual-class or a name of one.
  # @param label [String] The label of the new Individual. If the label will be computed from
  #   properties, this parameter can be empty.
  # @param label_properties [Hash] In case the label will be computed from properties, those
  #   should be given here. A Hash consisting of predicate-value-pairs is expected.
  #
  # @return [Individual] The newly created Individual.
  # @raise [Error] If klass is not a subclass of Individual.
  # @raise [Error] If klass is a weak Individual-subclass.
  # @raise [ForbiddenAction] If the user doesn't have sufficient rights.
  # @raise [ActiveRecord::RecordInvalid] If given values don't pass validations.
  def self.create_individual user, klass, label, label_properties: {}, campaign_slug: nil
    klass = klass.constantize unless klass.is_a? Class
    raise "Given class has to be a subclass of Individual" unless klass <= Individual
    raise "This method is intended for strong Individuals only" if klass.weak?
    raise ForbiddenAction unless user.can_create_individual?(klass)

    ActiveRecord::Base.transaction(requires_new: true) do
      indi = klass.new(label: label)

      # No validation here if label properties are given, because the label
      # might be empty now, but will be computed later on.
      indi.save(validate: !label_properties.any?)

      label_properties.each do |pred, val|
        PropertyManager.set_property(user, indi, pred, val,
            hide_on_global_list: true, check_permissions: false, campaign_slug: campaign_slug)
      end

      # This is a temporary solution for *strong* individuals that have a set_labels method
      # that sets their *label* (*inline_label* like in SciCollection is no problem).
      # At the moment this is only ObjectGenreComplex. (It would also apply to person, but in this
      # case we supply the values relevant for the label upon creation.)
      # TODO Find a good solution for this.
      outsmart_set_labels = !indi.weak? && label.present? && indi.label.blank?

      if outsmart_set_labels
        indi.save!(validate: false)
        # update_columns will just update the columns, without any validations or callbacks
        indi.update_columns(label: label, inline_label: label)
      else
        # Save indi again, this time with validation
        indi.save!
      end

      # Create revision after label affecting properties has been set:
      Revision.create_from_new_individual(indi, user, campaign_slug: campaign_slug)

      # The newly created Individual is visible only for users, who have at least
      # the same role as the creator. (Except for Admin-Users, where the minimum
      # required role will be "manager")
      role = user.role == :admin ? :manager : user.role
      PropertyManager.set_property(user, indi, "visible_for", role,
          hide_on_global_list: true, check_permissions: false, campaign_slug: campaign_slug)

      if user.member?
        # Generally speaking, members don't have universal edit permissions, but
        # of course they can edit their own created Individuals.
        PropertyManager.set_property(user, user.person, "can_edit", indi,
            hide_on_global_list: true, check_permissions: false, campaign_slug: campaign_slug)
      end

      set_default_properties(user, indi)

      indi
    end
  end

  # Update the label of an existing strong individual. The corresponding
  # Revision will be destroyed if its old and new labels are the same.
  # As of now (Jan '17), all weak individuals have their labels computed from
  # properties, thus they can't be edited directly.
  # Also, if the given strong individual has its label computed (i.e. Persons),
  # this method has no effect.
  #
  # @param user [User] The user who wants to perform this action. He/she has to have edit
  #   permissions for the given Individual and will be referenced in the revision.
  # @param indi [Individual, Integer] Whose label shall be changed. This can be either an object of
  #   an Individual subclass or an ID referencing one.
  # @param new_label [String] The new label of the individual.
  # @param rev [Revision, Integer] A revision or revision ID. If none is given, a new one will be
  #   created.
  #
  # @return [Array<(Individual, Revision)>]
  # @raise [Error] If klass is a weak Individual-subclass.
  # @raise [ForbiddenAction] If the user doesn't have sufficient rights.
  # @raise [ActiveRecord::RecordInvalid] If given values don't pass validations.
  def self.update_individual user, indi, new_label, rev: nil, campaign_slug: nil
    # Find indi by ID unless it is already given directly
    indi = Individual.find(indi) unless indi.is_a?(Individual)
    raise "Cannot update the label of a weak Individual" if indi.weak?
    raise ForbiddenAction unless user.can_edit_individual?(indi)

    ActiveRecord::Base.transaction(requires_new: true) do
      if rev.blank?
        rev = Revision.new(user: user, campaign_slug: campaign_slug)
        rev.set_old_individual(indi)
      elsif !rev.is_a?(Revision)
        rev = Revision.find(rev)
      end

      indi.label = new_label
      indi.save!

      rev.set_new_individual(indi)

      # Don't create a revision if nothing has changed
      if rev.old_label == rev.new_label
        rev.destroy
      else
        rev.save!
      end

      [indi, rev]
    end
  end


  # Delete an individual and all connected properties.
  # Also, weak individuals having the given individual set as one of their
  # owners will be deleted as well.
  #
  # @param user [User] The user who wants to perform this action. He/she has to have edit
  #   permissions for the given Individual and will be referenced in the revision.
  # @param indi [Individual, Integer] To be deleted individual. Can be given as an instance or ID.
  # @param hide_on_global_list [Boolean] Whether to hide any created revisions on the global list.
  # @param check_permissions [Boolean] Use this to turn off permission checking.
  #
  # @return [Array<(Individual, Revision)>]
  # @raise [UndeletableIndividual] If indi is a ontology constant.
  def self.delete_individual user, indi, hide_on_global_list: false,
                             check_permissions: true, campaign_slug: nil
    # Find indi by ID unless it is already given directly
    indi = Individual.find(indi) unless indi.is_a?(Individual)

    if check_permissions
      raise ForbiddenAction unless user.can_delete_individual?(indi)
    end

    # check if ontology constant before starting to delete this indi's properties
    if indi.descriptive_id.present?
      raise ErrorController::UndeletableIndividual,
        "This Individual '#{indi.label}'(#{indi.id}) is an ontology constant " \
        "as indicated by its non-empty descriptive_id value "                  \
        "'#{indi.descriptive_id}' and thus must not be deleted."
    end

    ActiveRecord::Base.transaction(requires_new: true) do
      # Get last visibility now, because it might change when "visible_for" properties are deleted.
      last_visibility = indi.visibility
      
      # cache label before properties (that might define label) are deleted
      cached_label = indi.label

      # Delete all properties first. Don't check if the subject would have an
      # empty label, because we will delete it anyway. Also, don't complain if
      # the subject is weak and would become an orphan, for the same reason.
      indi.properties.reload.each do |prop|
        PropertyManager.delete_property(user, prop, hide_on_global_list: true,
            check_permissions: false, delete_subject_on_empty_label: false,
            ignore_weak_orphans: true, campaign_slug: campaign_slug)
      end

      if indi.destroy
        rev = Revision.create_from_old_individual(indi, user, cached_label,
                  hide_on_global_list: hide_on_global_list, campaign_slug: campaign_slug)

        # Set last visibility in all revisions that have indi as objekt.
        %w(old new).each do |str|
          Revision.where("#{str}_objekt_id" => indi.id).update_all(
            "#{str}_objekt_last_visibility_before_deletion" => last_visibility
          )
        end
      else
        # Individual couldn't be deleted. For example, this can happen when the
        # action is aborted by the before_destroy-callback.
        raise Error, "Der Individual konnte leider nicht gelöscht werden."
      end

      [indi, rev]
    end
  end

  # Create a new weak individual with an intitial property (fill_on_create or otherwise).
  #
  # @param user [User] The user who wants to perform this action. He/she has to have edit
  #   permissions for the given individual and will be referenced in the revision.
  # @param indi [Individual, Integer] First related strong individual. Can be given as an instance
  #   or ID.
  # @param spred [String] The predicate pointing from (strong) indi to weak individual
  #   ("s" is for "strong").
  # @param wpred [String] The predicate from weak_indi to other ("w" is for "weak").
  # @param value [Individual, Integer] Value of first weak indi property (given as Individual or ID).
  def self.create_weak_individual user, indi, spred, wpred, value, campaign_slug: nil
    # Find indi by ID unless it is already given directly
    indi = Individual.find(indi) unless indi.is_a?(Individual)
    wklass = indi.singular_range_of(spred).constantize
    raise ForbiddenAction unless user.can_create_individual?(wklass)
    raise ForbiddenAction unless user.can_edit_property?(subject: indi, predicate: spred)
    
    # if bool_delete_on_false flag is set block creation of "false" property and weak indi
    if (value == "false" && wklass.predicates[wpred][:bool_delete_on_false])
      return [nil, nil, nil, nil, nil]
    end

    ActiveRecord::Base.transaction(requires_new: true) do
      weak_indi = wklass.new
      weak_indi.save(validate: false)
      Revision.create_from_new_individual(weak_indi, user, hide_on_global_list: true, campaign_slug: campaign_slug)

      # Create objekt property between indi & weak_indi.
      sprop, srev = PropertyManager.set_property(user, indi, spred, weak_indi,
                                                 occured_at_id: indi.id, campaign_slug: campaign_slug)

      # Create objekt property between `weak_indi` & `value`.
      # Not checking permissions for this property, because:
      # - In all existing cases, the permission specification at `indi.spred` is enough to
      #   determine whether the action is permitted.
      # - In the case of Curatorships, the `other` side (the Person) even forbids editing. This
      #   is because users can't be allowed to add any SciCollection as curated_collection to
      #   themselves, as this would give them edit permission for the SciCollection.
      # TODO Only turn of permission checking for is_owner/fill_on_create?
      if value && wpred
        wprop, wrev = PropertyManager.set_property(user, weak_indi, wpred, value,
                                               check_permissions: false,
                                                 occured_at_id: indi.id, campaign_slug: campaign_slug)
      end

      weak_indi.save!
      srev.new_objekt_label = weak_indi.label
      srev.save!

      [sprop, srev, weak_indi, wprop, wrev]
    end
  end

  class << self
    private

    # Set default properties for a newly created individual.
    #
    # @param user The user.
    # @param indi The new individual.
    def set_default_properties user, indi
      indi.predicates.each do |pred, options|
        default_value = options[:default]
        next unless default_value

        # ObjektPropertys müssen speziell behandelt werden, da sich dort
        # Default-Values auf Objekte aus der Datenbank beziehen
        if options[:type] == :objekt
          # Ein Default für eine Property wird über die descriptive_id eines Individuals
          # definiert (z.B. property "bla", ..., default: "City" )
          descriptive_id = default_value

          begin
            default_value = Individual.find_by!(descriptive_id: descriptive_id)
          rescue ActiveRecord::RecordNotFound
            # This is definitely not supposed to happen; an ontology constant is
            # missing!
            raise %(
              While trying to create default property #{pred} of an
              Individual of type #{indi.class} an error occured:
              Ontology constant with descriptive_id #{descriptive_id}
              is missing; if you newly created this class or property, be sure
              to create a migration that creates the referenced ontology
              constant with descriptive_id #{descriptive_id}!
            ).squish
          end
        end

        PropertyManager.set_property(user, indi, pred, default_value)
      end
    end
  end
end
