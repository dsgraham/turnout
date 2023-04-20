# require 'yaml'
# require 'fileutils'
require 'redis'

module Turnout
  class MaintenanceFile
    attr_reader :key

    SETTINGS = [:reason, :allowed_paths, :allowed_ips, :response_code, :retry_after]
    MARSHALLED = [:allowed_paths, :allowed_ips]
    attr_reader(*SETTINGS)

    def initialize(key, redis_options: nil)
      redis_options = default_redis_settings(redis_options)
      @key = key
      @client = redis_options ? Redis.new(redis_options) : Redis.current
      @reason = Turnout.config.default_reason
      @allowed_paths = Turnout.config.default_allowed_paths
      @allowed_ips = Turnout.config.default_allowed_ips
      @response_code = Turnout.config.default_response_code
      @retry_after = Turnout.config.default_retry_after

      import_settings if exists?
    end

    def exists?
      @client.exists?(@key)
    end

    def to_h
      SETTINGS.each_with_object({}) do |att, hash|
        hash[att] = send(att)
      end
    end

    def write
      SETTINGS.each do |att|
        value = send(att)
        next unless value.present?
        @client.hset(@key, att, serialize(value))
      end
    end

    def delete
      @client.del(@key)
    end

    def import(hash)
      SETTINGS.map(&:to_s).each do |att|
        self.send(:"#{att}=", hash[att]) unless hash[att].nil?
      end

      true
    end
    alias :import_env_vars :import

    # def allowed_paths
    #   @allowed_paths #? Marshal.load(@allowed_paths) : @allowed_paths
    # end
    #
    # def allowed_ips
    #   @allowed_ips #? Marshal.load(@allowed_ips) : @allowed_ips
    # end

    # Find the maintenance settings in Redis if exists
    def self.find
      settings_ = self.default
      return unless settings_.exists?
      settings_
    end

    def self.named(name)
      # path = named_paths[name.to_sym]
      # self.new(path) unless path.nil?
      self.default
    end

    def self.default
      self.new(Turnout.config.default_redis_key)
    end

    private

    def serialize(value)
      [Array, Hash].include?(value.class) ? Marshal.dump(value) : value
    end

    def default_redis_settings(options)
      return options if options&.fetch(:url){false} || options&.fetch(:host){false}
      url = ENV['REDIS_PROVIDER'] || ENV['REDIS_URL'] || ENV['REDIS_SERVER']
      if (url)
        options ||= {}
        options = options.merge(url: url)
      end
      options
    end

    def retry_after=(value)
      @retry_after = value
    end

    def reason=(reason)
      @reason = reason.to_s
    end

    # Splits strings on commas for easier importing of environment variables
    def allowed_paths=(paths)
      if paths.is_a? String
        # Grab everything between commas that aren't escaped with a backslash
        paths = paths.to_s.split(/(?<!\\),\ ?/).map do |path|
          path.strip.gsub('\,', ',') # remove the escape characters
        end
      end

      @allowed_paths = paths
    end

    # Splits strings on commas for easier importing of environment variables
    def allowed_ips=(ips)
      ips = ips.to_s.split(',') if ips.is_a? String

      @allowed_ips = ips
    end

    def response_code=(code)
      @response_code = code.to_i
    end

    def dir_path
      File.dirname(path)
    end

    def import_settings
      import fetch_existing_settings || {}
    end

    def fetch_existing_settings
      @client.hgetall(@key).map do |key, val|
        val = MARSHALLED.include?(key.to_sym) ? Marshal.load(val) : val
        [key, val]
      end.to_h
    end

    def self.named_paths
      Turnout.config.named_maintenance_file_paths
    end
  end
end
