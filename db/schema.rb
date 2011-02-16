# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110214171327) do

  create_table "assistants_course_instances", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_instance_id"
  end

  create_table "categories", :force => true do |t|
    t.string   "name"
    t.integer  "position",    :default => 0
    t.integer  "exercise_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "weight",      :default => 1.0
  end

  create_table "course_instances", :force => true do |t|
    t.integer  "course_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description"
    t.boolean  "active",      :default => true
  end

  create_table "course_instances_students", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_instance_id"
  end

  create_table "courses", :force => true do |t|
    t.string   "code"
    t.string   "name"
    t.string   "css"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email"
  end

  create_table "courses_teachers", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_id"
  end

  create_table "exercises", :force => true do |t|
    t.string   "name"
    t.integer  "course_instance_id"
    t.datetime "deadline"
    t.integer  "groupsizemax",            :default => 1
    t.integer  "groupsizemin",            :default => 1
    t.integer  "position",                :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "groups_from_exercise"
    t.string   "feedbackgrouping",        :default => "sections"
    t.text     "finalcomment"
    t.string   "positive_caption"
    t.string   "negative_caption"
    t.string   "neutral_caption"
    t.boolean  "anonymous_graders",       :default => false
    t.boolean  "anonymous_submissions",   :default => false
    t.text     "submit_post_message"
    t.text     "submit_pre_message"
    t.boolean  "grader_can_email"
    t.boolean  "unregistered_can_submit"
    t.boolean  "submit_without_login",    :default => false
    t.string   "grading_mode",            :default => "average"
    t.boolean  "autoassign",              :default => true
  end

  create_table "feedbacks", :force => true do |t|
    t.integer  "review_id"
    t.integer  "section_id"
    t.text     "good"
    t.text     "bad"
    t.text     "neutral"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "section_grading_option_id"
    t.string   "status",                    :limit => 16
  end

  create_table "groups", :force => true do |t|
    t.integer  "exercise_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "name"
  end

  create_table "groups_users", :id => false, :force => true do |t|
    t.integer "group_id"
    t.integer "user_id"
  end

  create_table "item_grades", :id => false, :force => true do |t|
    t.integer "feedback_id"
    t.integer "item_grading_option_id"
  end

  create_table "item_grading_options", :force => true do |t|
    t.integer "item_id"
    t.string  "text"
    t.integer "points"
    t.integer "position", :default => 0
  end

  create_table "items", :force => true do |t|
    t.string   "name"
    t.integer  "position",     :default => 0
    t.integer  "section_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "instructions"
  end

  create_table "phrases", :force => true do |t|
    t.text     "content"
    t.integer  "position",                   :default => 0
    t.integer  "item_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "feedbacktype", :limit => 32
  end

  create_table "reviews", :force => true do |t|
    t.integer  "user_id"
    t.integer  "submission_id"
    t.text     "feedback"
    t.integer  "grade"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "calculated_grade"
    t.integer  "final_grade"
    t.text     "notes_to_teacher"
    t.text     "notes_to_grader"
  end

  create_table "roles", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_id"
    t.string  "role"
  end

  create_table "section_grading_options", :force => true do |t|
    t.integer "section_id"
    t.string  "text"
    t.integer "points"
    t.integer "position",   :default => 0
  end

  create_table "sections", :force => true do |t|
    t.string   "name"
    t.integer  "position",     :default => 0
    t.text     "instructions"
    t.integer  "category_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "weight",       :default => 1.0
  end

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "submissions", :force => true do |t|
    t.integer  "exercise_id"
    t.integer  "group_id"
    t.string   "extension"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "filename"
  end

  create_table "submissions_users", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "submission_id"
  end

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "crypted_password"
    t.string   "salt"
    t.string   "firstname"
    t.string   "lastname"
    t.string   "email"
    t.string   "studentnumber"
    t.boolean  "admin"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "organization"
    t.string   "persistence_token"
    t.string   "perishable_token"
    t.integer  "login_count",       :default => 0, :null => false
    t.datetime "last_request_at"
    t.datetime "last_login_at"
    t.datetime "current_login_at"
  end

  add_index "users", ["last_request_at"], :name => "index_users_on_last_request_at"
  add_index "users", ["login"], :name => "index_users_on_login"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"

end
