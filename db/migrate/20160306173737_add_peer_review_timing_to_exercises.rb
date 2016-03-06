class AddPeerReviewTimingToExercises < ActiveRecord::Migration
  def change
    add_column :exercises, :peer_review_timing, :string
  end
end
