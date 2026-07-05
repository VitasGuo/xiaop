# 小P - AI 情感陪伴助手

基于 Stock-King (Flutter) 架构改造的手机端 AI 情感陪伴 Agent。

## 功能范围

- 多 AI 提供商支持（LM Studio 本地 / DeepSeek / Qwen / Kimi / GLM / MiMo / 文心 / 混元 / 豆包 / 自定义）
- 流式对话输出
- 分层记忆系统（L0-L4，AI 自动提取 + 定期整合）
- 人格系统（3 种预设 + 无限自定义，持久化）
- 对话管理（多对话、置顶、重命名、删除）
- 语音交互（STT 语音输入 + TTS 语音朗读）
- 联网搜索（DuckDuckGo API）
- 深色/浅色主题
- 连通性测试

## 技术栈

- **框架**: Flutter 3.x
- **状态管理**: Riverpod
- **路由**: GoRouter
- **网络**: Dio (SSE 流式)
- **持久化**: SharedPreferences + SQLite
- **AI**: OpenAI 兼容 API

## 目录结构

```
lib/
├── main.dart
├── core/           # 主题、网络客户端
├── models/         # ChatMessage, Companion, Conversation, MemoryEntry
├── services/       # AI、对话、记忆、人格、语音、搜索
├── providers/      # Riverpod 状态
├── routes/         # GoRouter 路由
└── presentation/   # 界面（home/chat/personality/memory/settings/widgets）
```

## 关键设计决策

- 分层记忆：L0身份/L1长期/L2热/L3温/L4归档
- 流式输出用 `ResponseType.stream` + SSE 解析，UTF-8 用 `utf8.decode` 防乱码
- thinking 模式默认开启，通过 `<think>` 标签在聊天气泡中可折叠展示
