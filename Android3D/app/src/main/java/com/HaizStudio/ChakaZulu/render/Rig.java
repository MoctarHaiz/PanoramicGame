package com.HaizStudio.ChakaZulu.render;

import android.opengl.Matrix;

import com.HaizStudio.ChakaZulu.game.Hero;
import com.HaizStudio.ChakaZulu.game.Level.Bandit;
import com.HaizStudio.ChakaZulu.game.World;
import com.HaizStudio.ChakaZulu.gl.Mesh;
import com.HaizStudio.ChakaZulu.gl.Shader;

/**
 * Poses and draws the jointed characters. Angles are in degrees. A positive rotation
 * about x swings a hanging limb forward (-z) and tilts an upright body backwards.
 */
final class Rig {

    private static final float HIP = 0.94f;

    private final float[] base = new float[16], hips = new float[16], torso = new float[16];
    private final float[] limb = new float[16], lower = new float[16];
    private Shader shader;

    // Pose, recomputed for each character
    private float legL, legR, kneeL, kneeR, armL, armR, elbowL, elbowR, spreadL, spreadR;
    private float hipsPitch, torsoPitch, torsoYaw, headYaw, headPitch;

    void use(Shader s) {
        shader = s;
    }

    private void draw(Mesh mesh, float[] m) {
        shader.setMatrix("uModel", m);
        mesh.draw();
    }

    private void neutral() {
        legL = legR = kneeL = kneeR = armL = armR = 0;
        elbowL = elbowR = 20;
        spreadL = spreadR = 8;
        hipsPitch = torsoPitch = torsoYaw = headYaw = headPitch = 0;
    }

    private void run(float phase, float amount) {
        float s = (float) Math.sin(phase), c = (float) Math.cos(phase);
        legL = s * 44 * amount;
        legR = -s * 44 * amount;
        kneeL = -(12 + 80 * Math.max(0, c)) * amount;
        kneeR = -(12 + 80 * Math.max(0, -c)) * amount;
        armL = -s * 42 * amount;
        armR = s * 42 * amount;
        elbowL = 60 + 25 * Math.max(0, -s) * amount;
        elbowR = 60 + 25 * Math.max(0, s) * amount;
        spreadL = spreadR = 9;
        torsoPitch = -11 * amount;
        torsoYaw = s * 9 * amount;
        headYaw = -s * 4 * amount;
    }

    // ----------------------------------------------------------------- hero

    void hero(Models m, Hero h, World w) {
        neutral();
        float time = w.time, bob = 0;
        float roll = Math.max(-22, Math.min(22, -h.lean * 26));
        float extraPitch = 0;

        if (w.state == World.State.MENU) {
            legL = 3;
            legR = -4;
            kneeL = kneeR = -5;
            armL = 6;
            elbowL = 30;
            armR = 18;
            elbowR = 55;
            spreadL = spreadR = 10;
            torsoPitch = (float) Math.sin(time * 2) * 1.5f;
            headYaw = (float) Math.sin(time * 0.6f) * 22;
            headPitch = (float) Math.sin(time * 0.9f) * 4;
        } else if (w.state == World.State.DYING || (w.state == World.State.OVER && h.lives == 0)) {
            extraPitch = Math.min(1, h.deadTime * 2.2f) * 82;
            armL = armR = 40;
            spreadL = spreadR = 55;
            legL = 20;
            kneeL = -30;
        } else if ((w.state == World.State.FINISHING || w.state == World.State.OVER) && h.speed < 2.5f) {
            float t = h.celebrate;
            bob = Math.abs((float) Math.sin(t * 7)) * 0.38f;
            armL = 168 + (float) Math.sin(t * 14) * 10;
            armR = 168 - (float) Math.sin(t * 14) * 10;
            spreadL = spreadR = 26;
            elbowL = elbowR = 12;
            legL = legR = bob > 0.1f ? 25 : 0;
            kneeL = kneeR = bob > 0.1f ? -45 : 0;
            headPitch = 12;
        } else if (h.sliding()) {
            hipsPitch = 62;
            legL = 30;
            kneeL = -5;
            legR = 18;
            kneeR = -28;
            armL = -45;
            armR = -30;
            elbowL = elbowR = 30;
            spreadL = spreadR = 28;
            torsoPitch = -14;
            headPitch = -25;
        } else if (!h.grounded && h.sinking < 0) {
            float t = Math.min(1, h.airTime / 0.22f);
            legL = 58 * t;
            kneeL = -100 * t;
            legR = -10 * t;
            kneeR = -55 * t;
            boolean rising = h.vy > 0;
            armL = (rising ? 150 : 95) * t;
            armR = (rising ? 120 : 70) * t;
            elbowL = elbowR = 18;
            spreadL = spreadR = rising ? 18 : 42;
            torsoPitch = -6;
        } else {
            run(h.runPhase, 1);
            bob = Math.abs((float) Math.sin(h.runPhase)) * 0.07f;
        }
        if (h.throwAnim > 0) {
            float k = h.throwAnim / 0.25f;
            armL = armL + (125 - armL) * k;
            elbowL = elbowL + (8 - elbowL) * k;
        }

        Matrix.setIdentityM(base, 0);
        float baseY = h.y + bob;
        if (h.sliding() && w.state == World.State.PLAYING) baseY += 0.42f - HIP;
        Matrix.translateM(base, 0, h.x, baseY, -h.d);
        Matrix.rotateM(base, 0, roll, 0, 0, 1);
        if (extraPitch != 0) Matrix.rotateM(base, 0, extraPitch, 1, 0, 0);
        if (h.squash > 0) {
            float q = h.squash;
            Matrix.scaleM(base, 0, 1 + 0.1f * q, 1 - 0.17f * q, 1 + 0.1f * q);
        }
        body(m.heroHips, m.heroTorso, m.heroHead, m.heroUpperArm, m.heroForearmL, m.heroForearmR, m.heroThigh, m.heroShin);
    }

    // ---------------------------------------------------------------- bandit

    /** Returns false when the bandit no longer needs drawing. */
    boolean bandit(Models m, Bandit b, World w) {
        neutral();
        Matrix.setIdentityM(base, 0);
        if (!b.alive) {
            if (b.stomped) {
                if (b.deathTime > 0.7f) return false;
                Matrix.translateM(base, 0, b.x, 0, -b.d);
                Matrix.rotateM(base, 0, 180, 0, 1, 0);
                Matrix.scaleM(base, 0, 1 + b.deathTime, Math.max(0.15f, 1 - b.deathTime * 8), 1 + b.deathTime);
                spreadL = spreadR = 70;
            } else {
                if (b.deathTime > 1.6f || b.y < -6) return false;
                Matrix.translateM(base, 0, b.x, b.y + 0.9f, -b.d);
                Matrix.rotateM(base, 0, (float) Math.toDegrees(b.spin), 1, 0.3f, 0);
                Matrix.translateM(base, 0, 0, -0.9f, 0);
                spreadL = spreadR = 60;
                legL = 30;
                legR = -20;
            }
        } else {
            boolean running = b.active && w.state == World.State.PLAYING;
            if (running) {
                run(b.phase, 1.1f);
                elbowL = elbowR = 95;
            } else {
                // Waiting: menacing idle
                armL = armR = 20;
                elbowL = elbowR = 100;
                spreadL = spreadR = 25;
                torsoPitch = -6;
                headYaw = (float) Math.sin(w.time * 1.3f + b.startD) * 20;
            }
            float bob = running ? Math.abs((float) Math.sin(b.phase)) * 0.08f : 0;
            Matrix.translateM(base, 0, b.x, b.y + bob, -b.d);
            Matrix.rotateM(base, 0, 180, 0, 1, 0);
        }
        body(m.banditHips, m.banditTorso, m.banditHead, m.banditUpperArm, m.banditForearm, m.banditForearm, m.banditThigh, m.banditShin);
        return true;
    }

    // -------------------------------------------------------------- skeleton

    private void body(Mesh hipsMesh, Mesh torsoMesh, Mesh headMesh, Mesh upperArm, Mesh forearmL, Mesh forearmR,
                      Mesh thigh, Mesh shin) {
        System.arraycopy(base, 0, hips, 0, 16);
        Matrix.translateM(hips, 0, 0, HIP, 0);
        if (hipsPitch != 0) Matrix.rotateM(hips, 0, hipsPitch, 1, 0, 0);
        draw(hipsMesh, hips);

        leg(thigh, shin, -0.11f, legL, kneeL);
        leg(thigh, shin, 0.11f, legR, kneeR);

        System.arraycopy(hips, 0, torso, 0, 16);
        if (torsoYaw != 0) Matrix.rotateM(torso, 0, torsoYaw, 0, 1, 0);
        if (torsoPitch != 0) Matrix.rotateM(torso, 0, torsoPitch, 1, 0, 0);
        draw(torsoMesh, torso);

        System.arraycopy(torso, 0, limb, 0, 16);
        Matrix.translateM(limb, 0, 0, 0.64f, 0);
        if (headYaw != 0) Matrix.rotateM(limb, 0, headYaw, 0, 1, 0);
        if (headPitch != 0) Matrix.rotateM(limb, 0, headPitch, 1, 0, 0);
        draw(headMesh, limb);

        arm(upperArm, forearmL, -0.27f, -spreadL, armL, elbowL);
        arm(upperArm, forearmR, 0.27f, spreadR, armR, elbowR);
    }

    private void leg(Mesh thigh, Mesh shin, float x, float swing, float knee) {
        System.arraycopy(hips, 0, limb, 0, 16);
        Matrix.translateM(limb, 0, x, -0.04f, 0);
        if (swing != 0) Matrix.rotateM(limb, 0, swing, 1, 0, 0);
        draw(thigh, limb);
        System.arraycopy(limb, 0, lower, 0, 16);
        Matrix.translateM(lower, 0, 0, -0.42f, 0);
        if (knee != 0) Matrix.rotateM(lower, 0, knee, 1, 0, 0);
        draw(shin, lower);
    }

    private void arm(Mesh upper, Mesh fore, float x, float spread, float swing, float elbow) {
        System.arraycopy(torso, 0, limb, 0, 16);
        Matrix.translateM(limb, 0, x, 0.5f, 0);
        if (spread != 0) Matrix.rotateM(limb, 0, spread, 0, 0, 1);
        if (swing != 0) Matrix.rotateM(limb, 0, swing, 1, 0, 0);
        draw(upper, limb);
        System.arraycopy(limb, 0, lower, 0, 16);
        Matrix.translateM(lower, 0, 0, -0.3f, 0);
        if (elbow != 0) Matrix.rotateM(lower, 0, elbow, 1, 0, 0);
        draw(fore, lower);
    }
}
