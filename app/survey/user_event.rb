class UserEvent < ApplicationRecord
  
  belongs_to :user, touch: true
  belongs_to :target_user, class_name: "User", foreign_key: "target_user_id", touch: true
  
  self.inheritance_column = :type 
  
  def self.types
    %w(MemberEvent RequestEvent SurveyEvent)
  end
end
