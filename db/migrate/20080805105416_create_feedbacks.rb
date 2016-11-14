class CreateFeedbacks < ActiveRecord::Migration
  def self.up
    create_table :feedbacks do |t|
      t.references :review
      t.references :section
      t.text :good
      t.text :bad
      t.text :neutral
      t.references :section_grading_option
      t.string :status, :limit => 16
      t.timestamps
    end
  end

  def self.down
    drop_table :feedbacks
  end
end
