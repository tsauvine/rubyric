class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.belongs_to :user
      t.string :payment_id
      t.string :state
      t.string :amount
      t.string :description

      t.timestamps
    end
    
    add_index :orders, :user_id
  end
end
