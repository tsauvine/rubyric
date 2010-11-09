class Autoassign < ActiveRecord::Migration
  def self.up
    add_column :exercises, :autoassign, :boolean, :default => true
  end

  def self.down
    remove_column :exercises, :autoassign
  end
end
