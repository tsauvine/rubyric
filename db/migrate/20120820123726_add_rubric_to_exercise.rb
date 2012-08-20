class AddRubricToExercise < ActiveRecord::Migration
  def change
    add_column :exercises, :rubric, :text
    add_column :reviews, :payload, :text
  end
end
