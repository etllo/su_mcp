# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 获取当前选中实体
      # ======================================================================
      class GetSelection < MCP::Tool

        tool_name 'get_selection'

        description '获取当前 SketchUp 中选中的实体列表及其详细信息。'

        input_schema(
          properties: {
            detail: {
              type:        'string',
              description: '信息详细程度: brief (简要) 或 full (完整)',
              enum:        ['brief', 'full'],
            },
          },
          required: []
        )

        annotations(
          read_only_hint:   true,
          destructive_hint: false,
          idempotent_hint:  true,
        )

        class << self
          def call(detail: 'brief', **_args)
            model = Sketchup.active_model
            selection = model&.selection

            unless selection
              return MCP::Tool::Response.new(
                content: [{ 'type' => 'text', 'text' => 'No active model' }],
                is_error: true
              )
            end

            detail_sym = detail.to_sym
            entities = Utils::EntitySerializer.serialize_many(
              selection.to_a, detail: detail_sym
            )

            result = {
              count:    selection.length,
              entities: entities,
            }

            MCP::Tool::Response.new(
              content: [{ 'type' => 'text', 'text' => JSON.generate(result) }]
            )
          end
        end

      end

    end
  end
end
