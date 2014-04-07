class AddTokenToGroup < ActiveRecord::Migration
  def change
    add_column :groups, :access_token, :string
    add_column :groups, :min_size, :integer, :null => false, :default => 1
    add_column :groups, :max_size, :integer, :null => false, :default => 1
    add_index :groups, :access_token
  end
end
