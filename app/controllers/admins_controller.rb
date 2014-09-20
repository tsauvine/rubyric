class AdminsController < ApplicationController
  before_filter :login_required
  before_filter :authorize
  
  layout 'narrow-new'
  
  def authorize
    return access_denied unless is_admin?(current_user)
  end
  
  def show
  end

  def test_mailer
    if params[:email]
      address = params[:email]
      TestMailer.test_email(address).deliver
      TestMailer.delay.test_email(address, {:delayed => true})
    end
    
    flash[:success] = 'One email was sent with delayed_job and one directly.'
    redirect_to admin_path
  end
  
end
