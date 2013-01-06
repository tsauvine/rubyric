class InvitationsController < ApplicationController
  before_filter :login_required

  def show
    @invitation = Invitation.find_by_token(params[:id])
    
    if @invitation
      @invitation.accept(current_user)
    
      flash[:success] = t("#{@invitation.type.underscore}_message")
      redirect_to @invitation.target
    else
      render :invalid_token
    end
  end

  def join
    return access_denied unless logged_in?

    invitation = GroupInvitation.where(:group_id => params[:id], :token => params[:token]).first

    if invitation
      group = invitation.group
      exercise = invitation.exercise

      # Add user to group
      group.users << current_user unless group.users.include?(current_user)

      # Delete invitation
      invitation.destroy

      # Redirect to submit
      flash[:success] = 'You have been added to the group'
      redirect_to submit_path(:exercise => exercise.id, :group => group.id)
    else
      render :invalid_token
    end

  end

  def destroy
    @invitation = Invitation.find(params[:id])
    authorize! :destroy, @invitation
    
    @invitation.delete
    
    respond_to do |format|
      #format.html { redirect_to course_teachers_path(@course) }
      format.json { render :json => [params[:id]].as_json }
    end
  end

end
