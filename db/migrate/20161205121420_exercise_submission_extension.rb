class ExerciseSubmissionExtension < ActiveRecord::Migration
  def up
    add_column :exercises, :allowed_extensions, :string
  end

  def down
    remove_column :exercises, :allowed_extensions
  end
end
