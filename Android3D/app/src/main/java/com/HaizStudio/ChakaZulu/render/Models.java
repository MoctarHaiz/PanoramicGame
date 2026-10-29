package com.HaizStudio.ChakaZulu.render;

import com.HaizStudio.ChakaZulu.gl.Mesh;
import com.HaizStudio.ChakaZulu.gl.MeshBuilder;

import java.util.Random;

/**
 * Every 3D model of the game, built from code in a stylised low-poly look.
 * Characters face -z (the running direction); their parts are built around their joints.
 */
public final class Models {

    // Hero (Panoramic): colours from the original sprites.
    private static final int SKIN = 0x8A5232, HAIR = 0x1C1719, SKIRT = 0xE9E5DC, SKIRT_DARK = 0xB8B1A6, BELT = 0x5B3A21,
            NECK = 0x1E88E5, SHOE = 0xF4F4F4, WRAP = 0xC5CBD3, SPEAR = 0xEFE7D4, METAL = 0xC2CCD6;
    // Bandit
    private static final int B_SKIN = 0xD8A07A, B_HAIR = 0x1FB5A5, B_SCARF = 0xE53935, B_ARMOR = 0xFBC02D,
            B_ARMOR_DARK = 0xD39A00, B_PANTS = 0x383A42, B_BOOT = 0x18181C;

    public Mesh heroHips, heroTorso, heroHead, heroUpperArm, heroForearmL, heroForearmR, heroThigh, heroShin;
    public Mesh banditHips, banditTorso, banditHead, banditUpperArm, banditForearm, banditThigh, banditShin;
    public Mesh bob, goldenBob, ring, shieldBubble;
    public Mesh logLane, logWide, crates2, crates3, rock, gate, finishArch, home, mountains, clouds;

    public void build() {
        MeshBuilder b = new MeshBuilder();
        Random rnd = new Random(42);

        heroHips = heroHips(b);
        heroTorso = heroTorso(b);
        heroHead = heroHead(b, rnd);
        heroUpperArm = limb(b, SKIN, 0.115f, 0.3f, 0.06f);
        heroForearmL = heroForearm(b, true);
        heroForearmR = heroForearm(b, false);
        heroThigh = limb(b, SKIN, 0.16f, 0.42f, 0.075f);
        heroShin = heroShin(b);

        banditHips = banditHips(b);
        banditTorso = banditTorso(b);
        banditHead = banditHead(b, rnd);
        banditUpperArm = limb(b, B_ARMOR, 0.12f, 0.3f, 0.065f);
        banditForearm = banditForearm(b);
        banditThigh = limb(b, B_PANTS, 0.16f, 0.42f, 0.075f);
        banditShin = banditShin(b);

        bob = bob(b);
        goldenBob = goldenBob(b);
        b.clear();
        b.jitter(0.06f).color(0x29B6F6);
        b.torus(0.25f, 0.075f, 18, 8);
        ring = b.build();
        b.clear();
        b.jitter(0).color(0xFFE7A0);
        b.sphere(1.15f, 2);
        shieldBubble = b.build();

        logLane = log(b, 1.9f);
        logWide = log(b, 7.6f);
        crates2 = crates(b, 2);
        crates3 = crates(b, 3);
        rock = bigRock(b, rnd);
        gate = gate(b);
        finishArch = finishArch(b);
        home = home(b, rnd);
        mountains = mountains(b, rnd);
        clouds = clouds(b, rnd);
    }

    // ---------------------------------------------------------------- hero

    private Mesh heroHips(MeshBuilder b) {
        b.clear();
        b.jitter(0.07f).color(SKIRT);
        b.push().translate(0, -0.26f, 0);
        b.cylinder(0.28f, 0.2f, 0.36f, 12);
        b.pop();
        b.color(SKIRT_DARK);
        for (int i = 0; i < 12; i++) {
            b.push().rotate(i * 30 + 15, 0, 1, 0).translate(0, -0.24f, 0.25f).rotate(-12, 1, 0, 0);
            b.box(0, 0, 0, 0.07f, 0.13f, 0.03f);
            b.pop();
        }
        b.color(BELT);
        b.push().translate(0, 0.07f, 0);
        b.torus(0.205f, 0.035f, 14, 4);
        b.pop();
        return b.build();
    }

    private Mesh heroTorso(MeshBuilder b) {
        b.clear();
        b.jitter(0.05f).color(SKIN);
        b.box(0, 0.15f, 0, 0.34f, 0.3f, 0.22f);
        b.box(0, 0.42f, 0, 0.47f, 0.28f, 0.26f);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.25f, 0.5f, 0);
            b.sphere(0.09f, 1);
            b.pop();
        }
        b.push().translate(0, 0.54f, 0);
        b.cylinder(0.068f, 0.062f, 0.12f, 8);
        b.pop();
        b.color(NECK);
        b.push().translate(0, 0.6f, 0);
        b.torus(0.105f, 0.036f, 14, 5);
        b.pop();
        // White bead necklace
        b.color(0xF5F1E6);
        for (int i = 0; i < 9; i++) {
            double a = Math.PI * (0.15 + 0.7 * i / 8.0);
            b.push().translate((float) Math.cos(a) * 0.16f, 0.5f - (float) Math.sin(a) * 0.04f, -(float) Math.sin(a) * 0.12f - 0.02f);
            b.sphere(0.025f, 0);
            b.pop();
        }
        return b.build();
    }

    private Mesh heroHead(MeshBuilder b, Random rnd) {
        b.clear();
        b.jitter(0.04f).color(SKIN);
        b.push().translate(0, 0.15f, 0).scale(1, 1.12f, 1.02f);
        b.sphere(0.15f, 1);
        b.pop();
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.148f, 0.15f, 0.01f);
            b.blob(0.03f, 0.05f, 0.035f, 0, 0, null);
            b.pop();
        }
        b.push().translate(0, 0.13f, -0.155f);
        b.blob(0.035f, 0.03f, 0.03f, 0, 0, null);
        b.pop();
        b.color(HAIR);
        b.push().translate(0, 0.24f, 0.035f);
        b.blob(0.168f, 0.12f, 0.17f, 1, 0.12f, rnd);
        b.pop();
        for (int i = 0; i < 7; i++) {
            float a = -60 + i * 20;
            b.push().translate((float) Math.sin(Math.toRadians(a)) * 0.08f, 0.3f, 0.06f + (float) Math.cos(Math.toRadians(a)) * 0.03f)
                    .rotate(35 + rnd.nextFloat() * 20, 1, 0, 0).rotate(a * 0.5f, 0, 0, 1);
            b.cylinder(0.05f, 0, 0.2f + rnd.nextFloat() * 0.06f, 4);
            b.pop();
        }
        b.jitter(0).color(0xFFFFFF);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.056f, 0.175f, -0.128f);
            b.sphere(0.034f, 1);
            b.pop();
        }
        b.color(0x15100E);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.056f, 0.172f, -0.155f);
            b.sphere(0.019f, 0);
            b.pop();
        }
        b.color(0x3B1D10);
        b.box(0, 0.075f, -0.146f, 0.075f, 0.016f, 0.02f);
        return b.build();
    }

    /** A limb hanging from its joint (pointing -y), with a round joint cap. */
    private Mesh limb(MeshBuilder b, int color, float width, float length, float joint) {
        b.clear();
        b.jitter(0.05f).color(color);
        b.box(0, -length / 2, 0, width, length, width);
        b.sphere(joint, 1);
        return b.build();
    }

    private Mesh heroForearm(MeshBuilder b, boolean left) {
        b.clear();
        b.jitter(0.05f).color(SKIN);
        b.box(0, -0.14f, 0, 0.1f, 0.28f, 0.1f);
        b.sphere(0.055f, 1);
        b.push().translate(0, -0.32f, 0);
        b.sphere(0.066f, 1);
        b.pop();
        b.color(NECK);
        b.box(0, -0.235f, 0, 0.125f, 0.05f, 0.125f);
        if (left) {
            // The blue ring he throws
            b.color(0x29B6F6);
            b.push().translate(0, -0.37f, -0.03f).rotate(90, 1, 0, 0);
            b.torus(0.15f, 0.04f, 16, 6);
            b.pop();
        } else {
            b.push().translate(0, -0.32f, 0).rotate(-72, 1, 0, 0).translate(0, -0.75f, 0);
            b.color(SPEAR);
            b.cylinder(0.024f, 0.022f, 1.85f, 6);
            b.translate(0, 1.85f, 0);
            b.color(METAL);
            b.cylinder(0.055f, 0, 0.26f, 4);
            b.color(0xE53935);
            b.translate(0, -0.06f, 0);
            b.box(0, 0, 0, 0.09f, 0.05f, 0.09f);
            b.pop();
        }
        return b.build();
    }

    private Mesh heroShin(MeshBuilder b) {
        b.clear();
        b.jitter(0.05f).color(SKIN);
        b.box(0, -0.09f, 0, 0.125f, 0.18f, 0.135f);
        b.sphere(0.07f, 1);
        b.color(WRAP);
        b.box(0, -0.27f, 0, 0.145f, 0.22f, 0.155f);
        b.color(SHOE);
        b.box(0, -0.415f, -0.055f, 0.155f, 0.1f, 0.29f);
        b.color(0x9AA3AD);
        b.box(0, -0.465f, -0.055f, 0.16f, 0.025f, 0.3f);
        return b.build();
    }

    // -------------------------------------------------------------- bandit

    private Mesh banditHips(MeshBuilder b) {
        b.clear();
        b.jitter(0.05f).color(B_PANTS);
        b.box(0, -0.06f, 0, 0.34f, 0.2f, 0.22f);
        b.color(B_ARMOR);
        b.push().translate(0, -0.22f, 0);
        b.cylinder(0.27f, 0.22f, 0.24f, 8);
        b.pop();
        b.color(0x111111);
        b.push().translate(0, 0.03f, 0);
        b.torus(0.2f, 0.035f, 12, 4);
        b.pop();
        return b.build();
    }

    private Mesh banditTorso(MeshBuilder b) {
        b.clear();
        b.jitter(0.05f).color(B_PANTS);
        b.box(0, 0.15f, 0, 0.33f, 0.3f, 0.21f);
        b.color(B_ARMOR);
        b.box(0, 0.42f, 0, 0.48f, 0.3f, 0.28f);
        b.color(B_ARMOR_DARK);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.27f, 0.52f, 0);
            b.blob(0.12f, 0.09f, 0.12f, 1, 0, null);
            b.pop();
        }
        b.color(B_SKIN);
        b.push().translate(0, 0.54f, 0);
        b.cylinder(0.065f, 0.06f, 0.12f, 8);
        b.pop();
        b.color(B_SCARF);
        b.push().translate(0, 0.6f, 0);
        b.torus(0.11f, 0.055f, 14, 6);
        b.pop();
        // Scarf tails flying back (+z is behind a bandit's back after it turns around)
        b.push().translate(0.06f, 0.6f, 0.12f).rotate(-25, 1, 0, 0);
        b.box(0, 0, 0.17f, 0.09f, 0.05f, 0.34f);
        b.pop();
        b.push().translate(-0.05f, 0.58f, 0.12f).rotate(-10, 1, 0, 0).rotate(12, 0, 1, 0);
        b.box(0, 0, 0.14f, 0.08f, 0.045f, 0.28f);
        b.pop();
        return b.build();
    }

    private Mesh banditHead(MeshBuilder b, Random rnd) {
        b.clear();
        b.jitter(0.04f).color(B_SKIN);
        b.push().translate(0, 0.15f, 0).scale(1, 1.1f, 1);
        b.sphere(0.15f, 1);
        b.pop();
        b.color(B_HAIR);
        b.push().translate(0, 0.25f, 0.03f);
        b.blob(0.17f, 0.11f, 0.17f, 1, 0.1f, rnd);
        b.pop();
        for (int i = 0; i < 9; i++) {
            float a = -80 + i * 20;
            b.push().translate((float) Math.sin(Math.toRadians(a)) * 0.1f, 0.3f, 0.02f + (float) Math.cos(Math.toRadians(a)) * 0.05f)
                    .rotate(25 + rnd.nextFloat() * 35, 1, 0, 0).rotate(a * 0.7f, 0, 0, 1);
            b.cylinder(0.06f, 0, 0.26f + rnd.nextFloat() * 0.1f, 4);
            b.pop();
        }
        // Red eye mask and angry eyes
        b.jitter(0).color(B_SCARF);
        b.box(0, 0.18f, -0.12f, 0.31f, 0.07f, 0.08f);
        b.color(0xFFFFFF);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.06f, 0.185f, -0.158f).scale(1.3f, 0.7f, 1);
            b.sphere(0.026f, 0);
            b.pop();
        }
        b.color(0x111111);
        b.box(0, 0.07f, -0.148f, 0.07f, 0.014f, 0.02f);
        return b.build();
    }

    private Mesh banditForearm(MeshBuilder b) {
        b.clear();
        b.jitter(0.05f).color(B_SKIN);
        b.box(0, -0.14f, 0, 0.1f, 0.28f, 0.1f);
        b.sphere(0.055f, 1);
        b.color(B_BOOT);
        b.push().translate(0, -0.32f, 0);
        b.sphere(0.07f, 1);
        b.pop();
        return b.build();
    }

    private Mesh banditShin(MeshBuilder b) {
        b.clear();
        b.jitter(0.05f).color(B_PANTS);
        b.box(0, -0.15f, 0, 0.13f, 0.3f, 0.14f);
        b.sphere(0.07f, 1);
        b.color(B_BOOT);
        b.box(0, -0.37f, -0.03f, 0.16f, 0.2f, 0.24f);
        return b.build();
    }

    // ------------------------------------------------------------- pickups

    private Mesh bob(MeshBuilder b) {
        b.clear();
        b.jitter(0.04f).color(0xE8352B);
        b.sphere(0.34f, 2);
        b.jitter(0).color(0xFFFFFF);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.12f, 0.09f, 0.27f);
            b.sphere(0.09f, 1);
            b.pop();
        }
        b.color(0x111111);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.12f, 0.09f, 0.35f);
            b.sphere(0.047f, 0);
            b.pop();
        }
        b.color(0x7A0F0B);
        for (int i = -2; i <= 2; i++) {
            b.push().translate(i * 0.05f, -0.12f + i * i * 0.012f, 0.31f - Math.abs(i) * 0.012f);
            b.box(0, 0, 0, 0.055f, 0.03f, 0.04f);
            b.pop();
        }
        b.color(0xFFC9C2);
        b.push().translate(-0.14f, 0.21f, 0.2f);
        b.blob(0.06f, 0.035f, 0.04f, 0, 0, null);
        b.pop();
        return b.build();
    }

    private Mesh goldenBob(MeshBuilder b) {
        b.clear();
        b.jitter(0.05f).color(0xFFC928);
        b.sphere(0.38f, 2);
        b.color(0xFFF4C2);
        b.push().rotate(20, 0, 0, 1);
        b.torus(0.52f, 0.04f, 20, 5);
        b.pop();
        b.color(0xFFFFFF);
        // A white star on the front
        for (int i = 0; i < 5; i++) {
            b.push().translate(0, 0, 0.36f).rotate(i * 72, 0, 0, 1);
            b.tri(-0.06f, 0, 0, 0.06f, 0, 0, 0, 0.2f, 0, 0, 0.05f, -1);
            b.pop();
        }
        b.push().translate(0, 0, 0.37f);
        b.box(0, 0, 0, 0.1f, 0.1f, 0.02f);
        b.pop();
        return b.build();
    }

    // ----------------------------------------------------------- obstacles

    private Mesh log(MeshBuilder b, float length) {
        b.clear();
        b.jitter(0.09f).color(0x7B4B2A);
        b.push().translate(0, 0.31f, 0).rotate(90, 0, 0, 1).translate(0, -length / 2, 0);
        b.cylinder(0.33f, 0.33f, length, 10);
        b.color(0xD9A066);
        b.translate(0, -0.012f, 0);
        b.cylinder(0.27f, 0.27f, 0.02f, 10);
        b.translate(0, length + 0.004f, 0);
        b.cylinder(0.27f, 0.27f, 0.02f, 10);
        b.pop();
        b.color(0x6A3F22);
        for (float x = -length / 2 + 0.6f; x < length / 2 - 0.4f; x += 1.7f) {
            b.push().translate(x, 0.55f, 0).rotate(30, 1, 0, 0);
            b.cylinder(0.07f, 0.04f, 0.32f, 5);
            b.pop();
        }
        b.color(0x6FA03A);
        for (float x = -length / 2 + 0.3f; x < length / 2; x += 2.3f) {
            b.push().translate(x, 0.6f, 0.12f);
            b.blob(0.22f, 0.08f, 0.16f, 0, 0, null);
            b.pop();
        }
        return b.build();
    }

    private Mesh crates(MeshBuilder b, int rows) {
        b.clear();
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < 2; c++)
                crate(b, -0.45f + c * 0.9f, 0.45f + r * 0.98f, (r + c) % 2 == 0);
        return b.build();
    }

    private void crate(MeshBuilder b, float x, float y, boolean light) {
        b.jitter(0.06f).color(light ? 0xD39A55 : 0xC08646);
        b.box(x, y, 0, 0.88f, 0.94f, 0.88f);
        b.color(0x8B5A2B);
        float f = 0.07f, s = 0.88f, o = 0.445f;
        for (int side = -1; side <= 1; side += 2) {
            float z = side * o;
            b.box(x, y + s / 2 - f / 2, z, s, f, 0.03f);
            b.box(x, y - s / 2 + f / 2, z, s, f, 0.03f);
            b.box(x - s / 2 + f / 2, y, z, f, s, 0.03f);
            b.box(x + s / 2 - f / 2, y, z, f, s, 0.03f);
            b.push().translate(x, y, z).rotate(45, 0, 0, 1);
            b.box(0, 0, 0, f, s * 1.25f, 0.03f);
            b.pop();
        }
    }

    private Mesh bigRock(MeshBuilder b, Random rnd) {
        b.clear();
        b.jitter(0.08f).color(0x9C968D);
        b.push().translate(0, 1.0f, 0);
        b.blob(0.95f, 1.15f, 0.85f, 1, 0.18f, rnd);
        b.pop();
        b.color(0x8A847B);
        b.push().translate(0.5f, 0.4f, 0.3f);
        b.blob(0.5f, 0.45f, 0.5f, 1, 0.2f, rnd);
        b.pop();
        b.color(0x7FA046);
        b.push().translate(-0.1f, 2.05f, 0.1f);
        b.blob(0.5f, 0.12f, 0.45f, 1, 0.15f, rnd);
        b.pop();
        return b.build();
    }

    private Mesh gate(MeshBuilder b) {
        b.clear();
        b.jitter(0.08f).color(0x7A4A28);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 3.8f, -0.3f, 0);
            b.cylinder(0.16f, 0.13f, 2.6f, 7);
            b.pop();
        }
        b.color(0x8A5630);
        b.box(0, 1.92f, 0, 8.0f, 0.26f, 0.3f);
        b.color(0x3E2A1A);
        b.box(0, 1.76f, 0, 7.6f, 0.03f, 0.03f);
        flags(b, 1.76f, 1.13f, 7.4f);
        return b.build();
    }

    /** Colourful bunting: a row of double-sided triangles hanging from y=top to y=tip. */
    private void flags(MeshBuilder b, float top, float tip, float width) {
        int[] colors = {0xE53935, 0xFFC107, 0x43A047, 0x1E88E5, 0xF4511E, 0x8E24AA};
        b.jitter(0);
        int i = 0;
        for (float x = -width / 2 + 0.25f; x <= width / 2 - 0.2f; x += 0.5f) {
            b.color(colors[i++ % colors.length]);
            b.tri(x - 0.22f, top, 0, x + 0.22f, top, 0, x, tip, 0, 0, top, -1);
            b.tri(x - 0.22f, top, 0, x + 0.22f, top, 0, x, tip, 0, 0, top, 1);
        }
    }

    private Mesh finishArch(MeshBuilder b) {
        b.clear();
        b.jitter(0.08f).color(0x7A4A28);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 4.4f, -0.3f, 0);
            b.cylinder(0.2f, 0.16f, 4.6f, 8);
            b.pop();
            b.color(0xE53935);
            b.push().translate(s * 4.4f, 4.3f, 0);
            b.cylinder(0.3f, 0, 0.6f, 6);
            b.pop();
            b.color(0x7A4A28);
        }
        b.jitter(0);
        for (int i = 0; i < 18; i++) {
            b.color(i % 2 == 0 ? 0x1A1A1A : 0xFAFAFA);
            b.box(-4.25f + i * 0.5f, 3.95f, 0, 0.5f, 0.25f, 0.2f);
            b.color(i % 2 == 0 ? 0xFAFAFA : 0x1A1A1A);
            b.box(-4.25f + i * 0.5f, 3.7f, 0, 0.5f, 0.25f, 0.2f);
        }
        flags(b, 3.55f, 3.0f, 8.4f);
        return b.build();
    }

    // ------------------------------------------------------------------ home

    /** The hollow log at the end of the level, with its HOME sign, mushrooms and bunnies. */
    private Mesh home(MeshBuilder b, Random rnd) {
        b.clear();
        float outer = 2.4f, inner = 1.95f, length = 7f;
        b.push().translate(0, 1.95f, 0).rotate(90, 1, 0, 0).translate(0, -length / 2, 0);
        int seg = 16;
        for (int i = 0; i < seg; i++) {
            double a0 = 2 * Math.PI * i / seg, a1 = 2 * Math.PI * (i + 1) / seg;
            float c0 = (float) Math.cos(a0), s0 = (float) Math.sin(a0), c1 = (float) Math.cos(a1), s1 = (float) Math.sin(a1);
            float mc = (float) Math.cos((a0 + a1) / 2), ms = (float) Math.sin((a0 + a1) / 2);
            b.jitter(0.1f).color(0x6B4226);
            b.quad(c0 * outer, 0, s0 * outer, c1 * outer, 0, s1 * outer, c1 * outer, length, s1 * outer, c0 * outer, length, s0 * outer,
                    0, length / 2, 0);
            b.color(0x3A2414);
            b.quad(c0 * inner, 0, s0 * inner, c1 * inner, 0, s1 * inner, c1 * inner, length, s1 * inner, c0 * inner, length, s0 * inner,
                    mc * 9, length / 2, ms * 9);
            b.color(0xC9935A);
            for (int end = 0; end <= 1; end++) {
                float y = end * length;
                b.quad(c0 * inner, y, s0 * inner, c1 * inner, y, s1 * inner, c1 * outer, y, s1 * outer, c0 * outer, y, s0 * outer,
                        mc * 2.2f, length / 2, ms * 2.2f);
            }
        }
        b.pop();
        // Mushrooms on top
        for (int i = 0; i < 4; i++)
            mushroom(b.push().translate(-0.8f + i * 0.55f, 4.2f, -1.5f + rnd.nextFloat() * 2.5f), rnd, 1.6f - i * 0.2f).pop();
        b.color(0x6FA03A).jitter(0.1f);
        for (int i = 0; i < 6; i++) {
            b.push().translate(-2.2f + rnd.nextFloat() * 4.4f, 4.15f, -3 + rnd.nextFloat() * 6);
            b.blob(0.5f, 0.2f, 0.4f, 1, 0.2f, rnd);
            b.pop();
        }
        // HOME sign on the left
        b.push().translate(-5.2f, 0, 3.0f).rotate(15, 0, 1, 0);
        b.jitter(0.08f).color(0x7A4A28);
        b.push().translate(0, -0.3f, 0);
        b.cylinder(0.12f, 0.1f, 2.9f, 6);
        b.pop();
        b.color(0xE8C07A);
        b.box(0, 2.15f, 0.1f, 2.4f, 0.9f, 0.12f);
        b.jitter(0).color(0x3B2412);
        float u = 0.11f;
        letter(b, 'H', -0.95f, 1.92f, 0.18f, u);
        letter(b, 'O', -0.42f, 1.92f, 0.18f, u);
        letter(b, 'M', 0.11f, 1.92f, 0.18f, u);
        letter(b, 'E', 0.64f, 1.92f, 0.18f, u);
        b.pop();
        // Bunnies welcoming the hero
        bunny(b, -3.1f, 1.8f, 0xA9A9A9, rnd);
        bunny(b, -2.4f, 2.6f, 0xD8B07A, rnd);
        bunny(b, 3.0f, 2.2f, 0xEDEDED, rnd);
        return b.build();
    }

    /** Blocky letters on a 3x5 grid of cells of size u. */
    private void letter(MeshBuilder b, char c, float x, float y, float z, float u) {
        String[] rows;
        switch (c) {
            case 'H': rows = new String[]{"X.X", "X.X", "XXX", "X.X", "X.X"}; break;
            case 'O': rows = new String[]{"XXX", "X.X", "X.X", "X.X", "XXX"}; break;
            case 'M': rows = new String[]{"X.X", "XXX", "XXX", "X.X", "X.X"}; break;
            default: rows = new String[]{"XXX", "X..", "XX.", "X..", "XXX"}; break;
        }
        for (int r = 0; r < 5; r++)
            for (int k = 0; k < 3; k++)
                if (rows[r].charAt(k) == 'X')
                    b.box(x + k * u, y + (4 - r) * u * 0.8f - 0.25f, z, u, u * 0.8f, 0.04f);
    }

    private void bunny(MeshBuilder b, float x, float z, int color, Random rnd) {
        b.push().translate(x, 0, z).rotate(160 + rnd.nextFloat() * 40, 0, 1, 0);
        b.jitter(0.06f).color(color);
        b.push().translate(0, 0.32f, 0);
        b.blob(0.26f, 0.3f, 0.32f, 1, 0.05f, rnd);
        b.pop();
        b.push().translate(0, 0.72f, -0.12f);
        b.sphere(0.2f, 1);
        b.pop();
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.08f, 0.92f, -0.1f).rotate(s * 12, 0, 0, 1);
            b.box(0, 0.18f, 0, 0.08f, 0.38f, 0.05f);
            b.pop();
        }
        b.color(0xFFFFFF);
        b.push().translate(0, 0.25f, 0.3f);
        b.sphere(0.1f, 1);
        b.pop();
        b.color(0x111111);
        for (int s = -1; s <= 1; s += 2) {
            b.push().translate(s * 0.08f, 0.76f, -0.29f);
            b.sphere(0.03f, 0);
            b.pop();
        }
        b.pop();
    }

    // ---------------------------------------------------------------- far

    private Mesh mountains(MeshBuilder b, Random rnd) {
        b.clear();
        b.jitter(0.06f);
        ridge(b, rnd, 470, 35, 85, 0x9A86C0, 56);
        ridge(b, rnd, 360, 14, 38, 0x8FA27E, 72);
        return b.build();
    }

    private void ridge(MeshBuilder b, Random rnd, float radius, float minH, float maxH, int color, int peaks) {
        b.color(color);
        for (int i = 0; i < peaks; i++) {
            double a0 = 2 * Math.PI * i / peaks, a1 = 2 * Math.PI * (i + 1) / peaks, am = (a0 + a1) / 2 + (rnd.nextDouble() - 0.5) * 0.04;
            float r0 = radius * (0.95f + rnd.nextFloat() * 0.1f);
            float h = minH + rnd.nextFloat() * (maxH - minH);
            boolean mesa = rnd.nextFloat() < 0.25f;
            float x0 = (float) Math.cos(a0) * r0, z0 = (float) Math.sin(a0) * r0;
            float x1 = (float) Math.cos(a1) * r0, z1 = (float) Math.sin(a1) * r0;
            float xm = (float) Math.cos(am) * (r0 + 15), zm = (float) Math.sin(am) * (r0 + 15);
            float ox = (float) Math.cos(am) * radius * 3, oz = (float) Math.sin(am) * radius * 3;
            if (mesa) {
                float k = 0.3f;
                b.quad(x0, -10, z0, x1, -10, z1, x1 + (xm - x1) * k, h, z1 + (zm - z1) * k, x0 + (xm - x0) * k, h, z0 + (zm - z0) * k, ox, 0, oz);
            } else {
                b.tri(x0, -10, z0, x1, -10, z1, xm, h, zm, ox, 0, oz);
                // a secondary shoulder for a more natural silhouette
                b.tri(x0, -10, z0, xm, h * 0.55f, zm, (x0 + xm) / 2, h * 0.7f, (z0 + zm) / 2, ox, 0, oz);
            }
        }
    }

    private Mesh clouds(MeshBuilder b, Random rnd) {
        b.clear();
        b.jitter(0.04f).color(0xFFFFFF);
        for (int c = 0; c < 16; c++) {
            double a = rnd.nextDouble() * Math.PI * 2;
            float r = 230 + rnd.nextFloat() * 160, y = 55 + rnd.nextFloat() * 60;
            float cx = (float) Math.cos(a) * r, cz = (float) Math.sin(a) * r;
            int puffs = 4 + rnd.nextInt(4);
            for (int p = 0; p < puffs; p++) {
                float s = 9 + rnd.nextFloat() * 10;
                b.push().translate(cx + (p - puffs / 2f) * s * 1.1f, y + rnd.nextFloat() * 5, cz + rnd.nextFloat() * 8)
                        .rotate((float) Math.toDegrees(-a), 0, 1, 0);
                b.blob(s * 1.3f, s * 0.7f, s, 1, 0.15f, rnd);
                b.pop();
            }
        }
        return b.build();
    }

    // ------------------------------------------------------------- scenery
    // Used by ChunkBuilder to bake trees, rocks and grass into the ground chunks.

    public static MeshBuilder acacia(MeshBuilder b, Random rnd, float s) {
        b.jitter(0.08f).color(0x6E4B2E);
        b.push();
        b.cylinder(0.24f * s, 0.18f * s, 1.7f * s, 6);
        b.translate(0, 1.65f * s, 0).rotate(rnd.nextFloat() * 30 - 15, 0, 0, 1);
        b.cylinder(0.18f * s, 0.12f * s, 1.5f * s, 6);
        b.translate(0, 1.45f * s, 0);
        int[] greens = {0x5C8F2D, 0x6C9E37, 0x7AA942, 0x4F8228};
        for (int k = -1; k <= 1; k += 2) {
            b.push().rotate(k * (28 + rnd.nextFloat() * 14), 0, 0, 1);
            b.color(0x6E4B2E);
            b.cylinder(0.1f * s, 0.06f * s, 1.3f * s, 5);
            b.translate(0, 1.25f * s, 0).rotate(-k * (28 + rnd.nextFloat() * 14), 0, 0, 1);
            b.color(greens[rnd.nextInt(greens.length)]);
            b.blob(1.5f * s, 0.38f * s, 1.3f * s, 1, 0.22f, rnd);
            b.pop();
        }
        b.color(greens[rnd.nextInt(greens.length)]);
        b.translate(0, 0.55f * s, 0);
        b.blob(2.2f * s, 0.5f * s, 1.9f * s, 1, 0.2f, rnd);
        b.pop();
        return b;
    }

    public static MeshBuilder bush(MeshBuilder b, Random rnd, float s) {
        int[] greens = {0x5F8F33, 0x6E9B3A, 0x557F2C, 0x88A442};
        b.jitter(0.1f);
        int n = 2 + rnd.nextInt(2);
        for (int i = 0; i < n; i++) {
            b.color(greens[rnd.nextInt(greens.length)]);
            b.push().translate((rnd.nextFloat() - 0.5f) * 0.8f * s, 0.35f * s, (rnd.nextFloat() - 0.5f) * 0.8f * s);
            b.blob(0.6f * s, 0.5f * s, 0.6f * s, 1, 0.22f, rnd);
            b.pop();
        }
        return b;
    }

    public static MeshBuilder stone(MeshBuilder b, Random rnd, float s) {
        int[] greys = {0x9C968D, 0x8B857C, 0xA8A196, 0x8E7F6E};
        b.jitter(0.08f).color(greys[rnd.nextInt(greys.length)]);
        b.push().translate(0, 0.25f * s, 0);
        b.blob((0.6f + rnd.nextFloat() * 0.4f) * s, 0.45f * s, (0.5f + rnd.nextFloat() * 0.3f) * s, 1, 0.25f, rnd);
        b.pop();
        return b;
    }

    public static MeshBuilder tuft(MeshBuilder b, Random rnd, float s) {
        b.jitter(0.12f).color(rnd.nextBoolean() ? 0xCDB352 : 0x93B640);
        for (int i = 0; i < 4; i++) {
            b.push().rotate(i * 90 + rnd.nextFloat() * 40, 0, 1, 0).rotate(18 + rnd.nextFloat() * 15, 1, 0, 0);
            b.cylinder(0.06f * s, 0, (0.45f + rnd.nextFloat() * 0.3f) * s, 3);
            b.pop();
        }
        return b;
    }

    public static MeshBuilder mushroom(MeshBuilder b, Random rnd, float s) {
        b.jitter(0.05f).color(0xF3EDE0);
        b.cylinder(0.08f * s, 0.07f * s, 0.32f * s, 6);
        b.color(0xE53935);
        b.push().translate(0, 0.32f * s, 0);
        b.blob(0.24f * s, 0.14f * s, 0.24f * s, 1, 0.05f, rnd);
        b.pop();
        b.jitter(0).color(0xFFFFFF);
        for (int i = 0; i < 4; i++) {
            double a = i * Math.PI / 2 + rnd.nextFloat();
            b.push().translate((float) Math.cos(a) * 0.13f * s, 0.41f * s, (float) Math.sin(a) * 0.13f * s);
            b.sphere(0.035f * s, 0);
            b.pop();
        }
        return b;
    }

    public static MeshBuilder termiteMound(MeshBuilder b, Random rnd, float s) {
        b.jitter(0.08f).color(0xB5713E);
        b.cylinder(0.95f * s, 0.25f * s, 2.8f * s, 7);
        b.push().translate(0.6f * s, 0, 0.2f * s);
        b.cylinder(0.5f * s, 0.12f * s, 1.6f * s, 6);
        b.pop();
        b.push().translate(-0.5f * s, 0, -0.3f * s);
        b.cylinder(0.45f * s, 0.1f * s, 1.2f * s, 6);
        b.pop();
        return b;
    }

    public static MeshBuilder baobab(MeshBuilder b, Random rnd, float s) {
        b.jitter(0.07f).color(0x8C7766);
        b.cylinder(1.25f * s, 0.95f * s, 5.2f * s, 9);
        b.translate(0, 5.0f * s, 0);
        for (int i = 0; i < 6; i++) {
            b.push().rotate(i * 60 + rnd.nextFloat() * 20, 0, 1, 0).rotate(40 + rnd.nextFloat() * 20, 1, 0, 0);
            b.color(0x8C7766);
            b.cylinder(0.25f * s, 0.12f * s, 2.0f * s, 5);
            b.translate(0, 2.0f * s, 0);
            b.color(0x6E9B3A);
            b.blob(0.8f * s, 0.45f * s, 0.8f * s, 1, 0.2f, rnd);
            b.pop();
        }
        return b;
    }
}
