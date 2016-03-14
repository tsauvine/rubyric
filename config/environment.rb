Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Rubyric::Application.initialize!

# FIXME: only in edge version
config.after_initialize do
  Delayed::Backend::ActiveRecord::Job.set_table_name 'delayd_jobs_edge'
end
