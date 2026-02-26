# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module MCP

      # ======================================================================
      # Tool 注册表
      # 管理所有已注册 Tool 的查找和枚举
      # ======================================================================
      class ToolRegistry

        def initialize
          @tools = {}
        end

        # 注册一个 Tool 类
        # @param tool_class [Class < Tool]
        def register(tool_class)
          name = tool_class.tool_name
          if @tools.key?(name)
            Utils::Logger.warn("Tool '#{name}' already registered, overwriting",
                               source: 'ToolRegistry')
          end
          @tools[name] = tool_class
          Utils::Logger.debug("Registered tool: #{name}", source: 'ToolRegistry')
        end

        # 批量注册
        # @param tool_classes [Array<Class>]
        def register_all(*tool_classes)
          tool_classes.flatten.each { |tc| register(tc) }
        end

        # 按名称查找
        # @param name [String]
        # @return [Class < Tool, nil]
        def find(name)
          @tools[name]
        end

        # 列举所有工具 (MCP tools/list 格式)
        # @return [Array<Hash>]
        def list
          @tools.values.map(&:to_mcp_hash)
        end

        # 调用工具
        # @param name [String] 工具名称
        # @param arguments [Hash] 调用参数
        # @return [Tool::Response]
        def call(name, arguments = {})
          tool_class = find(name)
          raise ArgumentError, "Unknown tool: #{name}" unless tool_class

          # 将 string keys 转为 symbol keys
          sym_args = symbolize_keys(arguments || {})
          tool_class.call(**sym_args)
        end

        # 已注册工具数量
        def size
          @tools.size
        end

        # 已注册工具名称列表
        def names
          @tools.keys
        end

        private

        def symbolize_keys(hash)
          hash.each_with_object({}) do |(k, v), h|
            h[k.to_sym] = v
          end
        end

      end # class ToolRegistry

    end
  end
end
