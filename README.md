# 小P - AI 情感陪伴助手

基于 Flutter 的手机端 AI 情感陪伴 Agent。

## 功能范围

- 多 AI 提供商支持（LM Studio 本地 / SenseNova / DeepSeek / Qwen / Kimi / GLM / MiMo / 文心 / 混元 / 豆包 / 自定义）
- 流式对话输出
- 分层记忆系统（L0-L4，AI 自动提取 + 定期整合）
- 人格系统（3 种预设 + 无限自定义，持久化）
- 对话管理（多对话、置顶、重命名、删除、搜索）
- 语音交互（STT 语音输入 + TTS 语音朗读）
- 联网搜索（必应中国）
- 工具插件系统（7 个内置工具：搜索/时间/位置/天气/汇率/计算器/翻译）
- 深色/浅色主题 + 5 种主题色
- 连通性测试

## 目标用户

需要情感陪伴、日常聊天、倾听倾诉的用户。

## 技术栈

- **框架**: Flutter 3.x（Dart SDK ^3.11.0）
- **状态管理**: Riverpod
- **路由**: GoRouter
- **网络**: Dio（SSE 流式）
- **持久化**: SharedPreferences + SQLite（sqflite）
- **AI**: OpenAI 兼容 API

## 目录结构

```
lib/
├── main.dart
├── core/           # 主题、网络客户端
├── models/         # ChatMessage, Companion, Conversation, MemoryEntry
├── services/       # AI、对话、记忆、人格、语音、搜索、工具插件
│   └── tools/      # 工具插件系统（ToolPlugin 接口 + 7 个内置工具）
├── providers/      # Riverpod 状态
├── routes/         # GoRouter 路由
└── presentation/   # 界面（home/chat/personality/memory/settings/widgets）
```

## 核心数据流

```
用户输入 → ChatService.saveUserMessage → 保存到 SharedPreferences
         → MemoryService.buildMemoryContext（读取 SQLite 记忆）
         → ToolRegistry.getEnabledSchemas（获取已启用工具）
         → 拼装 systemPrompt + 历史消息 + tools schema
         → Dio POST /chat/completions（stream=true）
         → SSE 流式解析（utf8.decode 防乱码 + leftover 缓存）
         → Agent Loop（支持 Function Calling 的 provider）：
           ├─ AI 返回 tool_calls → ToolRegistry.execute 执行工具 → 结果回传 AI → 继续循环（最多5轮）
           └─ AI 返回纯文本 → 结束
         → 不支持 FC 的 provider：规则触发搜索（路径 B）
         → onToken 回调（50ms 节流更新 UI）
         → onComplete 保存 AI 消息 + 触发记忆提取
```

## 关键设计决策

- **分层记忆**：L0身份 / L1长期 / L2热 / L3温 / L4归档。高重要性且高召回次数的记忆自动提升为 L1，旧记忆衰减并归档
- **流式输出**：用 `ResponseType.stream` + SSE 解析，`utf8.decode(chunk, allowMalformed: true)` + leftover 缓存防止多字节字符被 chunk 截断
- **thinking 模式**：默认开启，通过 `</think` 标签在聊天气泡中可折叠展示推理过程
- **节流渲染**：流式 token 回调每 50ms 才触发一次 UI 重建，避免高频 setState 卡顿
- **消息保存**：流式开始前提前捕获 `conversationId`，防止 widget dispose 后保存失败
- **工具插件系统**：`ToolPlugin` 接口 + `ToolRegistry` 单例。启动时 `registerBuiltin()` 注册 7 个内置工具，ChatService 通过 `getEnabledSchemas()` 动态获取已启用工具传给 AI。Agent Loop 最多 5 轮工具调用，不支持 Function Calling 的 provider 走规则触发搜索

## 安装与构建

### 环境要求

- Flutter 3.x（Dart SDK ^3.11.0）
- Android SDK（compileSdk / minSdk 跟随 Flutter 默认）

### 步骤

```bash
# 1. 克隆仓库
git clone https://github.com/VitasGuo/xiaop.git
cd xiaop

# 2. 安装依赖
flutter pub get

# 3. 运行（Debug）
flutter run

# 4. 构建 APK
flutter build apk --release
```

### LM Studio 本地连接

LM Studio 需绑定到所有网络接口，手机才能访问：

```bash
lms server start --bind 0.0.0.0
```

然后在 APP 设置中填入 PC 的局域网 IP，格式 `http://<你的IP>:1234/v1`（如 `http://192.168.1.10:1234/v1`），并填写已加载的模型名称。

## 开源协议

MIT License — 详见 [LICENSE](LICENSE)
