class AddLtiToExercise < ActiveRecord::Migration
  def change
    add_column :exercises, :lti_consumer, :string
    add_column :exercises, :lti_context_id, :string
    add_column :exercises, :lti_resource_link_id, :string
    
    add_column :users, :lti_consumer, :string
    add_column :users, :lti_user_id, :string
    
    add_index :users, [:lti_consumer, :lti_user_id]
    add_index :exercises, [:lti_consumer, :lti_context_id]
  end
end
