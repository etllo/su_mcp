# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Utils

      # ======================================================================
      # 实体序列化器
      # 将 SketchUp 实体转换为 JSON 友好的 Hash
      # ======================================================================
      module EntitySerializer

        module_function

        # 序列化单个实体（通用）
        # @param entity [Sketchup::Entity]
        # @param detail [Symbol] :brief 或 :full
        # @return [Hash]
        def serialize(entity, detail: :brief)
          return nil unless entity&.valid?

          base = {
            entity_id:  entity.entityID,
            type:       entity.typename,
            visible:    entity.visible?,
            layer:      entity.layer&.name,
          }

          case detail
          when :full
            base.merge!(serialize_full(entity))
          end

          base
        end

        # 序列化实体数组
        # @param entities [Array<Sketchup::Entity>]
        # @param detail [Symbol]
        # @return [Array<Hash>]
        def serialize_many(entities, detail: :brief)
          entities.map { |e| serialize(e, detail: detail) }.compact
        end

        # 序列化完整信息（按类型分派）
        def serialize_full(entity)
          case entity
          when Sketchup::Face
            serialize_face(entity)
          when Sketchup::Edge
            serialize_edge(entity)
          when Sketchup::Group
            serialize_group(entity)
          when Sketchup::ComponentInstance
            serialize_component_instance(entity)
          when Sketchup::ComponentDefinition
            serialize_component_definition(entity)
          else
            {}
          end
        end

        # --- 各类型序列化方法 ---

        def serialize_face(face)
          {
            area:     face.area,
            normal:   point_to_a(face.normal),
            material: face.material&.display_name,
            back_material: face.back_material&.display_name,
            vertices: face.vertices.map { |v| point_to_a(v.position) },
          }
        end

        def serialize_edge(edge)
          {
            length: edge.length,
            start:  point_to_a(edge.start.position),
            end:    point_to_a(edge.end.position),
            smooth: edge.smooth?,
            soft:   edge.soft?,
          }
        end

        def serialize_group(group)
          {
            name:        group.name,
            description: group.description,
            transform:   transform_to_a(group.transformation),
            bounds:      bounds_to_h(group.bounds),
            entity_count: group.entities.length,
          }
        end

        def serialize_component_instance(instance)
          {
            name:           instance.name,
            definition_name: instance.definition.name,
            transform:      transform_to_a(instance.transformation),
            bounds:         bounds_to_h(instance.bounds),
          }
        end

        def serialize_component_definition(definition)
          {
            name:           definition.name,
            description:    definition.description,
            instances_count: definition.instances.length,
            entity_count:   definition.entities.length,
          }
        end

        # --- 辅助方法 ---

        def point_to_a(point)
          [point.x.to_f, point.y.to_f, point.z.to_f]
        end

        def transform_to_a(transform)
          transform.to_a
        end

        def bounds_to_h(bounds)
          {
            min:    point_to_a(bounds.min),
            max:    point_to_a(bounds.max),
            width:  bounds.width.to_f,
            height: bounds.height.to_f,
            depth:  bounds.depth.to_f,
          }
        end

      end # module EntitySerializer

    end
  end
end
