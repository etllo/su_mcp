# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module MCP

      # ======================================================================
      # MCP Server 核心
      # 聚合 Tool/Resource/Prompt 注册表，管理 capabilities
      # ======================================================================
      class McpServer

        attr_reader :tool_registry, :resource_registry, :prompt_registry

        def initialize
          @tool_registry     = ToolRegistry.new
          @resource_registry = ResourceRegistry.new
          @prompt_registry   = PromptRegistry.new
        end

        # MCP initialize 请求的响应
        # @return [Hash]
        def server_info
          {
            'protocolVersion' => SuMcp::MCP_PROTOCOL_VERSION,
            'capabilities'    => capabilities,
            'serverInfo'      => {
              'name'    => SuMcp::SERVER_NAME,
              'version' => SuMcp::VERSION,
            },
          }
        end

        # 声明服务器能力
        # @return [Hash]
        def capabilities
          caps = {}

          caps['tools']     = {} if tool_registry.size > 0
          caps['resources'] = {} if resource_registry.size > 0
          caps['prompts']   = {} if prompt_registry.size > 0

          caps
        end

        # 处理 MCP 请求
        # @param method_name [String] JSON-RPC 方法名
        # @param params [Hash, nil] 请求参数
        # @return [Hash] 响应结果
        def handle_request(method_name, params = nil)
          case method_name
          when 'initialize'
            handle_initialize(params)
          when 'ping'
            handle_ping
          when 'notifications/initialized'
            handle_notifications_initialized
          when 'tools/list'
            handle_tools_list
          when 'tools/call'
            handle_tools_call(params)
          when 'resources/list'
            handle_resources_list
          when 'resources/read'
            handle_resources_read(params)
          when 'prompts/list'
            handle_prompts_list
          when 'prompts/get'
            handle_prompts_get(params)
          else
            nil  # 返回 nil 表示方法未找到
          end
        end

        private

        def handle_initialize(_params)
          server_info
        end

        def handle_ping
          {}
        end

        def handle_notifications_initialized
          Utils::Logger.info('Client initialized', source: 'McpServer')
          :notification  # 通知不需要响应
        end

        def handle_tools_list
          { 'tools' => tool_registry.list }
        end

        def handle_tools_call(params)
          name = params&.dig('name') || params&.dig(:name)
          arguments = params&.dig('arguments') || params&.dig(:arguments) || {}

          unless name
            raise ArgumentError, 'Missing tool name'
          end

          tool_response = tool_registry.call(name, arguments)
          tool_response.to_h
        end

        def handle_resources_list
          { 'resources' => resource_registry.list }
        end

        def handle_resources_read(params)
          uri = params&.dig('uri') || params&.dig(:uri)

          unless uri
            raise ArgumentError, 'Missing resource URI'
          end

          contents = resource_registry.read(uri)
          { 'contents' => contents }
        end

        def handle_prompts_list
          { 'prompts' => prompt_registry.list }
        end

        def handle_prompts_get(params)
          name = params&.dig('name') || params&.dig(:name)
          arguments = params&.dig('arguments') || params&.dig(:arguments) || {}

          unless name
            raise ArgumentError, 'Missing prompt name'
          end

          result = prompt_registry.get(name, arguments)
          result.to_h
        end

      end # class McpServer

    end
  end
end
