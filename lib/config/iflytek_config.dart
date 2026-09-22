/// 讯飞开放平台凭证（**可选**）。
///
/// LexVault 默认走**离线** Vosk 识别（模型随包内置），开箱即用、不联网、不需要密钥。
/// 只有在离线识别不可用、需要联网兜底时，才需要填这三个值。
///
/// ⚠️ 不要把真实密钥写进这个文件
/// ------------------------------------------------------------------
/// 这个文件是**受版本控制**的（GitHub 上公开可见）。往里面填密钥 = 直接泄露。
/// 本项目历史提交就踩过这个坑（AppID / APIKey / APISecret 曾被提交进 git）。
/// 所以这里**故意不提供**「填字符串」的位置，只从编译期注入取值。
///
/// 正确用法（密钥只存在于命令行或本机 json，不落进任何受版本控制的文件）：
///
/// ```bash
/// flutter run \
///   --dart-define=IFLYTEK_APP_ID=你的AppID \
///   --dart-define=IFLYTEK_KEY_ID=你的APIKey \
///   --dart-define=IFLYTEK_SECRET=你的APISecret
/// ```
///
/// 命令行太长的话，把它们写进一个**被 .gitignore 忽略**的 json：
///
/// ```json
/// { "IFLYTEK_APP_ID": "...", "IFLYTEK_KEY_ID": "...", "IFLYTEK_SECRET": "..." }
/// ```
///
/// 然后 `flutter build apk --release --dart-define-from-file=keys.json`。
///
/// 怎么申请
/// --------
/// 1. 注册 <https://console.xfyun.cn/>
/// 2. 创建应用 → 拿到 AppID / APIKey / APISecret
/// 3. 订阅「实时语音转写（大模型版）」
class IflytekConfig {
  /// 三个都为空即视为「未配置」，应用会自动跳过讯飞、只使用离线识别。
  static const String appId = String.fromEnvironment('IFLYTEK_APP_ID');
  static const String accessKeyId = String.fromEnvironment('IFLYTEK_KEY_ID');
  static const String accessKeySecret = String.fromEnvironment('IFLYTEK_SECRET');

  static bool get isConfigured =>
      appId.isNotEmpty && accessKeyId.isNotEmpty && accessKeySecret.isNotEmpty;
}
