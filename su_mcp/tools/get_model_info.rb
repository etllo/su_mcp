# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module Tools

      # ======================================================================
      # 获取模型信息
      # 返回当前 SketchUp 模型的概要信息
      # ======================================================================
      class GetModelInfo < MCP::Tool

        tool_name 'get_model_info'

        description '获取当前 SketchUp 模型的概要信息，包括文件名、路径、' \
                    '实体数量、图层/标签列表、组件定义、模型边界等。'

        input_schema(
          properties: {},
          required:   []
        )

        annotations(
          read_only_hint:    true,
          destructive_hint:  false,
          idempotent_hint:   true,
          open_world_hint:   false,
        )

        class << self
          def call(**_args)
            model = Sketchup.active_model

            unless model
              return MCP::Tool::Response.new(
                content: [{ 'type' => 'text', 'text' => 'No active model' }],
                is_error: true
              )
            end

            info = {
              title:             model.title,
              description:       model.description,
              path:              model.path,
              modified:          model.modified?,
              active_entities_count: model.active_entities.length,
              all_entities_count:    model.entities.length,
              layers:            collect_layers(model),
              component_definitions: collect_definitions(model),
              materials_count:   model.materials.length,
              bounds:            Utils::EntitySerializer.bounds_to_h(model.bounds),
              units:             model.options['UnitsOptions']['LengthUnit'],
            }

            MCP::Tool::Response.new(
              content: [{ 'type' => 'text', 'text' => JSON.generate(info) }]
            )
          end

          private

          def collect_layers(model)
            model.layers.map do |layer|
              {
                name:    layer.name,
                visible: layer.visible?,
              }
            end
          end

          def collect_definitions(model)
            model.definitions.select { |d| !d.group? && d.instances.length > 0 }.map do |defn|
              {
                name:            defn.name,
                instances_count: defn.instances.length,
                description:     defn.description,
              }
            end
          end
        end

      end # class GetModelInfo

    end
  end
end
