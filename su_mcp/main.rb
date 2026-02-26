# frozen_string_literal: true

# ============================================================================
# SU MCP Server - 插件主入口
# 此文件由 SketchupExtension 加载器延迟加载
# ============================================================================

module OnePitaph
  module SuMcp

    # --- 加载所有子模块 ---
    PLUGIN_PATH = File.join(File.dirname(__FILE__)) unless defined?(PLUGIN_PATH)

    require File.join(PLUGIN_PATH, 'version')
    require File.join(PLUGIN_PATH, 'config')

    # Utils
    require File.join(PLUGIN_PATH, 'utils', 'logger')
    require File.join(PLUGIN_PATH, 'utils', 'entity_serializer')

    # Server 层
    require File.join(PLUGIN_PATH, 'server', 'json_rpc')
    require File.join(PLUGIN_PATH, 'server', 'session')
    require File.join(PLUGIN_PATH, 'server', 'tcp_server')
    require File.join(PLUGIN_PATH, 'server', 'mcp_handler')

    # MCP 协议抽象
    require File.join(PLUGIN_PATH, 'mcp', 'tool')
    require File.join(PLUGIN_PATH, 'mcp', 'tool_registry')
    require File.join(PLUGIN_PATH, 'mcp', 'resource')
    require File.join(PLUGIN_PATH, 'mcp', 'prompt')
    require File.join(PLUGIN_PATH, 'mcp', 'server')

    # 具体 Tools
    require File.join(PLUGIN_PATH, 'tools', 'get_model_info')
    require File.join(PLUGIN_PATH, 'tools', 'get_selection')
    require File.join(PLUGIN_PATH, 'tools', 'create_geometry')
    require File.join(PLUGIN_PATH, 'tools', 'transform_entities')
    require File.join(PLUGIN_PATH, 'tools', 'set_material')
    require File.join(PLUGIN_PATH, 'tools', 'get_entity_info')
    require File.join(PLUGIN_PATH, 'tools', 'delete_entities')
    require File.join(PLUGIN_PATH, 'tools', 'execute_ruby')

    # ========================================================================
    # 插件管理器
    # 负责初始化 MCP 服务器和注册 UI 元素
    # ========================================================================
    module PluginManager

      # 使用 ||= 惰性初始化：文件 reload 时不会重置已有的服务器引用
      @tcp_server ||= nil
      @mcp_server ||= nil

      class << self

        # 启动 MCP 服务器
        def start_server
          if @tcp_server&.running?
            Utils::Logger.warn('Server already running', source: 'PluginManager')
            UI.messagebox('MCP Server 已在运行中！')
            return
          end

          begin
            # 创建 MCP Server 核心
            @mcp_server = MCP::McpServer.new
            register_tools(@mcp_server)

            # 创建 TCP 传输层
            handler = Server::McpHandler.new(@mcp_server)
            @tcp_server = Server::TcpServer.new(handler)
            @tcp_server.start

            port = SuMcp.config.port
            Utils::Logger.info("MCP Server started on port #{port}",
                               source: 'PluginManager')
            UI.messagebox("MCP Server 已启动!\n端口: #{port}")
          rescue => e
            Utils::Logger.error("Failed to start: #{e.message}",
                                source: 'PluginManager')
            UI.messagebox("MCP Server 启动失败:\n#{e.message}")
          end
        end

        # 停止 MCP 服务器
        def stop_server
          unless @tcp_server&.running?
            Utils::Logger.info('Server not running', source: 'PluginManager')
            UI.messagebox('MCP Server 未在运行。')
            return
          end

          @tcp_server.stop
          @tcp_server = nil
          @mcp_server = nil

          Utils::Logger.info('MCP Server stopped', source: 'PluginManager')
          UI.messagebox('MCP Server 已停止。')
        end

        # 查看服务器状态
        def show_status
          if @tcp_server&.running?
            sessions = @tcp_server.sessions.length
            tools = @mcp_server&.tool_registry&.size || 0
            port = SuMcp.config.port

            msg = "MCP Server 状态: 运行中\n" \
                  "端口: #{port}\n" \
                  "活跃连接: #{sessions}\n" \
                  "已注册工具: #{tools}\n" \
                  "版本: #{VERSION}"
          else
            msg = "MCP Server 状态: 已停止"
          end

          UI.messagebox(msg)
        end

        # 服务器是否运行中
        def running?
          @tcp_server&.running? || false
        end

        private

        # 注册所有 Tools
        def register_tools(mcp_server)
          mcp_server.tool_registry.register_all(
            Tools::GetModelInfo,
            Tools::GetSelection,
            Tools::CreateGeometry,
            Tools::TransformEntities,
            Tools::SetMaterial,
            Tools::GetEntityInfo,
            Tools::DeleteEntities,
            Tools::ExecuteRuby
          )

          count = mcp_server.tool_registry.size
          Utils::Logger.info("Registered #{count} tools: #{mcp_server.tool_registry.names.join(', ')}",
                            source: 'PluginManager')
        end

      end # class << self

    end # module PluginManager

    # ========================================================================
    # 注册 SketchUp 菜单
    # ========================================================================
    unless file_loaded?(File.basename(__FILE__))

      menu = UI.menu('Extensions').add_submenu('SU MCP Server')

      menu.add_item('Start Server')  { PluginManager.start_server }
      menu.add_item('Stop Server')   { PluginManager.stop_server }
      menu.add_separator
      menu.add_item('Server Status') { PluginManager.show_status }

      Utils::Logger.info("SU MCP Plugin v#{VERSION} loaded", source: 'Main')

      file_loaded(File.basename(__FILE__))
    end

  end
end
