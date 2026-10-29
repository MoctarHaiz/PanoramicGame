package com.HaizStudio.ChakaZulu.render;

import android.opengl.Matrix;

import com.HaizStudio.ChakaZulu.game.Hero;
import com.HaizStudio.ChakaZulu.game.World;

import java.util.Random;

/** Smooth follow camera: orbit on the menu, chase cam while running, swing-around at HOME. */
final class CameraRig {

    final float[] eye = new float[3];
    final float[] target = new float[3];
    private float fov = 52;
    private boolean initialised;
    private World.State lastState;
    private final Random random = new Random();

    void reset() {
        initialised = false;
    }

    void update(World w, float dt, float aspect, float[] view, float[] proj) {
        Hero h = w.hero;
        float hz = -h.d;
        float ex, ey, ez, tx, ty, tz, wantFov;
        boolean won = w.level != null && h.d >= w.level.length;

        if (w.state == World.State.MENU) {
            // Sway between 3/4 views of the hero's front. The camera aims to the left of him,
            // so he stands on the right half of the screen, next to the menu column.
            float a = (float) Math.sin(w.time * 0.12f) * 0.85f;
            float r = 6.2f, side = 2.4f;
            ex = (float) Math.sin(a) * r;
            ey = 1.45f + (float) Math.sin(w.time * 0.3f) * 0.15f;
            ez = hz - (float) Math.cos(a) * r;
            tx = (float) Math.cos(a) * side;
            ty = 0.95f;
            tz = hz + (float) Math.sin(a) * side;
            wantFov = 50;
        } else if (w.state == World.State.FINISHING || (w.state == World.State.OVER && won)) {
            // Swing round in front of the hero: the low sun lights his face and the
            // finish arch frames him from behind.
            // Orbit (not a straight line, which would pass through him) by his right side.
            float k = Noise.smoothstep(0, 2.0f, w.stateTime);
            float angle = k * 2.86f, radius = 6.4f - 0.6f * k;
            ex = h.x + (float) Math.sin(angle) * radius;
            ey = 2.9f + (1.55f - 2.9f) * k;
            ez = hz + (float) Math.cos(angle) * radius;
            tx = h.x;
            ty = 1.0f + 0.25f * k;
            tz = hz - 9 * (1 - k);
            wantFov = 58;
        } else if (w.state == World.State.DYING || w.state == World.State.OVER) {
            float t = Math.min(w.stateTime, 3);
            ex = h.x * 0.5f + t * 0.8f;
            ey = 3.4f + t * 1.4f;
            ez = hz + 7f + t * 1.2f;
            tx = h.x;
            ty = Math.max(h.y, -0.8f) + 0.6f;
            tz = hz;
            wantFov = 56;
        } else {
            float hy = Math.max(h.y, 0);
            ex = h.x * 0.55f;
            ey = 2.9f + hy * 0.35f;
            ez = hz + 6.3f;
            tx = h.x * 0.8f;
            ty = 1.0f + hy * 0.45f;
            tz = hz - 9f;
            wantFov = Math.min(70, 60 + Math.max(0, h.speed - 11) * 0.7f);
        }

        // A new run starts with the camera swooping down from the sky behind the hero.
        if (w.state == World.State.PLAYING && lastState != World.State.PLAYING && lastState != null) {
            eye[0] = h.x;
            eye[1] = 11f;
            eye[2] = hz + 16f;
            target[0] = 0;
            target[1] = 1f;
            target[2] = hz - 14f;
        }
        lastState = w.state;

        if (!initialised || dt <= 0) {
            if (!initialised) {
                eye[0] = ex;
                eye[1] = ey;
                eye[2] = ez;
                target[0] = tx;
                target[1] = ty;
                target[2] = tz;
                fov = wantFov;
                initialised = true;
            }
        } else {
            float kx = 1 - (float) Math.exp(-dt * 6), ky = 1 - (float) Math.exp(-dt * 4.5f), kz = 1 - (float) Math.exp(-dt * 11);
            eye[0] += (ex - eye[0]) * kx;
            eye[1] += (ey - eye[1]) * ky;
            eye[2] += (ez - eye[2]) * kz;
            target[0] += (tx - target[0]) * kx;
            target[1] += (ty - target[1]) * ky;
            target[2] += (tz - target[2]) * kz;
            fov += (wantFov - fov) * (1 - (float) Math.exp(-dt * 3));
        }

        float s = w.shake * w.shake * 0.35f;
        float sx = (random.nextFloat() * 2 - 1) * s, sy = (random.nextFloat() * 2 - 1) * s;
        Matrix.setLookAtM(view, 0, eye[0] + sx, eye[1] + sy, eye[2], target[0] + sx * 0.5f, target[1] + sy * 0.5f, target[2], 0, 1, 0);
        Matrix.perspectiveM(proj, 0, fov, aspect, 0.3f, 1400f);
    }
}
