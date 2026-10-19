"""Makes UVScan's icon and splash artwork from one drawing.

The drawing is a tachometer (blue arc with a red line, white needle) over a
live-data trace (amber), on deep navy. It is defined once in the 108 x 108
space of an Android adaptive icon (its safe zone: the circle of radius 33
around 54,54), and written out as:

  uvscan.svg                         the master, for the docs
  UVScan.ico                         Windows (exe, installer, taskbar), 16-256 px
  android/ic_launcher_*.png          launcher icons for Android 6-7
  android/playstore_512.png
  android/adaptive_*.xml             adaptive icon (8+) and themed icon (13+)
  android/splash.xml                 splash logo (6-11)
  android/splash_v31.xml             splash icon (12+: shown in a circle)
  android/splash_*.png               bitmap splash (unused while the vector one is on)
  android/notification_*.png / .xml  white silhouette

Run: python make_artwork.py   (needs Pillow; Segoe UI Bold for the splash text)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
AND = os.path.join(HERE, 'android')

NAVY = '#0E1B2E'
NAVY_TOP = (24, 44, 76)
NAVY_BOTTOM = (10, 19, 34)
BLUE = '#46AAFF'    # the app's selection blue
RED = '#FF5A3C'
WHITE = '#FFFFFF'
AMBER = '#FFB020'   # the app's mark colour

# the gauge
CX, CY, R, ARC_W = 54.0, 52.0, 23.0, 7.0
ARC_FROM, ARC_TO, RED_FROM = -135.0, 135.0, 95.0  # degrees clockwise from 12 o'clock
NEEDLE_ANGLE, NEEDLE_LEN = 55.0, 17.5
HUB_R, HUB_DOT = 5.2, 2.0
# the live-data trace under it
TRACE = [(38, 77), (45, 77), (48, 72), (52, 84), (56, 70), (59, 77), (70, 77)]
TRACE_W = 3.2


def pt(angle, radius):
    a = math.radians(angle)
    return CX + radius * math.sin(a), CY - radius * math.cos(a)


def needle_polygon():
    a = math.radians(NEEDLE_ANGLE)
    u = (math.sin(a), -math.cos(a))
    p = (math.cos(a), math.sin(a))

    def at(along, side):
        return CX + u[0] * along + p[0] * side, CY + u[1] * along + p[1] * side

    return [at(-3.5, 2.6), at(0, 3.0), at(NEEDLE_LEN, 0.9), at(NEEDLE_LEN + 0.9, 0), at(NEEDLE_LEN, -0.9),
            at(0, -3.0), at(-3.5, -2.6)]


def f(v):
    return ('%.2f' % v).rstrip('0').rstrip('.')


def arc_path(a0, a1):
    x0, y0 = pt(a0, R)
    x1, y1 = pt(a1, R)
    large = 1 if (a1 - a0) > 180 else 0
    return 'M%s,%s A%s,%s 0 %d 1 %s,%s' % (f(x0), f(y0), f(R), f(R), large, f(x1), f(y1))


def poly_path(points, close=True):
    s = 'M' + ' L'.join('%s,%s' % (f(x), f(y)) for x, y in points)
    return s + (' Z' if close else '')


def circle_path(cx, cy, r):
    return 'M%s,%s a%s,%s 0 1 0 %s,0 a%s,%s 0 1 0 %s,0 Z' % (
        f(cx - r), f(cy), f(r), f(r), f(2 * r), f(r), f(r), f(-2 * r))


ARC = arc_path(ARC_FROM, ARC_TO)
REDLINE = arc_path(RED_FROM, ARC_TO)
NEEDLE = poly_path(needle_polygon())
HUB = circle_path(CX, CY, HUB_R)
HUB_IN = circle_path(CX, CY, HUB_DOT)
TRACE_PATH = poly_path(TRACE, close=False)

# ---------------------------------------------------------------- vectors

def vector(width_dp, height_dp, vw, vh, body, extra=''):
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="%sdp"\n    android:height="%sdp"\n'
            '    android:viewportWidth="%s"\n    android:viewportHeight="%s"%s>\n%s</vector>\n'
            % (width_dp, height_dp, vw, vh, extra, body))


def stroke(path, color, width):
    return ('        <path android:pathData="%s"\n            android:strokeColor="%s" android:strokeWidth="%s"\n'
            '            android:strokeLineCap="round" android:strokeLineJoin="round"/>\n' % (path, color, f(width)))


def fill(path, color, evenodd=False):
    return '        <path android:pathData="%s"\n            android:fillColor="%s"%s/>\n' % (
        path, color, ' android:fillType="evenOdd"' if evenodd else '')


def gauge_body(mono=None):
    """The foreground's paths; mono = one colour for all (themed / notification icon)."""
    c = lambda col: mono or col
    s = stroke(TRACE_PATH, c(AMBER), TRACE_W)
    s += stroke(ARC, c(BLUE), ARC_W)
    if not mono:
        s += stroke(REDLINE, RED, ARC_W)
    s += fill(NEEDLE, c(WHITE))
    if mono:
        s += fill(HUB + ' ' + HUB_IN, mono, evenodd=True)
    else:
        s += fill(HUB, WHITE) + fill(HUB_IN, NAVY)
    return s


def group(body, scale=1.0, tx=0.0, ty=0.0):
    return ('    <group android:scaleX="%s" android:scaleY="%s" android:translateX="%s" android:translateY="%s">\n%s'
            '    </group>\n' % (f(scale), f(scale), f(tx), f(ty), body))


def write(name, text):
    with open(os.path.join(AND, name), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)


def write_vectors():
    # (a launcher's mask shows about the middle 72: the gauge at 80 % keeps clear of its edge)
    a = 0.8
    write('adaptive_foreground.xml', vector(108, 108, 108, 108, group(gauge_body(), a, 54 * (1 - a), 54 * (1 - a))))
    write('adaptive_background.xml', vector(108, 108, 108, 108,
          '    <path android:pathData="M0,0h108v108h-108z" android:fillColor="%s"/>\n' % NAVY))
    write('adaptive_monochrome.xml', vector(108, 108, 108, 108,
          group(gauge_body('#FF000000'), a, 54 * (1 - a), 54 * (1 - a))))
    # Android 6-11: the logo in the middle of the splash colour; the safe zone, 160 dp
    write('splash.xml', vector(160, 160, 72, 72, group(gauge_body(), 1, -18, -18)))
    # Android 12+: a 288 dp icon of which the middle 192 dp circle shows
    s = 2.6
    write('splash_v31.xml', vector(288, 288, 288, 288, group(gauge_body(), s, 144 - 54 * s, 144 - 54 * s)))
    write('notification.xml', vector(24, 24, 72, 72, group(gauge_body('#FFFFFFFF'), 1, -18, -18)))

# ---------------------------------------------------------------- bitmaps

def raster(size, x0, w, mono=None, small=False):
    """The foreground: the 108-space square (x0, x0) - (x0+w, x0+w) on size px, transparent."""
    ss = 8 if size < 128 else 4
    n = size * ss
    k = n / w
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = lambda x, y: ((x - x0) * k, (y - x0) * k)
    col = lambda c: mono or c
    arc_w = ARC_W * (1.25 if small else 1)

    def arc(a0, a1, color, width):
        r = R * k
        cx, cy = P(CX, CY)
        box = [cx - r - width * k / 2, cy - r - width * k / 2, cx + r + width * k / 2, cy + r + width * k / 2]
        # PIL: degrees clockwise from 3 o'clock
        d.arc(box, a0 - 90, a1 - 90, fill=color, width=round(width * k))
        for a in (a0, a1):
            x, y = P(*pt(a, R))
            rr = width * k / 2
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=color)

    if not small:
        pts = [P(x, y) for x, y in TRACE]
        tw = TRACE_W * k
        d.line(pts, fill=col(AMBER), width=round(tw), joint='curve')
        for x, y in (pts[0], pts[-1]):
            d.ellipse([x - tw / 2, y - tw / 2, x + tw / 2, y + tw / 2], fill=col(AMBER))
    arc(ARC_FROM, ARC_TO, col(BLUE), arc_w)
    if not mono:
        arc(RED_FROM, ARC_TO, RED, arc_w)
    d.polygon([P(x, y) for x, y in needle_polygon()], fill=col(WHITE))
    cx, cy = P(CX, CY)
    hr = HUB_R * k * (1.15 if small else 1)
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=col(WHITE))
    dr = HUB_DOT * k * (1.15 if small else 1)
    d.ellipse([cx - dr, cy - dr, cx + dr, cy + dr], fill=(0, 0, 0, 0) if mono else NAVY)
    return img.resize((size, size), Image.LANCZOS)


def background(size, rounded=True):
    ss = 4
    n = size * ss
    grad = Image.new('RGBA', (1, n))
    for y in range(n):
        t = y / (n - 1)
        grad.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(NAVY_TOP, NAVY_BOTTOM)) + (255,))
    grad = grad.resize((n, n))
    if not rounded:
        return grad.resize((size, size), Image.LANCZOS)
    mask = Image.new('L', (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=round(n * 0.22), fill=255)
    out = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def icon(size, rounded=True):
    """The whole icon: navy tile, the gauge filling its middle (more of it when small)."""
    small = size <= 24
    x0, w = (21, 66) if small else (15, 78)
    img = background(size, rounded)
    img.alpha_composite(raster(size, x0, w, small=small))
    return img


def splash_png(w, h):
    img = Image.new('RGBA', (w, h), NAVY)
    s = round(h * 0.55)
    img.alpha_composite(raster(s, 18, 72), ((w - s) // 2, round(h * 0.08)))
    try:
        font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', round(h * 0.11))
        d = ImageDraw.Draw(img)
        d.text((w / 2, h * 0.78), 'UVScan', fill=WHITE, font=font, anchor='mm')
    except OSError:
        pass
    return img


def write_bitmaps():
    sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    imgs = [icon(s) for s in sizes]
    imgs[-1].save(os.path.join(HERE, 'UVScan.ico'), format='ICO', sizes=[(s, s) for s in sizes],
                  append_images=imgs[:-1])
    for s in (36, 48, 72, 96, 144, 192):
        icon(s).save(os.path.join(AND, 'ic_launcher_%d.png' % s))
    icon(512, rounded=False).save(os.path.join(AND, 'playstore_512.png'))
    for w, h in ((426, 320), (470, 320), (640, 480), (960, 720)):
        splash_png(w, h).convert('RGB').save(os.path.join(AND, 'splash_%dx%d.png' % (w, h)))
    for s in (24, 36, 48, 72, 96):
        raster(s, 18, 72, mono=WHITE, small=s <= 36).save(os.path.join(AND, 'notification_%d.png' % s))

# ---------------------------------------------------------------- master svg

def write_svg():
    body = ('  <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#%02X%02X%02X"/><stop offset="1" stop-color="#%02X%02X%02X"/>'
            '</linearGradient></defs>\n' % (NAVY_TOP + NAVY_BOTTOM))
    body += '  <rect x="15" y="15" width="78" height="78" rx="17.16" fill="url(#bg)"/>\n'
    sp = lambda p, c, w: ('  <path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" '
                          'stroke-linejoin="round"/>\n' % (p, c, f(w)))
    body += sp(TRACE_PATH, AMBER, TRACE_W) + sp(ARC, BLUE, ARC_W) + sp(REDLINE, RED, ARC_W)
    body += '  <path d="%s" fill="%s"/>\n  <path d="%s" fill="%s"/>\n  <path d="%s" fill="%s"/>\n' % (
        NEEDLE, WHITE, HUB, WHITE, HUB_IN, NAVY)
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="15 15 78 78" width="256" height="256">\n'
           '  <title>UVScan</title>\n%s</svg>\n' % body)
    with open(os.path.join(HERE, 'uvscan.svg'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(svg)


if __name__ == '__main__':
    os.makedirs(AND, exist_ok=True)
    write_vectors()
    write_bitmaps()
    write_svg()
    print('artwork written to', HERE)
