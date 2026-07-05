# 小P 踩坑记录

## #1 Android 闪退 - ClassNotFoundException
- **现象**: `java.lang.ClassNotFoundException: Didn't find class "com.vitasguo.xiao_p.MainActivity"`
- **根因**: 从 Stock-King 复制后，Kotlin 源码目录仍是旧包名 `com.vitasguo.stock_king`，build.gradle.kts 改了 namespace 但源码没改
- **解决**: 创建 `android/app/src/main/kotlin/com/vitasguo/xiao_p/MainActivity.kt`，删除旧目录

## #2 LM Studio 连接超时
- **现象**: 手机连接 LM Studio 超时，PC 可以访问
- **根因**: LM Studio 绑定在链路本地地址 `169.254.83.107`，手机无法访问；需要 `lms server start --bind 0.0.0.0` 监听所有接口
- **解决**: 命令行启动 LM Studio 绑定 `0.0.0.0`，APP 默认 IP 改为局域网地址

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
