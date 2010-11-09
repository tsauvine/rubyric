class CreateGradingOptions < ActiveRecord::Migration
  def self.up
    create_table :item_grading_options do |t|
      t.references :item
      t.string     :text
      t.integer    :points
      t.integer    :position, :default => 0
    end

    create_table :section_grading_options do |t|
      t.references :section
      t.string     :text
      t.integer    :points
      t.integer    :position, :default => 0
    end
  end

  def self.down
    drop_table :item_grading_options
    drop_table :section_grading_options
  end
end
