class AddDeliveryModeToCourseInstance < ActiveRecord::Migration
  def change
    add_column :course_instances, :feedback_delivery_mode, :string
  end
end
