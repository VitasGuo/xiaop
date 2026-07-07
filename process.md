# 小P 进度

## 当前版本: v1.2.7

## 版本历史

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
