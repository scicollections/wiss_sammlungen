# Application-wide handler for server and client errors.
#
# @see http://stackoverflow.com/a/19279062/1870317
class ErrorController < ActionController::Base
  before_action :status, :report, except: [:unknown_post_route]

  # Renders specific view if a view with name error/e<http-error-code> is present,
  # e.g. "error/404", and a default error view otherwise.
  def show
    @page_title = "Fehler " + @status.to_s + (@page_title || "")

    if request.xhr? || request.format == :json
      render status: @status, json: {
        msg: @exception.message,
        errors: (@exception.record.errors.values.flatten rescue nil)
      }
    else
      # cascading error rendering: when an error is raised while rendering
      # an error, the next rendering attempt will be more done error-resistent
      begin
        # in case of db connectivity failure simply display raw error page; it's ok
        # for the response to be ugly if the service is basically offline
        if @exception.class == Mysql2::Error
          render "no_db_connection", layout: false
        # if migrations are pending, layout has to be deactivated; otherwise for each
        # side-loaded component (like stylesheets) a timeout is running down (followed
        # by an ActiveRecord::ConnectionTimeoutError) which makes the response time enormous
        elsif @exception.class == ActiveRecord::PendingMigrationError
          render @status.to_s, status: @status, layout: false
        else
          render @status.to_s, status: @status, layout: "error"
        end
      rescue Exception
        render "show_default", layout: false
      end
    end
  end
  
  # catches all unknown/undefined post requests
  def unknown_post_route
    raise ErrorController::RoutingError
  end
  
  # Logs the error's stacktrace and sends mail notifications if critical.
  def report
    # display error message on client side in dev env
    flash[:error] = @exception if Rails.env == "development"
    # print exception backtrace to server log
    logger.error puts "ErrorController Exception Report: " + @exception.to_s
    logger.error puts @exception.backtrace

    # check criticality of exception (only report critical errors)
    mailer = ErrorMailer.report_error request.env,session if critical? @exception
    logger.info "ErrorMailer Object is " + mailer.to_s
  end

  # Extracts relevant information from exception.
  def status
    @exception  = request.env['action_dispatch.exception']
    @status     = ExtendedExceptionWrapper.new(request.env, @exception).status_code
    @response   = ExtendedExceptionWrapper.rescue_responses[@exception.class.name]
    logger.error "Processing " + @exception.class.to_s + " by ErrorController"
  end

  # ActionDispatch::ExceptionWrapper does not cover all HTTP-Errors, especially
  # not 403/Forbidden. This extending class simply adds a mapping from Exceptions of
  # class Forbidden to :forbidden, that is thrown into Rack::Utils.staus_code in
  # ExtendedExceptionWrapper's superclass and ensures correct processing of Forbidden
  # exceptions in ErrorController.
  class ExtendedExceptionWrapper < ActionDispatch::ExceptionWrapper
    @@rescue_responses = self.superclass.rescue_responses.merge(
      'ErrorController::Forbidden' => :forbidden,
      'ForbiddenAction' => :forbidden,
      'ErrorController::UndeletableIndividual' => :forbidden,
      'ActiveModel::StrictValidationFailed' => :bad_request,
      'ErrorController::UserWithoutPerson' => :server_error,
      'ErrorController::InvalidToken' => :bad_request,
      'ErrorController::NoFacetKey' => :bad_request,
      'ErrorController::Gone' => 410,
      'ActionView::MissingTemplate' => :bad_request,
      'ErrorController::RoutingError' => :bad_request
    )
  end

  # This class is used to trigger a 403/Forbidden error on application level
  # using 'raise ErrorController::Forbidden'. The exception then is catched within ErrorController
  # and processed accordingly.
  # This class is used by ExtendedExceptionWrapper to define proper exception handling on HTTP-level.
  class Forbidden < ActionController::ActionControllerError; end

  # This class is used to trigger a 500/server error in case a User is requested
  # that is not associated with a Person.
  class UserWithoutPerson < ActionController::ActionControllerError; end

  # Used to trigger a 403/server error in case a User tries to register with an invalid (probably
  # expired) token.
  class InvalidToken < ActionController::ActionControllerError; end

  # Indicates that a requested Individual existed in the past, but not anymore.
  class Gone < ActionController::ActionControllerError; end

  # Is thrown when an Individual with non-empty descriptive_id is deleted.
  class UndeletableIndividual < ActionController::ActionControllerError; end

  # Is thrown when a search fails because of a missing facet key.
  class NoFacetKey < ActionController::ActionControllerError; end
  
  class MissingTemplate < ActionController::ActionControllerError; end

  class MissingTemplate < ActionController::ActionControllerError; end
  
  class RoutingError < ActionController::ActionControllerError; end

  private

  # This method classifies errors as critical or uncritical. It is used to
  # decide whether an error report should be sent out or not. Unknown
  # statuscodes or errorclasses are considered critical. To define errors as
  # uncritical, simply add their errorclass's name or errorstatus to
  # UNCRITICAL_ERROR_CLASSES or UNCRITICAL_ERROR_CODES.
  UNCRITICAL_ERROR_CLASSES = ["ActiveRecord::RecordInvalid"]
  UNCRITICAL_ERROR_CODES = [400, 403, 404, 410, 422]
  def critical?(exception)
    begin
      if request.xhr? && !exception.is_a?(ActiveRecord::RecordInvalid)
        # consider all errors in asynchronous/xhr-request context as critical
        # since they strongly imply an error in the client-side javascript
        # except for validation-errors
        return true
      else
        # check if error's status or class is classified as uncritical status or class
        return !(UNCRITICAL_ERROR_CLASSES.include?(exception.class.to_s) || UNCRITICAL_ERROR_CODES.include?(@status))
      end
    rescue
      # classify as critical if no status code is found in exception
      return true
    end
  end
end
