class ChangeDefaultGradingMode < ActiveRecord::Migration
  def up
    change_column :exercises, :grading_mode, :string, :default => nil
    Exercise.update_all(:grading_mode => nil)
  end

  def down
    change_column :exercises, :grading_mode, :string, :default => nil
    Exercise.update_all(:grading_mode => 'average')
  end
end
