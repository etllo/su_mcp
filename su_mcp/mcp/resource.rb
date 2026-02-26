# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module MCP

      # ======================================================================
      # Resource 基类
      # 代表可通过 MCP 暴露的数据资源
      # ======================================================================
      class Resource

        attr_reader :uri, :name, :title, :description, :mime_type

        def initialize(uri:, name:, title: nil, description: nil, mime_type: 'text/plain')
          @uri         = uri
          @name        = name
          @title       = title || name
          @description = description || ''
          @mime_type   = mime_type
        end

        # 读取资源内容 (子类或 block 实现)
        # @return [Hash] { uri:, mimeType:, text: }
        def read
          raise NotImplementedError, "#{self.class.name} must implement #read"
        end

        # 转换为 MCP resources/list 格式
        def to_mcp_hash
          hash = {
            'uri'      => @uri,
            'name'     => @name,
            'title'    => @title,
            'mimeType' => @mime_type,
          }
          hash['description'] = @description unless @description.empty?
          hash
        end

      end # class Resource

      # ======================================================================
      # Resource 注册表
      # ======================================================================
      class ResourceRegistry

        def initialize
          @resources = {}
          @read_handler = nil
        end

        # 注册资源
        # @param resource [Resource]
        def register(resource)
          @resources[resource.uri] = resource
          Utils::Logger.debug("Registered resource: #{resource.uri}",
                              source: 'ResourceRegistry')
        end

        # 设置统一的 resources/read 处理器
        # @yield [params] 处理读取请求的回调
        def on_read(&handler)
          @read_handler = handler
        end

        # 按 URI 查找
        def find(uri)
          @resources[uri]
        end

        # 列举所有资源
        def list
          @resources.values.map(&:to_mcp_hash)
        end

        # 读取资源
        # @param uri [String]
        # @return [Array<Hash>]
        def read(uri)
          if @read_handler
            @read_handler.call(uri: uri)
          else
            resource = find(uri)
            if resource
              [resource.read]
            else
              raise ArgumentError, "Resource not found: #{uri}"
            end
          end
        end

        def size
          @resources.size
        end

      end # class ResourceRegistry

    end
  end
end
