class CreateRubric < ActiveRecord::Migration

  def self.up
    create_table :categories do |t|
      t.string :name
      t.integer :position, :default => 0
      t.integer :weight
      t.references :exercise
      t.timestamps
    end

    create_table :sections do |t|
      t.string :name
      t.integer :position, :default => 0
      t.text :instructions
      t.references :category
      t.timestamps
    end

    create_table :items do |t|
      t.string :name
      t.integer :position, :default => 0
      t.references :section
      t.timestamps
    end

    create_table :phrases do |t|
      t.text :content
      t.integer :position, :default => 0
      t.string :type
      t.references :item
      t.references :user

      t.timestamps
    end
  end

  def self.down
    drop_table :phrases
    drop_table :items
    drop_table :sections
    drop_table :categories
  end
end
