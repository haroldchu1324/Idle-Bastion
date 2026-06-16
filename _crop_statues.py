"""
Crops assets/statues_sheet.png into individual statue PNGs.
Run after saving the sprite sheet to assets/statues_sheet.png.
"""
from PIL import Image
from collections import deque
import os

SRC = "assets/statues_sheet.png"
OUT = "assets/statues"

img = Image.open(SRC).convert("RGBA")
W, H = img.size
print(f"Sheet: {W} x {H}")

COLS = 5
col_w = W // COLS

# The sheet has 2 statue rows (each row = statue body + stone nameplate).
# Fractions are tuned for the 5x2 grid layout.
ROW0_Y0 = 0
ROW0_Y1 = H // 2 - 2
ROW1_Y0 = H // 2 + 2
ROW1_Y1 = H

print(f"Top row:    y {ROW0_Y0}–{ROW0_Y1}  ({ROW0_Y1-ROW0_Y0}px)")
print(f"Bottom row: y {ROW1_Y0}–{ROW1_Y1}  ({ROW1_Y1-ROW1_Y0}px)")
print(f"Col width:  {col_w}px")

def col_bounds(c):
    return c * col_w, (c + 1) * col_w

def remove_bg(cell: Image.Image, tol=40) -> Image.Image:
    """Flood-fill from corners to remove the uniform background."""
    cell = cell.convert("RGBA")
    px = cell.load()
    cw, ch = cell.size

    # Sample bg colour from corner patch
    corners = [(1,1),(cw-2,1),(1,ch-2),(cw-2,ch-2)]
    bg = [sum(px[x,y][i] for x,y in corners)//4 for i in range(3)]

    def is_bg(r,g,b):
        return abs(r-bg[0])<tol and abs(g-bg[1])<tol and abs(b-bg[2])<tol

    result = cell.copy()
    rpx = result.load()
    visited = [[False]*ch for _ in range(cw)]
    q = deque(corners)
    for x,y in corners:
        visited[x][y] = True

    while q:
        x,y = q.popleft()
        r,g,b,a = rpx[x,y]
        if is_bg(r,g,b):
            rpx[x,y] = (r,g,b,0)
            for nx,ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if 0<=nx<cw and 0<=ny<ch and not visited[nx][ny]:
                    visited[nx][ny] = True
                    q.append((nx,ny))
    return result

# Button → (row, col) in the grid
# Top row:    0=Upgrades  1=Shop  2=WorldMap  3=Heroes-alt  4=Towers-alt
# Bottom row: 0=Heroes    1=Towers  2=Relics   3=StartGame   4=Extra
STATUES = [
    ("upgrades",  0, 0),
    ("shop",      0, 1),
    ("worldmap",  0, 2),
    ("heroes",    1, 0),
    ("towers",    1, 1),
    ("relics",    1, 2),
    ("start",     1, 3),
]

os.makedirs(OUT, exist_ok=True)

for name, row, col in STATUES:
    x0, x1 = col_bounds(col)
    y0, y1  = (ROW0_Y0, ROW0_Y1) if row == 0 else (ROW1_Y0, ROW1_Y1)
    cell = img.crop((x0, y0, x1, y1))
    cell = remove_bg(cell)
    path = f"{OUT}/statue_{name}.png"
    cell.save(path, "PNG")
    print(f"  saved  {path}  ({cell.width}x{cell.height})")

print("\nDone — import them into Godot by reopening the project.")
