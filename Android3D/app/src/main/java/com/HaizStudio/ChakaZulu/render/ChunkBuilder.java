package com.HaizStudio.ChakaZulu.render;

import com.HaizStudio.ChakaZulu.game.Level;
import com.HaizStudio.ChakaZulu.gl.MeshBuilder;

import java.util.Random;

/**
 * Bakes one 40 m slice of the world (track, savanna, river, trees, rocks, grass) into
 * meshes. World z = -distance.
 */
final class ChunkBuilder {

    static final float LENGTH = 40f;

    private static final float[] SIDE_X = {3.9f, 4.8f, 6.0f, 7.6f, 9.6f, 12.5f, 16.5f, 22f, 29f, 38f, 50f, 65f, 85f, 110f};
    private static final float ROW = 2.5f;
    private static final float TRACK_TOP_HALF = Level.TRACK_HALF_WIDTH;

    private final Level level;
    private final int seed;

    ChunkBuilder(Level level) {
        this.level = level;
        this.seed = (int) level.seed;
    }

    /** Ground height of the savanna (not the track) at lateral x and distance d. */
    float groundY(float x, float d) {
        float ax = Math.abs(x);
        float y = -0.32f;
        y += Noise.smoothstep(12, 50, ax) * (Noise.value(x * 0.035f, d * 0.035f, seed) * 6f + 0.3f);
        y += Noise.smoothstep(4.5f, 9, ax) * (Noise.value(x * 0.18f, d * 0.18f, seed + 1) - 0.5f) * 0.45f;
        float riverDist = riverDistance(d);
        if (riverDist < 3.5f) y = mix(-1.9f, y, Noise.smoothstep(0, 3.5f, riverDist));
        return y;
    }

    private float riverDistance(float d) {
        float best = 1e9f;
        for (float[] gap : level.gaps) {
            float dist = d < gap[0] ? gap[0] - d : d > gap[1] ? d - gap[1] : 0;
            best = Math.min(best, dist);
        }
        return best;
    }

    private static float mix(float a, float b, float t) {
        return a + (b - a) * t;
    }

    // -------------------------------------------------------------- terrain

    /** Track, ground and scenery for chunk [index * 40, index * 40 + 40). */
    void terrain(MeshBuilder b, int index) {
        b.clear();
        float d0 = index * LENGTH, d1 = d0 + LENGTH;
        track(b, d0, d1);
        side(b, d0, d1, -1);
        side(b, d0, d1, 1);
        scenery(b, index, d0, d1);
    }

    private void track(MeshBuilder b, float d0, float d1) {
        // Split the chunk at river crossings.
        float start = d0;
        while (start < d1) {
            float[] gap = level.gapAt(start + 0.001f);
            if (gap != null) {
                start = Math.min(d1, gap[1]);
                continue;
            }
            float end = d1;
            for (float[] g : level.gaps)
                if (g[0] > start && g[0] < end) end = g[0];
            trackPiece(b, start, end);
            start = end;
        }
    }

    private void trackPiece(MeshBuilder b, float d0, float d1) {
        float z0 = -d0, z1 = -d1, zc = (z0 + z1) / 2, len = d1 - d0;
        b.jitter(0.05f);
        // Body of the raised path
        b.color(0x8A5732);
        b.box(0, -1.25f, zc, TRACK_TOP_HALF * 2, 2.5f, len);
        // Lanes: three strips of red earth, darker grooves between them
        b.jitter(0.035f);
        int[] lanes = {0xB9693A, 0xAE6134, 0xB9693A};
        for (int l = -1; l <= 1; l++) {
            b.color(lanes[l + 1]);
            float x = Level.laneX(l);
            b.box(x, 0.01f, zc, Level.LANE_WIDTH - 0.14f, 0.02f, len);
        }
        b.color(0x7E4626);
        for (int s = -1; s <= 1; s += 2)
            b.box(s * Level.LANE_WIDTH / 2, 0.002f, zc, 0.14f, 0.012f, len);
        // Grass borders
        b.jitter(0.1f);
        for (int s = -1; s <= 1; s += 2) {
            for (float d = d0; d < d1 - 0.01f; d += 2f) {
                float e = Math.min(d1, d + 2f);
                b.color(((int) d / 2) % 2 == 0 ? 0x6DB443 : 0x63A83C);
                b.box(s * (TRACK_TOP_HALF - 0.22f), 0.05f, -(d + e) / 2, 0.5f, 0.12f, e - d);
            }
        }
        // Small stones along the path edges
        Random rnd = new Random(seed * 31L + (long) d0);
        b.jitter(0.08f);
        for (int i = 0; i < (int) (len / 3); i++) {
            float d = d0 + rnd.nextFloat() * len;
            float x = (rnd.nextBoolean() ? -1 : 1) * (Level.LANE_WIDTH * 1.5f - 0.15f + rnd.nextFloat() * 0.2f);
            b.color(0xA58C6E);
            b.push().translate(x, 0.02f, -d);
            b.blob(0.09f, 0.05f, 0.08f, 0, 0.2f, rnd);
            b.pop();
        }
    }

    private void side(MeshBuilder b, float d0, float d1, int sign) {
        b.jitter(0.06f);
        for (float d = d0; d < d1 - 0.01f; d += ROW) {
            float e = Math.min(d1, d + ROW);
            for (int i = 0; i < SIDE_X.length - 1; i++) {
                float xa = sign * SIDE_X[i], xb = sign * SIDE_X[i + 1];
                float y00 = groundY(xa, d), y10 = groundY(xb, d), y01 = groundY(xa, e), y11 = groundY(xb, e);
                // two triangles, each coloured from its own height and position
                groundTri(b, xa, y00, -d, xb, y10, -d, xb, y11, -e);
                groundTri(b, xa, y00, -d, xb, y11, -e, xa, y01, -e);
            }
        }
    }

    private void groundTri(MeshBuilder b, float ax, float ay, float az, float bx, float by, float bz, float cx, float cy, float cz) {
        float x = (ax + bx + cx) / 3, y = (ay + by + cy) / 3, z = (az + bz + cz) / 3;
        int color;
        if (y < -1.0f) color = 0x7E6037;            // river bank
        else if (y < -0.6f) color = 0x8DA644;       // wet grass near water
        else {
            float n = Noise.value(x * 0.05f, z * 0.05f, seed + 7);
            float m = Noise.value(x * 0.21f, z * 0.21f, seed + 9);
            if (n < 0.38f) color = m < 0.5f ? 0x7FA53A : 0x8DB042;     // green patches
            else if (n < 0.72f) color = m < 0.5f ? 0xC4A346 : 0xB99A40; // golden grass
            else color = m < 0.5f ? 0xB98A48 : 0xAD8042;               // dry earth
            if (y > 2.5f) color = 0xB29A62;                             // hill tops
        }
        b.color(color);
        b.tri(ax, ay, az, bx, by, bz, cx, cy, cz, x, y - 10, z);
    }

    // -------------------------------------------------------------- scenery

    private void scenery(MeshBuilder b, int index, float d0, float d1) {
        Random rnd = new Random(seed * 7919L + index * 104729L);
        scatter(b, rnd, d0, d1, 7, 8, 70, 1.0f, 1.9f, 0);   // acacias
        scatter(b, rnd, d0, d1, 12, 5.5f, 45, 0.7f, 1.5f, 1); // bushes
        scatter(b, rnd, d0, d1, 9, 5f, 50, 0.6f, 1.8f, 2);  // stones
        scatter(b, rnd, d0, d1, 40, 4.4f, 16, 0.8f, 1.4f, 3); // grass
        scatter(b, rnd, d0, d1, 3, 4.4f, 5.2f, 0.8f, 1.2f, 4); // mushrooms near the path
        if (rnd.nextFloat() < 0.7f) scatter(b, rnd, d0, d1, 1, 9, 30, 0.8f, 1.3f, 5); // termite mound
        if (rnd.nextFloat() < 0.35f) scatter(b, rnd, d0, d1, 1, 28, 70, 1.0f, 1.5f, 6); // baobab
    }

    private void scatter(MeshBuilder b, Random rnd, float d0, float d1, int count, float minX, float maxX,
                         float minScale, float maxScale, int kind) {
        for (int i = 0; i < count; i++) {
            float d = d0 + rnd.nextFloat() * (d1 - d0);
            float ax = minX + (float) Math.pow(rnd.nextFloat(), 1.6) * (maxX - minX);
            float x = (rnd.nextBoolean() ? -1 : 1) * ax;
            float s = minScale + rnd.nextFloat() * (maxScale - minScale);
            if (kind == 0) s *= 1 + Noise.smoothstep(15, 70, ax) * 0.8f;
            if (riverDistance(d) < 4.5f) continue;
            if (Math.abs(d) < 22 && ax < 15) continue; // keep the menu camera's orbit clear
            b.push().translate(x, groundY(x, d) - 0.05f, -d).rotate(rnd.nextFloat() * 360, 0, 1, 0);
            switch (kind) {
                case 0: Models.acacia(b, rnd, s); break;
                case 1: Models.bush(b, rnd, s); break;
                case 2: Models.stone(b, rnd, s); break;
                case 3: Models.tuft(b, rnd, s); break;
                case 4: Models.mushroom(b, rnd, s); break;
                case 5: Models.termiteMound(b, rnd, s); break;
                default: Models.baobab(b, rnd, s); break;
            }
            b.pop();
        }
    }

    // ---------------------------------------------------------------- water

    /** Rivers crossing this chunk (empty if none). */
    void water(MeshBuilder b, int index) {
        b.clear();
        float d0 = index * LENGTH, d1 = d0 + LENGTH;
        b.jitter(0.05f);
        for (float[] gap : level.gaps) {
            float s = Math.max(d0, gap[0] - 3.5f), e = Math.min(d1, gap[1] + 3.5f);
            if (s >= e) continue;
            for (float x = -110; x < 110; x += 5) {
                for (float d = s; d < e - 0.01f; d += 1.5f) {
                    float dd = Math.min(e, d + 1.5f);
                    b.color(((int) (x / 5) + (int) (d / 1.5f)) % 2 == 0 ? 0x2FA3C4 : 0x34ABCB);
                    b.quad(x, -0.85f, -d, x + 5, -0.85f, -d, x + 5, -0.85f, -dd, x, -0.85f, -dd, x + 2.5f, -10, -(d + dd) / 2);
                }
            }
        }
    }
}
