# frozen_string_literal: true

module OnePitaph
  module SuMcp
    module MCP

      # ======================================================================
      # Prompt 基类
      # 提供可复用的提示模板
      # ======================================================================
      class Prompt

        Message = Struct.new(:role, :content, keyword_init: true)

        Result = Struct.new(:description, :messages, keyword_init: true) do
          def to_h
            {
              'description' => description,
              'messages'    => messages.map do |m|
                {
                  'role'    => m.role,
                  'content' => { 'type' => 'text', 'text' => m.content },
                }
              end,
            }
          end
        end

        Argument = Struct.new(:name, :description, :required, keyword_init: true) do
          def to_h
            hash = { 'name' => name, 'description' => description.to_s }
            hash['required'] = required if required
            hash
          end
        end

        class << self

          def prompt_name(name = nil)
            if name
              @prompt_name = name
            else
              @prompt_name || self.name.split('::').last
                                  .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                                  .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                                  .downcase
            end
          end

          def description(desc = nil)
            desc ? (@description = desc) : (@description || '')
          end

          def arguments(args = nil)
            args ? (@arguments = args) : (@arguments || [])
          end

          # 生成提示模板 (子类实现)
          # @param args [Hash]
          # @return [Prompt::Result]
          def template(args = {})
            raise NotImplementedError, "#{name} must implement .template"
          end

          def to_mcp_hash
            hash = {
              'name'        => prompt_name,
              'description' => description,
            }
            unless arguments.empty?
              hash['arguments'] = arguments.map(&:to_h)
            end
            hash
          end

        end

      end # class Prompt

      # ======================================================================
      # Prompt 注册表
      # ======================================================================
      class PromptRegistry

        def initialize
          @prompts = {}
        end

        def register(prompt_class)
          name = prompt_class.prompt_name
          @prompts[name] = prompt_class
          Utils::Logger.debug("Registered prompt: #{name}",
                              source: 'PromptRegistry')
        end

        def register_all(*prompt_classes)
          prompt_classes.flatten.each { |pc| register(pc) }
        end

        def find(name)
          @prompts[name]
        end

        def list
          @prompts.values.map(&:to_mcp_hash)
        end

        def get(name, arguments = {})
          prompt_class = find(name)
          raise ArgumentError, "Unknown prompt: #{name}" unless prompt_class

          prompt_class.template(arguments)
        end

        def size
          @prompts.size
        end

      end # class PromptRegistry

    end
  end
end
