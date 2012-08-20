# Delayed::Job.destroy_failed_jobs = true
# silence_warnings do
#   Delayed::Job.const_set("MAX_ATTEMPTS", 3)
#   Delayed::Job.const_set("MAX_RUN_TIME", 1.hours)
# end

Delayed::Worker.backend = :active_record
