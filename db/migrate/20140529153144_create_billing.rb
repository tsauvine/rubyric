class CreateBilling < ActiveRecord::Migration
  def change
    add_column :users, :tester, :string
  end
end
