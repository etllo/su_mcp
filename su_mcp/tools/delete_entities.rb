# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 删除实体
      # ======================================================================
      class DeleteEntities < MCP::Tool

        tool_name 'delete_entities'

        description '根据 entity_id 删除 SketchUp 中的实体。支持批量删除。'

        input_schema(
          properties: {
            entity_ids: {
              type:        'array',
              description: '要删除的实体 ID 数组',
              items:       { type: 'integer' },
            },
          },
          required: ['entity_ids']
        )

        annotations(
          destructive_hint: true,
          idempotent_hint:  false,
        )

        class << self
          def call(entity_ids:, **_args)
            model = Sketchup.active_model
            return error_response('No active model') unless model

            entities_to_delete = find_entities(model, entity_ids)

            if entities_to_delete.empty?
              return MCP::Tool::Response.new(
                content: [{ 'type' => 'text',
                             'text' => JSON.generate({ deleted: 0, message: 'No matching entities found' }) }]
              )
            end

            model.start_operation('MCP Delete', true)

            begin
              deleted_ids = entities_to_delete.map(&:entityID)
              model.active_entities.erase_entities(entities_to_delete)
              model.commit_operation

              MCP::Tool::Response.new(
                content: [{
                  'type' => 'text',
                  'text' => JSON.generate({
                    deleted:     deleted_ids.length,
                    entity_ids:  deleted_ids,
                  }),
                }]
              )
            rescue => e
              model.abort_operation
              error_response(e.message)
            end
          end

          private

          def find_entities(model, entity_ids)
            id_set = entity_ids.to_set
            result = []
            model.active_entities.each do |entity|
              result << entity if id_set.include?(entity.entityID)
            end
            result
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
