# Property Manager
#
# Manages properties.
#
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
# - card: cardinality
#
# All methods return [prop, rev], both of which can be nil. This is because there are some cases
# where the property manager just silently does nothing. These are:
#
# - set_property for card_1 data preds where no prop existed before with empty ("" or nil) value
# - set_property for card_many objekt preds where the value is a duplicate
# - delete_property for non-existent property ids
# - update_data_property where the value hasn't changed
#
# One might think that the property manager should raise an exception in these cases, but that would
# be weird at least in the first case, since the exact same call is valid for the case where a prop
# exists (the prop will be deleted in that case).
class PropertyManager
  # Set value for a given predicate.
  #
  # If a data property for a card-1 predicate already exists, {update_data_property} will be
  # called. Otherwise a new property will be created. For data properties, this means:
  #
  # > {include:set_data_property}
  #
  # For objekt properties, this means:
  #
  # > {include:set_object_property}
  #
  # @param user [User] The User who wants to perform this action. Will be referenced in the
  #   revision.
  # @param indi [Individual] The property's subject.
  # @param pred [String] The desired predicate of the property.
  # @param val [Individual, Integer, String, Float, DateTime] The value of the property. For objekt
  #   properties, this can be given as an individual object or as an ID.
  # @param rev [Revision, Integer] A revision object or ID to be updated. If none is given, a new
  #   one will be created.
  # @param check_permissions [Boolean] Can be set to false to skip permissions checks.
  # @param hide_on_global_list [Boolean] If set to true, the created revision will be hidden
  #   from the global revision list.
  # @param occured_at_id [Integer] Will be propagated to the revision.
  #
  # @return [Array<(Property, Revision)>] Both return values can be nil.
  # @raise [Error] If predicate is of type "Objekt", has cardinality of 1 and such a property
  #   exists already.
  def self.set_property user, indi, pred, val, rev: nil,
                        check_permissions: true, hide_on_global_list: false,
                        occured_at_id: nil, campaign_slug: nil
    indi = Individual.find(indi) unless indi.is_a?(Individual)
    if check_permissions && !user.can_edit_property?(subject: indi, predicate: pred)
      raise ForbiddenAction
    end

    is_objekt = (indi.type_of(pred) == :objekt)
    is_card_1 = (indi.cardinality_of(pred) == 1)
    prop = indi.send(pred)
    
    if is_card_1 && prop
      if is_objekt
        #raise "Replacement of ObjectProperties not implemented."
        delete_property(user,prop)
        set_object_property(user, indi, pred, val, hide_on_global_list, occured_at_id, campaign_slug: campaign_slug)
      else
        update_data_property(user, prop, val, rev: rev, occured_at_id: occured_at_id, campaign_slug: campaign_slug)
      end
    else
      if is_objekt
        set_object_property(user, indi, pred, val, hide_on_global_list, occured_at_id, campaign_slug: campaign_slug)
      else
        set_data_property(user, indi, pred, val, hide_on_global_list, occured_at_id, campaign_slug: campaign_slug)
      end
    end
  end

  # Update the value of a single data property. If the value is nil or an empty
  # string, the property will be deleted instead.
  #
  # @param user [User] The user who wants to perform this action. He/she has to have edit
  #   permissions for the given predicate and will be referenced in the revision.
  # @param prop [Property, Integer] The property. Can either be a property object or an ID.
  # @param val The property's value.
  # @param rev [Revision, Integer] A revision object or ID to be updated. If none is given, a new
  #   one will be created.
  # @param occured_at_id [Integer] If set, will be propagated to the revision.
  #
  # @return [Array<(Property, Revision)>] Both return values can be nil.
  #
  # @raise [ForbiddenAction] If the user doesn't have sufficient rights.
  # @raise [Error] If given predicate is an object predicate.
  # @raise [ActiveRecord::RecordInvalid] If given values don't pass validations.
  def self.update_data_property user, prop, val, rev: nil, occured_at_id: nil, campaign_slug: nil
    # Find prop by ID unless it is already given directly
    # TODO Don't raise exception if value is empty (i.e. the property would be deleted anyway),
    # just return [nil, nil] in that case.
    prop = Property.find(prop) unless prop.is_a?(Property)
    raise ForbiddenAction unless user.can_edit_property?(prop)
    raise Error, "This method is intended for data predicates." if prop.objekt?

    # Return early if value hasn't changed
    return [prop, nil] if (prop.value == val) || (prop.class == PropertyBool && val == prop.value.to_s)

    if val == nil || val == "" || (val == false && prop.property_type != :bool)
      delete_property user, prop
    else
      ActiveRecord::Base.transaction(requires_new: true) do
        if rev.blank?
          rev = Revision.new(user: user, campaign_slug: campaign_slug)
          rev.set_old_property(prop)
        elsif !rev.is_a?(Revision)
          rev = Revision.find(rev)
        end

        prop.value = val
        prop.save!

        prop.subject.save! if prop.subject.predicates[prop.predicate][:affects_label]

        if rev.old_value == val
          rev.destroy
        else
          rev.set_new_property(prop)
          rev.set_strong_individual_fields occured_at_id: occured_at_id
          rev.save!
        end

        [prop, rev]
      end
    end
  end


  # Delete a Property. If it is an object property, the inverse will be deleted
  # as well.
  # If the subject of the property is a weak individual and would have an empty
  # label after the deletion of the property, it will be deleted as well. This
  # can be turned off via the `delete_subject_on_empty_label` switch.
  # Also, if the object of the property has the subject set as its owner (thus
  # the object is weak), the object will be deleted to prevent a weak individual
  # without owner (i.e. an orphan).
  #
  # @param user [User] The user who wants to perform this action. He/she has to have edit
  #   permissions for the given predicate and will be referenced in the revision.
  # @param prop [Property, Integer] The property. Can either be a property object or an ID.
  # @param check_permissions [Boolean] If set to false, user permissions will be ignored.
  # @param hide_on_global_list [Boolean] If set to true, the created revision will be hidden
  #   from the global revision list.
  # @param delete_subject_on_empty_label [Boolean] See method description.
  # @param ignore_weak_orphans [Boolean] Force-delete property even though the weak subject has
  #   the object set as its owner (and thus become an orphan).
  #
  # @return [Array<(Property, Revision)>] Both return values can be nil.
  #
  # @raise [ForbiddenAction] if the user doesn't have sufficient rights.
  # @raise [Error] it the subject has the object set as its owner.
  # @raise [ActiveRecord::RecordInvalid] if given values don't pass validations.
  def self.delete_property user, prop, check_permissions: true,
                           hide_on_global_list: false,
                           delete_subject_on_empty_label: true,
                           ignore_weak_orphans: false, campaign_slug: nil
    # Find prop by ID unless it is already given directly (don't raise exception on non-existent
    # IDs).
    prop = Property.find_by(id: prop) unless prop.is_a?(Property)

    # Return early if there is nothing left to do, i.e. the property was already deleted in the
    # meantime by someone else.
    return [nil, nil] if prop.nil?

    if check_permissions && !user.can_edit_property?(prop)
      raise ForbiddenAction
    end

    if !ignore_weak_orphans && prop.subject.predicates[prop.predicate][:is_owner]
      raise "Can't delete property because its subject would become an orphan."
    end

    ActiveRecord::Base.transaction(requires_new: true) do
      prop.destroy
      # If the deletion of the property affects the label or inline_label of its
      # subject, save the latter so that the new labels will be computed.
      prop.subject.save! if prop.subject.predicates[prop.predicate][:affects_label]

      rev = Revision.create_from_old_property(prop, user,
                        hide_on_global_list: hide_on_global_list, campaign_slug: campaign_slug)

      if prop.objekt? and prop.inverse
        # If no inverse exists, this will throw an exception. But since we have
        # an object property, there must be one. 
        # This is not true for request_edit_privileges/request_publicicity
        # properties, therefore a check for inverse properties is added.
        prop.inverse.destroy
        Revision.create_from_old_property(prop.inverse, user, inverse: true, campaign_slug: campaign_slug)

        # Delete the object of the property iff the object is weak and the subject is its owner to
        # prevent weak orphans. ("is_owner" should in theory only be set for weak individuals,
        # making the first part of the condition redundant, BUT we'll leave it there just in case,
        # as accidentally deleting a non-weak individual is very bad.)
        obj = prop.objekt
        inv_pred = prop.inverse.predicate
        if obj.weak? && obj.predicates[inv_pred.to_s][:is_owner]
          IndividualManager.delete_individual(user, obj, hide_on_global_list: true,
                                              check_permissions: false, campaign_slug: campaign_slug)
        end
      end

      if delete_subject_on_empty_label && prop.subject.weak? &&
            prop.subject.label.empty?
        IndividualManager.delete_individual(user, prop.subject,
            hide_on_global_list: true, check_permissions: false, campaign_slug: campaign_slug)
      end

      [prop, rev]
    end
  end

  class << self
    private

    # Create a new data property and revision.
    # If it affects the individuals' label, save (and thereby validate) the latter
    # to compute the new labels.
    #
    # @param user [User] The User who wants to perform this action. Will be referenced in the
    #   revision.
    # @param indi [Individual] The property's subject.
    # @param pred [String] The desired predicate of the property.
    # @param val [String, Integer, Float, DateTime] The value of the Property. If nil or "", method
    #   returns without action.
    # @param hide_on_global_list [Boolean] If true, the revision is hidden from global list.
    # @param occured_at_id [Integer] Will be propagated to the revision.
    #
    # @return (see set_property)
    # @raise [ActiveRecord::RecordInvalid] If given values don't pass validations.
    def set_data_property user, indi, pred, val, hide_on_global_list, occured_at_id, campaign_slug: nil
      # Don't do anything if value is no value
      return [nil, nil] if val == nil || val == ""

      ActiveRecord::Base.transaction(requires_new: true) do
        # Create prop via AR
        prop = make_activerecord_call(indi, pred, val)

        # If the created property affects the label or inline_label of its
        # subject, save the latter so that the new labels will be computed.
        indi.save! if indi.predicates[pred.to_s][:affects_label]

        rev = Revision.new(user: user, hide_on_global_list: hide_on_global_list, campaign_slug: campaign_slug)
        rev.set_new_property(prop)
        # REVIEW is this necessary?
        if occured_at_id
          rev.set_strong_individual_fields occured_at_id: occured_at_id
        end
        rev.save

        [prop, rev]
      end
    end


    # Create a new object property, its inverse, a revision and inverse revision.
    # If it affects the individuals' label, save (and thereby validate) the latter
    # to compute the new labels. Same for the object.
    #
    # @param user [User] The User who wants to perform this action. Will be referenced in the
    #   revision.
    # @param indi [Individual] The property's subject.
    # @param pred [String] The desired predicate of the property.
    # @param val [Individual, Integer] The objekt of the property. Can be given directly or
    #   referenced by ID.
    # @param hide_on_global_list [Boolean] If true, the revision is hidden from global list.
    # @param occured_at_id [Integer] Will be propagated to the revision.
    #
    # @return (see set_property)
    # @raise [ActiveRecord::RecordInvalid] If given values don't pass validations.
    def set_object_property user, indi, pred, val, hide_on_global_list, occured_at_id, campaign_slug: nil
      # Find object by ID unless it is already given directly
      obj = val.is_a?(Individual) ? val : Individual.find(val)
      inv_pred = indi.inverse_of(pred)

      # TODO Check range and inverse range.

      # Return early if property already exists.
      # Note: To *really* prevent duplicates, we'd need a UNIQUE constraint in the database, as it's
      # possible that two requests are handled at the same time by different threads on the server.
      if existing_prop = indi.properties.find_by(predicate: pred, objekt_id: obj.id)
        return [existing_prop, nil]
      end
      ActiveRecord::Base.transaction(requires_new: true) do
        # Create prop via AR (with validation)
        prop     = make_activerecord_call(indi, pred,     obj)
        inv_prop = make_activerecord_call(obj,  inv_pred, indi)

        # If the created property affects the label or inline_label of its
        # subject, save the latter so that the new labels will be computed.
        indi.save! if indi.predicates[pred.to_s][:affects_label]
        # Same for the object
        obj.save! if obj.predicates[inv_pred.to_s][:affects_label]

        rev = Revision.new(user: user, hide_on_global_list: hide_on_global_list, campaign_slug: campaign_slug)
        rev.set_new_property(prop)
        rev.set_strong_individual_fields(occured_at_id: occured_at_id)
        rev.save
        inv_rev = Revision.new(user: user, inverse: true, campaign_slug: campaign_slug)
        inv_rev.set_new_property(inv_prop)
        inv_rev.set_strong_individual_fields
        inv_rev.save

        [prop, rev]
      end
    end

    # Perform the ActiveRecord create-call corresponding to the cardinality of the
    # predicate.
    #
    # subj - The subject.
    # pred - The predicate.
    # val  - The value (an Individual, if we have an object predicate)
    #
    # Returns the newly created property.
    # TODO Explain why we don't create Property instances directly here.
    def make_activerecord_call subj, pred, val
      # Using the "!" variants because we want exceptions like validation errors to bubble up.
      if subj.cardinality_of(pred.to_s) == 1
        subj.send("create_#{pred}!", value: val)
      else
        subj.send(pred).create!(value: val)
      end
    end
  end
end
