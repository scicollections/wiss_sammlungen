if defined?(ActionMailer)
  class MayaUserMailer < Devise::Mailer 
    helper :application # gives access to all helpers defined within `application_helper`.
    include Devise::Controllers::UrlHelpers # Optional. eg. `confirmation_url`
    default template_path: 'devise/mailer' # to make sure that your mailer uses the devise views
    
    
    include Devise::Mailers::Helpers

    def confirmation_instructions(record, token, opts={})
      opts = set_postoffice_mail(opts)
      super
    end

    def reset_password_instructions(record, token, opts={})
      opts = set_postoffice_mail(opts)
      super
    end

    def unlock_instructions(record, token, opts={})
      opts = set_postoffice_mail(opts)
      super
    end

    def email_changed(record, opts={})
      opts = set_postoffice_mail(opts)
      super
    end

    def password_change(record, opts={})
      opts = set_postoffice_mail(opts)
      super
    end
    
    private
    
    def set_postoffice_mail(opts)
      po = PostOffice.new
      
      recipient = po.to_address(opts[:to])
      if recipient
        opts[:to] = recipient
      end
      return opts
    end
    
  end
end