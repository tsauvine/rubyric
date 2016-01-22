class AddTypeToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :type, :string
    Submission.update_all(:type => 'Submission')
  end
end
