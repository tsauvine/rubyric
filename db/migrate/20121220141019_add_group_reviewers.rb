class AddGroupReviewers < ActiveRecord::Migration
  def up
    create_table :group_reviewers do |t|
      t.references :group, :null => false
      t.references :user, :null => false
    end
    
    # Copy assignments from submissions to group_reviewers
    Group.includes(:submissions => :reviews).find_each do |group|
      reviewer_ids = Set.new
      
      group.submissions.each do |submission|
        submission.reviews.each do |review|
          reviewer_ids << review.user_id
        end
      end
      
      reviewer_ids.each do |reviewer_id|
        GroupReviewer.create(:user_id => reviewer_id, :group_id => group.id)
      end
    end
  end

  def down
    drop_table :group_reviewers
  end
end
