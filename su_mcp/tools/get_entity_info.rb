# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 获取实体详细信息
      # 通过 entity_id 获取实体的完整属性
      # ======================================================================
      class GetEntityInfo < MCP::Tool

        tool_name 'get_entity_info'

        description '根据 entity_id 获取实体的详细信息，包含几何属性、材质、变换等。'

        input_schema(
          properties: {
            entity_ids: {
              type:        'array',
              description: '目标实体 ID 数组',
              items:       { type: 'integer' },
            },
          },
          required: ['entity_ids']
        )

        annotations(
          read_only_hint:   true,
          destructive_hint: false,
          idempotent_hint:  true,
        )

        class << self
          def call(entity_ids:, **_args)
            model = Sketchup.active_model
            return error_response('No active model') unless model

            entities = find_entities(model, entity_ids)

            result = {
              found:    entities.length,
              entities: Utils::EntitySerializer.serialize_many(entities, detail: :full),
            }

            MCP::Tool::Response.new(
              content: [{ 'type' => 'text', 'text' => JSON.generate(result) }]
            )
          end

          private

          def find_entities(model, entity_ids)
            id_set = entity_ids.to_set
            result = []
            collect_entities(model.active_entities, id_set, result)
            # 也搜索模型根实体（在组编辑外的情况）
            if model.active_entities != model.entities
              collect_entities(model.entities, id_set, result)
            end
            result.uniq { |e| e.entityID }
          end

          def collect_entities(entities, id_set, result)
            entities.each do |entity|
              result << entity if id_set.include?(entity.entityID)
              if entity.respond_to?(:entities)
                collect_entities(entity.entities, id_set, result)
              end
            end
          end

          def error_response(message)
            MCP::Tool::Response.new(
              content: [{ 'type' => 'text', 'text' => message }],
              is_error: true
            )
          end
        end

      end

    end
  end
end
