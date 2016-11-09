class CreateSubmissions < ActiveRecord::Migration
  def self.up
    create_table :submissions do |t|
      t.references :exercise
      t.string :extension
      t.timestamps
    end

    create_table :reviews do |t|
      t.references :user
      t.references :submission
      t.text :feedback
      t.integer :grade
      t.string :status
      t.timestamps
    end
  end

  def self.down
    drop_table :reviews
    drop_table :submissions
  end
end
