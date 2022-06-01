class RequestEvent < UserEvent
  def self.actions
    %i(request_publicity, request_edit_privileges)
  end
end