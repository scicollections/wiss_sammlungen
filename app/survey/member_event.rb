class MemberEvent < UserEvent
  def self.actions
    %i(invite, join)
  end
end