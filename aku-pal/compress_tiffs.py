import os
import subprocess
from PIL import Image, ImageOps

input_dir = "./tiffs/ht"
output_dir = "./eps/ht"

os.makedirs(output_dir, exist_ok=True)

for filename in sorted(os.listdir(input_dir)):
    if not filename.lower().endswith((".tif", ".tiff")):
        continue

    print(filename)

    input_path = os.path.join(input_dir, filename)
    base = os.path.splitext(filename)[0]

    pbm_path = os.path.join(output_dir, base + ".pbm")
    eps_path = os.path.join(output_dir, base + ".eps")

    img = Image.open(input_path)

    if img.mode == "RGBA":
        alpha = img.getchannel("A")
        img = ImageOps.invert(alpha)
        bw = img.point(lambda x: 0 if x < 250 else 255, mode="1")
    else:
        img = img.convert("L")
        bw = img.point(lambda x: 0 if x < 250 else 255, mode="1")

    bw.save(pbm_path)

    subprocess.run([
        "potrace",
        pbm_path,
        "-b", "eps",
        "--turdsize", "2",
        "--alphamax", "1.0",
        "--opttolerance", "0.2",
        "-o", eps_path
    ], check=True)

    os.remove(pbm_path)

print("Done.")