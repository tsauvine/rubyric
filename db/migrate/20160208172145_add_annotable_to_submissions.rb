class AddAnnotableToSubmissions < ActiveRecord::Migration
  def change
    add_column :submissions, :annotatable, :boolean, :nil => false, :default => false
    add_column :submissions, :conversion, :string
    add_column :submissions, :page_sizes, :text
    
    Submission.where(extension: 'pdf').update_all(annotatable: true)
  end
end
