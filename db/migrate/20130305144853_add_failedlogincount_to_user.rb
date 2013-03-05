class AddFailedlogincountToUser < ActiveRecord::Migration
  def change
    add_column :users, :failed_login_count, :integer, :null => false, :default => 0
    User.update_all(:failed_login_count => 0)
  end
end
