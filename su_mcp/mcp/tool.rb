# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module MCP

      # ======================================================================
      # Tool 基类
      # 参考 MCP 官方 Ruby SDK 的 MCP::Tool 设计
      # 子类继承后使用 DSL 声明 tool_name, description, input_schema 等
      # ======================================================================
      class Tool

        # ToolResponse 封装工具调用结果
        Response = Struct.new(:content, :is_error, keyword_init: true) do
          def initialize(content:, is_error: false)
            super
          end

          def to_h
            result = { 'content' => content }
            result['isError'] = true if is_error
            result
          end
        end

        class << self

          # --- DSL 方法 ---

          # 设置/获取工具名称
          def tool_name(name = nil)
            if name
              @tool_name = name
            else
              @tool_name || self.name.split('::').last
                                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                                .downcase
            end
          end

          # 设置/获取描述
          def description(desc = nil)
            if desc
              @description = desc
            else
              @description || ''
            end
          end

          # 设置/获取输入 schema
          # @param schema [Hash] JSON Schema 格式
          def input_schema(schema = nil)
            if schema
              @input_schema = schema
            else
              @input_schema || { properties: {}, required: [] }
            end
          end

          # 设置/获取注解
          def annotations(annots = nil)
            if annots
              @annotations = annots
            else
              @annotations || {}
            end
          end

          # 调用工具 (子类必须实现)
          # @param args [Hash] 输入参数
          # @param server_context [Hash] 服务器上下文
          # @return [Tool::Response]
          def call(**args)
            raise NotImplementedError, "#{name} must implement .call"
          end

          # 转换为 MCP tools/list 格式
          def to_mcp_hash
            hash = {
              'name'        => tool_name,
              'description' => description,
              'inputSchema' => {
                'type'       => 'object',
                'properties' => stringify_keys_deep(input_schema[:properties] || {}),
              },
            }

            required = input_schema[:required]
            if required && !required.empty?
              hash['inputSchema']['required'] = required.map(&:to_s)
            end

            annots = annotations
            unless annots.empty?
              hash['annotations'] = stringify_keys_deep(annots)
            end

            hash
          end

          private

          # 递归将 Hash 的 Symbol key 转为 String
          def stringify_keys_deep(obj)
            case obj
            when Hash
              obj.each_with_object({}) do |(k, v), h|
                h[k.to_s] = stringify_keys_deep(v)
              end
            when Array
              obj.map { |v| stringify_keys_deep(v) }
            else
              obj
            end
          end

        end # class << self

      end # class Tool

    end
  end
end
