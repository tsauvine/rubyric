class AddOrganizationToCourse < ActiveRecord::Migration
  def change
    add_column :courses, :organization_id, :integer
  end
end
