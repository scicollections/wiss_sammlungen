class Memo < InformationResource
  property "memo_subject", :string, cardinality: 1, affects_label: true
  property "text", :text, cardinality: 1, affects_label: true
  property "is_memo_for", :objekt, range: "Individual", fill_on_create: true, inverse: "has_memo", is_owner: true, affects_label: true, cardinality: 1
  
  access_rule action: [:view, :create, :edit, :delete], minimum_required_role: :manager

  def self.weak?
    true
  end
  
  def creator
    user_id = Revision.where(new_individual_id: id, individual_type: "Memo", action: "indi_create").first.user_id
    return User.find user_id
  end
  
  def last_updater
    if Revision.where(subject_id: id).any?
      user_id = Revision.where(subject_id: id, action: ["prop_update","prop_create","prop_delete"]).last.user_id
      return User.find user_id
    else
      return nil
    end
  end
  
  private

  def set_labels
    author = last_updater ? last_updater : creator
    str = "#{memo_subject ? memo_subject_value + " • ": ""}#{author} • #{ I18n.l(self.updated_at, format: :date_condensed )}"
    
    self.label = str
    self.inline_label = str
  end
  
  def self.migrate_old_internal_notes
    old_notes = Property.where(predicate: "internal_notes")
    
    old_notes.each do |old_note|
    
      indi = old_note.subject
      memo_text = old_note.data_text
      
      rev_user = Revision.where(property_id: old_note.id).first.user
      author_user = rev_user || User.find(1)
    
      _,_,memo,_,_ = IndividualManager.create_weak_individual author_user, indi, "has_memo", "memo_subject", "Interne Notiz"
      PropertyManager.set_property author_user, memo, "text", memo_text, rev: nil,
                              check_permissions: false, hide_on_global_list: true,
                              occured_at_id: nil, campaign_slug: nil
    end
  end
end