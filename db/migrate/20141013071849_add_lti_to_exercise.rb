class AddLtiToExercise < ActiveRecord::Migration
  def change
    add_column :exercises, :lticontext, :string
    add_column :users, :lti_id, :string
  end
end
