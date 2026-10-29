package com.HaizStudio.ChakaZulu.gl;

import android.opengl.Matrix;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * Builds flat-shaded, vertex-coloured low-poly geometry from code.
 * <p>
 * Every triangle gets its own face normal (the faceted "low poly" look). Primitives take
 * a reference point inside the shape and wind each face so its normal points away from it,
 * so lighting and back-face culling are always right.
 */
public final class MeshBuilder {

    private float[] data = new float[Mesh.FLOATS_PER_VERTEX * 3 * 512];
    private int size;

    private final float[] matrix = new float[16];
    private final ArrayDeque<float[]> stack = new ArrayDeque<>();
    private float red = 1, green = 1, blue = 1;
    private float shadeJitter = 0;
    private final Random shadeRandom = new Random(7);

    private final float[] in = new float[4];
    private final float[] out = new float[4];
    private final float[] p = new float[9];

    public MeshBuilder() {
        Matrix.setIdentityM(matrix, 0);
    }

    // ------------------------------------------------------------------ state

    public MeshBuilder color(int rgb) {
        red = ((rgb >> 16) & 0xFF) / 255f;
        green = ((rgb >> 8) & 0xFF) / 255f;
        blue = (rgb & 0xFF) / 255f;
        return this;
    }

    /** Random brightness variation per triangle (0 = none, 0.1 = +/-10%). */
    public MeshBuilder jitter(float amount) {
        shadeJitter = amount;
        return this;
    }

    public MeshBuilder push() {
        stack.push(matrix.clone());
        return this;
    }

    public MeshBuilder pop() {
        System.arraycopy(stack.pop(), 0, matrix, 0, 16);
        return this;
    }

    public MeshBuilder translate(float x, float y, float z) {
        Matrix.translateM(matrix, 0, x, y, z);
        return this;
    }

    public MeshBuilder rotate(float degrees, float x, float y, float z) {
        Matrix.rotateM(matrix, 0, degrees, x, y, z);
        return this;
    }

    public MeshBuilder scale(float x, float y, float z) {
        Matrix.scaleM(matrix, 0, x, y, z);
        return this;
    }

    public void clear() {
        size = 0;
        stack.clear();
        Matrix.setIdentityM(matrix, 0);
    }

    public int floatCount() {
        return size;
    }

    public float[] data() {
        return data;
    }

    public Mesh build() {
        return new Mesh(data, size);
    }

    // -------------------------------------------------------------- triangles

    /** Triangle in local coordinates, wound so its normal points away from the reference point r. */
    public void tri(float ax, float ay, float az, float bx, float by, float bz, float cx, float cy, float cz,
                    float rx, float ry, float rz) {
        float ux = bx - ax, uy = by - ay, uz = bz - az;
        float vx = cx - ax, vy = cy - ay, vz = cz - az;
        float nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
        float mx = (ax + bx + cx) / 3 - rx, my = (ay + by + cy) / 3 - ry, mz = (az + bz + cz) / 3 - rz;
        if (nx * mx + ny * my + nz * mz < 0)
            triRaw(ax, ay, az, cx, cy, cz, bx, by, bz);
        else
            triRaw(ax, ay, az, bx, by, bz, cx, cy, cz);
    }

    /** Triangle exactly as given: counter-clockwise is the front face. */
    public void triRaw(float ax, float ay, float az, float bx, float by, float bz, float cx, float cy, float cz) {
        transform(ax, ay, az, 0);
        transform(bx, by, bz, 3);
        transform(cx, cy, cz, 6);
        float ux = p[3] - p[0], uy = p[4] - p[1], uz = p[5] - p[2];
        float vx = p[6] - p[0], vy = p[7] - p[1], vz = p[8] - p[2];
        float nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
        float len = (float) Math.sqrt(nx * nx + ny * ny + nz * nz);
        if (len < 1e-9f) return;
        nx /= len;
        ny /= len;
        nz /= len;
        float f = shadeJitter == 0 ? 1f : 1f + (shadeRandom.nextFloat() * 2f - 1f) * shadeJitter;
        ensure(Mesh.FLOATS_PER_VERTEX * 3);
        for (int i = 0; i < 3; i++) {
            data[size++] = p[i * 3];
            data[size++] = p[i * 3 + 1];
            data[size++] = p[i * 3 + 2];
            data[size++] = nx;
            data[size++] = ny;
            data[size++] = nz;
            data[size++] = Math.min(1f, red * f);
            data[size++] = Math.min(1f, green * f);
            data[size++] = Math.min(1f, blue * f);
        }
    }

    private void transform(float x, float y, float z, int offset) {
        in[0] = x;
        in[1] = y;
        in[2] = z;
        in[3] = 1;
        Matrix.multiplyMV(out, 0, matrix, 0, in, 0);
        p[offset] = out[0];
        p[offset + 1] = out[1];
        p[offset + 2] = out[2];
    }

    private void ensure(int extra) {
        if (size + extra <= data.length) return;
        float[] bigger = new float[Math.max(data.length * 2, size + extra)];
        System.arraycopy(data, 0, bigger, 0, size);
        data = bigger;
    }

    /** Quad a-b-c-d (in order around the edge) facing away from r. */
    public void quad(float ax, float ay, float az, float bx, float by, float bz,
                     float cx, float cy, float cz, float dx, float dy, float dz,
                     float rx, float ry, float rz) {
        tri(ax, ay, az, bx, by, bz, cx, cy, cz, rx, ry, rz);
        tri(ax, ay, az, cx, cy, cz, dx, dy, dz, rx, ry, rz);
    }

    // ------------------------------------------------------------- primitives

    /** Axis-aligned box centred on (cx, cy, cz) with full sizes (sx, sy, sz). */
    public void box(float cx, float cy, float cz, float sx, float sy, float sz) {
        float x0 = cx - sx / 2, x1 = cx + sx / 2, y0 = cy - sy / 2, y1 = cy + sy / 2, z0 = cz - sz / 2, z1 = cz + sz / 2;
        quad(x0, y1, z0, x1, y1, z0, x1, y1, z1, x0, y1, z1, cx, cy, cz); // top
        quad(x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1, cx, cy, cz); // bottom
        quad(x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, cx, cy, cz); // +z
        quad(x0, y0, z0, x1, y0, z0, x1, y1, z0, x0, y1, z0, cx, cy, cz); // -z
        quad(x1, y0, z0, x1, y0, z1, x1, y1, z1, x1, y1, z0, cx, cy, cz); // +x
        quad(x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0, cx, cy, cz); // -x
    }

    /** Box with a different colour on its top face. */
    public void box(float cx, float cy, float cz, float sx, float sy, float sz, int topColor, int sideColor) {
        float x0 = cx - sx / 2, x1 = cx + sx / 2, y0 = cy - sy / 2, y1 = cy + sy / 2, z0 = cz - sz / 2, z1 = cz + sz / 2;
        color(topColor);
        quad(x0, y1, z0, x1, y1, z0, x1, y1, z1, x0, y1, z1, cx, cy, cz);
        color(sideColor);
        quad(x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1, cx, cy, cz);
        quad(x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, cx, cy, cz);
        quad(x0, y0, z0, x1, y0, z0, x1, y1, z0, x0, y1, z0, cx, cy, cz);
        quad(x1, y0, z0, x1, y0, z1, x1, y1, z1, x1, y1, z0, cx, cy, cz);
        quad(x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0, cx, cy, cz);
    }

    /** Cylinder / cone / frustum along +y from y=0 to y=height. */
    public void cylinder(float bottomRadius, float topRadius, float height, int segments) {
        float ry = height / 2;
        for (int i = 0; i < segments; i++) {
            double a0 = 2 * Math.PI * i / segments, a1 = 2 * Math.PI * (i + 1) / segments;
            float c0 = (float) Math.cos(a0), s0 = (float) Math.sin(a0), c1 = (float) Math.cos(a1), s1 = (float) Math.sin(a1);
            float bx0 = c0 * bottomRadius, bz0 = s0 * bottomRadius, bx1 = c1 * bottomRadius, bz1 = s1 * bottomRadius;
            float tx0 = c0 * topRadius, tz0 = s0 * topRadius, tx1 = c1 * topRadius, tz1 = s1 * topRadius;
            if (topRadius > 0)
                quad(bx0, 0, bz0, bx1, 0, bz1, tx1, height, tz1, tx0, height, tz0, 0, ry, 0);
            else
                tri(bx0, 0, bz0, bx1, 0, bz1, 0, height, 0, 0, ry, 0);
            if (bottomRadius > 0)
                tri(0, 0, 0, bx0, 0, bz0, bx1, 0, bz1, 0, ry, 0);
            if (topRadius > 0)
                tri(0, height, 0, tx0, height, tz0, tx1, height, tz1, 0, ry, 0);
        }
    }

    /** Torus lying in the XZ plane. */
    public void torus(float majorRadius, float minorRadius, int majorSegments, int minorSegments) {
        for (int i = 0; i < majorSegments; i++) {
            double a0 = 2 * Math.PI * i / majorSegments, a1 = 2 * Math.PI * (i + 1) / majorSegments;
            double am = (a0 + a1) / 2;
            float rx = (float) (Math.cos(am) * majorRadius), rz = (float) (Math.sin(am) * majorRadius);
            for (int j = 0; j < minorSegments; j++) {
                double b0 = 2 * Math.PI * j / minorSegments, b1 = 2 * Math.PI * (j + 1) / minorSegments;
                float[] q00 = torusPoint(a0, b0, majorRadius, minorRadius), q10 = torusPoint(a1, b0, majorRadius, minorRadius);
                float[] q11 = torusPoint(a1, b1, majorRadius, minorRadius), q01 = torusPoint(a0, b1, majorRadius, minorRadius);
                quad(q00[0], q00[1], q00[2], q10[0], q10[1], q10[2], q11[0], q11[1], q11[2], q01[0], q01[1], q01[2], rx, 0, rz);
            }
        }
    }

    private static float[] torusPoint(double a, double b, float major, float minor) {
        double r = major + minor * Math.cos(b);
        return new float[]{(float) (Math.cos(a) * r), (float) (minor * Math.sin(b)), (float) (Math.sin(a) * r)};
    }

    /** Low-poly sphere (subdivided icosahedron). */
    public void sphere(float radius, int detail) {
        blob(radius, radius, radius, detail, 0, null);
    }

    /**
     * Organic shape: a subdivided icosahedron scaled to (sx, sy, sz) radii, with each vertex
     * moved in or out by up to {@code roughness} (rocks, bushes, tree tops, clouds).
     */
    public void blob(float sx, float sy, float sz, int detail, float roughness, Random random) {
        List<float[]> vertices = new ArrayList<>();
        List<int[]> faces = new ArrayList<>();
        icosphere(detail, vertices, faces);
        float[][] v = new float[vertices.size()][];
        for (int i = 0; i < v.length; i++) {
            float[] u = vertices.get(i);
            float k = random == null ? 1 : 1 + (random.nextFloat() * 2 - 1) * roughness;
            v[i] = new float[]{u[0] * sx * k, u[1] * sy * k, u[2] * sz * k};
        }
        for (int[] f : faces) {
            float[] a = v[f[0]], b = v[f[1]], c = v[f[2]];
            tri(a[0], a[1], a[2], b[0], b[1], b[2], c[0], c[1], c[2], 0, 0, 0);
        }
    }

    private static void icosphere(int detail, List<float[]> vertices, List<int[]> faces) {
        float t = (float) ((1 + Math.sqrt(5)) / 2);
        float[][] base = {{-1, t, 0}, {1, t, 0}, {-1, -t, 0}, {1, -t, 0}, {0, -1, t}, {0, 1, t}, {0, -1, -t}, {0, 1, -t},
                {t, 0, -1}, {t, 0, 1}, {-t, 0, -1}, {-t, 0, 1}};
        for (float[] b : base) vertices.add(normalize(b));
        int[][] f = {{0, 11, 5}, {0, 5, 1}, {0, 1, 7}, {0, 7, 10}, {0, 10, 11}, {1, 5, 9}, {5, 11, 4}, {11, 10, 2}, {10, 7, 6},
                {7, 1, 8}, {3, 9, 4}, {3, 4, 2}, {3, 2, 6}, {3, 6, 8}, {3, 8, 9}, {4, 9, 5}, {2, 4, 11}, {6, 2, 10}, {8, 6, 7}, {9, 8, 1}};
        for (int[] face : f) faces.add(face);
        for (int d = 0; d < detail; d++) {
            Map<Long, Integer> cache = new HashMap<>();
            List<int[]> next = new ArrayList<>();
            for (int[] face : faces) {
                int a = midpoint(face[0], face[1], vertices, cache);
                int b = midpoint(face[1], face[2], vertices, cache);
                int c = midpoint(face[2], face[0], vertices, cache);
                next.add(new int[]{face[0], a, c});
                next.add(new int[]{face[1], b, a});
                next.add(new int[]{face[2], c, b});
                next.add(new int[]{a, b, c});
            }
            faces.clear();
            faces.addAll(next);
        }
    }

    private static int midpoint(int i, int j, List<float[]> vertices, Map<Long, Integer> cache) {
        long key = ((long) Math.min(i, j) << 32) | Math.max(i, j);
        Integer cached = cache.get(key);
        if (cached != null) return cached;
        float[] a = vertices.get(i), b = vertices.get(j);
        vertices.add(normalize(new float[]{(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2}));
        cache.put(key, vertices.size() - 1);
        return vertices.size() - 1;
    }

    private static float[] normalize(float[] v) {
        float l = (float) Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
        return new float[]{v[0] / l, v[1] / l, v[2] / l};
    }
}
