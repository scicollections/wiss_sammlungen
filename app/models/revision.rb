# Represents a change to a {Property} or to an {Individual}.
class Revision < ApplicationRecord
  belongs_to :user
  belongs_to :subject, class_name: "Individual"
  belongs_to :old_individual, class_name: "Individual"
  belongs_to :new_individual, class_name: "Individual"
  belongs_to :old_objekt, class_name: "Individual"
  belongs_to :new_objekt, class_name: "Individual"
  belongs_to :occured_at_related_strong_individual, class_name: "Individual"
  belongs_to :other_related_strong_individual, class_name: "Individual"
  belongs_to :complex_property_parent_individual, class_name: "Individual"

  before_save :set_indexed, :set_creator_role, :set_action

  def self.create_from_new_individual indi, user, hide_on_global_list: false, campaign_slug: nil
    rev = self.new(hide_on_global_list: hide_on_global_list)
    rev.set_new_individual indi
    rev.user = user if user
    rev.campaign_slug = campaign_slug if campaign_slug
    rev.set_strong_individual_fields
    rev.save
    rev
  end

  def self.create_from_old_individual indi, user, label=nil,hide_on_global_list: false, campaign_slug: nil
    rev = self.new(hide_on_global_list: hide_on_global_list)
    rev.set_old_individual indi, label
    rev.user = user if user
    rev.campaign_slug = campaign_slug if campaign_slug
    rev.set_strong_individual_fields
    rev.save
    rev
  end

  def self.create_from_new_property prop, user, campaign_slug: nil
    rev = self.new
    rev.set_new_property prop
    rev.user = user if user
    rev.campaign_slug = campaign_slug if campaign_slug
    rev.set_strong_individual_fields
    rev.save
    rev
  end

  def self.create_from_old_property prop, user, hide_on_global_list: false, inverse: false, campaign_slug: nil
    rev = self.new(hide_on_global_list: hide_on_global_list, inverse: inverse)
    rev.set_old_property prop
    rev.user = user if user
    rev.campaign_slug = campaign_slug if campaign_slug
    rev.set_strong_individual_fields
    rev.save
    rev
  end

  def set_old_individual indi, label=nil
    self.old_individual_id = indi.id
    self.individual_type   = indi.type
    if label
      self.old_label = label
    else
      self.old_label         = indi.label
    end
  end

  def set_new_individual indi
    self.new_individual_id = indi.id
    self.individual_type   = indi.type
    self.new_label         = indi.label
  end

  def set_old_property prop
    self.property_id   = prop.id
    self.property_type = prop.type
    self.subject_id    = prop.subject.id
    self.subject_label = prop.subject.label
    self.subject_type  = prop.subject.type
    self.predicate     = prop.predicate

    if prop.objekt_id
      self.old_objekt_id    = prop.objekt_id
      self.old_objekt_label = prop.objekt.label
      self.old_objekt_type  = prop.objekt.type
    end

    self.old_data       = prop.data
    self.old_data_text  = prop.data_text
    self.old_data_int   = prop.data_int
    self.old_data_float = prop.data_float
    self.old_data_bool  = prop.data_bool
    self.old_data_date  = prop.data_date
  end

  def set_new_property prop
    self.property_id   = prop.id
    self.property_type = prop.type
    self.subject_id    = prop.subject.id
    self.subject_label = prop.subject.label
    self.subject_type  = prop.subject.type
    self.predicate     = prop.predicate

    if prop.objekt_id
      self.new_objekt_id    = prop.objekt_id
      self.new_objekt_label = prop.objekt.label
      self.new_objekt_type  = prop.objekt.type
    end

    self.new_data       = prop.data
    self.new_data_text  = prop.data_text
    self.new_data_int   = prop.data_int
    self.new_data_float = prop.data_float
    self.new_data_bool  = prop.data_bool
    self.new_data_date  = prop.data_date
  end

  # Feststellen, ob es sich um ein String-Property mit Options handelt,
  # das bei der Anzeige übersetzt werden soll.
  def translate
    return @translate if @translate != nil
    @translate = subject_type.constantize.predicates[predicate][:options] rescue false
  end

  def old_value
    return I18n.t(old_data, default: old_data) if old_data && translate

    old_objekt_label || old_objekt_id || old_data || old_data_text || old_data_int ||
      old_data_float || old_data_date || old_data_bool
  end

  def new_value
    return I18n.t(new_data, default: new_data) if new_data && translate

    new_objekt_label || new_objekt_id || new_data || new_data_text || new_data_int ||
      new_data_float || new_data_date || new_data_bool
  end

  def individual
    subject || old_individual || new_individual
  end

  # Brauchen dies zusätzlich zu "individual", da letzteres nil sein kann, obwohl eine id da
  # ist (nämlich wenn der individual inzwischen gelöscht wurde).
  def individual_id
    subject_id || old_individual_id || new_individual_id
  end

  def individual_label
    subject_label || old_label || new_label
  end

  def occured_at_individual
    if occured_at_related_strong_individual
      occured_at_related_strong_individual
    elsif individual
      if individual.weak?
        # Dieser Fall tritt auf, wenn es zwar eine occured_at_related_strong_individual_id
        # gibt, aber # dieser Individual schon gelöscht ist.
        nil
      else
        individual
      end
    else
      nil
    end
  end

  def occured_at_individual_id
    occured_at_related_strong_individual_id || individual_id
  end

  def occured_at_individual_label
    occured_at_related_strong_individual_label || individual_label
  end
  
  def weak_occured_at_indi_label search_indi_id
    print_occur_label = nil
    if complex_property_parent_individual_id
      print_occur_label = complex_property_parent_individual_label
    elsif occured_at_individual_id && other_related_strong_individual_id
      if occured_at_individual_id == search_indi_id
        print_occur_label = other_related_strong_individual_label
      else
        print_occur_label = occured_at_individual_label
      end
    end
    return print_occur_label
  end

  # @return [Boolean] Whether this is an Individual revision, i.e. "create individual", "delete
  #   individual" or "update label".
  def individual_revision?
    !!(old_individual_id || new_individual_id)
  end

  # @return [Boolean] Whether this is a Property revision, i.e. "create property", "update
  #   property" or "delete property".
  def property_revision?
    !!property_id
  end

  def h str
    ERB::Util.html_escape str
  end

  def to_s
    if property_id
      str = h(I18n.t(predicate)).to_str
      if new_data_bool
        # Boolean Properties brauchen eigenen Text
        str = "Als „#{str}“ markiert."
      elsif old_data_bool
        str = "Markierung als „#{str}“ entfernt."
      elsif old_value && new_value
        if subject_id != occured_at_individual_id
          str << " einer/s #{h I18n.t(occured_at_related_strong_individual_predicate)}"
        end
        str << " von „#{h old_value}“ zu „#{h new_value}“ geändert."
      elsif new_value
        if new_objekt && !new_objekt.weak?
          str << " <a href='#{new_objekt.path}'>#{h new_objekt_label}</a>"
        else
          if new_data_date
            str << " „#{h new_data_date.to_s(:ger_date)}“"
          else
            str << " „#{h new_value}“"
          end
        end
        if subject_id != occured_at_individual_id
          str << " zu #{h I18n.t(subject_type)}"
        end
        str << " hinzugefügt."
      else
        if old_objekt && !old_objekt.weak?
          str << " <a href='#{old_objekt.path}'>#{h old_objekt_label}</a>"
        else
          if old_data_date
            str << " „#{h old_data_date.to_s(:ger_date)}“"
          else
            str << " „#{h old_value}“"
          end
        end
        if subject_id != occured_at_individual_id
          str << " von #{h I18n.t(subject_type)}"
        end
        str << " entfernt."
      end

    else
      if old_individual_id && new_individual_id
        str = "Label von „#{h old_label}“ zu „#{h new_label}“ geändert."
      elsif new_individual_id
        str = "Datensatz erstellt."
      else
        str = "Datensatz gelöscht."
      end
    end
    str.html_safe
  end
  
  def to_html_compact
    if property_id
      str = h(I18n.t(predicate)).to_str
      str << ": "
      if new_data_bool
        # Boolean Properties brauchen eigenen Text
        str = "Als „#{str}“ markiert."
      elsif old_data_bool
        str = "Markierung als „#{str}“ entfernt."
      elsif old_value && new_value
        if subject_id != occured_at_individual_id
          str << " einer/s #{h I18n.t(occured_at_related_strong_individual_predicate)}"
        end
        str << "#{h old_value} => #{h new_value}"
      elsif new_value
        if new_objekt && !new_objekt.weak?
          str << " <a href='#{new_objekt.path}'>#{h new_objekt_label}</a>"
        else
          if new_data_date
            str << " #{h new_data_date.to_s(:ger_date)}"
          else
            str << " #{h new_value}"
          end
        end
        if subject_id != occured_at_individual_id
          str << " zu #{h I18n.t(subject_type)}"
        end
        #str << " hinzugefügt."
      else
        tmp_str = str
        str = ""
        if old_objekt && !old_objekt.weak?
          str << " <a href='#{old_objekt.path}'>#{h old_objekt_label}</a>"
        else
          if old_data_date
            str << " #{h old_data_date.to_s(:ger_date)}"
          else
            str << " #{h old_value}"
          end
        end
        if subject_id != occured_at_individual_id
          str << " von #{h I18n.t(subject_type)}"
        end
        str = tmp_str + "<del>#{str}</del>"
      end

    else
      if old_individual_id && new_individual_id
        str = "Label: „#{h new_label}“ (<del>#{h old_label}</del>)"
      elsif new_individual_id
        str = "Datensatz erstellt."
      else
        str = "Datensatz gelöscht."
      end
    end
    str.html_safe
  end

  # Fill the strong individual fields, i.e.
  # `occured_at_related_strong_individual_{id,label,predicate}` and
  # `other_related_strong_individual_{id,predicate}` with the respective values from the
  # owners of the individual this revision is about. (The owners are
  # specified through the calls to `property`.)
  #
  # As a result of this, the revision will be displayed on the *local* revision lists of both the
  # occured_at_related_strong_individual and the other_related_strong_individual. Additionally,
  # the revisions will be displayed on the *global* revision list associated with the
  # occured_at_related_strong_individual.
  #
  # @param occured_at_id [Integer] The ID of the strong individual the user was viewing when they
  #   made the changes, and therefore should be associated with this revision on the global
  #   revision list.
  # TODO Rename this to "set_owner_fields"?
  def set_strong_individual_fields occured_at_id: nil
    # Since owners (should) only be specified for *weak* individuals, this method
    # won't have any effects for strong individuals (and therefore doesn't need to be called for
    # those).
    return unless individual.weak?

    owners = individual.owners

    # Wenn ein Owner selbst das Objekt der Revision ist, dann sollen
    # ausnahmsweise *keine* "related strong individuals" in die Revision eingetragen
    # werden. Grund: Es wird eine Revision für das inverse Property erstellt werden, die
    # schon auf der lokalen Revision-Liste angezeigt wird. Die Info ist somit schon da.
    return if owners.any? { |indi, _| indi.id == new_objekt_id }
    
    # if it's a complex property and it's parent is weak (should be, otherwise indi isn't a complex prop)
    if individual.complex_property? && owners.try(:first).try(:first).try(:weak?)
      # if indi is a complex property, the first/nearest owner is it's parent
      self.complex_property_parent_individual_id = owners[0][0].id
      self.complex_property_parent_individual_label = owners[0][0].label 
      self.complex_property_parent_individual_predicate = owners[0][1]
      
      # for related strong indi fetch parent's owners
      owners = owners[0][0].owners
    end

    first_index = owners.index { |indi, _| indi.id.to_s == occured_at_id }

    if first_index
      self.occured_at_related_strong_individual_id        = owners[first_index][0].id
      self.occured_at_related_strong_individual_label     = owners[first_index][0].label
      self.occured_at_related_strong_individual_predicate = owners[first_index][1]
      owners.delete_at(first_index)
    elsif owners.any?
      self.occured_at_related_strong_individual_id        = owners[0][0].id
      self.occured_at_related_strong_individual_label     = owners[0][0].label
      self.occured_at_related_strong_individual_predicate = owners[0][1]
      
      owners.delete_at(0)
    end

    if owners.any?
      self.other_related_strong_individual_id        = owners[0][0].id
      self.other_related_strong_individual_label     = owners[0][0].label
      self.other_related_strong_individual_predicate = owners[0][1]
      owners.delete_at(0)
    end

    if owners.any?
      # TODO Sagen, dass man noch third_related_strong_individual_id braucht
    end
  rescue
    # TODO Laut beschweren, falls development mode
  end

  # Vorm Speichern indexed wieder auf false setzen, damit die Revision beim nächsten
  # Delayed-Update vom Indexer wieder erfasst wird
  def set_indexed
    self.indexed = false
    # Gebe hier nil und nicht false zurück, da sonst die save-Action nicht
    # ausgeführt werden kann (Danke, Rails...)
    nil
  end

  # Beim Speichern der Revision automatisch die Rolle des Subjekts in creator_role cachen
  def set_creator_role
    # da die Spalte :creator_role erst kürzlich hinzukam und es noch ausstehende Migrations gibt,
    # in denen Revision.save aufgerufen wird (20160309154605_run_derive_tasks) muss hier vorerst
    # noch geprüft werden, ob die Spalte :creator_role überhaupt schon existiert. Sobald im master
    # in schema.rb diese Spalte vorhanden ist, kann "&& self.attribute_present?(:creator_role)"
    # entfernt werden
    if self.user.present? && self.has_attribute?(:creator_role)
      self.creator_role = self.user.role
    end
  end

  def set_action
    self.action = derive_action || self.action
  end

  # Versuche die Aktion der Revision daraus abzuleiten, welche Felder gesetzt sind.
  # Das funktioniert für die meisten allgemeinen Aktionen, wie das Hinzufügen einer
  # Property zu einem Individual, nicht jedoch für spezielle Aktionen wie ein "send_invite", daher kann u.U. hier auch false zurückgegeben werden
  def derive_action
    # Revision bezieht sich auf eine Property
    # da new_value und old_value bei PropertyBools auch true/false sein können,
    # muss hier explizit auf nil geprüft werden
    if property_id
      if !new_value.nil? && !old_value.nil?
        "prop_update"
      elsif !new_value.nil?
        "prop_create"
      elsif !old_value.nil?
        "prop_delete"
      end
    # Revision bezieht sich direkt auf das Subjekt
    else
      if new_individual_id && old_individual_id
        "indi_rename"
      elsif new_individual_id
        "indi_create"
      elsif old_individual_id
        "indi_delete"
      else
        false
      end
    end
  end
end
