class AddAnnotations < ActiveRecord::Migration
  def up
    add_column :reviews, :type, :string, :null => false, :default => 'Review'
    add_column :exercises, :review_mode, :string
    add_column :exercises, :share_rubric, :boolean, :default => false
  end

  def down
    remove_column :reviews, :type
    remove_column :exercises, :review_mode
    remove_column :exercises, :share_rubric
  end
end
