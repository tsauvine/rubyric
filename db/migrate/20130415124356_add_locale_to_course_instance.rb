class AddLocaleToCourseInstance < ActiveRecord::Migration
  def change
    add_column :course_instances, :locale, :string, :length => 5
  end
end
