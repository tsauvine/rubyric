class CreateGroups < ActiveRecord::Migration
  def self.up
    create_table :groups do |t|
      t.references :exercise
      t.string     :name
      t.timestamps
    end

    create_table :groups_users, :id => false do |t|
      t.references :group
      t.references :user
    end
  end

  def self.down
    drop_table :groups_users
    drop_table :groups
  end
end
