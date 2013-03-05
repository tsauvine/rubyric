class Session < Authlogic::Session::Base
  authenticate_with User
  
  consecutive_failed_logins_limit 10
end
