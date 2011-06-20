class CreateGroupInvitations < ActiveRecord::Migration
  def self.up
    create_table :group_invitations do |t|
      t.references :group, :nil => false
      t.references :exercise
      t.string :token, :nil => false
      t.string :email, :length => 320
      t.date :expires_at
    end
    
    add_index :group_invitations, [:group_id, :token]
  end

  def self.down
    drop_table :group_invitations
  end
end
