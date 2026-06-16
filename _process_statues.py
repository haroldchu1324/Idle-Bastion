"""
Removes dark backgrounds from statue PNGs in assets/statues/.
Run after saving the raw statue images with their final filenames.
Overwrites each file in-place with a transparent-background version.
"""
from PIL import Image
from collections import deque
import os

STATUES_DIR = "assets/statues"
NAMES = [
    "statue_shop.png",
    "statue_upgrades.png",
    "statue_start.png",
    "statue_relics.png",
    "statue_towers.png",
    "statue_heroes.png",
    "statue_worldmap.png",
]

def remove_dark_bg(img: Image.Image, tol: int = 45) -> Image.Image:
    """Flood-fill from all 4 corners + all 4 edges to erase the background."""
    img = img.convert("RGBA")
    px  = img.load()
    w, h = img.size

    # Sample background from the four corner patches (average of 3x3 block)
    def corner_avg(cx, cy):
        samples = []
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                nx, ny = max(0, min(w-1, cx+dx)), max(0, min(h-1, cy+dy))
                samples.append(px[nx, ny][:3])
        return tuple(sum(s[i] for s in samples)//len(samples) for i in range(3))

    corners_rgb = [corner_avg(0,0), corner_avg(w-1,0),
                   corner_avg(0,h-1), corner_avg(w-1,h-1)]
    # Use the darkest corner as the bg reference
    bg = min(corners_rgb, key=lambda c: c[0]+c[1]+c[2])

    def is_bg(r, g, b):
        return abs(r-bg[0]) < tol and abs(g-bg[1]) < tol and abs(b-bg[2]) < tol

    result = img.copy()
    rpx    = result.load()
    visited = [[False]*h for _ in range(w)]
    queue   = deque()

    def seed(x, y):
        if not visited[x][y]:
            visited[x][y] = True
            queue.append((x, y))

    # Seed from all 4 edges
    for x in range(w):
        seed(x, 0); seed(x, h-1)
    for y in range(h):
        seed(0, y); seed(w-1, y)

    while queue:
        x, y = queue.popleft()
        r, g, b, a = rpx[x, y]
        if is_bg(r, g, b):
            rpx[x, y] = (r, g, b, 0)
            for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if 0 <= nx < w and 0 <= ny < h and not visited[nx][ny]:
                    visited[nx][ny] = True
                    queue.append((nx, ny))

    return result

for name in NAMES:
    path = os.path.join(STATUES_DIR, name)
    if not os.path.exists(path):
        print(f"  MISSING  {path}")
        continue
    img = Image.open(path)
    out = remove_dark_bg(img)
    out.save(path, "PNG")
    print(f"  done     {path}  ({out.width}x{out.height})")

print("\nAll done — reopen Godot to reimport.")
