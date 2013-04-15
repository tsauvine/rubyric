# encoding: UTF-8
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

ActiveRecord::Schema.define(:version => 20130415124356) do

  create_table "assistants_course_instances", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_instance_id"
  end

  create_table "course_instance_roles", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_instance_id"
    t.string  "role"
  end

  create_table "course_instances", :force => true do |t|
    t.integer  "course_id"
    t.string   "name"
    t.text     "description"
    t.boolean  "active",      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "locale"
  end

  create_table "course_instances_students", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_instance_id"
  end

  create_table "course_roles", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_id"
    t.string  "role"
  end

  create_table "courses", :force => true do |t|
    t.string   "code"
    t.string   "name"
    t.string   "css"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "courses_teachers", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "course_id"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "queue"
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "exercises", :force => true do |t|
    t.string   "name"
    t.integer  "course_instance_id"
    t.datetime "deadline"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "groupsizemax",          :default => 1
    t.integer  "groupsizemin",          :default => 1
    t.boolean  "anonymous_graders",     :default => false
    t.boolean  "anonymous_submissions", :default => false
    t.text     "submit_post_message"
    t.text     "submit_pre_message"
    t.boolean  "grader_can_email"
    t.boolean  "submit_without_login",  :default => false
    t.text     "rubric"
  end

  create_table "group_invitations", :force => true do |t|
    t.integer "group_id"
    t.integer "exercise_id"
    t.string  "token",       :null => false
    t.string  "email"
    t.date    "expires_at"
  end

  add_index "group_invitations", ["group_id", "token"], :name => "index_group_invitations_on_group_id_and_token"

  create_table "group_reviewers", :force => true do |t|
    t.integer "group_id", :null => false
    t.integer "user_id",  :null => false
  end

  create_table "groups", :force => true do |t|
    t.integer  "course_instance_id"
    t.integer  "exercise_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "name"
  end

  create_table "groups_users", :id => false, :force => true do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.string  "studentnumber"
    t.string  "email"
  end

  create_table "invitations", :force => true do |t|
    t.string  "token",      :null => false
    t.string  "type"
    t.string  "email"
    t.integer "target_id"
    t.integer "inviter_id"
    t.date    "expires_at"
  end

  add_index "invitations", ["token"], :name => "index_invitations_on_token"

  create_table "organizations", :force => true do |t|
    t.string "domain"
    t.string "name"
  end

  create_table "reviews", :force => true do |t|
    t.integer  "user_id"
    t.integer  "submission_id"
    t.text     "payload"
    t.text     "feedback"
    t.string   "grade"
    t.string   "status"
    t.text     "notes_to_teacher"
    t.text     "notes_to_grader"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "submissions", :force => true do |t|
    t.integer  "exercise_id"
    t.integer  "group_id"
    t.string   "filename"
    t.string   "extension"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "crypted_password"
    t.string   "salt"
    t.string   "firstname"
    t.string   "lastname"
    t.string   "email"
    t.string   "studentnumber"
    t.integer  "organization_id"
    t.boolean  "admin"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "organization"
    t.string   "persistence_token"
    t.string   "perishable_token"
    t.string   "locale"
    t.integer  "login_count",        :default => 0, :null => false
    t.datetime "last_request_at"
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.integer  "failed_login_count", :default => 0, :null => false
  end

  add_index "users", ["last_request_at"], :name => "index_users_on_last_request_at"
  add_index "users", ["login"], :name => "index_users_on_login"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"

end
