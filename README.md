<div align="center">

# LexVault · 背单词

**看图 → 跟读 → 拼写，一条链把单词真正记住。**

Flutter 写的英语背单词 App · Android 手机 / 平板 · Windows 桌面 · 内置离线语音识别

**在线演示（免安装，浏览器直接打开）：** <https://strivehe123.github.io/lexvault/>

</div>

---

## 目录

- [这是什么](#这是什么)
- [功能](#功能)
- [内置词库](#内置词库)
- [怎么用：三种方式](#怎么用三种方式)
  - [方式一：Android 手机 / 平板（推荐）](#方式一android-手机--平板推荐)
  - [方式二：Windows 电脑](#方式二windows-电脑)
  - [方式三：浏览器打开网页版](#方式三浏览器直接打开网页演示版已上线零安装)
- [学习流程说明](#学习流程说明)
- [语音识别（可选配置）](#语音识别可选配置)
- [从源码构建](#从源码构建)
- [项目结构](#项目结构)
- [常见问题](#常见问题)
- [素材来源与版权声明](#素材来源与版权声明)
- [许可](#许可)

---

## 这是什么

一个**单机、不需要注册登录、数据全在本地**的背单词 App。

核心设计只有一条：**一个单词要被「眼睛看、耳朵听、嘴巴说、手指拼」四次打磨，才算学会。**
所以每个词都会走完三个阶段 —— 先看图听音，再按住跟读（App 实时判断你读对没有），
最后用 App 内置的字母键盘把它拼出来。全程不需要联网，也不需要讯飞之类的云服务。

技术栈：Flutter 3.x · Provider 状态管理 · Vosk 离线语音识别 · flutter_tts 朗读 · audioplayers 音效。

---

## 功能

| 功能 | 说明 |
|---|---|
| **五本词库** | CEFR A1 / A2 / KET / PET / AWL 学术词表，共 7,369 词 |
| **图文卡片** | 每个词配一张图 + 音标 + 词性 + 中文 + 英文释义 + 例句 |
| **自动朗读** | 进单词卡、拼错后，都会自动播一遍标准发音 |
| **语音跟读判定** | 按住按钮读一遍，App 离线判断读对没有（不联网、不上传录音） |
| **内置拼写键盘** | 只保留 26 个字母键，去掉数字/符号/中英切换，防误触 |
| **三振出局** | 跟读连错 3 次自动转拼写，拼写连错 3 次自动看详情 —— 绝不被一个词卡死 |
| **强化 / 复习** | 学完一轮后进入强化阶段，专攻没掌握的 |
| **学情热力图** | 首页 14 周 × 7 天打卡热力图，按「每日目标」分四档着色 |
| **打卡与进度** | 连续天数、今日进度、每日目标、全书进度、收藏夹 |
| **提示音** | 跟读成功 / 拼写错误 / 按键音效，可在首页长按 Logo 打开自检面板试听 |

> 未完成的入口：首页四宫格里的**「错题本」和「设置」目前是空按钮**（点了没反应），别当失效 bug。

---

## 内置词库

| ID | 名称 | 词数 | 每日默认 | 素材体积（图 / 音） |
|---|---|---|---|---|
| `a1` | CEFR A1 入门词汇 | 89 | 5 | 7 MB / 2 MB |
| `a2` | CEFR A2 基础词汇 | 539 | 10 | 44 MB / 11 MB |
| `ket` | KET 核心词汇 | 1,508 | 5 | 134 MB / 24 MB |
| `pet` | PET 必备单词 | 3,024 | 5 | 287 MB / 53 MB |
| `awl` | AWL 学术词汇表 | 2,209 | 15 | 211 MB / 53 MB |

> ⚠️ **这是本项目最需要注意的一点：全部素材加起来约 866 MB**（图片 683 MB + 音频 143 MB + Vosk 模型 40 MB），
> 所以打出来的 APK 接近 **900 MB**。装得下，但下载和安装都很慢。
> 只想留几本的话，见 [APK 太大怎么办](#apk-太大怎么办)。

---

## 怎么用：三种方式

### 方式一：Android 手机 / 平板（推荐）

这是唯一**完整支持**的方式，离线识别、朗读、音效全部可用。

#### 1-a. 直接下载现成的 APK（最省事）

不用装任何开发环境，直接拿编译好的包：

**下载页：<https://github.com/strivehe123/lexvault/releases>**

| 文件 | 适用设备 |
|---|---|
| `LexVault-v1.0.0-arm64.apk` | **绝大多数手机 / 平板（2017 年后的机型都行）**，装这个 |

直链（发布后可用）：
`https://github.com/strivehe123/lexvault/releases/latest/download/LexVault-v1.0.0-arm64.apk`

> **包比较大（约 890 MB）**，因为词库配图和真人发音是**打包在应用里**的 ——
> 换来的好处是装完**完全离线可用**，不联网、不耗流量。
> 嫌大就看下一节自己裁剪词库（能砍到十几 MB 到几百 MB 不等）。
>
> 这是 arm64 单架构包，不含 32 位老设备和模拟器版本。装不上就往下看。

#### 1-b. 自己打一个 APK 装到手机上

前提：电脑上装好 [Flutter SDK](https://docs.flutter.dev/get-started/install)（`flutter doctor` 全绿）。

```bash
git clone https://github.com/strivehe123/lexvault.git
cd lexvault

flutter pub get

# 打 release 包；--split-per-abi 会按 CPU 架构分开打，体积最小
flutter build apk --release --split-per-abi
```

产物在 `build/app/outputs/flutter-apk/`：

| 文件 | 给谁用 |
|---|---|
| `app-arm64-v8a-release.apk` | **绝大多数现代手机 / 平板，装这个** |
| `app-armeabi-v7a-release.apk` | 很老的 32 位设备 |
| `app-x86_64-release.apk` | 模拟器 |

> 想要能调试的包就 `flutter build apk --debug`，产物是 `app-debug.apk`（体积更大）。
> 手机已开 USB 调试的话，直接 `flutter install` 更省事。

#### 1-c. 把 APK 传到手机

随便哪种都行：

- **数据线**：手机选「传输文件（MTP）」，拖进 `内部存储/Download/`
- **微信**：发到「文件传输助手」，手机端点开
- **局域网**（手机和电脑连同一个 Wi-Fi）：电脑上执行

  ```bash
  cd build/app/outputs/flutter-apk
  python -m http.server 8000
  ```

  手机浏览器打开 `http://<电脑的局域网IP>:8000/`，点文件名下载。
  查电脑 IP：Windows 上跑 `ipconfig`，看 IPv4 地址。

#### 1-d. 安装与首次启动

1. 在手机「文件管理」里找到 APK，点开安装
2. 系统提示「禁止安装未知应用」→ 允许当前来源安装（各厂商路径不同，通常在
   `设置 → 安全 → 安装未知应用`）
3. 首次启动会**解压 40 MB 的离线语音模型**，可能停留几秒，属正常
4. 第一次跟读时系统会要**麦克风权限**，同意即可（不给也能用，只是跟读阶段会被跳过）

> 权限一共只申请两个：`RECORD_AUDIO`（跟读）和 `INTERNET`（讯飞兜底，用不到就不会发请求）。
> 没有账号、没有埋点、没有云同步 —— **所有学习进度都只存在本机**。

---

### 方式二：Windows 电脑

仓库里已经有 `windows/` 桌面工程，**但作者尚未实测**，属于「理论可用、需自己踩坑」：

```bash
flutter config --enable-windows-desktop
flutter run -d windows
```

需要 Visual Studio 2022，并勾选「使用 C++ 的桌面开发」工作负载。

已知风险：

- `vosk_flutter` 声明了 Windows 平台实现（FFI），依赖原生库；若运行时报「找不到库」，
  需要把对应的 dll 放到 `windows/runner/` 或可执行文件同级目录
- 桌面麦克风走另一套权限体系（Windows 设置 → 隐私 → 麦克风）
- 素材体积问题在桌面端同样存在，构建产物体积接近 900 MB

**如果只是想在电脑上背单词，用 Android 模拟器往往更省事**：装个模拟器，把 1-a 打出的
APK 拖进去即可，功能和手机完全一致。

---

### 方式三：浏览器直接打开（网页演示版，**已上线，零安装**）

👉 **<https://strivehe123.github.io/lexvault/>**

不想装 App 的话，把上面这个链接发给对方就行 —— 手机、平板、电脑浏览器都能开，不用注册。

| | 网页版 | Android 版 |
|---|---|---|
| 安装 | **不用装**，打开链接就用 | 装 APK |
| 看图 / 发音 / 拼写 | ✅ | ✅ |
| 跟读识别 | 浏览器内置语音识别（Chrome / Edge / Safari）；不支持的浏览器（如 Firefox）自动进入**演示模式**，松手即判定成功，保证流程能走通 | 离线 Vosk，断网也能用 |
| 学习进度 | 存在浏览器本地（清缓存 / 换浏览器会丢） | 存在设备上，离线可靠 |
| 加载速度 | 首次要下几 MB 前端资源，图片按需加载 | 装完就在本地 |

网页版适合**快速体验和给别人演示**；日常背词还是推荐装 Android 版。

自己构建网页版：

```bash
flutter build web --release --base-href /lexvault/ --no-web-resources-cdn
# --no-web-resources-cdn 很关键：默认 CanvasKit 从 gstatic CDN 取，国内打不开会白屏

# 想本地预览
python -m http.server 8080 -d build/web
```

部署是自动的：push 到 `main` 后由 `.github/workflows/deploy-web.yml` 构建并发布到 GitHub Pages。

> 技术说明：Web 平台**不支持 `dart:ffi`**，而离线识别库 `vosk_flutter` 依赖它，
> 所以 `lib/services/speech_service.dart` 做了一层条件导出 ——
> 原生用 `speech_service_io.dart`（Vosk / 讯飞），Web 用 `speech_service_web.dart`（浏览器语音识别 + 演示模式）。
> 两个文件公开 API 一致，原生端行为与拆分前完全相同。

---

## 学习流程说明

```
选择题库 → 单词卡（自动朗读）
            ↓
       按住按钮「跟读」→ 离线判定 → 读对 ↓
            ↓ 连错 3 次 ────────┘
       拼写（内置字母键盘）
            ↓ 拼对 → 下一个词
              连错 3 次 → 详情页（看完整释义与例句）
            ↓
       当日目标完成 → 强化阶段复习 → 完成页
```

首页能看到：

- **连续打卡天数**、**今日已学 / 每日目标**、百分比进度条
- **学习热力图**：最近 14 周 × 7 天，颜色越深当天学得越多（按每日目标分档，不是按历史最高值）
- **每日目标**可在首页调整（点进度卡片里的「每日 N 词」）

---

## 语音识别（可选配置）

### 默认：离线 Vosk（**什么都不用配**）

包内自带 `vosk-model-small-en-us-0.15`（40 MB），首次启动自动解压到应用目录。
不联网、不上传录音、不需要任何密钥。

### 可选：讯飞在线识别（准确率更高，需要联网）

只有在离线识别不可用时才会走这条路。要用的话：

1. 注册 <https://console.xfyun.cn/>，创建应用，拿到 **AppID / APIKey / APISecret**
2. 订阅「实时语音转写（大模型版）」
3. **用编译期注入的方式**传进去（**不要**写进源码文件）：

```bash
flutter run \
  --dart-define=IFLYTEK_APP_ID=你的AppID \
  --dart-define=IFLYTEK_KEY_ID=你的APIKey \
  --dart-define=IFLYTEK_SECRET=你的APISecret
```

命令行太长，可以写进一个被 `.gitignore` 忽略的 `keys.json`：

```json
{ "IFLYTEK_APP_ID": "...", "IFLYTEK_KEY_ID": "...", "IFLYTEK_SECRET": "..." }
```

```bash
flutter build apk --release --dart-define-from-file=keys.json
```

> 🔐 **为什么必须这么绕？** 因为 `lib/config/iflytek_config.dart` 是**受版本控制**的文件，
> 往里面填密钥就等于把密钥发布到 GitHub 上（本项目早期版本就这么翻过车）。
> 所以那个文件只从 `--dart-define` 取值，**故意没有留可以填字符串的位置**。
> 没配也不会报错 —— 应用会自动跳过讯飞，只用离线识别。

---

## 从源码构建

### 环境要求

| 项目 | 版本 |
|---|---|
| Flutter | 3.x（stable） |
| Dart | 随 Flutter 安装 |
| Android 构建 | Android SDK + JDK 17 |
| Windows 构建 | Visual Studio 2022（含 C++ 桌面工作负载） |

```bash
flutter doctor          # 先确认没有红色项
flutter pub get         # 拉依赖
flutter run             # 连上设备跑调试版
flutter test            # 跑单元测试
flutter build apk --release --split-per-abi
```

> ⚠️ `flutter test` 会先把 `assets/`（866 MB）打包一遍，**第一次跑要好几分钟且期间没有任何输出**，
> 不是卡死了，耐心等。

### 常用命令

| 想干什么 | 命令 |
|---|---|
| 跑调试版 | `flutter run` |
| 装到已连接的手机 | `flutter install` |
| 打 release APK（分架构） | `flutter build apk --release --split-per-abi` |
| 只跑某一个测试 | `flutter test test/heatmap_card_test.dart` |
| 检查代码问题 | `flutter analyze` |
| 清理构建产物 | `flutter clean` |

---

## 项目结构

```
lib/
├── main.dart                     应用入口（主题、路由、Provider）
├── config/iflytek_config.dart    可选：在线识别凭证（只从 --dart-define 取值）
├── models/                       word.dart / word_book.dart —— 词条与词书数据模型
├── pages/
│   ├── splash_page.dart          启动页（品牌页）
│   ├── home_page.dart            首页：进度、打卡、热力图、四宫格入口
│   ├── word_books_page.dart      词库列表 / 收藏夹
│   ├── book_detail_page.dart     单词本详情
│   ├── study/study_session_page.dart    学习流程（跟读 → 拼写 → 详情）
│   ├── review/review_session_page.dart  强化复习流程
│   └── complete_page.dart        完成页
├── services/
│   ├── speech_service.dart       语音识别（Vosk 离线优先，讯飞兜底）
│   ├── tts_service.dart          单词朗读（flutter_tts）
│   ├── sound_service.dart        提示音（含 diagnose() 自检）
│   └── progress_service.dart     本地学习进度（shared_preferences）
├── state/app_state.dart          全局状态
├── theme/app_theme.dart          配色与字体
└── widgets/                      通用组件（热力图卡片、品牌标、音效自检弹窗…）

assets/
├── data/books/       a1/a2/ket/pet/awl.json + library.json（词库清单）
├── images/<book>/    单词配图（webp）
├── audio/<book>/     单词发音（mp3）
├── models/           Vosk 离线模型（zip，首启解压）
├── sounds/           提示音（success / error / tick）
├── icons/            品牌标记
└── splash/           启动图源文件

android/               Android 工程
windows/               Windows 桌面工程
test/                  单元测试
tools/ tool/ *.py      素材制作脚本（词库转换、音频抓取、图标/启动图生成、音效归一）
docs/                  设计说明
```

---

## 常见问题

### 没有声音 / 拼写时没有音效？

按顺序排查：

1. **按手机音量键，确认「媒体音量」不是 0**（不是「铃声音量」），也别开「应用单独音量」把本应用调成 0
2. **长按首页左上角的蓝色 Logo** → 打开「音效自检」面板，那里会显示：
   - 音效系统初始化是否成功、每个音效文件的报错、**累计播出次数**
   - 三个试听按钮
3. 判断方法：
   - 点试听**有声音、累计次数在涨** → 正常
   - **累计次数不涨 / 有报错** → 是 App 的问题，带截图提 issue
   - **次数在涨但你没听到** → 是设备侧音量或蓝牙输出设备的问题

### 跟读一直失败？

- 确认给了**麦克风权限**（设置 → 应用 → LexVault → 权限）
- 首次识别前要等模型解压完成（约几秒）
- 环境太吵、离麦克风太远都会影响；**连错 3 次会自动跳过进入拼写**，不会卡住
- 手机壳挡住麦克风孔也会明显拉低识别率

### APK 太大怎么办？

素材占 866 MB。只留需要的词库即可，改完直接重新打包，pubspec 不用动
（`assets/` 是按目录声明的）：

```bash
# 例：只保留 A1 + A2（素材从 866 MB 降到约 51 MB，APK 大约 80 MB）
rm -rf assets/images/{awl,ket,pet} assets/audio/{awl,ket,pet}

# 同步改词库清单，否则首页会去加载已经不存在的词库
echo '{ "files": ["a1.json", "a2.json"] }' > assets/data/books/library.json

flutter build apk --release --split-per-abi
```

（Vosk 模型那 40 MB 不能删，删了跟读功能就没了。）

### 首页的「错题本」「设置」点了没反应？

这两个入口**还没实现**，是空按钮，不是设备问题。

### 换个手机，进度会同步吗？

不会。进度只存在本机，这是刻意设计 —— 不注册、不联网、不上传。
换设备就是重新开始。

---

## 素材来源与版权声明

⚠️ **把本仓库公开之前请务必读完这一节。** 代码是原创的，但素材不是。

| 内容 | 来源 | 分发风险 |
|---|---|---|
| 单词发音（`assets/audio/`） | 通过网络公开接口抓取（见 `fetch_us_audio.py`） | **中高** —— 录音版权属来源方，仅供个人学习；公开分发需自行确认条款 |
| 单词配图（`assets/images/`，7,359 张） | 网上检索收集整理 | **中高** —— 版权归各自原作者，未逐张取得授权 |
| 词表（KET / PET） | Cambridge 考试官方词汇表整理 | **中** —— 词表本身属他人整理成果 |
| AWL 学术词表 | Coxhead (2000) 学术词汇表 | 低 —— 学术资源，引用请注明出处 |
| Vosk 语音模型 | [alphacep/vosk](https://github.com/alphacep/vosk-api) | 低 —— Apache-2.0 |
| 代码 | 本项目原创 | 见下方「许可」 |

**建议**：

- 个人学习、内部试用：直接用没问题
- **公开分发 / 上架应用商店前**：把发音和配图换成自有、有授权或可商用的素材
  （词的释义、例句、词表本身通常可以保留）
- 抓取脚本（`fetch_us_audio.py`、`convert_*.py`）仅作技术示例，
  使用前请自行确认并遵守目标网站的 robots 与使用条款

---

## 许可

- **代码**：建议采用 MIT 许可（仓库当前尚未放 `LICENSE` 文件，作者可自行补充）
- **素材（图片 / 音频 / 词表）**：**不在**上述许可范围内，版权归各自权利人，
  仅限个人学习使用，不得直接商用或再分发
- 若需转载或商用，请先替换素材或取得授权

---

<div align="center">

**如果这个项目对你有帮助，给个 ⭐ 吧。**

</div>
