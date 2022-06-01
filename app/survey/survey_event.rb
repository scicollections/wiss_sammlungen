class SurveyEvent < UserEvent
  
  after_save_commit :write_to_index
  
  def self.actions
    %i(invite remind access complete i_am_done add_to_survey survey_memo)
  end

  def self.create_invite user, action, campaign, target_user
    
  end
  
  def self.create_remember
    
  end
  
  def self.create_access
  end
  
  def self.create_completion
  end
  
  def self.create_event user, action, campaign, target_user
    self.create(user_id: user.id, campaign_slug: campaign, action: action, target_user_id: target_user)
  end
  
  def self.create_memo user, campaign_slug, target_user, text
    self.create(user_id: user.id, campaign_slug: campaign_slug, action: "survey_memo", target_user_id: target_user.id, text: text)
  end
  
  private
  def write_to_index
    if target_user
      Indexer.delayed_update
    end
  end
end