class AlterUser < ActiveRecord::Migration
  def self.up
    add_column :users, :organization, :string
  end

  def self.down
    remove_column :users, :organization
  end
end
