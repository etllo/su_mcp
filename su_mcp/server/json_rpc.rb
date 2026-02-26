# frozen_string_literal: true

require 'json'

module OnePitaph
  module SuMcp
    module Server

      # ======================================================================
      # JSON-RPC 2.0 协议实现
      # 纯 Ruby 实现，无外部依赖
      # 参考规范: https://www.jsonrpc.org/specification
      # ======================================================================
      module JsonRpc

        JSONRPC_VERSION = '2.0'

        # --- 标准错误码 ---
        module ErrorCode
          PARSE_ERROR      = -32700
          INVALID_REQUEST  = -32600
          METHOD_NOT_FOUND = -32601
          INVALID_PARAMS   = -32602
          INTERNAL_ERROR   = -32603

          # 自定义 MCP 错误码 (-32000 ~ -32099 为实现保留)
          TOOL_EXECUTION_ERROR = -32000
          RESOURCE_NOT_FOUND   = -32001
          PROMPT_NOT_FOUND     = -32002
        end

        # ==================================
        # JSON-RPC 请求
        # ==================================
        class Request
          attr_reader :id, :method_name, :params

          def initialize(id:, method_name:, params: nil)
            @id          = id
            @method_name = method_name
            @params      = params
          end

          # 是否为通知 (无 id)
          def notification?
            @id.nil?
          end

          # 从 JSON 字符串解析
          # @param json_str [String] JSON 字符串
          # @return [Request]
          # @raise [ParseError] JSON 解析失败
          # @raise [InvalidRequestError] 结构校验失败，异常携带 :request_id
          def self.parse(json_str)
            data = JSON.parse(json_str, symbolize_names: false)

            # 尽早提取 id，保证错误响应里能带上正确的 id
            request_id = data.is_a?(Hash) ? data['id'] : nil
            validate!(data, request_id)

            new(
              id:          request_id,
              method_name: data['method'],
              params:      data['params']
            )
          rescue JSON::ParserError => e
            raise ParseError, "JSON parse error: #{e.message}"
          end

          # 验证 JSON-RPC 格式
          # @param data [Object] 已解析的 JSON
          # @param request_id [Object] 已提取的 id（用于错误响应）
          def self.validate!(data, request_id = nil)
            unless data.is_a?(Hash)
              err = InvalidRequestError.new('Request must be a JSON object')
              err.instance_variable_set(:@request_id, request_id)
              raise err
            end

            # 宽容处理 jsonrpc 版本字段 — 部分客户端可能省略或使用其他值
            unless data.key?('method')
              err = InvalidRequestError.new('Missing method field')
              err.instance_variable_set(:@request_id, request_id)
              raise err
            end

            unless data['method'].is_a?(String)
              err = InvalidRequestError.new('Method must be a string')
              err.instance_variable_set(:@request_id, request_id)
              raise err
            end

            # params 允许 null / 省略 / Hash / Array
            if data.key?('params') &&
               !data['params'].nil? &&
               !data['params'].is_a?(Hash) &&
               !data['params'].is_a?(Array)
              err = InvalidRequestError.new('Params must be object, array, or null')
              err.instance_variable_set(:@request_id, request_id)
              raise err
            end
          end

          # 从自定义异常中读取 request_id
          def self.request_id_from_error(err)
            err.instance_variable_defined?(:@request_id) ? err.instance_variable_get(:@request_id) : nil
          end
        end

        # ==================================
        # JSON-RPC 响应构建
        # ==================================
        module Response

          # 构建成功响应
          # @param id [String, Integer] 请求 ID
          # @param result [Object] 结果数据
          # @return [String] JSON 字符串
          def self.success(id:, result:)
            {
              'jsonrpc' => JSONRPC_VERSION,
              'id'      => id,
              'result'  => result,
            }.to_json
          end

          # 构建错误响应
          # @param id [String, Integer, nil] 请求 ID
          # @param code [Integer] 错误码
          # @param message [String] 错误消息
          # @param data [Object, nil] 附加数据
          # @return [String] JSON 字符串
          def self.error(id:, code:, message:, data: nil)
            error_obj = {
              'code'    => code,
              'message' => message,
            }
            error_obj['data'] = data if data

            {
              'jsonrpc' => JSONRPC_VERSION,
              'id'      => id,
              'error'   => error_obj,
            }.to_json
          end

          # 便捷方法: 解析错误
          def self.parse_error(message = 'Parse error')
            error(id: nil, code: ErrorCode::PARSE_ERROR, message: message)
          end

          # 便捷方法: 无效请求
          def self.invalid_request(id: nil, message: 'Invalid request')
            error(id: id, code: ErrorCode::INVALID_REQUEST, message: message)
          end

          # 便捷方法: 方法未找到
          def self.method_not_found(id:, method_name: '')
            error(id: id, code: ErrorCode::METHOD_NOT_FOUND,
                  message: "Method not found: #{method_name}")
          end

          # 便捷方法: 参数无效
          def self.invalid_params(id:, message: 'Invalid params')
            error(id: id, code: ErrorCode::INVALID_PARAMS, message: message)
          end

          # 便捷方法: 内部错误
          def self.internal_error(id:, message: 'Internal error', data: nil)
            error(id: id, code: ErrorCode::INTERNAL_ERROR,
                  message: message, data: data)
          end

        end # module Response

        # ==================================
        # JSON-RPC 通知
        # ==================================
        module Notification
          # 构建通知消息 (无 id)
          # @param method_name [String]
          # @param params [Hash, nil]
          # @return [String] JSON 字符串
          def self.build(method_name:, params: nil)
            msg = {
              'jsonrpc' => JSONRPC_VERSION,
              'method'  => method_name,
            }
            msg['params'] = params if params
            msg.to_json
          end
        end

        # ==================================
        # 自定义异常
        # ==================================
        class ParseError < StandardError; end
        class InvalidRequestError < StandardError; end

      end # module JsonRpc

    end
  end
end
