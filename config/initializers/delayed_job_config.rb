# config/initializers/delayed_job_config.rb
Delayed::Worker.sleep_delay = 30
Delayed::Worker.max_attempts = 2
Delayed::Worker.max_run_time = 5.minutes
