package com.HaizStudio.ChakaZulu.game;

import com.HaizStudio.ChakaZulu.game.Level.Bandit;
import com.HaizStudio.ChakaZulu.game.Level.Bob;
import com.HaizStudio.ChakaZulu.game.Level.Obstacle;

import java.util.Random;

/**
 * Builds a level from hand-designed patterns. The same level number always gives the
 * same level; later levels are longer, faster and denser.
 */
public final class LevelGenerator {

    private static final float BOB_Y = 0.95f;
    private static final float BOB_STEP = 2.3f;

    private final Random rnd;
    private final Level level;
    private final int n;
    private float lastGolden = 0;

    private LevelGenerator(int number) {
        n = number;
        long seed = 9_371L + number * 7_919L;
        rnd = new Random(seed);
        float length = Math.min(420 + 120 * (number - 1), 1700);
        float base = Math.min(11.5f + 0.7f * (number - 1), 18f);
        level = new Level(number, seed, length, base, Math.min(base + 5f, 23f));
    }

    public static Level generate(int number) {
        return new LevelGenerator(Math.max(1, number)).build();
    }

    private Level build() {
        // Runway with a welcome line of red bobs.
        bobLine(0, 14, 7);
        float d = 36;
        if (n == 1) {
            // First level teaches each move once: jump, dodge, slide, throw, jump a river.
            d = logHurdle(d, true) + 10;
            d = crateWall(d, 2) + 10;
            d = gate(d) + 10;
            d = banditGroup(d, 1) + 8;
            d = waterGap(d) + 12;
        }
        float end = level.length - 40;
        while (d < end) {
            d = pattern(d);
            float spacing = Math.max(3.5f, 9f - n * 0.7f) + rnd.nextFloat() * 5f;
            d += spacing;
        }
        // The world scans these in distance order.
        level.bobs.sort((a, b) -> Float.compare(a.d, b.d));
        level.obstacles.sort((a, b) -> Float.compare(a.d, b.d));
        return level;
    }

    private int lane() {
        return rnd.nextInt(3) - 1;
    }

    private float pattern(float d) {
        float difficulty = Math.min(1f, 0.25f + n * 0.12f);
        float roll = rnd.nextFloat();
        if (d - lastGolden > 260 && rnd.nextFloat() < 0.35f) {
            lastGolden = d;
            golden(d + 4, lane());
            return d + 8;
        }
        if (roll < 0.09f) return bobLine(lane(), d, 6 + rnd.nextInt(5));
        if (roll < 0.23f) return logHurdle(d, rnd.nextFloat() < difficulty * 0.6f);
        if (roll < 0.37f) return crateWall(d, rnd.nextFloat() < difficulty ? 2 : 1);
        if (roll < 0.49f) return waterGap(d);
        if (roll < 0.59f) return gate(d);
        if (roll < 0.79f) return banditGroup(d, 1 + rnd.nextInt(n >= 3 ? 3 : 2));
        if (roll < 0.90f) return zigzag(d);
        return combo(d);
    }

    // -------------------------------------------------------------- patterns

    private float bobLine(int lane, float d, int count) {
        for (int i = 0; i < count; i++)
            level.bobs.add(new Bob(d + i * BOB_STEP, Level.laneX(lane), BOB_Y, false));
        return d + count * BOB_STEP;
    }

    /** Bobs following a jump arc centred on d (the path of a jump started 4.5 m before). */
    private void bobArc(int lane, float d, float peak) {
        for (int i = -3; i <= 3; i++) {
            float t = i / 3.5f;
            level.bobs.add(new Bob(d + i * 1.5f, Level.laneX(lane), BOB_Y + peak * (1 - t * t), false));
        }
    }

    private float logHurdle(float d, boolean fullWidth) {
        float at = d + 6;
        if (fullWidth) {
            level.obstacles.add(new Obstacle(Obstacle.LOG, at, 0, Level.TRACK_HALF_WIDTH - 0.2f, 0.35f, 0, 0.62f, 1));
            bobArc(lane(), at, 1.1f);
        } else {
            int lane = lane();
            level.obstacles.add(new Obstacle(Obstacle.LOG, at, Level.laneX(lane), 0.95f, 0.35f, 0, 0.62f, 0));
            bobArc(lane, at, 1.1f);
            if (rnd.nextBoolean()) bobLine(otherLane(lane), d + 2, 4);
        }
        return at + 6;
    }

    private float crateWall(float d, int blocked) {
        int free = lane();
        float at = d + 6;
        int a = otherLane(free), b = -a - free; // the two lanes that are not free
        addCrates(at, a);
        if (blocked == 2) addCrates(at, b);
        bobLine(free, at - 4, 4);
        return at + 4;
    }

    private void addCrates(float at, int lane) {
        boolean rock = rnd.nextFloat() < 0.3f;
        float h = rock ? 2.2f : 2.0f + rnd.nextInt(2) * 1.0f;
        level.obstacles.add(new Obstacle(rock ? Obstacle.ROCK : Obstacle.CRATES, at, Level.laneX(lane), 0.9f, 0.85f, 0, h, rnd.nextInt(3)));
    }

    private float waterGap(float d) {
        float width = Math.min(3.6f + n * 0.25f + rnd.nextFloat() * 1.2f, 6.2f);
        float start = d + 6;
        level.gaps.add(new float[]{start, start + width});
        bobArc(lane(), start + width / 2, 1.2f);
        return start + width + 4;
    }

    private float gate(float d) {
        float at = d + 6;
        level.obstacles.add(new Obstacle(Obstacle.GATE, at, 0, Level.TRACK_HALF_WIDTH - 0.2f, 0.25f, 1.12f, 1.75f, rnd.nextInt(3)));
        int lane = lane();
        for (int i = -2; i <= 2; i++)
            level.bobs.add(new Bob(at + i * 1.4f, Level.laneX(lane), 0.45f, false));
        return at + 5;
    }

    private float banditGroup(float d, int count) {
        int first = lane();
        for (int i = 0; i < count; i++) {
            int lane = ((first + 1 + i) % 3) - 1;
            level.bandits.add(new Bandit(d + 26 + i * 9, Level.laneX(lane)));
        }
        bobLine(lane(), d + 4, 5);
        return d + 26 + count * 9;
    }

    private float zigzag(float d) {
        int lane = lane();
        float at = d + 6;
        int steps = 3 + (n >= 4 ? 1 : 0);
        for (int i = 0; i < steps; i++) {
            addCrates(at, lane);
            int next = otherLane(lane);
            bobLine(next, at - 3, 3);
            lane = next;
            at += Math.max(9f, 13f - n * 0.5f);
        }
        return at;
    }

    private float combo(float d) {
        float after = waterGap(d);
        if (rnd.nextBoolean()) return logHurdle(after, true);
        return banditGroup(after, 1 + rnd.nextInt(2));
    }

    private void golden(float d, int lane) {
        level.bobs.add(new Bob(d, Level.laneX(lane), 1.2f, true));
    }

    private int otherLane(int lane) {
        int l;
        do {
            l = lane();
        } while (l == lane);
        return l;
    }
}
