# frozen_string_literal: true

require 'socket'

module OnePitaph
  module SuMcp
    module Server

      # ======================================================================
      # 非阻塞 TCP 服务器
      # 使用 UI.start_timer 定时器轮询，不阻塞 SketchUp 主线程
      # ======================================================================
      class TcpServer

        attr_reader :running, :sessions

        def initialize(mcp_handler)
          @mcp_handler = mcp_handler
          @server      = nil
          @timer_id    = nil
          @sessions    = []
          @running     = false
        end

        # 启动 TCP 服务器
        def start
          return if @running

          host = SuMcp.config.host
          port = SuMcp.config.port

          begin
            @server = TCPServer.new(host, port)
            @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
            @running = true

            Utils::Logger.info("TCP Server started on #{host}:#{port}",
                               source: 'TcpServer')

            # 启动轮询定时器
            start_poll_timer
          rescue Errno::EADDRINUSE
            Utils::Logger.error("Port #{port} already in use!", source: 'TcpServer')
            raise
          rescue => e
            Utils::Logger.error("Failed to start server: #{e.message}",
                                source: 'TcpServer')
            raise
          end
        end

        # 停止 TCP 服务器
        def stop
          return unless @running

          @running = false

          # 停止定时器
          UI.stop_timer(@timer_id) if @timer_id
          @timer_id = nil

          # 关闭所有会话
          @sessions.each(&:close)
          @sessions.clear

          # 关闭服务器 socket
          @server&.close rescue nil
          @server = nil

          Utils::Logger.info('TCP Server stopped', source: 'TcpServer')
        end

        # 是否正在运行
        def running?
          @running
        end

        private

        # 启动轮询定时器
        def start_poll_timer
          interval = SuMcp.config.poll_interval

          @timer_id = UI.start_timer(interval, true) do
            poll_once if @running
          end
        end

        # 单次轮询: 接受连接 + 读取消息
        def poll_once
          accept_new_connections
          process_sessions
          cleanup_closed_sessions
        rescue => e
          Utils::Logger.error("Poll error: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}",
                              source: 'TcpServer')
        end

        # 接受新连接 (非阻塞)
        def accept_new_connections
          return unless @server

          loop do
            begin
              client_socket = @server.accept_nonblock
              if @sessions.length >= SuMcp.config.max_clients
                Utils::Logger.warn('Max clients reached, rejecting connection',
                                   source: 'TcpServer')
                client_socket.close
                return
              end

              session = Session.new(client_socket)
              @sessions << session
              Utils::Logger.info("New connection: #{session.id}", source: 'TcpServer')
            rescue IO::WaitReadable
              # 无新连接
              break
            end
          end
        end

        # 处理所有活跃会话的消息
        def process_sessions
          @sessions.each do |session|
            next if session.closed?

            messages = session.read_messages
            messages.each do |raw_message|
              handle_message(session, raw_message)
            end
          end
        end

        # 处理单条消息
        def handle_message(session, raw_message)
          Utils::Logger.debug("Received: #{raw_message}", source: 'TcpServer')

          response = @mcp_handler.handle_raw_message(raw_message, session)

          if response
            Utils::Logger.debug("Sending: #{response}", source: 'TcpServer')
            session.write_message(response)
          end
        rescue => e
          Utils::Logger.error("Message handling error: #{e.message}",
                              source: 'TcpServer')
          error_response = JsonRpc::Response.internal_error(
            id: nil,
            message: e.message
          )
          session.write_message(error_response)
        end

        # 清理已关闭的会话
        def cleanup_closed_sessions
          @sessions.reject!(&:closed?)
        end

      end # class TcpServer

    end
  end
end
