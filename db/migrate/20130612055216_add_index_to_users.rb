class AddIndexToUsers < ActiveRecord::Migration
  def up
    add_index :group_reviewers, :user_id
    add_index :group_reviewers, :group_id
    
    execute "CREATE INDEX index_users_on_lowercase_studentnumber ON users USING btree (lower(studentnumber));"
    execute "CREATE INDEX index_users_on_lowercase_firstname ON users USING btree (lower(firstname));"
    execute "CREATE INDEX index_users_on_lowercase_lastname ON users USING btree (lower(lastname));"
    execute "CREATE INDEX index_users_on_lowercase_email ON users USING btree (lower(email));"
  end

  def down
    drop_index :group_reviewers, :user_id
    drop_index :group_reviewers, :group_id
    
    execute "DROP INDEX index_users_on_lowercase_studentnumber;"
    execute "DROP INDEX index_users_on_lowercase_firstname;"
    execute "DROP INDEX index_users_on_lowercase_lastname;"
    execute "DROP INDEX index_users_on_lowercase_email;"
  end
end
