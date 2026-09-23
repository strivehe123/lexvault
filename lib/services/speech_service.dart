/// 跟读识别的**门面**：按编译目标二选一，二者公开 API 必须保持一致。
///
/// - 原生（Android / Windows）：`speech_service_io.dart`
///   —— 本地 Vosk 离线模型优先，失败回退讯飞 RTASR，走自研 MethodChannel 采音。
/// - Web（GitHub Pages 演示站）：`speech_service_web.dart`
///   —— 浏览器原生 Web Speech API，不可用时退化为演示模式。
///
/// 之所以要做这层：`vosk_flutter` 依赖 `dart:ffi`，**Web 平台根本无法编译**。
/// 用 conditional export 让 Web 构建在编译期就把它排除掉，
/// 原生构建的行为与拆分前**完全一致**（io 文件是原文件的原样拷贝）。
export 'speech_service_web.dart'
    if (dart.library.io) 'speech_service_io.dart';
