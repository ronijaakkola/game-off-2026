"""Writes grain.png: seamless, soft, blotchy noise for the cosy glow shaders.

Run: python3 make_noise.py   (needs numpy and Pillow)
"""

import numpy as np
from PIL import Image

SIZE = 256
rng = np.random.default_rng(7)


def blurred(sigma: float) -> np.ndarray:
    """White noise low-passed in Fourier space, so the tile wraps without a seam."""
    field = rng.standard_normal((SIZE, SIZE))
    fx = np.fft.fftfreq(SIZE)[:, None]
    fy = np.fft.fftfreq(SIZE)[None, :]
    kernel = np.exp(-(fx**2 + fy**2) * (2 * np.pi * sigma) ** 2 / 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(field) * kernel))
    return (out - out.mean()) / out.std()


field = 0.6 * blurred(14) + 0.3 * blurred(5) + 0.1 * blurred(1.5)
field = np.clip(0.5 + field * 0.22, 0.0, 1.0)
Image.fromarray((field * 255).astype(np.uint8), "L").save("grain.png")
