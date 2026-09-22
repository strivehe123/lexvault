"""⛔ 已停用 —— 部署逻辑已并入 make_splash.py

本文件（deploy_splash.py）原先只负责把 assets/splash/ 下的素材铺到
android res 各 density 目录。现在生成与部署是同一件事的两半，
拆开跑容易出现"素材是新的、res 里还是旧的"，所以合并了。

请改用：

    python make_splash.py      # 生成 + 部署，一条命令

（原件已备份在 _brand_backup_20260922_1209/ 下）
"""
import sys

print(__doc__)
sys.exit(1)
