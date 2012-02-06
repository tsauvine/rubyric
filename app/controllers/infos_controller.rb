class InfosController < ApplicationController
  before_filter :login_required

  # GET /info/1
  def show
    @info = Info.first(:conditions => ["studentnumber = ? AND exercise_id = ?", current_user.studentnumber, params[:id]])
  end
end
