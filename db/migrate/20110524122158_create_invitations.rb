class CreateInvitations < ActiveRecord::Migration
  def self.up
    create_table :group_invitations do |t|
      t.references :group, :nil => false
      t.references :exercise
      t.string :token, :nil => false
      t.string :email, :length => 320
      t.date :expires_at
    end
    add_index :group_invitations, [:group_id, :token]
    
    create_table "invitations", :force => true do |t|
      t.string  "token", :null => false
      t.string  "type"
      t.string  "email"
      t.integer "target_id"
      t.integer "inviter_id"
      t.date    "expires_at"
    end
    add_index :invitations, ["token"]
  end

  def self.down
    drop_table :group_invitations
    drop_table :invitations
  end
end
