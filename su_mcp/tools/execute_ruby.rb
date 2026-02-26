# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 执行 Ruby 代码
      # 在 SketchUp 环境中执行任意 Ruby 代码
      # ======================================================================
      class ExecuteRuby < MCP::Tool

        tool_name 'execute_ruby'

        description '在 SketchUp Ruby 环境中执行任意 Ruby 代码。' \
                    '可以直接调用所有 SketchUp API。返回代码的最后表达式值。' \
                    '⚠️ 注意: 此工具具有完全权限，请谨慎使用。'

        input_schema(
          properties: {
            code: {
              type:        'string',
              description: '要执行的 Ruby 代码字符串',
            },
          },
          required: ['code']
        )

        annotations(
          destructive_hint:  true,
          idempotent_hint:   false,
          open_world_hint:   true,
        )

        class << self
          def call(code:, **_args)
            Utils::Logger.info("Executing Ruby code: #{code.length} chars",
                               source: 'ExecuteRuby')

            begin
              # 在 SketchUp 上下文中执行
              result = eval(code)  # rubocop:disable Security/Eval

              result_str = case result
                           when NilClass
                             'nil'
                           when String
                             result
                           else
                             result.inspect
                           end

              MCP::Tool::Response.new(
                content: [{
                  'type' => 'text',
                  'text' => JSON.generate({
                    success: true,
                    result:  result_str,
                  }),
                }]
              )
            rescue SyntaxError => e
              MCP::Tool::Response.new(
                content: [{
                  'type' => 'text',
                  'text' => JSON.generate({
                    success: false,
                    error:   "SyntaxError: #{e.message}",
                  }),
                }],
                is_error: true
              )
            rescue => e
              MCP::Tool::Response.new(
                content: [{
                  'type' => 'text',
                  'text' => JSON.generate({
                    success:   false,
                    error:     "#{e.class}: #{e.message}",
                    backtrace: e.backtrace&.first(5),
                  }),
                }],
                is_error: true
              )
            end
          end
        end

      end

    end
  end
end
