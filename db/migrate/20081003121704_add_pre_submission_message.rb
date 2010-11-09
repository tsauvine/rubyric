class AddPreSubmissionMessage < ActiveRecord::Migration
  def self.up
    add_column :exercises, :submit_pre_message, :text
  end

  def self.down
    remove_column :exercises, :submit_pre_message
  end
end
