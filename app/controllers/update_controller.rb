# Die Aufgabe dieses Controllers ist es, eine API bereitzustellen, die von
# den Edit-Modals genutzt wird.
class UpdateController < ApplicationController
  # Nur authentifizierte User durchlassen
  before_action :authenticate_user!

  # @action POST
  # @url /update/individual
  def create_individual
    type = params[:type]

    indi = if type == "Person"
      label_props = Hash[%i(gender title first_name name).map { |sym| [sym, params[sym]] }]
      IndividualManager.create_individual(current_user, type, "", label_properties: label_props)
    else
      IndividualManager.create_individual(current_user, type, params[:label])
    end

    # Trigger delayed index update
    Indexer.delayed_update

    redirect_to "#{indi.path}?mode=edit"
  end

  # @action PUT
  # @url /update/individual
  def update_individual
    individual_id = params[:individual_id]
    revision_id = params[:revision_id]
    new_label = params[:value]

    _, rev = IndividualManager.update_individual(current_user, individual_id,
                                                 new_label, rev: revision_id)

    # Trigger delayed index update
    Indexer.delayed_update

    @glass = Glass.new(self)
    inline_predicate = params[:inline_predicate]
    inline_individual = Individual.find(params[:inline_individual_id])

    render json: {
      valid: true,
      inline_html: @glass.inline(inline_individual, inline_predicate),
      revision_id: (rev.destroyed? ? "" : rev.id),
      revision_message: rev.to_s,
    }
  end

  # @action DELETE
  # @url /update/individual
  def delete_individual
    indi, _ = IndividualManager.delete_individual(current_user, params[:id])

    # Trigger delayed index update
    Indexer.delayed_update

    redirect_to "#{indi.path}/revisions"
  end

  # @action GET
  # @url /validate/property
  #
  # Used to test whether the passed data would result in a valid property
  # withouth actually creating this property (i.e. dry-run creation). Is
  # accessed by glass-edit#validateProperty, which is called in one-column-edit-
  # modals when the user attempts to create a new Property.
  def validate_property
    predicate     = params[:predicate]
    individual_id = params[:individual_id]
    value         = params[:value]

    indi = Individual.where(id: individual_id).first

    # get class of predicate
    klass = indi.class_of predicate
    # and create new instance of this predicate class
    prop = klass.new
    prop.subject = indi
    prop.predicate = predicate
    prop.value = value

    # check validity of property instance
    begin
      if prop.valid?
        render json: {valid: true, revision_message: "Zum Bestätigen Enter drücken oder Hinzufügen klicken."}
      else
        # error message includes attribute name which is not useful here
        msg = prop.errors.messages[:data].first
        render json: {valid: false, revision_message: msg}
      end
    rescue => e
      # error message includes attribute name which is not useful here
      msg = e.message.split(' ')[1..-1].join(' ')
      render json: {valid: false, revision_message: msg}
    end
  end

  # @action POST
  # @url /update/property
  def create_property
    inline_id   = params[:inline_individual_id]
    inline_pred = params[:inline_predicate]
    inline_indi = Individual.find(inline_id)

    indi_id   = params[:individual_id]
    predicate = params[:predicate]
    value     = params[:value]
    
    campaign_slug = params[:campaign_slug]
    
    # check for complex property, card==1
    complex_prop_parent_id = params[:complex_prop_parent_id] || inline_id
    complex_prop_parent_indi = Individual.find(complex_prop_parent_id)
    complex_prop_predicate = params[:complex_prop_predicate] || inline_pred
    if params[:complex_prop_parent_id] && 1 == complex_prop_parent_indi.cardinality_of(complex_prop_predicate)
      indi_id = complex_prop_parent_indi.try(complex_prop_predicate).try(:objekt_id)
    end
    
    if indi_id.blank?
      # Create base property and weak individual because no indi_id is given
      base_prop, _, _, prop, rev =
        IndividualManager.create_weak_individual(current_user,
                                                 complex_prop_parent_indi, complex_prop_predicate,
                                                 predicate, value)
      # There is a case where we need both prop and base_prop: When we create an address
      # by setting the location property.
    else
      # prop and rev will be nil if value is empty
      prop, rev = PropertyManager.set_property(current_user, indi_id, predicate, value, campaign_slug: campaign_slug)
    end
    
    # Trigger delayed index update
    Indexer.delayed_update

    @glass = Glass.new(self)
    prop.reload
    render json: {
      valid: true,
      edit_html: (@glass.edit_property(prop) if prop),
      inline_html: @glass.inline(inline_indi, inline_pred),
      revision_id: (rev.id if rev),
      revision_message: rev.to_s,
      subject_id: (prop.subject.id if prop),
      subject_label: (prop.subject.label if prop), # Wird benutzt bei geändertem Address-Label
      base_property: (@glass.edit_property(base_prop) if base_prop),
      id: prop.id
    }
  end

  # @action PUT
  # @url /update/property
  #
  # @note Wird nicht für Objekt-Properties benutzt. Daher muss man hier auch
  #   nicht auf inverse Properties achten.
  def update_property
    individual_id = params[:individual_id]
    property_id   = params[:id]
    predicate     = params[:predicate]
    value         = params[:value]
    revision_id   = params[:revision_id]
    campaign_slug = params[:campaign_slug]

    inline_predicate = params[:inline_predicate]
    inline_individual_id = params[:inline_individual_id]
    inline_individual = Individual.find(inline_individual_id)

    complex_prop_parent_id = params[:complex_prop_parent_id] || params[:inline_individual_id]
    complex_prop_parent_indi = Individual.find(complex_prop_parent_id)
    complex_prop_predicate = params[:complex_prop_predicate] || inline_predicate
    
    # check for complex property, card==1
    if params[:complex_prop_parent_id] && 1 == complex_prop_parent_indi.cardinality_of(complex_prop_predicate)
      individual_id = complex_prop_parent_indi.try(complex_prop_predicate).try(:objekt_id)
    end
    
    if individual_id.blank?
      # User wants to create a single owner weak individual (e.g. WebResource)
      # and is currently entering the first data.
      base_prop, _, _, prop, rev =
        IndividualManager.create_weak_individual(current_user,
                                                 complex_prop_parent_indi, complex_prop_predicate,
                                                 predicate, value)
    elsif property_id.blank?
      # User wants to create a new data property for a weak individual
      prop, rev = PropertyManager.set_property(current_user, individual_id, predicate, value, occured_at_id: inline_individual_id, campaign_slug: campaign_slug)
    else
      # User wants to edit existing data property (of inline or weak indi)
      prop, rev = PropertyManager.update_data_property(current_user, property_id, value,
                                                       rev: revision_id,
                                                       occured_at_id: inline_individual_id,
                                                       campaign_slug: campaign_slug)
    end

    # Für den Fall, dass jemand manuell zwei Requests schickt mit value=""
    # (über die UI geht das eigentlich nicht).
    head :no_content and return unless prop

    # Trigger delayed index update
    Indexer.delayed_update

    @glass = Glass.new(self)

    render json: {
      valid: true,
      id: (prop.nil? || prop.destroyed? ? "" : prop.id),

      # Need to reload inline_individual, because its label might have changed.
      inline_html: @glass.inline(inline_individual.reload, inline_predicate),
      revision_id: (rev.nil? || rev.destroyed? ? "" : rev.id),
      revision_message: rev.to_s,
      subject_id: (prop.nil? || prop.subject.destroyed? ? "" : prop.subject.id),
      subject_label: (prop.subject.label if prop),

      # Für den Fall, dass der weak Indi und das Base-Property neu erstellt wurden,
      # liefere das Property-Html mit, so dass das in die Linke Spalte gebracht werden kann.
      base_property: (@glass.edit_property(base_prop) if base_prop),
      base_property_removed: (prop && prop.subject.destroyed?),

      # Gebe die Sichtbarkeit nur dann zurück, wenn sie geändert wurde, damit das Auge in der
      # UI angepasst werden kann.
      visibility: (prop.subject.visibility if predicate == "visible_for"),
    }
  end

  # @action DELETE
  # @url /update/property
  def delete_property
    id = params[:id]
    campaign_slug = params[:campaign_slug]
    delete_on_empty_flag = ActiveModel::Type::Boolean.new.cast(params[:delete_on_empty]) 

    # Wenn prop.subject weak ist, und das Label von prop.subject hiermit leer wird
    # (zB wenn man die Stadt von einer Adresse entfernt), dann wird hier prop.subject
    # gelöscht.
    #
    # (This will silently do nothing and return nils if the ID doesn't exist anymore.)
    prop, rev = PropertyManager.delete_property(current_user, id, 
                  campaign_slug: campaign_slug,
                  delete_subject_on_empty_label: delete_on_empty_flag)

    @glass = Glass.new(self)
    inline_predicate = params[:inline_predicate]
    inline_individual = Individual.find(params[:inline_individual_id])

    # Wollen wir gleich eine Range zurückgeben?
    # Nur bei weak Subjects, da man bei den anderen erstmal auf "Hinzufügen" klicken soll.
    if prop && prop.subject.weak? && prop.cardinality == 1
      range = @glass.new(prop.subject, prop.predicate)
    end

    # Trigger delayed index update
    Indexer.delayed_update
    render json: {
      inline_html: @glass.inline(inline_individual, inline_predicate),
      revision_message: rev.to_s,
      subject_label: (prop.subject.label if prop),
      base_property_removed: (prop.subject.destroyed? if prop),
      range: range,
    }
  end
  
  # PUT /update/table_row
  def new_table_row
    @glass = Glass.new(self, survey: true)
    individual = Individual.find params[:individual_id]
    predicate = params[:predicate]
    campaign_slug = params[:campaign_slug]

    sprop, _,_,_,_ = IndividualManager.create_weak_individual(current_user, individual, predicate, nil,nil, campaign_slug: campaign_slug)


    render json: {
      valid: true,
      inline_html: @glass.edit_property( sprop, locals: {as_table: true})
    }
  end
end
