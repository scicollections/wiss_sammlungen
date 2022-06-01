# Mailer that is responsible for sending error reports.
class ErrorMailer < ActionMailer::Base
  # Sends an error report mail to all addresses that are set in
  # `Maya::Application::APP_CONFIG["report_mails"]`.
  def report_error(env,session)
    @exception = env["action_dispatch.exception"]
    @datetime = DateTime.now
    @hostname = `hostname`.strip
    @rid = env["action_dispatch.request.request_id"]
    @rparams = env["action_dispatch.request.parameters"]
    @env = env
    @session = session
    # send mail to all recipients defined in config.yml
    @recipients = Maya::Application::APP_CONFIG["report_mails"] || []
    sender = Maya::Application::APP_CONFIG["support_mail"]
    subject = "Error on " + @hostname + ": " + @exception.inspect
    body = render_to_string "report", layout: false
    logger.info "Sending Mails to Report Email Addresses: " + @recipients.to_s
    Thread.new do
      @recipients.each do |recipient|
        logger.info "Reporting Error to " + recipient
        Mail.deliver do
          from sender
          to recipient
          subject subject
          body body
        end
      end
      # every thread opens its own db connection
      ActiveRecord::Base.connection.close
    end
  end

  # Same as {#report_error}, but for Fallback-Searches (where no Error is thrown).
  def report_search_error(env, exception, searcher)
    @exception = exception
    @datetime = DateTime.now
    @hostname = `hostname`.strip
    @rid = env["action_dispatch.request.request_id"]
    @rparams = env["action_dispatch.request.parameters"]
    @searcher = searcher
    @env = env
    # send mail to all recipients defined in config.yml
    @recipients = Maya::Application::APP_CONFIG["report_mails"] || []
    sender = Maya::Application::APP_CONFIG["support_mail"]
    subject = "Search-Error on " + @hostname + ": " + @exception.inspect
    body = render_to_string "search_report", formats: [:text], layout: false
    logger.info "Sending Mails to Report Email Addresses: " + @recipients.to_s
    Thread.new do
      @recipients.each do |recipient|
        logger.error "Reporting Error to " + recipient
        mail = Mail.new
        mail.from = sender
        mail. to = recipient
        mail.subject = subject
        mail.body = body
        mail.charset = "UTF-8"
        mail.deliver
      end
      # every thread opens its own db connection
      ActiveRecord::Base.connection.close
    end
  end
end
