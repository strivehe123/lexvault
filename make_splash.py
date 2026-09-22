"""Generate + deploy LexVault splash assets
（本文件取代 make_splash_v2.py 与 deploy_splash.py，两处已停用）

设计 ── 版式照「未采纳版」启动页，配色换成本工程品牌紫蓝：
  - 背景：纯色 #4D7CFF（= 主题蓝，也是渐变的左上端）
  - 居中：钥匙孔 L 标记（白色，与 App 图标**同一个形状**）
  - 下方：LexVault（白色粗体）
  - 下方：Build your word vault.（白色 85%）
  - 底部：细白色横线

两个刻意的决定：

  ① 标记与图标**必须是同一个形状**。
     未采纳那版其实有毛病：图标是竖版粗衬线 L（AI 生成），
     启动页标记却是另一个用 CustomPainter 画的横版"拱门+底座"。
     一个品牌不能有两个标记 —— 这里统一用图标那个（它是 34px 擂台赛的赢家）。

  ② 背景保持**纯色**，不用渐变。
     Android 12+ 的 windowSplashScreenBackground 只吃颜色资源，吃不了渐变。
     若这里用渐变、那边用纯色，冷启动会看到"纯色 → 渐变"跳一下。
     渐变交给 App 图标去表达。备选渐变的预览也出了，想换再说。

Android 兼容策略：
  splash_full.png         → splash.png       （< Android 12：居中整块）
  logo_only_android12.png → android12splash  （12+：圆形遮罩安全区内）
  branding.png            → branding         （底部横线）
  #4D7CFF（colors.xml）    → @color/splash_bg （窗口底色，保证无色差过渡）

用法：
  python make_splash.py
"""
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
OUT = os.path.join(ROOT, "assets", "splash")
GLYPH = os.path.join(ROOT, "assets", "icons", "ic_glyph_white.png")
os.makedirs(OUT, exist_ok=True)

BG_COLOR = (0x4D, 0x7C, 0xFF)
BG_TL = (0x4D, 0x7C, 0xFF)
BG_BR = (0x6C, 0x5C, 0xE7)
WHITE = (255, 255, 255, 255)
# 副标用的白。**不能用 70%**：白 70% 压 #4D7CFF 的对比度只有 2.62:1，
# 低于大字线 3:1，真机上看着"发灰发虚"。85% 白 → 3.13:1，过线。
# （想再高就得动品牌底色了 —— 纯白压在 #4D7CFF 上也只有 3.72:1。）
WHITE85 = (255, 255, 255, 217)

FONT = r"C:\Windows\Fonts\segoeuib.ttf"

DENSITIES = [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0),
             ("xxhdpi", 3.0), ("xxxhdpi", 4.0)]


def load_glyph():
    """读出无色母版，裁到图形外接框，返回 (图, 宽高比)"""
    im = Image.open(GLYPH).convert("RGBA")
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.where(a > 127)
    im = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    return im, im.size[0] / im.size[1]


def place_mark(canvas, mk, aspect, height, cy):
    """把标记按给定高度居中摆在 cy 处，返回摆放后的 (x, y, w, h)"""
    w = int(round(height * aspect))
    m = mk.resize((w, height), Image.LANCZOS)
    x, y = (canvas.width - w) // 2, int(cy - height / 2)
    canvas.paste(m, (x, y), m)
    return x, y, w, height


def gradient(w, h):
    """45° 线性渐变（按矢量投影，不是欧氏距离）"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = ((xx / max(1, w - 1)) + (yy / max(1, h - 1))) / 2.0
    t = t[:, :, None]
    rgb = np.array(BG_TL, np.float32) * (1 - t) + np.array(BG_BR, np.float32) * t
    out = np.zeros((h, w, 4), np.uint8)
    out[:, :, :3] = (rgb + 0.5).astype(np.uint8)
    out[:, :, 3] = 255
    return Image.fromarray(out, "RGBA")


mark, aspect = load_glyph()
print(f"标记母版 {mark.size[0]}×{mark.size[1]}   宽高比 {aspect:.3f}")

# ═════════════════════════════════════════════════════════════════
# 1) 居中整块设计：标记 + LexVault + tagline（透明底 1024²）
# ═════════════════════════════════════════════════════════════════
C = 1024
MARK_H = 300                    # 标记高度 = 画布 29.3%（宽度与未采纳版量得的一致）
FONT_BRAND = 116                # 字标：未采纳版里字标比标记更宽（经典 lockup）
FONT_TAG = 40
GAP_MARK = 84                   # 标记下沿 → 字标
# 字标下沿 → 副标。踩过的坑：取 28（≈0.24×字标 ink 高）时，缩到真机只有 ~20px，
# 而字标 ink 高 ~84px，副标像"贴在字标底边上"。比例至少要 ≥0.45×字标 ink 高。
GAP_TAG = 56
GROUP_CY = int(C * 0.42)        # 整组（标记+字标+副标）的垂直中心

center = Image.new("RGBA", (C, C), (0, 0, 0, 0))
draw = ImageDraw.Draw(center)

brand_font = ImageFont.truetype(FONT, FONT_BRAND)
bb = draw.textbbox((0, 0), "LexVault", font=brand_font)
brand_ink = bb[3] - bb[1]
tag_font = ImageFont.truetype(FONT, FONT_TAG)
tb = draw.textbbox((0, 0), "Build your word vault.", font=tag_font)
tag_ink = tb[3] - tb[1]

# 先把整组高度算出来，再决定各元素落点 —— 比一路 offset 下去稳，
# 改了任何字号，整组仍自动居中，不会跑偏
group_h = MARK_H + GAP_MARK + brand_ink + GAP_TAG + tag_ink
group_top = GROUP_CY - group_h // 2

print(f"\n① 居中整块 {C}²")
print(f"   整组高 {group_h}px，中心 y={GROUP_CY}（{GROUP_CY / C:.0%}）")
print(f"   标记   {int(round(MARK_H * aspect))}×{MARK_H}")
print(f"   字标   LexVault {FONT_BRAND}px（ink 高 {brand_ink}）")
print(f"   副标   {FONT_TAG}px（ink 高 {tag_ink}）")

mx, my, mw, mh = place_mark(center, mark, aspect, MARK_H,
                            group_top + MARK_H // 2)
draw.text(((C - (bb[2] - bb[0])) // 2 - bb[0], my + mh + GAP_MARK),
          "LexVault", font=brand_font, fill=WHITE)
draw.text(((C - (tb[2] - tb[0])) // 2 - tb[0],
           my + mh + GAP_MARK + brand_ink + GAP_TAG),
          "Build your word vault.", font=tag_font, fill=WHITE85)
print(f"   落在   y {group_top}→{group_top + group_h}")

center.save(os.path.join(OUT, "splash_full.png"))
print("   ✓ splash_full.png")

# ═════════════════════════════════════════════════════════════════
# 2) 只有标记：给 Android 12+ 的 AnimatedIcon
#    安全区 = 画布居中 2/3 直径的圆 → 标记外接框**对角线**必须 ≤ 0.667 × 画布。
#    对角线 = 高度 × sqrt(1 + 比例²)，由此反推高度上限。
# ═════════════════════════════════════════════════════════════════
A12 = 960
diag_factor = (1 + aspect ** 2) ** 0.5
limit = 0.667 / diag_factor
A12_H = 400
a12_diag = A12_H / A12 * diag_factor
ok = a12_diag <= 0.667
print(f"\n② Android 12 图标 {A12}²")
print(f"   圆安全区：对角线系数 {diag_factor:.3f} → 高度上限 {limit:.1%}，"
      f"实取 {A12_H / A12:.1%}")
print(f"   标记外接框对角线 {a12_diag:.1%} {'✓ 不会被圆形遮罩裁到' if ok else '✗ 会被裁'}")
if not ok:
    raise SystemExit("标记过大，请调小 A12_H")

a12 = Image.new("RGBA", (A12, A12), (0, 0, 0, 0))
place_mark(a12, mark, aspect, A12_H, A12 // 2)
a12.save(os.path.join(OUT, "logo_only_android12.png"))
print("   ✓ logo_only_android12.png")

# ═════════════════════════════════════════════════════════════════
# 3) 底部横线（包要求 800×320）
# ═════════════════════════════════════════════════════════════════
branding = Image.new("RGBA", (800, 320), (0, 0, 0, 0))
bd = ImageDraw.Draw(branding)
cy = 80
bd.line([(260, cy), (540, cy)], fill=WHITE, width=5)
for i in range(1, 15):
    bd.line([(540 + i, cy), (540 + i, cy)],
            fill=(255, 255, 255, max(0, 255 - i * 18)), width=5)
branding.save(os.path.join(OUT, "branding.png"))
print("\n③ ✓ branding.png（居中细横线 + 右端渐隐）")

# ═════════════════════════════════════════════════════════════════
# 4) 预览：纯色（正式）+ 渐变（备选）
# ═════════════════════════════════════════════════════════════════
PW, PH = 780, 1688
scale = PW / C * 0.95
block = center.resize((int(C * scale), int(C * scale)), Image.LANCZOS)
# 真机上 launch_background.xml 用 android:gravity="center" —— 画布是**居中**贴的，
# 不是靠上。上一版预览按 15% 靠上摆，看图会误判成"内容偏上"。这里按居中摆，
# 中心落在 46% 屏高（视觉重心略高于几何中心，观感更稳）。
blk_xy = ((PW - block.width) // 2, int(PH * 0.46) - block.height // 2)
brand_scaled = branding.resize((int(800 * 1.5), int(320 * 1.5)), Image.LANCZOS)
brand_xy = ((PW - brand_scaled.width) // 2, PH - 220)


def compose(bg_img, path, note):
    pv = bg_img.copy()
    pv.paste(block, blk_xy, block)
    pv.paste(brand_scaled, brand_xy, brand_scaled)
    pv.convert("RGB").save(path)
    print(f"   ✓ {note}")


print("\n④ 预览")
compose(Image.new("RGBA", (PW, PH), BG_COLOR + (255,)),
        os.path.join(OUT, "_PREVIEW_PHONE.png"), "_PREVIEW_PHONE.png（纯色 · 正式）")
compose(gradient(PW, PH), os.path.join(OUT, "_PREVIEW_PHONE_GRADIENT.png"),
        "_PREVIEW_PHONE_GRADIENT.png（渐变 · 备选，未部署）")

# 图标与启动页并排放一张，方便一眼看形状是否一致
icon_pv = Image.open(os.path.join(ROOT, "assets", "icons", "_PREVIEW_ICON.png")).convert("RGB")
icon_pv = icon_pv.resize((300, 300), Image.LANCZOS).convert("RGBA")
m = Image.new("L", (300, 300), 0)
ImageDraw.Draw(m).rounded_rectangle([0, 0, 299, 299], radius=67, fill=255)
icon_pv.putalpha(m)
combo = Image.new("RGB", (PH // 2 + 360, PH // 2), (244, 245, 250))
combo.paste(icon_pv, (30, PH // 4 - 150), icon_pv)
sp = Image.open(os.path.join(OUT, "_PREVIEW_PHONE.png")).convert("RGB")
sp = sp.resize((PH // 2 * PW // PH, PH // 2), Image.LANCZOS)
combo.paste(sp, (360, 0))
combo.save(os.path.join(OUT, "_PREVIEW_ICON_SPLASH.png"))
print("   ✓ _PREVIEW_ICON_SPLASH.png（图标 + 启动页同一个形状）")

# ═════════════════════════════════════════════════════════════════
# 5) 部署到 Android res
# ═════════════════════════════════════════════════════════════════
print("\n── 部署 ──")
cleared = 0
if os.path.isdir(RES):
    for d in os.listdir(RES):
        full = os.path.join(RES, d)
        if d.startswith("drawable") and os.path.isdir(full):
            for fn in ("splash.png", "branding.png", "android12splash.png"):
                p = os.path.join(full, fn)
                if os.path.exists(p):
                    os.remove(p)
                    cleared += 1
print(f"   清理旧文件 {cleared} 个（幂等，重复跑不累积）")

JOBS = [("splash_full.png", "splash.png"),
        ("branding.png", "branding.png"),
        ("logo_only_android12.png", "android12splash.png")]
for src_name, out_name in JOBS:
    src = Image.open(os.path.join(OUT, src_name))
    # ⚠️ 必须按**各自源图的宽高比**算目标尺寸，不能一律用正方形边长。
    #   踩过的坑：branding 源是 800×320（ratio 2.5），按 (800,800) 导出 →
    #   纵向拉伸 2.5 倍，真机上细横线变成粗横条。splash/android12splash
    #   恰好都是正方形，所以只有 branding 暴露了这个 bug。
    for density, factor in DENSITIES:
        target = (max(1, round(src.width * factor / 4)),
                  max(1, round(src.height * factor / 4)))
        resized = src.resize(target, Image.LANCZOS)
        for prefix in ("drawable-", "drawable-night-"):
            d = os.path.join(RES, f"{prefix}{density}")
            os.makedirs(d, exist_ok=True)
            resized.save(os.path.join(d, out_name))
    print(f"   {out_name:20s} {src.width}×{src.height} 基准 × 5 档（含 night）")

print("\n" + "═" * 58)
print("✅ 启动页完成")
print("   版式 未采纳版 · 配色本工程紫蓝 #4D7CFF")
print("   标记与 App 图标同一个 keyhole-L 形状")
print("═" * 58)
