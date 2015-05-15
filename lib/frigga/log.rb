module Frigga
  require 'logger'
  require 'singleton'
  class Log
    include Singleton
    attr_accessor :logger
    def initialize
      @logger = Logger.new('log/frigga.log', 'daily', 10)
      @logger.formatter = proc { |severity, datetime, progname, msg| "#{datetime} #{severity} -- : #{msg}\n"}
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      @logger.level = eval("Logger::#{LOG_LEVEL.upcase}")
    end
  end
  Logger = Log.instance.logger

end