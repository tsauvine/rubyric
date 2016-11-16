class CreateCourses < ActiveRecord::Migration
  def self.up
    create_table :courses do |t|
      t.string :code
      t.string :name
      t.string :css
      t.timestamps
    end

    create_table :course_instances do |t|
      t.references :course
      t.string :name

      t.timestamps
    end

    create_table :exercises do |t|
      t.string :name
      t.references :course_instance
      t.timestamp :deadline
      t.integer :position,          :default => 0
      t.integer :groupsizemax, :default => 1
      t.integer :groupsizemin, :default => 1
      t.timestamps
      t.integer  :groups_from_exercise
      t.string   :feedbackgrouping,        :default => 'sections'
      t.text     :finalcomment
      t.string   :positive_caption
      t.string   :negative_caption
      t.string   :neutral_caption
      t.text     :xml
    end
  end

  def self.down
    drop_table :exercises
    drop_table :course_instances
    drop_table :courses
  end
end
