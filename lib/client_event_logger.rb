require 'singleton'
class ClientEventLogger < Logger
  include Singleton

  def initialize
    super(Rails.root.join('log/client.log'))
    self.formatter = formatter()
    self
  end

  # Optional, but good for prefixing timestamps automatically
  def formatter
    Proc.new{|severity, time, progname, msg|
      "#{msg.to_s}\n"
    }
  end

  class << self
    delegate :error, :debug, :fatal, :info, :warn, :add, :log, :to => :instance
  end
end
