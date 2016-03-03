class AddKnowledgeToUser < ActiveRecord::Migration
  def change
    add_column :users, :knowledge, :text
  end
end
