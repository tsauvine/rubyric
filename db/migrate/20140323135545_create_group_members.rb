class CreateGroupMembers < ActiveRecord::Migration
  def up
    create_table :group_members do |t|
      t.references :group, :null => false
      t.references :user
      t.references :group_invitation
      t.string :email
      t.string :studentnumber
      t.string :access_token
      t.timestamps
    end
    add_index :group_members, :group_id
    add_index :group_members, :user_id
    add_index :group_members, :access_token
    
    ActiveRecord::Base.connection.execute("SELECT user_id, group_id, studentnumber, email FROM groups_users").each do |row|
      member = GroupMember.new(:studentnumber => row['studentnumber'], :email => row['email'])
      member.user_id = row['user_id'].to_i
      member.group_id = row['group_id'].to_i
      member.save
    end
    
    add_column :submissions, :authenticated, :boolean, :null => false, :default => false
  end
  
  def down
    drop_table :group_members
    remove_column :submissions, :authenticated
  end
end
