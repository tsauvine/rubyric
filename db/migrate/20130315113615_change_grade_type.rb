class ChangeGradeType < ActiveRecord::Migration
  def up
    change_column :reviews, :grade, :string
  end

  def down
    change_column :reviews, :grade, :integer
  end
end
