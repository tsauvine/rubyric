require 'rest_client'

class GoogleAnalyticsApi

  def event(category, action, client_id = '555')
    return unless GOOGLE_ANALYTICS_SETTINGS[:tracking_code].present?

    params = {
      v: GOOGLE_ANALYTICS_SETTINGS[:version],
      tid: GOOGLE_ANALYTICS_SETTINGS[:tracking_code],
      cid: client_id
      t: "event",
      ec: category,
      ea: action
    }

    begin
      RestClient.get(GOOGLE_ANALYTICS_SETTINGS[:endpoint], params: params, timeout: 4, open_timeout: 4)
      return true
    rescue  RestClient::Exception => rex
      return false
    end
  end

end
 
