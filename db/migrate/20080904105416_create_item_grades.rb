class CreateItemGrades < ActiveRecord::Migration
  def self.up
    create_table :item_grades, :id => false do |t|
      t.references :feedback
      t.references :item_grading_option
    end

    create_table :section_grades, :id => false do |t|
      t.references :feedback
      t.references :section_grading_option
    end
  end

  def self.down
    drop_table :item_grades
    drop_table :section_grades
  end
end
