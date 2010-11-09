class SubmitWithoutAuth < ActiveRecord::Migration
  def self.up
    add_column :exercises, :submit_without_login, :boolean, :default => false
  end

  def self.down
    remove_column :exercises, :submit_without_login
  end
end
