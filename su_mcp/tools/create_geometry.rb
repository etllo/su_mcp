# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 创建几何体
      # 支持创建 face, edge, group, component_instance
      # ======================================================================
      class CreateGeometry < MCP::Tool

        tool_name 'create_geometry'

        description '在 SketchUp 中创建几何体。支持创建面 (face)、边 (edge)、' \
                    '组 (group) 和组件实例 (component_instance)。' \
                    '所有坐标单位为英寸 (SketchUp 内部单位)。'

        input_schema(
          properties: {
            type: {
              type:        'string',
              description: '要创建的几何类型',
              enum:        ['face', 'edge', 'group_with_faces', 'box'],
            },
            points: {
              type:        'array',
              description: '点坐标数组，每个点为 [x, y, z]。' \
                           'face: 至少 3 个点; edge: 2 个点; box: 不需要',
              items:       { type: 'array', items: { type: 'number' } },
            },
            origin: {
              type:        'array',
              description: 'box 类型的原点 [x, y, z]，默认 [0,0,0]',
              items:       { type: 'number' },
            },
            width: {
              type:        'number',
              description: 'box 宽度 (X 方向)，单位英寸',
            },
            depth: {
              type:        'number',
              description: 'box 深度 (Y 方向)，单位英寸',
            },
            height: {
              type:        'number',
              description: 'box 高度 (Z 方向)，单位英寸',
            },
            name: {
              type:        'string',
              description: '组/组件名称 (可选)',
            },
          },
          required: ['type']
        )

        annotations(
          destructive_hint:  true,
          idempotent_hint:   false,
        )

        class << self
          def call(type:, points: nil, origin: nil, width: nil, depth: nil,
                   height: nil, name: nil, **_args)
            model = Sketchup.active_model

            unless model
              return error_response('No active model')
            end

            result = nil
            model.start_operation('MCP Create Geometry', true)

            begin
              case type
              when 'face'
                result = create_face(model, points)
              when 'edge'
                result = create_edge(model, points)
              when 'group_with_faces'
                result = create_group_with_faces(model, points, name)
              when 'box'
                result = create_box(model, origin, width, depth, height, name)
              else
                model.abort_operation
                return error_response("Unknown geometry type: #{type}")
              end

              model.commit_operation

              MCP::Tool::Response.new(
                content: [{ 'type' => 'text', 'text' => JSON.generate(result) }]
              )
            rescue => e
              model.abort_operation
              error_response("#{e.message}")
            end
          end

          private

          def create_face(model, points)
            validate_points!(points, min: 3)
            pts = points.map { |p| Geom::Point3d.new(p) }
            face = model.active_entities.add_face(pts)
            {
              created: 'face',
              entity_id: face.entityID,
              area: face.area,
            }
          end

          def create_edge(model, points)
            validate_points!(points, min: 2, max: 2)
            pt1 = Geom::Point3d.new(points[0])
            pt2 = Geom::Point3d.new(points[1])
            edge = model.active_entities.add_line(pt1, pt2)
            {
              created: 'edge',
              entity_id: edge.entityID,
              length: edge.length,
            }
          end

          def create_group_with_faces(model, points, name)
            validate_points!(points, min: 3)
            group = model.active_entities.add_group
            pts = points.map { |p| Geom::Point3d.new(p) }
            face = group.entities.add_face(pts)
            group.name = name if name && !name.empty?
            {
              created: 'group',
              entity_id: group.entityID,
              name: group.name,
              face_entity_id: face.entityID,
            }
          end

          def create_box(model, origin, width, depth, height, name)
            width  ||= 10
            depth  ||= 10
            height ||= 10
            origin_pt = origin ? Geom::Point3d.new(origin) : ORIGIN

            group = model.active_entities.add_group
            entities = group.entities

            # 创建底面
            pts = [
              origin_pt,
              Geom::Point3d.new(origin_pt.x + width, origin_pt.y, origin_pt.z),
              Geom::Point3d.new(origin_pt.x + width, origin_pt.y + depth, origin_pt.z),
              Geom::Point3d.new(origin_pt.x, origin_pt.y + depth, origin_pt.z),
            ]
            face = entities.add_face(pts)
            face.pushpull(-height) if face

            group.name = name if name && !name.empty?

            {
              created: 'box',
              entity_id: group.entityID,
              name: group.name,
              dimensions: { width: width, depth: depth, height: height },
            }
          end

          def validate_points!(points, min: 1, max: nil)
            unless points.is_a?(Array) && points.length >= min
              raise ArgumentError, "需要至少 #{min} 个坐标点"
            end
            if max && points.length > max
              raise ArgumentError, "最多 #{max} 个坐标点"
            end
            points.each_with_index do |p, i|
              unless p.is_a?(Array) && p.length == 3
                raise ArgumentError, "第 #{i + 1} 个点必须是 [x, y, z] 格式"
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
