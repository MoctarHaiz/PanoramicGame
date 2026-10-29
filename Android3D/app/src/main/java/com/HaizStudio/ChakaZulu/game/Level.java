package com.HaizStudio.ChakaZulu.game;

import java.util.ArrayList;
import java.util.List;

/**
 * One run: the track from the start to the HOME log. Distances ("d") are metres from the
 * start along the track; lateral positions ("x") are metres from the centre lane.
 */
public final class Level {

    public static final float LANE_WIDTH = 2.2f;
    public static final float TRACK_HALF_WIDTH = 3.9f;

    public static float laneX(int lane) {
        return lane * LANE_WIDTH;
    }

    public final int number;
    public final long seed;
    public final float length;
    public final float baseSpeed;
    public final float maxSpeed;

    /** Water crossings: pairs of [start, end] distances with no ground. */
    public final List<float[]> gaps = new ArrayList<>();
    public final List<Obstacle> obstacles = new ArrayList<>();
    public final List<Bob> bobs = new ArrayList<>();
    public final List<Bandit> bandits = new ArrayList<>();

    public Level(int number, long seed, float length, float baseSpeed, float maxSpeed) {
        this.number = number;
        this.seed = seed;
        this.length = length;
        this.baseSpeed = baseSpeed;
        this.maxSpeed = maxSpeed;
    }

    public boolean hasGround(float d) {
        for (float[] gap : gaps)
            if (d > gap[0] && d < gap[1]) return false;
        return true;
    }

    /** The gap that contains d, or null. */
    public float[] gapAt(float d) {
        for (float[] gap : gaps)
            if (d > gap[0] && d < gap[1]) return gap;
        return null;
    }

    public int totalBobs() {
        int n = 0;
        for (Bob b : bobs)
            if (!b.golden) n++;
        return n;
    }

    // ------------------------------------------------------------- entities

    public static final class Obstacle {
        public static final int LOG = 0, CRATES = 1, GATE = 2, ROCK = 3;

        public final int type;
        public final float d, x, halfWidth, halfDepth, bottom, top;
        public final int variant;
        public boolean broken;
        public float brokenTime;

        public Obstacle(int type, float d, float x, float halfWidth, float halfDepth, float bottom, float top, int variant) {
            this.type = type;
            this.d = d;
            this.x = x;
            this.halfWidth = halfWidth;
            this.halfDepth = halfDepth;
            this.bottom = bottom;
            this.top = top;
            this.variant = variant;
        }

        public boolean breakable() {
            return type == CRATES || type == ROCK;
        }
    }

    public static final class Bob {
        public final float d, x, y;
        public final boolean golden;
        public boolean taken;
        public float takenTime;

        public Bob(float d, float x, float y, boolean golden) {
            this.d = d;
            this.x = x;
            this.y = y;
            this.golden = golden;
        }
    }

    public static final class Bandit {
        public float d, x, y, vy;
        public final float startD;
        public boolean active, alive = true, stomped;
        public float deathTime, spin, knockX, phase;

        public Bandit(float d, float x) {
            this.d = startD = d;
            this.x = x;
        }
    }
}
