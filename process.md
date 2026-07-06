# 小P 进度

## 当前版本: v1.1.0

## 版本历史

### v1.1.0 (2026-07-06)
- 内置 SenseNova 开箱即用（预置 API Key，deepseek-v4-flash）
- 默认提供商改为 SenseNova，无需配置即可对话
- 代码清理：删除死代码（voice_chat_screen 454行 + memory_extractor 245行）
- 修复变量遮蔽 Bug（chat_screen 流式回调中 text 变量名冲突）
- 去重：合并 clearMessages/deleteConversationMessages
- 去重：删除对话列表重复排序
- 去重：删除人格编辑重复 setCurrentCompanion 调用
- 渐变色提取为 AppTheme.accentGradient 常量，替换 6 处硬编码
- 移除未使用的 cupertino_icons 依赖
- 版本号更新至 1.1.0+1

### v1.0.2 (2026-07-06)
- thinking 模式开关：关闭时发送 `/no_think` 提示词
- 上下文长度设置：2-50条消息滑块，持久化
- 修复退出对话卡死：添加 `_disposed` 标志防止 dispose 后 setState
- 记忆提取修复：onComplete 回调中恢复记忆提取
- 自定义人格编辑：已保存的人格可二次编辑

### v1.0.1 (2026-07-06)
- 修复界面卡死：联网搜索5秒超时，流式输出50ms节流
- 流式输出乱码修复：UTF-8 正确解码 + 不完整行缓存
- thinking 模式：聊天气泡内折叠展示思考过程
- 关于页面：版本号、功能特性、技术栈
- 对话历史：滑动删除 + 长按置顶/重命名
- 自定义人格持久化：切换预设不丢失
- 项目规范：README.md + process.md + traps.md

### v1.0.0 (2026-07-06)
- 多 AI 提供商支持（LM Studio / DeepSeek / Qwen / Kimi / GLM / MiMo / 文心 / 混元 / 豆包 / 自定义）
- 流式对话输出（SSE + UTF-8 正确解码）
- 分层记忆系统（L0-L4 五层 + AI 自动提取 + 定期整合）
- 人格系统（3 种预设 + 自定义，持久化，不因切换预设丢失）
- 对话管理（多对话、置顶、重命名、滑动删除）
- 语音交互（STT 语音输入 + TTS 语音朗读）
- 联网搜索（DuckDuckGo API，5秒超时）
- 深色/浅色主题
- 连通性测试按钮
- Android HTTP 明文流量支持（network_security_config）
- 自定义 APP 图标（薰衣草紫 + 爱心）

## 已知问题

- Gemma 4 的 thinking/reasoning 模式无法通过 API 关闭（模型内置）
- 退出对话偶尔仍有卡顿（需进一步排查）
