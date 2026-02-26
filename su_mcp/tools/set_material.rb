# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 设置材质
      # 为指定实体设置颜色或材质
      # ======================================================================
      class SetMaterial < MCP::Tool

        tool_name 'set_material'

        description '为 SketchUp 实体设置材质。支持设置颜色 (RGB/名称)、透明度。'

        input_schema(
          properties: {
            entity_ids: {
              type:        'array',
              description: '目标实体 ID 数组',
              items:       { type: 'integer' },
            },
            color: {
              type:        'string',
              description: '颜色值，支持格式: 颜色名称 (如 "Red")、' \
                           'HEX (如 "#FF0000")、RGB (如 "255,0,0")',
            },
            alpha: {
              type:        'number',
              description: '不透明度 0.0~1.0，默认 1.0',
            },
            back_face: {
              type:        'boolean',
              description: '是否设置背面材质（仅对 Face 有效），默认 false',
            },
          },
          required: ['entity_ids', 'color']
        )

        annotations(
          destructive_hint: true,
          idempotent_hint:  true,
        )

        class << self
          def call(entity_ids:, color:, alpha: 1.0, back_face: false, **_args)
            model = Sketchup.active_model
            return error_response('No active model') unless model

            # 解析颜色
            su_color = parse_color(color)
            su_color.alpha = (alpha * 255).to_i if alpha < 1.0

            # 创建或查找材质
            material = model.materials.add("MCP_#{color.gsub(/[^a-zA-Z0-9]/, '_')}")
            material.color = su_color

            model.start_operation('MCP Set Material', true)

            begin
              applied_count = 0

              find_entities(model, entity_ids).each do |entity|
                if entity.respond_to?(:material=)
                  if back_face && entity.is_a?(Sketchup::Face)
                    entity.back_material = material
                  else
                    entity.material = material
                  end
                  applied_count += 1
                end
              end

              model.commit_operation

              MCP::Tool::Response.new(
                content: [{
                  'type' => 'text',
                  'text' => JSON.generate({
                    applied_count: applied_count,
                    material_name: material.display_name,
                    color:         color,
                    alpha:         alpha,
                  }),
                }]
              )
            rescue => e
              model.abort_operation
              error_response(e.message)
            end
          end

          private

          def parse_color(color_str)
            if color_str.start_with?('#')
              # HEX 格式
              hex = color_str.delete('#')
              r = hex[0..1].to_i(16)
              g = hex[2..3].to_i(16)
              b = hex[4..5].to_i(16)
              Sketchup::Color.new(r, g, b)
            elsif color_str.include?(',')
              # RGB 格式
              parts = color_str.split(',').map(&:strip).map(&:to_i)
              Sketchup::Color.new(*parts[0..2])
            else
              # 颜色名称
              Sketchup::Color.new(color_str)
            end
          end

          def find_entities(model, entity_ids)
            id_set = entity_ids.to_set
            result = []
            collect_entities(model.active_entities, id_set, result)
            result
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
