class AddGroupReviewers < ActiveRecord::Migration
  def up
    create_table :group_reviewers do |t|
      t.references :group, :null => false
      t.references :user, :null => false
    end
  end

  def down
    drop_table :group_reviewers
  end
end
