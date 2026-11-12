Add-Type -ReferencedAssemblies "System.Drawing" -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class LogoProcessor {
    public static void Process(string srcPath, string cleanOutPath, string glowOutPath) {
        using (Bitmap src = new Bitmap(srcPath)) {
            int w = src.Width;
            int h = src.Height;
            Rectangle rect = new Rectangle(0, 0, w, h);

            BitmapData srcData = src.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int bytes = w * h * 4;
            byte[] srcBytes = new byte[bytes];
            Marshal.Copy(srcData.Scan0, srcBytes, 0, bytes);
            src.UnlockBits(srcData);

            // 1. Identify brightness (max channel) of each pixel
            byte[] maxLum = new byte[w * h];
            for (int i = 0; i < w * h; i++) {
                int p = i * 4;
                byte b = srcBytes[p];
                byte g = srcBytes[p + 1];
                byte r = srcBytes[p + 2];
                maxLum[i] = Math.Max(r, Math.Max(g, b));
            }

            // 2. Flood-fill from borders to find all exterior background pixels
            // A pixel is considered background if maxLum <= 25 and it is reachable from the image perimeter
            bool[] isExterior = new bool[w * h];
            Queue<int> q = new Queue<int>();

            // Seed top and bottom borders
            for (int x = 0; x < w; x++) {
                q.Enqueue(x); // y = 0
                isExterior[x] = true;
                int bot = (h - 1) * w + x;
                q.Enqueue(bot); // y = h-1
                isExterior[bot] = true;
            }
            // Seed left and right borders
            for (int y = 0; y < h; y++) {
                int left = y * w;
                if (!isExterior[left]) { q.Enqueue(left); isExterior[left] = true; }
                int right = y * w + (w - 1);
                if (!isExterior[right]) { q.Enqueue(right); isExterior[right] = true; }
            }

            // BFS flood fill from borders
            int[] dx = { 0, 0, 1, -1 };
            int[] dy = { 1, -1, 0, 0 };

            while (q.Count > 0) {
                int curr = q.Dequeue();
                int cx = curr % w;
                int cy = curr / w;

                for (int d = 0; d < 4; d++) {
                    int nx = cx + dx[d];
                    int ny = cy + dy[d];
                    if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                        int nIdx = ny * w + nx;
                        if (!isExterior[nIdx]) {
                            // Expand through background / outer glow fringe up to threshold 28
                            if (maxLum[nIdx] <= 28) {
                                isExterior[nIdx] = true;
                                q.Enqueue(nIdx);
                            }
                        }
                    }
                }
            }

            // Any dark pocket below the neck (y >= 375) is empty background space between limbs/sword
            for (int y = 375; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    int idx = y * w + x;
                    if (maxLum[idx] <= 28 && !isExterior[idx]) {
                        isExterior[idx] = true;
                        q.Enqueue(idx);
                    }
                }
            }

            while (q.Count > 0) {
                int curr = q.Dequeue();
                int cx = curr % w;
                int cy = curr / w;

                for (int d = 0; d < 4; d++) {
                    int nx = cx + dx[d];
                    int ny = cy + dy[d];
                    if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                        int nIdx = ny * w + nx;
                        if (!isExterior[nIdx]) {
                            if (maxLum[nIdx] <= 28) {
                                isExterior[nIdx] = true;
                                q.Enqueue(nIdx);
                            }
                        }
                    }
                }
            }

            // Ensure head interior is solid black so background particles cannot show through face
            for (int y = 265; y <= 385; y++) {
                for (int x = 460; x <= 580; x++) {
                    int dxHead = x - 520;
                    int dyHead = y - 325;
                    if (dxHead * dxHead + dyHead * dyHead <= 56 * 56) {
                        int idx = y * w + x;
                        if (maxLum[idx] <= 40) {
                            isExterior[idx] = false;
                        }
                    }
                }
            }

            // Count exterior vs interior
            int extCount = 0;
            for (int i = 0; i < w * h; i++) {
                if (isExterior[i]) extCount++;
            }
            Console.WriteLine(string.Format("Exterior pixels: {0} ({1:P1})", extCount, (float)extCount / (w * h)));

            // 3. Build CLEAN CUTOUT
            // Inside the character (not exterior) is 100% opaque.
            // On the boundary (exterior but has glow > 8), blend alpha smoothly.
            byte[] cleanBytes = new byte[bytes];
            for (int i = 0; i < w * h; i++) {
                int p = i * 4;
                byte b = srcBytes[p];
                byte g = srcBytes[p + 1];
                byte r = srcBytes[p + 2];
                byte lum = maxLum[i];

                if (!isExterior[i]) {
                    // Fully inside character envelope
                    cleanBytes[p] = b;
                    cleanBytes[p + 1] = g;
                    cleanBytes[p + 2] = r;
                    cleanBytes[p + 3] = 255;
                } else {
                    // Exterior: if it has faint glow just outside the threshold (8..28), smooth fade
                    if (lum > 8) {
                        float alphaNorm = (lum - 8.0f) / (28.0f - 8.0f);
                        alphaNorm = Math.Max(0.0f, Math.Min(1.0f, alphaNorm));
                        cleanBytes[p] = b;
                        cleanBytes[p + 1] = g;
                        cleanBytes[p + 2] = r;
                        cleanBytes[p + 3] = (byte)(alphaNorm * 255.0f);
                    } else {
                        // Completely transparent
                        cleanBytes[p] = 0;
                        cleanBytes[p + 1] = 0;
                        cleanBytes[p + 2] = 0;
                        cleanBytes[p + 3] = 0;
                    }
                }
            }

            using (Bitmap cleanBmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
                BitmapData d = cleanBmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                Marshal.Copy(cleanBytes, 0, d.Scan0, bytes);
                cleanBmp.UnlockBits(d);
                cleanBmp.Save(cleanOutPath, ImageFormat.Png);
            }
            Console.WriteLine("Saved clean cutout to: " + cleanOutPath);

            // 4. Build NEON GLOW BLOOM (Isolated outline bloom)
            // Extract glowing lines (maxLum >= 50) and apply smooth Gaussian bloom
            float[] glowIntensity = new float[w * h];
            for (int i = 0; i < w * h; i++) {
                int p = i * 4;
                byte lum = maxLum[i];
                if (lum > 45) {
                    float v = (lum - 45.0f) / (255.0f - 45.0f);
                    glowIntensity[i] = Math.Min(1.0f, v * 1.25f);
                }
            }

            // Separable Gaussian Blur (radius = 11, sigma = 5.0)
            int radius = 11;
            float[] kernel = new float[radius * 2 + 1];
            float sigma = 5.0f;
            float sum = 0.0f;
            for (int r = -radius; r <= radius; r++) {
                float k = (float)Math.Exp(-(r * r) / (2.0f * sigma * sigma));
                kernel[r + radius] = k;
                sum += k;
            }
            for (int k = 0; k < kernel.Length; k++) kernel[k] /= sum;

            float[] blurH = new float[w * h];
            for (int y = 0; y < h; y++) {
                int row = y * w;
                for (int x = 0; x < w; x++) {
                    float s = 0.0f;
                    for (int r = -radius; r <= radius; r++) {
                        int sx = Math.Max(0, Math.Min(w - 1, x + r));
                        s += glowIntensity[row + sx] * kernel[r + radius];
                    }
                    blurH[row + x] = s;
                }
            }

            float[] blurHV = new float[w * h];
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    float s = 0.0f;
                    for (int r = -radius; r <= radius; r++) {
                        int sy = Math.Max(0, Math.Min(h - 1, y + r));
                        s += blurH[sy * w + x] * kernel[r + radius];
                    }
                    blurHV[y * w + x] = s;
                }
            }

            // Composite glow: blend core sharp glow + wide smooth bloom into cyan/white neon
            byte[] glowBytes = new byte[bytes];
            for (int i = 0; i < w * h; i++) {
                float core = glowIntensity[i];
                float bloom = blurHV[i];
                float combined = Math.Min(1.0f, core * 0.9f + bloom * 1.1f);

                if (combined > 0.02f) {
                    int p = i * 4;
                    // Radiant cyan-electric with bright white core
                    float whiteMix = core * core;
                    byte r = (byte)Math.Min(255.0f, (combined * 130.0f + whiteMix * 125.0f));
                    byte g = (byte)Math.Min(255.0f, (combined * 210.0f + whiteMix * 45.0f));
                    byte b = (byte)Math.Min(255.0f, (combined * 255.0f));
                    byte a = (byte)Math.Min(255.0f, combined * 255.0f);

                    glowBytes[p] = b;
                    glowBytes[p + 1] = g;
                    glowBytes[p + 2] = r;
                    glowBytes[p + 3] = a;
                }
            }

            using (Bitmap glowBmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
                BitmapData d = glowBmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                Marshal.Copy(glowBytes, 0, d.Scan0, bytes);
                glowBmp.UnlockBits(d);
                glowBmp.Save(glowOutPath, ImageFormat.Png);
            }
            Console.WriteLine("Saved neon outline glow to: " + glowOutPath);
        }
    }
}
'@

[LogoProcessor]::Process(
    "c:/WORK/infinite-tower/assets-source/logo/logo_upscaled.jpg",
    "c:/WORK/infinite-tower/assets-source/logo/logo_clean_hd.png",
    "c:/WORK/infinite-tower/assets-source/logo/logo_glow_hd.png"
)
