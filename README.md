# SU MCP Server

SketchUp MCP (Model Context Protocol) 服务器插件，使 AI 客户端（如 Claude）能通过标准化协议与 SketchUp 交互，实现 AI 辅助 3D 建模。

## 架构

```
MCP客户端 (Claude) <--stdio--> stdio_bridge.py <--TCP--> SketchUp TCP Server
```

- **SketchUp 内部**: 非阻塞 TCP 服务器 (端口 9876)，使用 `UI.start_timer` 轮询
- **stdio_bridge.py**: 跨平台 Python 脚本，桥接 stdio 和 TCP（无外部依赖）
- **SketchUp 插件**: 全部纯 Ruby 实现，无外部 gem 依赖

## 安装

1. 将 `su_mcp.rb` 和 `su_mcp/` 文件夹复制到 SketchUp 的 Plugins 目录:
   - Windows: `%APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\`
   - macOS: `~/Library/Application Support/SketchUp 2024/SketchUp/Plugins/`

2. 重启 SketchUp，在 Extension Manager 中确认 "SU MCP Server" 已启用

## 使用

### 启动服务器
- 菜单: **Extensions > SU MCP Server > Start Server**
- 或在 Ruby Console 中: `OnePitaph::SuMcp::PluginManager.start_server`

### 配置 Claude Desktop

编辑 Claude Desktop 配置文件：
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

**Windows** (需先将 `stdio_bridge.py` 复制到纯英文路径):
```json
{
  "mcpServers": {
    "sketchup": {
      "command": "python",
      "args": ["C:\\su_mcp_bridge\\stdio_bridge.py"],
      "env": { "SU_MCP_PORT": "9876" }
    }
  }
}
```

**macOS:**
```json
{
  "mcpServers": {
    "sketchup": {
      "command": "python3",
      "args": ["/path/to/bridge/stdio_bridge.py"],
      "env": { "SU_MCP_PORT": "9876" }
    }
  }
}
```

> **依赖**: Python 3（macOS 内置；Windows 若无请从 [python.org](https://www.python.org/downloads/) 安装并勾选 "Add Python to PATH"）

配置保存后，**完全重启** Claude Desktop 生效。

## 可用工具

| 工具名               | 说明                       | 只读 |
| -------------------- | -------------------------- | ---- |
| `get_model_info`     | 获取模型概要信息           | ✅    |
| `get_selection`      | 获取当前选中实体           | ✅    |
| `create_geometry`    | 创建几何体 (面/边/组/盒子) | ❌    |
| `transform_entities` | 变换实体 (移动/旋转/缩放)  | ❌    |
| `set_material`       | 设置材质颜色               | ❌    |
| `get_entity_info`    | 获取实体详细信息           | ✅    |
| `delete_entities`    | 删除实体                   | ❌    |
| `execute_ruby`       | 执行任意 Ruby 代码         | ❌    |

## 自定义配置

```ruby
OnePitaph::SuMcp.configure do |c|
  c.port = 8888
  c.log_level = :debug
  c.max_clients = 10
end
```

## 文件结构

```
su_mcp/
├── su_mcp.rb              # 扩展加载器
├── su_mcp/                # 支撑文件夹
│   ├── main.rb            # 插件入口
│   ├── version.rb         # 版本
│   ├── config.rb          # 配置
│   ├── server/            # TCP/JSON-RPC 传输层
│   ├── mcp/               # MCP 协议抽象
│   ├── tools/             # 工具实现
│   └── utils/             # 工具函数
├── bridge/
│   ├── stdio_bridge.py    # Stdio 桥接脚本 (Python, 推荐跨平台)
│   └── stdio_bridge.rb    # Stdio 桥接脚本 (Ruby, 备用)
└── README.md
```

## License

Copyright (c) 2024 1Pitaph. All rights reserved.
