# frozen_string_literal: true

require 'socket'

module OnePitaph
  module SuMcp
    module Server

      # ======================================================================
      # TCP 客户端会话
      # 封装单个 TCP 连接的状态和 I/O
      # ======================================================================
      class Session

        attr_reader :socket, :id, :created_at
        attr_accessor :initialized  # MCP 协议是否已初始化

        def initialize(socket)
          @socket      = socket
          @id          = "session_#{object_id}"
          @buffer      = String.new(encoding: 'UTF-8')
          @created_at  = Time.now
          @initialized = false
          @closed      = false
        end

        # 是否已关闭
        def closed?
          @closed || @socket.closed?
        end

        # 非阻塞读取，返回完整的行 (JSON-RPC 以 \n 分隔)
        # @return [Array<String>] 读取到的完整消息行
        def read_messages
          messages = []
          return messages if closed?

          begin
            data = @socket.read_nonblock(SuMcp.config.read_buffer_size)
            @buffer << data

            # 按换行符分割，提取完整消息
            while (newline_idx = @buffer.index("\n"))
              line = @buffer.slice!(0, newline_idx + 1).strip
              messages << line unless line.empty?
            end
          rescue IO::WaitReadable
            # 没有数据可读，正常情况
          rescue EOFError, Errno::ECONNRESET, Errno::ECONNABORTED, IOError => e
            Utils::Logger.info("Session #{@id} disconnected: #{e.class}",
                               source: 'Session')
            close
          end

          messages
        end

        # 非阻塞写入
        # @param message [String] 要发送的消息
        def write_message(message)
          return if closed?

          begin
            @socket.write(message + "\n")
            @socket.flush
          rescue Errno::EPIPE, Errno::ECONNRESET, IOError => e
            Utils::Logger.warn("Write failed for #{@id}: #{e.message}",
                               source: 'Session')
            close
          end
        end

        # 关闭会话
        def close
          return if @closed

          @closed = true
          @socket.close rescue nil
          Utils::Logger.info("Session #{@id} closed", source: 'Session')
        end

      end # class Session

    end
  end
end
