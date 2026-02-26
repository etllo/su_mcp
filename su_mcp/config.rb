# frozen_string_literal: true

module OnePitaph
  module SuMcp

    # ========================================================================
    # 配置管理
    # 集中管理插件的可配置参数
    # ========================================================================
    class Config

      # 默认配置
      DEFAULTS = {
        host: '127.0.0.1',
        port: 9876,
        poll_interval: 0.1,        # TCP 轮询间隔 (秒)
        max_clients: 5,            # 最大同时连接数
        read_buffer_size: 65536,   # 读缓冲区大小 (字节)
        log_level: :info,          # 日志级别 :debug, :info, :warn, :error
      }.freeze

      attr_accessor :host, :port, :poll_interval, :max_clients,
                    :read_buffer_size, :log_level

      def initialize
        reset!
      end

      # 重置为默认值
      def reset!
        DEFAULTS.each do |key, value|
          send(:"#{key}=", value)
        end
        self
      end

      # 从 Hash 加载配置
      def update(options = {})
        options.each do |key, value|
          send(:"#{key}=", value) if respond_to?(:"#{key}=")
        end
        self
      end

      # 导出为 Hash
      def to_h
        DEFAULTS.keys.each_with_object({}) do |key, hash|
          hash[key] = send(key)
        end
      end

    end # class Config

    # 全局配置实例
    @config = Config.new

    class << self
      attr_reader :config

      # 配置 DSL
      # @example
      #   OnePitaph::SuMcp.configure do |c|
      #     c.port = 8888
      #     c.log_level = :debug
      #   end
      def configure
        yield @config if block_given?
        @config
      end
    end

  end
end
