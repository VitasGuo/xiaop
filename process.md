# 小P 进度

## 当前版本: v1.4.1

## 版本历史

### v1.4.1-patch (2026-07-08)
- **修复工具系统不工作**：
  - 根因：Agent Loop 条件依赖 `webSearchEnabled`，用户关闭联网搜索后整个工具系统被禁用
  - 修复：Agent Loop 条件改为只检查 `enabledSchemas.isNotEmpty`，不再依赖 `webSearchEnabled`
  - 路径 B（规则搜索）仍由 `webSearchEnabled` 控制
- **修复日志不可见**：`Log.d` 从 `dart:developer` 改为 `debugPrint`，确保 flutter run 控制台可见
- **修复 Gradle 编译超时**：`dl.google.com` 被墙，切换阿里云镜像仓库
- **测试验证**：get_location → weather 多轮工具调用成功（深圳天气）

### v1.4.1 (2026-07-08)
- **新增位置获取工具**：
  - GetLocationTool：GPS 定位 + Nominatim 反向地理编码获取城市名
  - 用户问天气未指定城市时，AI 自动调用 get_location 获取位置再查天气
  - AndroidManifest 添加 ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION 权限
  - 依赖 geolocator ^14.0.3
- **Agent Loop 修复**：
  - H1: onToolCall 移到 execute 之前（用户立即看到"正在搜索..."提示）
  - H2: fullBuffer 累积工具提示，流式显示与最终保存一致
  - H3: 请求取消后不再保存半截消息/不触发记忆提取（_StreamResult.cancelled）
  - M2: Agent Loop 循环改为 <= maxIterations，第5轮工具结果不再被丢弃
- **死代码清理**：
  - 删除 getAllSchemas/isRegistered（从未调用）
  - 删除 _StreamResult.finishReason 字段（从未读取）
  - 修复 exchange_rate_tool 三元表达式两分支相同的死逻辑
  - 移除误加的 ignore 注释，禁用 use_null_aware_elements lint（map entry 不适用）

### v1.4.0 (2026-07-08)
- **工具插件系统**：
  - 插件注册制架构（ToolPlugin 接口 + ToolRegistry 单例）
  - 6 个内置工具：联网搜索、当前时间、天气查询、汇率换算、计算器、翻译
  - 设置页工具管理入口（底部弹窗展示所有工具 + 单独开关）
  - ChatService 改用 ToolRegistry 动态获取 schemas（不再硬编码工具定义）
  - 通用 system prompt（引导 AI 按 schema 自主选择工具）
- **死代码清理**：删除 message_service.dart（sqflite 保留，MemoryService 仍需要）
- **MemoryExtractor 接线**：修复 apiKey 三种情况处理（presetKey/needsApiKey/无key），接入 chat_screen
- CalculatorTool 依赖 expressions ^0.2.5+3（纯 Dart 表达式解析，支持 ^→pow() 预处理）
- 修复 4 个断裂点：registerBuiltin 空壳、main 未注册、chat_service 编译错误、expressions 版本号

### v1.3.1 (2026-07-08)
- **搜索质量大幅提升**：
  - 修复必应标题解析（h2>strong 结构，非 h2>a）
  - 新增深度阅读：搜索后并行抓取 Top 3 网页正文（每页限 2000 字符）
  - 正文清洗：去 script/style/nav/footer，优先提取 article/main 标签
  - 搜索超时从 10s 提升到 20s（含网页抓取时间）
  - 优化 system prompt：引导 AI 信息不足时换关键词多轮搜索
  - 外部链接过滤：跳过 bing.com/msn.com 内部链接

### v1.3.0 (2026-07-08)
- **Agent Loop（智能体循环）**：
  - 支持 Function Calling 的 provider（DeepSeek/Qwen/Kimi/GLM/豆包/混元/文心/LM Studio）启用 AI 自主工具调用
  - AI 可多轮调用 web_search + get_current_time 工具，最多 5 轮
  - 流式解析 tool_calls 分片累积，执行工具后结果回传 AI 继续思考
  - 不支持的 provider（SenseNova/MiMo/自定义）自动回退规则触发搜索
  - UI 展示工具调用过程（🔍 正在搜索 / 🕐 获取时间）
- 联网搜索改用必应中国（cn.bing.com），DuckDuckGo 国内不可访问
- 智能触发规则（时效/事实/搜索意图关键词），避免情感聊天也搜索
- http 包改为 Dio，减少外部依赖

### v1.2.7 (2026-07-08)
- 发布前代码审查全量修复：
  - 修复重新生成/重试导致用户消息重复保存的 bug（新增 isNewMessage 参数）
  - 修复 typing indicator 与空 streaming bubble 同时显示
  - 修复 flutter analyze 4 项问题（deprecated color.value / 下划线本地变量 / 死代码 / BuildContext 跨 async gap）
  - 接入 MemoryService.incrementRecall 到 buildMemoryContext（原为死代码，记忆提升规则 recall_count 现可生效）
  - 删除 WebSearchService.fetchPage 死代码
  - 修复 _parseAndSaveExtractedMemories 的 void async 反模式
  - settings_screen 版本号改用 package_info_plus 动态读取
  - 修复 conversation_list_screen 的 _searchController 未释放
  - system 主题模式监听 platformBrightness 变化（XiaoPApp 改为 StatefulWidget + WidgetsBindingObserver）
  - 清除 about_screen 中 Stock-King + The-hacker-world 引用，修正 SenseNova "开箱即用" 描述
  - 新增 MIT LICENSE
  - README 补全安装/构建说明、核心数据流、修复 thinking 标签名
  - .gitignore 补充敏感文件规则（.env / *.key / keystore / google-services.json 等）

### v1.2.6 (2026-07-06)
- 主题色实时切换：重构 Theme 类，accentColor 改为可变，支持 5 种主题色
- 主题色持久化到 SharedPreferences，启动时自动加载

### v1.2.5 (2026-07-06)
- 对话导出：AppBar 导出按钮，复制 Markdown 格式到剪贴板
- 主题色选择：设置页 5 种预设主题色
- 版本号更新至 1.2.5

### v1.2.4 (2026-07-06)
- 记忆自动整合：每 6 小时自动衰减旧记忆、提升重要记忆
- Logger 工具：新建 `utils/logger.dart`

### v1.2.3 (2026-07-06)
- 错误处理日志：16 处静默异常改为带日志输出

### v1.2.2 (2026-07-06)
- AI 记忆提取接入：每次对话后调用 AI 接口提取用户事实/偏好/情绪/习惯/关系
- 单条消息删除：长按消息弹出菜单可删除
- TTS 暂停控制：服务层新增 pause()/stop() 方法
- 关于页功能列表更新

### v1.2.1 (2026-07-06)
- 单条消息长按菜单：复制 + 重新生成 + 删除
- TTS 语速调节 UI：设置页滑块 0.1x-2.0x
- 联网搜索开关：设置页可关闭搜索

### v1.2.0 (2026-07-06)
- 首页删除"开始聊天"入口，用户从底部对话 tab 进入
- 欢迎引导页：首次打开 3 页引导（介绍/记忆/语音）
- 对话搜索：AppBar 搜索图标，按标题过滤
- 消息重新生成：AI 消息长按可重新生成
- 联网搜索开关

### v1.1.1 (2026-07-06)
- 消息保存兜底：conversationId 提前捕获
- SenseNova 重新内置
- 功能完成度评估

### v1.1.0 (2026-07-06)
- SenseNova 内置开箱即用
- 代码清理：删除死代码 700 行
- 修复变量遮蔽 Bug
- 渐变色重构为常量

### v1.0.2 (2026-07-06)
- thinking 模式开关（/no_think）
- 上下文长度滑块
- 退出卡死修复
- 自定义人格编辑

### v1.0.1 (2026-07-06)
- 流式乱码修复
- thinking 折叠展示
- 滑动删除 + 置顶
- 自定义人格持久化

### v1.0.0 (2026-07-06)
- 初始版本：多 AI 提供商、流式对话、记忆系统、人格系统、语音、搜索、主题

## 已知问题

- Gemma 4 的 thinking/reasoning 模式无法通过 API 关闭（模型内置）
