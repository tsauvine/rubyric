class CreatePricings < ActiveRecord::Migration
  def change
    create_table :pricings do |t|
      t.string :type
      t.integer :paid_students, :default => 0, :null => false
      t.integer :planned_students, :default => 0, :null => false
    end
    
    add_column :course_instances, :pricing_id, :integer
    add_column :users, :course_count, :integer, :default => 0, :null => false
  end
end
