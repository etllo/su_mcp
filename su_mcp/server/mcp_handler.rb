# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Server

      # ======================================================================
      # MCP 协议请求处理器
      # 桥接 JSON-RPC 传输层 与 MCP Server 核心
      # ======================================================================
      class McpHandler

        attr_reader :mcp_server

        def initialize(mcp_server)
          @mcp_server = mcp_server
        end

        # 处理原始 JSON-RPC 消息
        # @param raw_message [String] JSON 字符串
        # @param session [Session] 当前会话
        # @return [String, nil] JSON-RPC 响应字符串；通知返回 nil
        def handle_raw_message(raw_message, session)
          request = JsonRpc::Request.parse(raw_message)
          process_request(request, session)
        rescue JsonRpc::ParseError => e
          # JSON 本身无法解析，尝试提取 id
          fallback_id = extract_id_from_raw(raw_message)
          Utils::Logger.warn("Parse error (id=#{fallback_id.inspect}): #{e.message}",
                             source: 'McpHandler')
          # id 为 nil 时不发送响应：Claude MCP SDK Zod schema 要求 id 必须是
          # string | number，发送 id:null 会在客户端触发验证错误
          return nil if fallback_id.nil?
          JsonRpc::Response.error(
            id: fallback_id, code: JsonRpc::ErrorCode::PARSE_ERROR, message: e.message
          )
        rescue JsonRpc::InvalidRequestError => e
          # validate! 已将 id 存入异常
          fallback_id = JsonRpc::Request.request_id_from_error(e)
          Utils::Logger.warn("Invalid request (id=#{fallback_id.inspect}): #{e.message}",
                             source: 'McpHandler')
          return nil if fallback_id.nil?
          JsonRpc::Response.invalid_request(id: fallback_id, message: e.message)
        end

        private

        # 解析 JSON-RPC 请求
        def parse_request(raw_message)
          JsonRpc::Request.parse(raw_message)
        end

        # 当 JSON 解析失败时，少量提取 id字段
        def extract_id_from_raw(raw_message)
          data = JSON.parse(raw_message.to_s)
          data.is_a?(Hash) ? data['id'] : nil
        rescue
          nil
        end

        # 处理已解析的请求
        # @return [String, nil] JSON-RPC 响应字符串
        def process_request(request, session)
          method_name = request.method_name
          params      = request.params

          Utils::Logger.debug("Processing: #{method_name}",
                              source: 'McpHandler')

          # 路由到 MCP Server
          result = @mcp_server.handle_request(method_name, params)

          # 方法未找到
          if result.nil?
            return JsonRpc::Response.method_not_found(
              id: request.id,
              method_name: method_name
            )
          end

          # 通知类请求 (无需响应)
          return nil if result == :notification

          # 通知类请求 (request 无 id)
          return nil if request.notification?

          # 构建成功响应
          JsonRpc::Response.success(id: request.id, result: result)

        rescue ArgumentError => e
          JsonRpc::Response.invalid_params(
            id: request.id,
            message: e.message
          )
        rescue => e
          Utils::Logger.error("Error processing #{method_name}: #{e.message}\n" \
                              "#{e.backtrace&.first(5)&.join("\n")}",
                              source: 'McpHandler')
          JsonRpc::Response.internal_error(
            id: request.id,
            message: e.message
          )
        end

      end # class McpHandler

    end
  end
end
