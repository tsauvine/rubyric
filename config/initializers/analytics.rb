path = Rails.root.join("config", "paypal.yml")
if File.exist? path
  PayPal::SDK::Core::Config.load(path, Rails.env)
  PayPal::SDK::Core::Config.logger = Rails.logger
end

path = Rails.root.join("config", "analytics.yml")
if File.exist? path
  GOOGLE_ANALYTICS_SETTINGS = HashWithIndifferentAccess.new
  config = YAML.load_file(path)[Rails.env]
  GOOGLE_ANALYTICS_SETTINGS.update(config) if config
end
