import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'pages/splash_page.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_mark.dart';

/// 品牌启动页最短停留时长。
///
/// 初始化通常一两百毫秒就完了；一跑完就跳首页，品牌页等于"闪一下"，
/// 看着像卡顿而不是有意为之。给它一个完整的展示时间。
/// 这只是**下界** —— 初始化真慢就老实等，宁可慢也不要白屏。
const Duration _minSplash = Duration(milliseconds: 900);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先把标记解码好再上第一帧，否则首帧上标记是空的（解码是异步的），
  // 冷启动会看到"标记闪一下没了"。
  await warmUpBrandMark();
  runApp(const LexVaultApp());
}

/// 应用根：**先上品牌启动页，初始化在后台跑**。
///
/// ⚠️ 这里刻意**不**写 `await state.init()` 再 `runApp`。
/// 那条老路会让原生启动页一直停在屏幕上直到首个 Flutter 帧，而首帧要等
/// 初始化结束 —— 中间那段（实测 1~2 秒）用户盯着的是系统那个"只有图标"的
/// 启动页。先 runApp，品牌页就能接住这段时间，字标也就看得见了。
///
/// Provider 必须留在 `MaterialApp` **外面**：push 出来的页面
/// （词书列表 / 学习页…）是 Navigator 的兄弟节点，挂在 `home` 里面的
/// Provider 它们找不到。
class LexVaultApp extends StatefulWidget {
  const LexVaultApp({super.key});

  @override
  State<LexVaultApp> createState() => _LexVaultAppState();
}

class _LexVaultAppState extends State<LexVaultApp> {
  final AppState _state = AppState();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    try {
      await _state.init();
    } catch (e, s) {
      // 不能把异常吞了 —— 这里挂了首页会一直转圈，至少日志里要看得到原因。
      // 仍然放行到首页（book == null 时首页显示加载态），不做黑屏。
      debugPrint('[LexVault] 初始化失败：$e\n$s');
    }
    final spent = DateTime.now().difference(started);
    if (spent < _minSplash) {
      await Future<void>.delayed(_minSplash - spent);
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _state,
      child: MaterialApp(
        title: 'LexVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: _ready
            // 首页是浅底 → 状态栏图标用深色。必须显式声明：
            // 启动页那帧把 overlay 设成了 light，不覆盖会残留成白色（白图标压浅底=看不见）
            ? const AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark,
                child: HomePage(),
              )
            : const SplashPage(),
      ),
    );
  }
}
