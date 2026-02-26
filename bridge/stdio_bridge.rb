#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================================
# SU MCP Stdio Bridge
# 独立 Ruby 脚本，作为 MCP 客户端 (Claude Desktop 等) 与 SketchUp 之间的桥梁
#
# 工作原理:
#   MCP 客户端 <--stdio (JSON-RPC)--> stdio_bridge.rb <--TCP--> SketchUp TCP Server
#
# 使用方法:
#   ruby stdio_bridge.rb [host] [port]
#
# Claude Desktop 配置 (claude_desktop_config.json):
#   {
#     "mcpServers": {
#       "sketchup": {
#         "command": "ruby",
#         "args": ["C:/path/to/stdio_bridge.rb"],
#         "env": { "SU_MCP_PORT": "9876" }
#       }
#     }
#   }
# ============================================================================

require 'socket'
require 'json'

module SuMcpBridge

  DEFAULT_HOST = '127.0.0.1'
  DEFAULT_PORT = 9876

  CONNECT_RETRY_INTERVAL = 2     # 重连间隔 (秒)
  CONNECT_MAX_RETRIES    = 30    # 最大重试次数
  READ_TIMEOUT           = 30    # TCP 读取超时 (秒)

  class StdioBridge

    def initialize(host, port)
      @host    = host
      @port    = port
      @socket  = nil
      @running = false
    end

    # 启动桥接
    def run
      @running = true
      log("SU MCP Bridge starting, connecting to #{@host}:#{@port}...")

      connect_with_retry

      log('Connected to SketchUp MCP Server')

      # 主循环: 从 stdin 读取，转发到 TCP，回写 stdout
      while @running
        process_stdin
      end
    rescue Interrupt
      log('Bridge interrupted')
    rescue => e
      log("Bridge error: #{e.message}")
      # 写一个 JSON-RPC 错误到 stdout 通知客户端
      error_response = {
        'jsonrpc' => '2.0',
        'id'      => nil,
        'error'   => {
          'code'    => -32603,
          'message' => "Bridge error: #{e.message}",
        },
      }
      $stdout.puts(JSON.generate(error_response))
      $stdout.flush
    ensure
      disconnect
    end

    private

    # 带重试的 TCP 连接
    def connect_with_retry
      retries = 0

      loop do
        begin
          @socket = TCPSocket.new(@host, @port)
          @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          return
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT => e
          retries += 1
          if retries >= CONNECT_MAX_RETRIES
            raise "Cannot connect to SketchUp MCP Server at #{@host}:#{@port} " \
                  "after #{retries} attempts. Is SketchUp running with the plugin started?"
          end
          log("Connection attempt #{retries}/#{CONNECT_MAX_RETRIES} failed: #{e.message}, " \
              "retrying in #{CONNECT_RETRY_INTERVAL}s...")
          sleep(CONNECT_RETRY_INTERVAL)
        end
      end
    end

    # 处理 stdin 输入
    def process_stdin
      # 阻塞读取一行
      line = $stdin.gets

      unless line
        # stdin 关闭 (客户端断开)
        @running = false
        return
      end

      line = line.strip
      return if line.empty?

      # 验证是否为合法 JSON
      begin
        JSON.parse(line)
      rescue JSON::ParserError => e
        log("Invalid JSON from stdin: #{e.message}")
        error_response = {
          'jsonrpc' => '2.0',
          'id'      => nil,
          'error'   => {
            'code'    => -32700,
            'message' => "Parse error: #{e.message}",
          },
        }
        $stdout.puts(JSON.generate(error_response))
        $stdout.flush
        return
      end

      # 转发到 TCP
      begin
        send_to_tcp(line)
        response = read_from_tcp
        if response
          $stdout.puts(response)
          $stdout.flush
        end
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError => e
        log("TCP connection lost: #{e.message}, reconnecting...")
        reconnect
        # 重试一次
        begin
          send_to_tcp(line)
          response = read_from_tcp
          if response
            $stdout.puts(response)
            $stdout.flush
          end
        rescue => retry_err
          log("Retry failed: #{retry_err.message}")
        end
      end
    end

    # 发送到 TCP
    def send_to_tcp(message)
      @socket.puts(message)
      @socket.flush
    end

    # 从 TCP 读取响应
    def read_from_tcp
      ready = IO.select([@socket], nil, nil, READ_TIMEOUT)

      unless ready
        log('TCP read timeout')
        return nil
      end

      line = @socket.gets
      line&.strip
    end

    # 重新连接
    def reconnect
      disconnect
      connect_with_retry
      log('Reconnected to SketchUp')
    end

    # 断开连接
    def disconnect
      @socket&.close rescue nil
      @socket = nil
    end

    # 日志输出到 stderr (不影响 stdout 的 JSON-RPC 通信)
    def log(message)
      $stderr.puts("[SU-MCP-Bridge] #{Time.now.strftime('%H:%M:%S')} #{message}")
      $stderr.flush
    end

  end # class StdioBridge

end # module SuMcpBridge

# --- 主程序入口 ---
if __FILE__ == $PROGRAM_NAME
  host = ARGV[0] || ENV['SU_MCP_HOST'] || SuMcpBridge::DEFAULT_HOST
  port = (ARGV[1] || ENV['SU_MCP_PORT'] || SuMcpBridge::DEFAULT_PORT).to_i

  bridge = SuMcpBridge::StdioBridge.new(host, port)
  bridge.run
end
