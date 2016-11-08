class CreateGroups < ActiveRecord::Migration
  def self.up
    create_table :groups do |t|
      t.references  :exercise
      t.text        :name
      t.timestamps
    end

    create_table :groups_users, :id => false do |t|
      t.references :group
      t.references :user
    end

    add_column  :submissions, :group_id, :integer, null: false
    add_index   :submissions, :group_id, name: 'index_submissions_on_group_id'
  end

  def self.down
    remove_index  :submissions, name: 'index_submissions_on_group_id'
    remove_column :submissions, :group_id

    drop_table :groups_users
    drop_table :groups
  end
end
