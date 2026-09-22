"""Generate LexVault app icon（自适应图标 + legacy 回退）。

形状 ── 取自「未采纳版」的 keyhole-L glyph（assets/icons/ic_glyph_white.png）：
        一坨连体的粗衬线 L，锁孔开在竖杆里。
        它是 10 个候选里唯一通过「34px 最近邻放大」可辨性测试的形态。
        旧版是三块分离圆角矩形，小尺寸下读不出 L，也不够整。
配色 ── 本工程品牌紫蓝渐变 #4D7CFF (左上) → #6C5CE7 (右下)。

三条硬约束（都是踩过的）：

  ① Android 自适应图标的安全区是 108dp 画布居中 66dp（66/108 ≈ 0.611）。
     图形外接框最长边必须落在安全区内，否则会被圆形/方形遮罩裁掉笔画。
     这里取 0.60 留一点余量。

  ② 自适应前景必须是**透明底**：底色由 background 层给，前景只放图形。

  ③ 背景渐变**不再用 drawable shape XML**。XML 的 android:angle 表达的是
     "渐变方向"，起止端点在哪两个角上很容易搞反（225 和 315 刚好差一个镜像），
     而 Python 预览是按 TL→BR 画的 —— 两者不一致时，预览和真机就是反的。
     改成预渲染位图 mipmap-*/ic_launcher_background.png：
     设备上看到的就是这里渲染的，零歧义，也和 _PREVIEW_ICON.png 逐像素一致。

用法：
  python make_icon.py
"""
from PIL import Image, ImageDraw
import numpy as np
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
ICONS = os.path.join(ROOT, "assets", "icons")
GLYPH = os.path.join(ICONS, "ic_glyph_white.png")

CANVAS = 1024
SAFE_RATIO = 0.60          # 66/108 = 0.611，留余量
BG_TL = (0x4D, 0x7C, 0xFF)  # 主题蓝
BG_BR = (0x6C, 0x5C, 0xE7)  # 主题紫

LEGACY_DP = 48             # legacy ic_launcher.png 的基准
ADAPTIVE_DP = 108          # 自适应 foreground / background 的基准
DENSITIES = [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0),
             ("xxhdpi", 3.0), ("xxxhdpi", 4.0)]


# ══════════════════════════════════════════════════════════════════
# 1) 背景：真 45° 对角线性渐变（按矢量投影，不是欧氏距离）
# ══════════════════════════════════════════════════════════════════
def gradient_bg(size=CANVAS):
    """TL=start, BR=end。t 取 (x+y) 的归一化 —— 这才是 45° 线性渐变的正确投影，
    欧氏距离 sqrt(x²+y²) 是径向近似，会把右上/左下角压到 0.707 而不是 0.5。"""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    t = (xx + yy) / (2.0 * (size - 1))
    t = t[:, :, None]
    tl = np.array(BG_TL, np.float32)
    br = np.array(BG_BR, np.float32)
    rgb = tl * (1 - t) + br * t
    out = np.zeros((size, size, 4), np.uint8)
    out[:, :, :3] = (rgb + 0.5).astype(np.uint8)
    out[:, :, 3] = 255
    return Image.fromarray(out, "RGBA")


# ══════════════════════════════════════════════════════════════════
# 2) 前景：glyph 按安全区摆正
# ══════════════════════════════════════════════════════════════════
def build_foreground():
    src = Image.open(GLYPH).convert("RGBA")
    a = np.asarray(src)[:, :, 3]
    ys, xs = np.where(a > 127)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    gw, gh = x1 - x0 + 1, y1 - y0 + 1
    print(f"  glyph 源     : {src.size[0]}×{src.size[1]}，图形 {gw}×{gh} "
          f"（占 {gw / src.size[0]:.1%} × {gh / src.size[1]:.1%}）")

    crop = src.crop((x0, y0, x1 + 1, y1 + 1))
    s = SAFE_RATIO * CANVAS / max(gw, gh)
    new = (max(1, round(gw * s)), max(1, round(gh * s)))
    crop = crop.resize(new, Image.LANCZOS)
    print(f"  按安全区摆放 : 外接框 {new[0]}×{new[1]}  "
          f"= 画布 {new[0] / CANVAS:.1%} × {new[1] / CANVAS:.1%}"
          f"（安全区上限 {66 / 108:.1%}）")

    fg = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    fg.paste(crop, ((CANVAS - new[0]) // 2, (CANVAS - new[1]) // 2), crop)
    return fg


# ══════════════════════════════════════════════════════════════════
# 3) 遮罩预检：圆形 / 圆角方形下有没有被裁到
# ══════════════════════════════════════════════════════════════════
def mask_preview(preview, size=220):
    """把成品分别套圆形与圆角方形遮罩，检查笔画有没有出界。
    自适应图标在真机上会被裁成厂商自定义形状（圆/方/水滴），这里取两种极端。"""
    tile = preview.resize((size, size), Image.LANCZOS)
    out = Image.new("RGB", (size * 2 + 30, size + 8), (239, 241, 246))

    circle = Image.new("L", (size, size), 0)
    ImageDraw.Draw(circle).ellipse([0, 0, size - 1, size - 1], fill=255)
    out.paste(tile, (0, 4), circle)

    squircle = Image.new("L", (size, size), 0)
    ImageDraw.Draw(squircle).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * 0.2237), fill=255)
    out.paste(tile, (size + 30, 4), squircle)
    return out


# ══════════════════════════════════════════════════════════════════
# 主流程
# ══════════════════════════════════════════════════════════════════
def main():
    print("─" * 58)
    print("① 背景渐变  #4D7CFF (TL) → #6C5CE7 (BR)")
    bg = gradient_bg()
    print(f"   TL={bg.getpixel((0, 0))[:3]}  BR={bg.getpixel((CANVAS - 1, CANVAS - 1))[:3]}")

    print("\n② 前景 glyph")
    fg = build_foreground()
    fg_path = os.path.join(ICONS, "ic_launcher_foreground_raw.png")
    fg.save(fg_path)
    print(f"   → {os.path.relpath(fg_path, ROOT)}")

    print("\n③ 预览合成")
    preview = Image.alpha_composite(bg, fg)
    preview_path = os.path.join(ICONS, "_PREVIEW_ICON.png")
    preview.save(preview_path)
    print(f"   → {os.path.relpath(preview_path, ROOT)}")

    mp = mask_preview(preview)
    mp_path = os.path.join(ICONS, "_PREVIEW_MASKS.png")
    mp.save(mp_path)
    print(f"   遮罩预检 → {os.path.relpath(mp_path, ROOT)}")

    print("\n④ 部署到 5 档 mipmap")
    deployed = []
    for density, factor in DENSITIES:
        out_dir = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(out_dir, exist_ok=True)

        # 自适应层：108dp 基准（foreground 透明底 / background 渐变位图）
        ad = max(1, round(ADAPTIVE_DP * factor))
        fg.resize((ad, ad), Image.LANCZOS).save(
            os.path.join(out_dir, "ic_launcher_foreground.png"))
        bg.resize((ad, ad), Image.LANCZOS).save(
            os.path.join(out_dir, "ic_launcher_background.png"))

        # legacy 回退：**48dp 基准**，不是 108dp。
        # 踩过的坑：三张图共用同一个边长（108dp），legacy 图标就大了 2.25 倍 ——
        # 系统要按非整数比缩放，且白占体积。这里按各自 dp 基准分别算。
        lg = max(1, round(LEGACY_DP * factor))
        preview.resize((lg, lg), Image.LANCZOS).save(
            os.path.join(out_dir, "ic_launcher.png"))
        # round 版：内容同 legacy，形状交给系统裁（部分厂商启动器会主动找它）
        preview.resize((lg, lg), Image.LANCZOS).save(
            os.path.join(out_dir, "ic_launcher_round.png"))

        deployed.append((density, ad, lg))
        print(f"   {density:8s} 自适应 {ad:>3}×{ad:<3}（{ADAPTIVE_DP}dp）  "
              f"legacy {lg:>3}×{lg:<3}（{LEGACY_DP}dp）")

    # 自检：别让"共用边长"这类错误静默通过
    for density, factor in DENSITIES:
        d = os.path.join(RES, f"mipmap-{density}")
        checks = {"ic_launcher.png": LEGACY_DP,
                  "ic_launcher_round.png": LEGACY_DP,
                  "ic_launcher_foreground.png": ADAPTIVE_DP,
                  "ic_launcher_background.png": ADAPTIVE_DP}
        for fn, dp in checks.items():
            got = Image.open(os.path.join(d, fn)).size
            exp = round(dp * factor)
            assert got == (exp, exp), f"{density}/{fn} 是 {got}，应为 {(exp, exp)}"
    print("   ✓ 自检通过：legacy 48dp / 自适应 108dp，5 档全部匹配")

    # ⚠️ 背景由 @drawable/ic_launcher_background(shape XML) 换成位图，
    #    消除 android:angle 起止端点的歧义
    xml = os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml")
    os.makedirs(os.path.dirname(xml), exist_ok=True)
    with open(xml, "w", encoding="utf-8") as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
""")
    print(f"\n⑤ 自适应图标 XML 已指向位图背景 → {os.path.relpath(xml, ROOT)}")

    print("\n" + "═" * 58)
    print("✅ 图标完成")
    print(f"   形状 keyhole-L  ·  配色 紫蓝渐变 #4D7CFF→#6C5CE7")
    print(f"   5 档 mipmap 各 4 个文件（foreground / background / ic_launcher / ic_launcher_round）")
    print("═" * 58)


if __name__ == "__main__":
    main()
