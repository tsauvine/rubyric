class AddTimezoneToCourse < ActiveRecord::Migration
  def change
    add_column :courses, :time_zone, :string
    Course.update_all(:time_zone => 'Helsinki')
  end
end
