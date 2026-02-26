# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Utils

      # ======================================================================
      # 日志模块
      # 输出到 SketchUp Ruby Console，支持日志级别过滤
      # ======================================================================
      module Logger

        LEVELS = {
          debug: 0,
          info:  1,
          warn:  2,
          error: 3,
        }.freeze

        module_function

        def debug(message, source: nil)
          log(:debug, message, source: source)
        end

        def info(message, source: nil)
          log(:info, message, source: source)
        end

        def warn(message, source: nil)
          log(:warn, message, source: source)
        end

        def error(message, source: nil)
          log(:error, message, source: source)
        end

        def log(level, message, source: nil)
          return unless should_log?(level)

          prefix = source ? "[SU-MCP][#{source}]" : '[SU-MCP]'
          tag = level.to_s.upcase.ljust(5)
          timestamp = Time.now.strftime('%H:%M:%S')

          puts "#{timestamp} #{tag} #{prefix} #{message}"
        end

        def should_log?(level)
          current_level = LEVELS[SuMcp.config.log_level] || LEVELS[:info]
          message_level = LEVELS[level] || 0
          message_level >= current_level
        end

      end # module Logger

    end
  end
end
