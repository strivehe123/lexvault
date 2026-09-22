"""⛔ 已停用 —— 实现已合并进 make_splash.py

本文件（make_splash_v2.py）原先负责生成"圆角方块 + 白 L"版启动页素材，
现已统一改为 keyhole-L 标记版，并连同部署一起并入 make_splash.py。

保留此桩是为了防止误跑：直接执行它会在 assets/splash/ 里重新生成旧版方块 L 素材，
覆盖掉新版。请改用：

    python make_splash.py

（原件已备份在 _brand_backup_20260922_1209/ 下）
"""
import sys

print(__doc__)
sys.exit(1)
