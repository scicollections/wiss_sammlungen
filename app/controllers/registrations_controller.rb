class RegistrationsController < Devise::RegistrationsController
  def new
    flash[:alert] = "Registrierungen sind zurzeit nicht möglich."
    redirect_to root_path
  end

  def create
    flash[:alert] = "Registrierungen sind zurzeit nicht möglich."
    redirect_to root_path
  end

  def edit
    # highlight home tab in user menu
    @user_menu_tab_settings_active = true
  end

  protected

  def after_update_path_for(resource)
    if resource.respond_to?(:person) && resource.person
      "/users/home"
    else
      root_path
    end
  end

  private
  # Einige Methoden des Standard-Controllers werden hier überschrieben,
  # damit die Werte von "name" und "first_name" durchgelassen werden.
  
  def sign_up_params
    params.require(:user).permit(:first_name, :name, :email,
                                 :password, :password_confirmation)
  end

  def account_update_params
    params.require(:user).permit(:first_name, :name, :email,
                                 :password, :password_confirmation, :current_password)
  end
end
