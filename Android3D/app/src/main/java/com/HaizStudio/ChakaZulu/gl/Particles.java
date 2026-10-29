package com.HaizStudio.ChakaZulu.gl;

import android.opengl.GLES30;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.Random;

/** Simple CPU particle system drawn as camera-facing quads (dust, sparkles, splashes, confetti). */
public final class Particles {

    public static final int SHAPE_SOFT = 0, SHAPE_STAR = 1, SHAPE_SQUARE = 2;

    private static final int MAX = 900;
    private static final int FLOATS = 10;

    private final float[] x = new float[MAX], y = new float[MAX], z = new float[MAX];
    private final float[] vx = new float[MAX], vy = new float[MAX], vz = new float[MAX];
    private final float[] life = new float[MAX], maxLife = new float[MAX];
    private final float[] size0 = new float[MAX], size1 = new float[MAX];
    private final float[] r = new float[MAX], g = new float[MAX], b = new float[MAX], a = new float[MAX];
    private final float[] gravity = new float[MAX], drag = new float[MAX], spin = new float[MAX];
    private final int[] shape = new int[MAX];
    private final boolean[] additive = new boolean[MAX];
    private int count;

    private final Random random = new Random();
    private final float[] vertices = new float[MAX * 6 * FLOATS];
    private FloatBuffer buffer;
    private int vao, vbo;

    /** Creates the GPU buffers (call on the GL thread, again after a context loss). */
    public void initGl() {
        buffer = ByteBuffer.allocateDirect(vertices.length * 4).order(ByteOrder.nativeOrder()).asFloatBuffer();
        int[] ids = new int[1];
        GLES30.glGenVertexArrays(1, ids, 0);
        vao = ids[0];
        GLES30.glGenBuffers(1, ids, 0);
        vbo = ids[0];
        GLES30.glBindVertexArray(vao);
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo);
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, vertices.length * 4, null, GLES30.GL_DYNAMIC_DRAW);
        int stride = FLOATS * 4;
        GLES30.glEnableVertexAttribArray(0);
        GLES30.glVertexAttribPointer(0, 3, GLES30.GL_FLOAT, false, stride, 0);
        GLES30.glEnableVertexAttribArray(1);
        GLES30.glVertexAttribPointer(1, 2, GLES30.GL_FLOAT, false, stride, 12);
        GLES30.glEnableVertexAttribArray(2);
        GLES30.glVertexAttribPointer(2, 4, GLES30.GL_FLOAT, false, stride, 20);
        GLES30.glEnableVertexAttribArray(3);
        GLES30.glVertexAttribPointer(3, 1, GLES30.GL_FLOAT, false, stride, 36);
        GLES30.glBindVertexArray(0);
    }

    public void clear() {
        count = 0;
    }

    public float rnd(float min, float max) {
        return min + random.nextFloat() * (max - min);
    }

    /** Adds one particle. Colour is 0xRRGGBB. */
    public void spawn(float px, float py, float pz, float pvx, float pvy, float pvz, float lifetime,
                      float startSize, float endSize, int rgb, float alpha, float grav, float dragK,
                      int shapeType, boolean add) {
        if (count >= MAX) return;
        int i = count++;
        x[i] = px;
        y[i] = py;
        z[i] = pz;
        vx[i] = pvx;
        vy[i] = pvy;
        vz[i] = pvz;
        life[i] = maxLife[i] = lifetime;
        size0[i] = startSize;
        size1[i] = endSize;
        r[i] = ((rgb >> 16) & 0xFF) / 255f;
        g[i] = ((rgb >> 8) & 0xFF) / 255f;
        b[i] = (rgb & 0xFF) / 255f;
        a[i] = alpha;
        gravity[i] = grav;
        drag[i] = dragK;
        shape[i] = shapeType;
        additive[i] = add;
        spin[i] = rnd(-6, 6);
    }

    // --------------------------------------------------------------- effects

    public void dust(float px, float py, float pz, int n) {
        for (int i = 0; i < n; i++)
            spawn(px + rnd(-0.25f, 0.25f), py + 0.05f, pz + rnd(-0.2f, 0.2f), rnd(-1.2f, 1.2f), rnd(0.4f, 1.6f), rnd(0.5f, 2.5f),
                    rnd(0.35f, 0.7f), rnd(0.15f, 0.3f), rnd(0.5f, 0.9f), 0xE8CFA0, 0.55f, -0.5f, 2.5f, SHAPE_SOFT, false);
    }

    public void sparkle(float px, float py, float pz, int rgb, int n) {
        for (int i = 0; i < n; i++) {
            double t = random.nextDouble() * Math.PI * 2, p = random.nextDouble() * Math.PI;
            float speed = rnd(2.5f, 5.5f);
            spawn(px, py, pz, (float) (Math.cos(t) * Math.sin(p)) * speed, (float) Math.cos(p) * speed + 1.5f,
                    (float) (Math.sin(t) * Math.sin(p)) * speed, rnd(0.35f, 0.6f), rnd(0.25f, 0.4f), 0.02f, rgb, 1f, 4f, 3f,
                    SHAPE_STAR, true);
        }
    }

    public void poof(float px, float py, float pz, int rgb, int n) {
        for (int i = 0; i < n; i++)
            spawn(px + rnd(-0.3f, 0.3f), py + rnd(0f, 1.2f), pz + rnd(-0.3f, 0.3f), rnd(-3, 3), rnd(0, 3), rnd(-3, 3),
                    rnd(0.4f, 0.8f), rnd(0.3f, 0.5f), rnd(0.9f, 1.4f), rgb, 0.8f, -1f, 3f, SHAPE_SOFT, false);
    }

    public void splash(float px, float py, float pz) {
        for (int i = 0; i < 46; i++)
            spawn(px + rnd(-0.5f, 0.5f), py, pz + rnd(-0.5f, 0.5f), rnd(-3, 3), rnd(4, 9), rnd(-3, 3), rnd(0.6f, 1.1f),
                    rnd(0.12f, 0.3f), rnd(0.05f, 0.15f), i % 3 == 0 ? 0xFFFFFF : 0x9EE6F5, 0.9f, 16f, 0.5f, SHAPE_SOFT, false);
        for (int i = 0; i < 10; i++)
            spawn(px + rnd(-0.6f, 0.6f), py + 0.1f, pz + rnd(-0.6f, 0.6f), rnd(-1, 1), rnd(0.3f, 1f), rnd(-1, 1), rnd(0.8f, 1.3f),
                    0.5f, 2.2f, 0xE6FAFF, 0.6f, 0, 2f, SHAPE_SOFT, false);
    }

    public void debris(float px, float py, float pz, int rgb, int n) {
        for (int i = 0; i < n; i++)
            spawn(px + rnd(-0.5f, 0.5f), py + rnd(0.2f, 1.8f), pz + rnd(-0.4f, 0.4f), rnd(-4, 4), rnd(2, 7), rnd(-5, 1),
                    rnd(0.6f, 1.1f), rnd(0.18f, 0.32f), 0.1f, rgb, 1f, 18f, 0.4f, SHAPE_SQUARE, false);
    }

    public void confetti(float px, float py, float pz, int n) {
        int[] colors = {0xFF4D4D, 0xFFD24D, 0x4DD2FF, 0x7CFF6B, 0xFF7BD5, 0xFFFFFF};
        for (int i = 0; i < n; i++)
            spawn(px + rnd(-3, 3), py + rnd(0, 1), pz + rnd(-3, 3), rnd(-4, 4), rnd(6, 12), rnd(-4, 4), rnd(1.6f, 2.6f),
                    rnd(0.12f, 0.2f), rnd(0.12f, 0.2f), colors[i % colors.length], 1f, 9f, 1.2f, SHAPE_SQUARE, false);
    }

    // ---------------------------------------------------------------- update

    public void update(float dt) {
        for (int i = 0; i < count; ) {
            life[i] -= dt;
            if (life[i] <= 0) {
                remove(i);
                continue;
            }
            float k = 1f / (1f + drag[i] * dt);
            vx[i] *= k;
            vy[i] = (vy[i] - gravity[i] * dt) * k;
            vz[i] *= k;
            x[i] += vx[i] * dt;
            y[i] += vy[i] * dt;
            z[i] += vz[i] * dt;
            i++;
        }
    }

    private void remove(int i) {
        int last = --count;
        x[i] = x[last];
        y[i] = y[last];
        z[i] = z[last];
        vx[i] = vx[last];
        vy[i] = vy[last];
        vz[i] = vz[last];
        life[i] = life[last];
        maxLife[i] = maxLife[last];
        size0[i] = size0[last];
        size1[i] = size1[last];
        r[i] = r[last];
        g[i] = g[last];
        b[i] = b[last];
        a[i] = a[last];
        gravity[i] = gravity[last];
        drag[i] = drag[last];
        shape[i] = shape[last];
        additive[i] = additive[last];
        spin[i] = spin[last];
    }

    // ---------------------------------------------------------------- render

    /** Draws the particles; camera right and up vectors make them face the camera. */
    public void render(Shader shader, float[] viewProj, float[] right, float[] up, float time) {
        if (count == 0 || buffer == null) return;
        shader.use();
        shader.setMatrix("uViewProj", viewProj);
        GLES30.glBindVertexArray(vao);
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo);
        GLES30.glDepthMask(false);
        GLES30.glEnable(GLES30.GL_BLEND);
        for (int pass = 0; pass < 2; pass++) {
            boolean add = pass == 1;
            int n = fill(add, right, up, time);
            if (n == 0) continue;
            GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, add ? GLES30.GL_ONE : GLES30.GL_ONE_MINUS_SRC_ALPHA);
            buffer.position(0);
            buffer.put(vertices, 0, n * 6 * FLOATS).position(0);
            GLES30.glBufferSubData(GLES30.GL_ARRAY_BUFFER, 0, n * 6 * FLOATS * 4, buffer);
            GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, n * 6);
        }
        GLES30.glDisable(GLES30.GL_BLEND);
        GLES30.glDepthMask(true);
        GLES30.glBindVertexArray(0);
    }

    private int fill(boolean add, float[] right, float[] up, float time) {
        int n = 0, o = 0;
        for (int i = 0; i < count; i++) {
            if (additive[i] != add) continue;
            float t = 1f - life[i] / maxLife[i];
            float s = size0[i] + (size1[i] - size0[i]) * t;
            float alpha = a[i] * Math.min(1f, life[i] / maxLife[i] * 3f);
            float rx = right[0] * s, ry = right[1] * s, rz = right[2] * s;
            float ux = up[0] * s, uy = up[1] * s, uz = up[2] * s;
            if (shape[i] == SHAPE_SQUARE) {
                // Confetti and debris tumble.
                float c = (float) Math.cos(spin[i] * (maxLife[i] - life[i])), sn = (float) Math.sin(spin[i] * (maxLife[i] - life[i]));
                float rx2 = rx * c + ux * sn, ry2 = ry * c + uy * sn, rz2 = rz * c + uz * sn;
                float ux2 = ux * c - rx * sn, uy2 = uy * c - ry * sn, uz2 = uz * c - rz * sn;
                rx = rx2;
                ry = ry2;
                rz = rz2;
                ux = ux2;
                uy = uy2;
                uz = uz2;
            }
            o = corner(o, i, -rx - ux, -ry - uy, -rz - uz, 0, 0, alpha);
            o = corner(o, i, rx - ux, ry - uy, rz - uz, 1, 0, alpha);
            o = corner(o, i, rx + ux, ry + uy, rz + uz, 1, 1, alpha);
            o = corner(o, i, -rx - ux, -ry - uy, -rz - uz, 0, 0, alpha);
            o = corner(o, i, rx + ux, ry + uy, rz + uz, 1, 1, alpha);
            o = corner(o, i, -rx + ux, -ry + uy, -rz + uz, 0, 1, alpha);
            n++;
        }
        return n;
    }

    private int corner(int o, int i, float dx, float dy, float dz, float u, float v, float alpha) {
        vertices[o++] = x[i] + dx;
        vertices[o++] = y[i] + dy;
        vertices[o++] = z[i] + dz;
        vertices[o++] = u;
        vertices[o++] = v;
        vertices[o++] = r[i];
        vertices[o++] = g[i];
        vertices[o++] = b[i];
        vertices[o++] = alpha;
        vertices[o++] = shape[i];
        return o;
    }
}
