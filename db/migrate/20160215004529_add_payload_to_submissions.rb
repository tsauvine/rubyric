class AddPayloadToSubmissions < ActiveRecord::Migration
  def change
    add_column :submissions, :payload, :text
    add_column :exercises, :submission_type, :string
    
    Exercise.update_all(submission_type: 'file')
  end
end
