class ExerciseSubmissionExtension < ActiveRecord::Migration
  def up
    add_column :exercises, :allowed_extensions, :string, null: false, default: ''
  end

  def down
    remove_column :exercises, :allowed_extensions
  end
end
