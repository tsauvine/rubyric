class AddRubricToExercise < ActiveRecord::Migration
  def change
    add_column :exercises, :rubric, :text
  end
end
