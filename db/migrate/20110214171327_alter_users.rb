class AlterUsers < ActiveRecord::Migration
  def self.up
    change_column :users, :crypted_password, :string
    change_column :users, :salt, :string
    
    remove_column :users, :remember_token
    remove_column :users, :remember_token_expires_at
    add_column :users, :persistence_token, :string
    add_column :users, :perishable_token, :string
    
    add_column :users, :locale, :string, :length => 5
    
    add_column :users, :login_count, :integer , :default => 0, :null => false
    add_column :users, :last_request_at, :datetime
    add_column :users, :last_login_at, :datetime
    add_column :users, :current_login_at, :datetime
    
    add_index :users, :login
    add_index :users, :persistence_token
    add_index :users, :last_request_at
  end

  def self.down
    remove_index :users, :login
    remove_index :users, :persistence_token
    remove_index :users, :last_request_at
    
    remove_column :users, :login_count
    remove_column :users, :last_request_at
    remove_column :users, :last_login_at
    remove_column :users, :current_login_at
    
    remove_column :users, :current_login_at
    
    add_column :users, :remember_token, :string
    add_column :users, :remember_token_expires_at, :datetime
    remove_column :users, :persistence_token
    remove_column :users, :perishable_token
  end
end
