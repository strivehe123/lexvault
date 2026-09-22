"""从无色母版裁出「UI 用标记」→ assets/icons/glyph_mark.png

用途：Flutter 启动页、首页顶栏、任何需要画品牌标记的地方。

为什么要单独裁一份，而不直接用 ic_glyph_white.png：
  母版是 1024² 带大量留白的（图形只占 46%×53%），那是给 Android 自适应图标
  用的 —— 图标有"安全区"要求，留白是**内容**的一部分。
  但 UI 排版里留白是**干扰**：标记下沿到字标的间距会被这圈透明边吃掉，
  算不准。裁到外接框后，SizedBox(height: 120) 就是实实在在的 120dp 图形高。

两条约束：
  ① 只裁不缩放。母版 538px 高，在 4x 屏（120dp × 4 = 480px）仍然够用，
     放大反而糊。分辨率不够时再插值。
  ② 判 alpha 用 >8 而不是 >0：AI 生成的边缘有极淡的残余 alpha
     （值 1~5），按 >0 判会把外接框撑大几个像素。

用法：
  python make_glyph_mark.py
"""
from PIL import Image
import numpy as np
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(ROOT, "assets", "icons")
SRC = os.path.join(ICONS, "ic_glyph_white.png")
DST = os.path.join(ICONS, "glyph_mark.png")

ALPHA_MIN = 8     # 低于此值视为全透明（去 AI 边缘残余）
PAD = 0           # 留白 0：Flutter 侧要能精确控制"标记下沿→字标"的间距


def main():
    if not os.path.exists(SRC):
        raise SystemExit(f"找不到母版：{SRC}\n（先跑 make_icon.py 的抽形状步骤，或用 _extract_glyph.py 生成）")

    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im)
    mask = a[:, :, 3] > ALPHA_MIN
    ys, xs = np.where(mask)
    if len(xs) == 0:
        raise SystemExit("母版里没有不透明像素，检查 SRC")

    x0, x1 = max(0, xs.min() - PAD), min(im.width - 1, xs.max() + PAD)
    y0, y1 = max(0, ys.min() - PAD), min(im.height - 1, ys.max() + PAD)
    mark = im.crop((x0, y0, x1 + 1, y1 + 1))

    # 裁完必须复验：外接框 == 整幅，否则说明 PAD 或阈值算错了
    b = np.asarray(mark)[:, :, 3] > ALPHA_MIN
    ys2, xs2 = np.where(b)
    assert xs2.min() == 0 and xs2.max() == mark.width - 1, "裁切后仍有横向留白"
    assert ys2.min() == 0 and ys2.max() == mark.height - 1, "裁切后仍有纵向留白"

    mark.save(DST)
    w, h = mark.size
    print(f"母版      {im.width}×{im.height}")
    print(f"图形外接框 x {x0}-{x1}  y {y0}-{y1}")
    print(f"✓ {os.path.basename(DST)}  {w}×{h}  宽高比 {w / h:.3f}  零留白")
    print(f"  可支撑到 {(w / 120):.1f}x 屏（按 120dp 显示算）")


if __name__ == "__main__":
    main()
