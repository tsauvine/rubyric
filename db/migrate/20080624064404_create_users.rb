class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users, :force => true do |t|
      t.string :login
      t.string :crypted_password,     :limit => 40
      t.string :salt,                 :limit => 40
      t.string :firstname
      t.string :lastname
      t.string :email
      t.string :studentnumber
      t.boolean :admin
      t.string :remember_token
      t.datetime :remember_token_expires_at
      t.timestamps
    end

    create_table :submissions_users, :id => false do |t|
      t.references :user
      t.references :submission
    end

    create_table :course_instances_students, :id => false do |t|
      t.references :user
      t.references :course_instance
    end

    create_table :assistants_course_instances, :id => false do |t|
      t.references :user
      t.references :course_instance
    end

    create_table :courses_teachers, :id => false do |t|
      t.references :user
      t.references :course
    end

    create_table :infos, :id => false, :force => true do |t|
      t.integer :exercise_id
      t.string  :studentnumber
      t.text    :content
    end

    add_index :infos, [:exercise_id, :studentnumber], :name => 'index_infos_on_exercise_id_and_studentnumber'

    create_table :roles, :id => false, :force => true do |t|
      t.integer :user_id
      t.integer :course_id
      t.string  :role
    end
  end

  def self.down
    drop_table :roles
    drop_table :infos
    drop_table :courses_teachers
    drop_table :course_instances_students
    drop_table :assistants_course_instances
    drop_table :submissions_users
    drop_table :users
  end
end
