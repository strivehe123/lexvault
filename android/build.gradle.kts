allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
}

// ─────────────────────────────────────────────────────────────────────
// 给"没写 namespace 的老插件"补上 namespace
//
// 背景：AGP 8 起，每个 Android 模块必须自己声明 namespace，没写就**直接配置失败**
// （不是警告）：
//   A problem occurred configuring project ':vosk_flutter'.
//   > Namespace not specified. Specify a namespace in the module's build file
//
// 撞上的是 vosk_flutter 0.3.48 —— 上游最新就是它、没修，而离线语音要用它，删不掉。
//
// 为什么修在工程侧，而不是去改 pub cache：
//   ① pub cache 是全局共享的，`flutter pub cache repair` 会把它冲掉，
//      换台机器 clone 又坏；修在工程里才可复现；
//   ② 插件本身不用动 —— 将来上游补了 namespace，这段自动空操作。
//
// ⚠️ 位置必须在文件最前面（在 `evaluationDependsOn(":app")` 之前）：
// 那行会提前求值子工程，等它跑完再注册 afterEvaluate 会直接报
// "Cannot run Project.afterEvaluate(Action) when the project is already evaluated"。
// 而且 AGP 自己也是在 afterEvaluate 里建 variant 的，我们的回调必须注册在它前面。
//
// 取 namespace 优先用插件自己声明的 group（vosk 是 org.vosk.vosk_flutter，
// 正好等于它 AndroidManifest 里的 package），取不到再退到模块名。
// 用反射而不是 AGP 类型，是为了不依赖 AGP 的编译期类。
// ─────────────────────────────────────────────────────────────────────
subprojects {
    val patchNamespace: () -> Unit = {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val cls = androidExt.javaClass
            val current = try {
                cls.getMethod("getNamespace").invoke(androidExt)
            } catch (_: Exception) {
                null
            }
            if (current == null) {
                val ns = project.group.toString().ifBlank { "com.example.${project.name}" }
                try {
                    cls.getMethod("setNamespace", String::class.java).invoke(androidExt, ns)
                    logger.lifecycle("[namespace] ${project.name} ← $ns（插件没写，工程侧补上）")
                } catch (e: Exception) {
                    logger.lifecycle("[namespace] ${project.name} 补写失败：$e")
                }
            }
        }
    }
    if (state.executed) patchNamespace() else afterEvaluate { patchNamespace() }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
