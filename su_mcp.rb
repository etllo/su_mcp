# frozen_string_literal: true

# ============================================================================
# SU MCP Server - SketchUp Model Context Protocol Plugin
# Copyright (c) 2024 1Pitaph
# ============================================================================
#
# 标准 SketchUp 扩展加载器
# 此文件应放置在 SketchUp 的 Plugins 目录下
#

require 'sketchup'
require 'extensions'

module OnePitaph
  module SuMcp

    # --- 扩展信息 ---
    PLUGIN_ID       = 'OnePitaph_SuMcp'    unless defined?(PLUGIN_ID)
    PLUGIN_NAME     = 'SU MCP Server'      unless defined?(PLUGIN_NAME)
    PLUGIN_VERSION  = '0.1.0'              unless defined?(PLUGIN_VERSION)
    PLUGIN_DIR      = File.dirname(__FILE__) unless defined?(PLUGIN_DIR)
    PLUGIN_PATH     = File.join(PLUGIN_DIR, 'su_mcp') unless defined?(PLUGIN_PATH)

    # --- 注册扩展 ---
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_PATH, 'main'))
      extension.description = 'MCP (Model Context Protocol) server for SketchUp, ' \
                              'enabling AI-assisted 3D modeling through standardized protocol.'
      extension.version     = PLUGIN_VERSION
      extension.creator     = '1Pitaph'
      extension.copyright   = "Copyright (c) 2024 1Pitaph"

      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end

  end # module SuMcp
end # module OnePitaph
