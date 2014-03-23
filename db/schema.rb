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

ActiveRecord::Schema.define(:version => 20140323135545) do

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
    t.boolean  "active",                 :default => true
    t.string   "locale"
    t.string   "submission_policy"
    t.string   "feedback_delivery_mode"
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
    t.integer  "organization_id"
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
    t.text     "xml"
    t.text     "rubric"
    t.string   "review_mode"
    t.boolean  "share_rubric",            :default => false
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

  create_table "group_invitations", :force => true do |t|
    t.integer "group_id"
    t.integer "exercise_id"
    t.string  "token"
    t.string  "email"
    t.date    "expires_at"
  end

  add_index "group_invitations", ["group_id", "token"], :name => "index_group_invitations_on_group_id_and_token"

  create_table "group_members", :force => true do |t|
    t.integer  "group_id",            :null => false
    t.integer  "user_id"
    t.integer  "group_invitation_id"
    t.string   "email"
    t.string   "studentnumber"
    t.string   "access_token"
    t.datetime "created_at",          :null => false
    t.datetime "updated_at",          :null => false
  end

  add_index "group_members", ["access_token"], :name => "index_group_members_on_access_token"
  add_index "group_members", ["group_id"], :name => "index_group_members_on_group_id"
  add_index "group_members", ["user_id"], :name => "index_group_members_on_user_id"

  create_table "group_reviewers", :force => true do |t|
    t.integer "group_id", :null => false
    t.integer "user_id",  :null => false
  end

  add_index "group_reviewers", ["group_id"], :name => "index_group_reviewers_on_group_id"
  add_index "group_reviewers", ["user_id"], :name => "index_group_reviewers_on_user_id"

  create_table "groups", :force => true do |t|
    t.integer  "exercise_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "name"
    t.integer  "course_instance_id"
  end

  create_table "groups_users", :id => false, :force => true do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.string  "studentnumber"
    t.string  "email"
  end

  create_table "infos", :id => false, :force => true do |t|
    t.integer "exercise_id"
    t.string  "studentnumber"
    t.text    "content"
  end

  add_index "infos", ["exercise_id", "studentnumber"], :name => "index_infos_on_exercise_id_and_studentnumber"

  create_table "invitations", :force => true do |t|
    t.string  "token",      :null => false
    t.string  "type"
    t.string  "email"
    t.integer "target_id"
    t.integer "inviter_id"
    t.date    "expires_at"
  end

  add_index "invitations", ["token"], :name => "index_invitations_on_token"

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

  create_table "organizations", :force => true do |t|
    t.string "domain"
    t.string "name"
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
    t.string   "grade"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "calculated_grade"
    t.integer  "final_grade"
    t.text     "notes_to_teacher"
    t.text     "notes_to_grader"
    t.text     "payload"
    t.string   "filename"
    t.string   "extension"
    t.string   "type",             :default => "Review", :null => false
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
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
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
    t.boolean  "book_mode"
    t.integer  "page_count"
    t.float    "page_width"
    t.float    "page_height"
    t.boolean  "authenticated", :default => false, :null => false
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
    t.string   "locale"
    t.integer  "login_count",        :default => 0, :null => false
    t.datetime "last_request_at"
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.integer  "organization_id"
    t.integer  "failed_login_count", :default => 0, :null => false
  end

  add_index "users", ["last_request_at"], :name => "index_users_on_last_request_at"
  add_index "users", ["login"], :name => "index_users_on_login"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"

end
