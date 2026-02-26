# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 变换实体
      # 对指定实体执行平移、旋转、缩放操作
      # ======================================================================
      class TransformEntities < MCP::Tool

        tool_name 'transform_entities'

        description '对 SketchUp 实体执行几何变换：平移 (move)、旋转 (rotate)、' \
                    '缩放 (scale)。通过 entity_id 指定目标实体。'

        input_schema(
          properties: {
            entity_ids: {
              type:        'array',
              description: '目标实体 ID 数组',
              items:       { type: 'integer' },
            },
            transform_type: {
              type:        'string',
              description: '变换类型',
              enum:        ['move', 'rotate', 'scale'],
            },
            vector: {
              type:        'array',
              description: 'move: 平移向量 [dx, dy, dz]; scale: 缩放因子 [sx, sy, sz]',
              items:       { type: 'number' },
            },
            angle: {
              type:        'number',
              description: 'rotate: 旋转角度 (度)',
            },
            axis: {
              type:        'array',
              description: 'rotate: 旋转轴向量 [x, y, z]，默认 [0,0,1]',
              items:       { type: 'number' },
            },
            center: {
              type:        'array',
              description: 'rotate/scale: 中心点 [x, y, z]，默认 [0,0,0]',
              items:       { type: 'number' },
            },
          },
          required: ['entity_ids', 'transform_type']
        )

        annotations(
          destructive_hint: true,
          idempotent_hint:  false,
        )

        class << self
          def call(entity_ids:, transform_type:, vector: nil, angle: nil,
                   axis: nil, center: nil, **_args)
            model = Sketchup.active_model
            return error_response('No active model') unless model

            # 查找实体
            entities = find_entities(model, entity_ids)
            return error_response('No matching entities found') if entities.empty?

            # 构建变换矩阵
            transform = build_transform(transform_type, vector, angle, axis, center)
            return error_response('Failed to build transform') unless transform

            model.start_operation('MCP Transform', true)

            begin
              model.active_entities.transform_entities(transform, entities)
              model.commit_operation

              MCP::Tool::Response.new(
                content: [{
                  'type' => 'text',
                  'text' => JSON.generate({
                    transformed: entities.length,
                    entity_ids:  entities.map(&:entityID),
                    transform_type: transform_type,
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
            all_entities = []
            collect_entities(model.active_entities, id_set, all_entities)
            all_entities
          end

          def collect_entities(entities, id_set, result)
            entities.each do |entity|
              result << entity if id_set.include?(entity.entityID)

              if entity.respond_to?(:entities)
                collect_entities(entity.entities, id_set, result)
              end
            end
          end

          def build_transform(type, vector, angle, axis, center)
            case type
            when 'move'
              raise ArgumentError, 'move requires vector [dx, dy, dz]' unless vector
              Geom::Transformation.translation(Geom::Vector3d.new(vector))

            when 'rotate'
              raise ArgumentError, 'rotate requires angle' unless angle
              axis_vec = axis ? Geom::Vector3d.new(axis) : Z_AXIS
              center_pt = center ? Geom::Point3d.new(center) : ORIGIN
              Geom::Transformation.rotation(center_pt, axis_vec, angle.degrees)

            when 'scale'
              raise ArgumentError, 'scale requires vector [sx, sy, sz]' unless vector
              center_pt = center ? Geom::Point3d.new(center) : ORIGIN
              Geom::Transformation.scaling(center_pt, *vector)

            else
              raise ArgumentError, "Unknown transform type: #{type}"
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
