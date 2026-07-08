# 小P 踩坑记录

## #1 Android 闪退 - ClassNotFoundException
- **现象**: `java.lang.ClassNotFoundException: Didn't find class "com.vitasguo.xiao_p.MainActivity"`
- **根因**: 从 Stock-King 复制后，Kotlin 源码目录仍是旧包名 `com.vitasguo.stock_king`，build.gradle.kts 改了 namespace 但源码没改
- **解决**: 创建 `android/app/src/main/kotlin/com/vitasguo/xiao_p/MainActivity.kt`，删除旧目录

## #2 LM Studio 连接超时
- **现象**: 手机连接 LM Studio 超时，PC 可以访问
- **根因**: LM Studio 绑定在链路本地地址 `169.254.83.107`，手机无法访问；需要 `lms server start --bind 0.0.0.0` 监听所有接口
- **解决**: 命令行启动 LM Studio 绑定 `0.0.0.0`，APP 中 LM Studio 不再预填默认 IP，由用户自行填写局域网地址

## #3 流式输出乱码
- **现象**: 中文回复出现乱码
- **根因**: SSE 流式返回的字节流中，中文 UTF-8 多字节字符被 chunk 截断
- **解决**: 用 `utf8.decode(chunk, allowMalformed: true)` + `leftover` 缓存不完整行

## #4 自定义人格切换预设后丢失
- **现象**: 保存自定义人格后，切换到预设再切回来，自定义人格消失
- **根因**: 人格只存了一个 `current` key，切换预设直接覆盖
- **解决**: 新增 `companion_list` key 存储所有保存的人格列表，切换只改 current 不删 list

## #5 界面卡死
- **现象**: 发送消息后界面冻结，无法点击
- **根因**: 联网搜索阻塞主线程 + 每个 token 都触发 setState 全量重建
- **解决**: 搜索加 5 秒超时；onToken 回调加 50ms 节流

## #6 Android 禁止 HTTP 明文流量
- **现象**: LM Studio 用 `http://` 被系统拦截
- **根因**: Android 9+ 默认 `cleartextTrafficPermitted=false`
- **解决**: 添加 `res/xml/network_security_config.xml`，AndroidManifest 引用

## #7 消息保存丢失
- **现象**: 对话列表有记录但进入后看不到消息内容
- **根因**: 流式 onComplete 回调中用 `widget.conversationId`，widget dispose 后引用无效导致保存静默失败
- **解决**: 流式开始前用 `final convId = widget.conversationId` 提前捕获，回调中用 `convId`

## #8 PowerShell 替换破坏 UTF-8 文件
- **现象**: 用 PowerShell `-replace` 替换中文字符串后文件乱码，Flutter 编译报错
- **根因**: PowerShell 的 `-replace` 运算符对 Unicode 处理有问题，会截断多字节字符
- **解决**: 用 Dart/Flutter 的 edit 工具逐文件替换，不要用 PowerShell 批量替换含中文的代码文件

## #9 expressions 包版本号错误导致 pub get 失败
- **现象**: `Because xiao_p depends on expressions ^5.0.0 which doesn't match any versions, version solving failed.`
- **根因**: pubspec.yaml 写了 `expressions: ^5.0.0`，但 pub.dev 上 expressions 包最新版本是 0.2.5+3（版本号体系不同，不是 5.x 大版本）
- **解决**: 改为 `expressions: ^0.2.5+3`，API（`Expression.parse()` + `ExpressionEvaluator().eval()`）完全兼容

## #10 工具系统接线断裂导致 agent 无法调用工具
- **现象**: 工具插件文件全部创建完成，但 AI 始终不调用工具，表现为"只能 chat 不能 work"
- **根因**: 4 个接线点断裂：① `tool_registry.dart` 的 `registerBuiltin()` 方法体为空（只有注释）；② `main.dart` 未调用 `registerBuiltin()`；③ `chat_service.dart` 引用已删除的 `_toolDefinitions` 且未 import `tool_registry.dart`（编译错误）；④ `expressions` 版本号错误导致 pub get 失败
- **解决**: 逐一修复 4 个断裂点：填充 registerBuiltin、main 中注册、chat_service 改用 `ToolRegistry().getEnabledSchemas()`、expressions 版本改为 ^0.2.5+3
