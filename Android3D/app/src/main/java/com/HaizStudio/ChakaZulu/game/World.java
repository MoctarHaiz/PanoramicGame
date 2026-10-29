package com.HaizStudio.ChakaZulu.game;

import com.HaizStudio.ChakaZulu.game.Level.Bandit;
import com.HaizStudio.ChakaZulu.game.Level.Bob;
import com.HaizStudio.ChakaZulu.game.Level.Obstacle;
import com.HaizStudio.ChakaZulu.gl.Particles;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Random;

/**
 * All the game rules. Runs on the GL thread; the UI thread talks to it through
 * GLSurfaceView.queueEvent and reads the volatile HUD fields.
 */
public final class World {

    public enum State {MENU, PLAYING, DYING, FINISHING, OVER}

    public static final int SFX_COIN = 0, SFX_GOLD = 1, SFX_JUMP = 2, SFX_SLIDE = 3, SFX_THROW = 4, SFX_BANDIT = 5,
            SFX_STOMP = 6, SFX_CRASH = 7, SFX_SPLASH = 8, SFX_SMASH = 9, SFX_WIN = 10, SFX_LOSE = 11;

    /** Callbacks to the UI (called on the GL thread). */
    public interface Events {
        void sound(int id, float rate);

        void haptic(boolean strong);

        void toast(String text);

        void finished(boolean won, int level, int score, int bobs, int totalBobs, int kills);
    }

    private static final float GRAVITY = 30f;
    private static final float JUMP_SPEED = 10.6f;
    private static final float RING_SPEED = 36f;
    private static final float BANDIT_SPEED = 3.8f;
    private static final float STEP = 1f / 120f;

    public final Hero hero = new Hero();
    public final Particles particles = new Particles();
    public final List<Ring> rings = new ArrayList<>();
    public Level level;
    public State state = State.MENU;

    public float time, playTime, stateTime;
    public int score, bonus, bobs, kills, combo;
    public float shake, comboTimer;
    private boolean reported;
    private int obstacleCursor, bobCursor;
    private float confettiTimer;
    private final Random random = new Random();
    private final Events events;

    // Read by the UI thread.
    public volatile int hudScore, hudBobs, hudLives = 3;
    public volatile float hudProgress, hudShield;

    public World(Events events) {
        this.events = events;
    }

    public static final class Ring {
        public float x, y, d, life = 1.4f, spin;

        Ring(float x, float y, float d) {
            this.x = x;
            this.y = y;
            this.d = d;
        }
    }

    // ----------------------------------------------------------------- flow

    /** Shows level n behind the menu with the hero idle at the start. */
    public void showMenu(int n) {
        level = LevelGenerator.generate(n);
        resetRun();
        hero.d = 2;
        state = State.MENU;
    }

    public void start(int n) {
        level = LevelGenerator.generate(n);
        resetRun();
        hero.speed = level.baseSpeed;
        state = State.PLAYING;
        events.toast("GO!");
    }

    private void resetRun() {
        hero.reset();
        rings.clear();
        particles.clear();
        playTime = stateTime = 0;
        score = bonus = bobs = kills = combo = 0;
        shake = 0;
        reported = false;
        obstacleCursor = bobCursor = 0;
        hudScore = hudBobs = 0;
        hudLives = 3;
        hudProgress = hudShield = 0;
    }

    // ---------------------------------------------------------------- debug

    /** Debug builds only: never lose a life. */
    public boolean godMode;

    /** Debug builds only: jump ahead in the level. */
    public void skipTo(float d) {
        if (level == null) return;
        hero.d = Math.max(0, Math.min(d, level.length - 5));
        obstacleCursor = bobCursor = 0;
    }

    /** Where things are in the current level (for testing). */
    public String describe() {
        StringBuilder s = new StringBuilder("level " + level.number + " length " + (int) level.length);
        for (float[] g : level.gaps) s.append(" | gap ").append((int) g[0]);
        for (Obstacle o : level.obstacles) s.append(" | ").append(new String[]{"log", "crates", "gate", "rock"}[o.type]).append(' ').append((int) o.d);
        for (Bandit b : level.bandits) s.append(" | bandit ").append((int) b.d);
        return s.toString();
    }

    public int levelNumber() {
        return level == null ? 1 : level.number;
    }

    // ---------------------------------------------------------------- input

    public void left() {
        if (state == State.PLAYING && hero.sinking < 0) hero.lane = Math.max(-1, hero.lane - 1);
    }

    public void right() {
        if (state == State.PLAYING && hero.sinking < 0) hero.lane = Math.min(1, hero.lane + 1);
    }

    public void up() {
        if (state != State.PLAYING || hero.sinking >= 0) return;
        if (hero.grounded || hero.coyote > 0) jump();
        else hero.jumpBuffer = 0.16f;
    }

    public void down() {
        if (state != State.PLAYING || hero.sinking >= 0) return;
        if (hero.grounded) {
            slide();
        } else {
            hero.vy = Math.min(hero.vy, -17f); // slam down
            hero.slideOnLanding = true;
        }
    }

    public void tap() {
        if (state != State.PLAYING || hero.sinking >= 0 || hero.throwCooldown > 0) return;
        float y = hero.y + (hero.sliding() ? 0.55f : 1.2f);
        rings.add(new Ring(hero.x, y, hero.d + 0.7f));
        hero.throwCooldown = 0.28f;
        hero.throwAnim = 0.25f;
        events.sound(SFX_THROW, 1f + random.nextFloat() * 0.15f);
    }

    private void jump() {
        hero.vy = JUMP_SPEED;
        hero.grounded = false;
        hero.coyote = hero.jumpBuffer = 0;
        hero.slideTime = 0;
        hero.airTime = 0;
        particles.dust(hero.x, hero.y, -hero.d, 6);
        events.sound(SFX_JUMP, 1f);
    }

    private void slide() {
        hero.slideTime = 0.72f;
        particles.dust(hero.x, hero.y, -hero.d, 8);
        events.sound(SFX_SLIDE, 1f);
    }

    // --------------------------------------------------------------- update

    public void update(float dt) {
        dt = Math.min(dt, 0.05f);
        time += dt;
        stateTime += dt;
        int steps = Math.max(1, Math.round(dt / STEP));
        float h = dt / steps;
        for (int i = 0; i < steps; i++) step(h);
        particles.update(dt);
        shake = Math.max(0, shake - dt * 2.2f);
        comboTimer -= dt;
        if (comboTimer <= 0) combo = 0;

        hudScore = score;
        hudBobs = bobs;
        hudLives = hero.lives;
        hudProgress = level == null ? 0 : Math.min(1f, hero.d / level.length);
        hudShield = Math.max(0, hero.shield / 8f);
    }

    private void step(float h) {
        switch (state) {
            case MENU:
                hero.runPhase += h * 1.4f;
                break;
            case PLAYING:
                stepPlaying(h);
                break;
            case DYING:
                hero.deadTime += h;
                hero.speed = Math.max(0, hero.speed - 22 * h);
                hero.d += hero.speed * h;
                if (!hero.grounded) {
                    hero.vy -= GRAVITY * h;
                    hero.y = Math.max(level.hasGround(hero.d) ? 0 : -3, hero.y + hero.vy * h);
                }
                if (hero.deadTime > 1.5f) report(false);
                break;
            case FINISHING:
                hero.celebrate += h;
                hero.speed = Math.max(0, hero.speed - 8 * h);
                hero.d += hero.speed * h;
                hero.runPhase += h * hero.speed * 2.4f;
                hero.x += (0 - hero.x) * (1 - (float) Math.exp(-4 * h));
                confettiTimer -= h;
                if (hero.celebrate < 1.8f && confettiTimer <= 0) {
                    confettiTimer = 0.35f;
                    particles.confetti(hero.x, 2.5f, -hero.d - 4, 40);
                }
                if (hero.celebrate > 2.6f) report(true);
                break;
            case OVER:
                break;
        }
        updateBandits(h);
        updateRings(h);
    }

    private void stepPlaying(float h) {
        playTime += h;
        hero.stumble = Math.max(0, hero.stumble - h);
        float target = Math.min(level.maxSpeed, level.baseSpeed + playTime * 0.06f);
        hero.speed = target * (1f - 0.55f * Math.min(1f, hero.stumble / 0.8f));
        hero.invulnerable -= h;
        hero.shield -= h;
        hero.throwCooldown -= h;
        hero.throwAnim -= h;
        hero.jumpBuffer -= h;
        hero.coyote -= h;
        hero.slideTime = Math.max(0, hero.slideTime - h);
        hero.squash = Math.max(0, hero.squash - h * 4);

        if (hero.sinking >= 0) {
            sink(h);
            return;
        }

        hero.d += hero.speed * h;
        float prevX = hero.x;
        hero.x += (Level.laneX(hero.lane) - hero.x) * (1 - (float) Math.exp(-15 * h));
        float targetLean = (hero.x - prevX) / h * 0.05f;
        hero.lean += (targetLean - hero.lean) * (1 - (float) Math.exp(-12 * h));

        float surface = surfaceAt(hero.d, hero.x, hero.y);
        if (hero.grounded) {
            if (surface < hero.y - 0.01f) {
                hero.grounded = false;
                hero.coyote = 0.1f;
                hero.vy = 0;
            } else {
                hero.y = surface;
            }
        }
        if (!hero.grounded) {
            hero.airTime += h;
            hero.vy -= GRAVITY * h;
            hero.y += hero.vy * h;
            if (hero.vy <= 0 && hero.y <= surface) land(surface);
        }
        if (hero.grounded) {
            hero.runPhase += h * hero.speed * 2.4f;
            if (hero.jumpBuffer > 0) jump();
        }

        if (hero.y < -0.9f) {
            hero.sinking = 0;
            particles.splash(hero.x, -0.8f, -hero.d);
            events.sound(SFX_SPLASH, 1f);
            events.haptic(true);
            shake = Math.max(shake, 0.45f);
            return;
        }

        collideObstacles();
        collectBobs();

        score = (int) hero.d + bonus;

        if (hero.d >= level.length) {
            state = State.FINISHING;
            stateTime = 0;
            hero.celebrate = 0;
            hero.slideTime = 0;
            confettiTimer = 0;
            events.sound(SFX_WIN, 1f);
            events.toast("HOME!");
        }
    }

    private void land(float surface) {
        boolean hard = hero.vy < -13f;
        hero.y = surface;
        hero.vy = 0;
        hero.grounded = true;
        hero.squash = hard ? 1f : 0.6f;
        hero.airTime = 0;
        particles.dust(hero.x, hero.y, -hero.d, hard ? 14 : 7);
        if (hero.slideOnLanding) {
            hero.slideOnLanding = false;
            slide();
        }
    }

    /** Height the hero can stand on: the ground, or the top of a log he is above. */
    private float surfaceAt(float d, float x, float y) {
        float s = level.hasGround(d) ? 0f : -60f;
        for (int i = obstacleCursor; i < level.obstacles.size(); i++) {
            Obstacle o = level.obstacles.get(i);
            if (o.d - o.halfDepth > d + 1) break;
            if (o.type != Obstacle.LOG || o.broken) continue;
            if (Math.abs(d - o.d) < o.halfDepth + 0.15f && Math.abs(x - o.x) < o.halfWidth + Hero.HALF_WIDTH * 0.5f
                    && y >= o.top - 0.25f)
                s = Math.max(s, o.top);
        }
        return s;
    }

    private void sink(float h) {
        hero.sinking += h;
        hero.y -= 2.6f * h;
        hero.d += hero.speed * 0.15f * h;
        if (hero.sinking < 0.75f) return;
        float[] gap = level.gapAt(hero.d);
        float respawn = gap != null ? gap[1] + 1.5f : hero.d + 2f;
        hero.sinking = -1;
        loseLife();
        if (state != State.PLAYING) {
            hero.y = -3;
            return;
        }
        hero.d = respawn;
        hero.y = 0;
        hero.vy = 0;
        hero.grounded = true;
        hero.invulnerable = 2f;
        particles.sparkle(hero.x, 1f, -hero.d, 0xFFFFFF, 20);
    }

    private void loseLife() {
        if (godMode) return;
        hero.lives--;
        combo = 0;
        events.haptic(true);
        if (hero.lives <= 0) {
            hero.lives = 0;
            state = State.DYING;
            stateTime = 0;
            hero.deadTime = 0;
            events.sound(SFX_LOSE, 1f);
        }
    }

    private void hurt() {
        events.sound(SFX_CRASH, 1f);
        hero.invulnerable = 2f;
        hero.stumble = 0.8f;
        shake = Math.max(shake, 0.7f);
        loseLife();
    }

    // ------------------------------------------------------------- contacts

    private void collideObstacles() {
        List<Obstacle> obstacles = level.obstacles;
        while (obstacleCursor < obstacles.size()) {
            Obstacle o = obstacles.get(obstacleCursor);
            if (o.d + o.halfDepth < hero.d - 30) obstacleCursor++;
            else break;
        }
        float bottom = hero.y, top = hero.y + hero.height();
        for (int i = obstacleCursor; i < obstacles.size(); i++) {
            Obstacle o = obstacles.get(i);
            if (o.d - o.halfDepth > hero.d + Hero.HALF_DEPTH) break;
            if (o.broken || o.d + o.halfDepth < hero.d - Hero.HALF_DEPTH) continue;
            if (Math.abs(hero.x - o.x) > o.halfWidth + Hero.HALF_WIDTH) continue;
            if (o.type == Obstacle.LOG && hero.y >= o.top - 0.25f) continue;
            if (top <= o.bottom + 0.03f || bottom >= o.top - 0.03f) continue;
            smash(o);
            if (hero.shield > 0) {
                bonus += 20;
                shake = Math.max(shake, 0.3f);
                events.haptic(false);
            } else if (hero.invulnerable <= 0) {
                hurt();
            }
        }
    }

    private void smash(Obstacle o) {
        o.broken = true;
        o.brokenTime = time;
        int color = o.type == Obstacle.ROCK ? 0x9A948C : o.type == Obstacle.GATE ? 0xB0703C : 0xC8914A;
        float x = o.x, cx = o.halfWidth > 1.5f ? hero.x : x;
        particles.debris(cx, o.bottom, -o.d, color, 26);
        particles.poof(cx, o.bottom, -o.d, 0xE8D8B8, 10);
        events.sound(SFX_SMASH, 1f);
    }

    private void collectBobs() {
        List<Bob> list = level.bobs;
        while (bobCursor < list.size() && list.get(bobCursor).d < hero.d - 30) bobCursor++;
        for (int i = bobCursor; i < list.size(); i++) {
            Bob b = list.get(i);
            if (b.d > hero.d + 1.5f) break;
            if (b.taken || Math.abs(b.d - hero.d) > 0.95f || Math.abs(b.x - hero.x) > 0.9f) continue;
            if (b.y < hero.y - 0.35f || b.y > hero.y + hero.height() + 0.3f) continue;
            b.taken = true;
            b.takenTime = time;
            if (b.golden) {
                hero.shield = 8f;
                bonus += 50;
                particles.sparkle(b.x, b.y, -b.d, 0xFFD54F, 40);
                events.sound(SFX_GOLD, 1f);
                events.toast("SHIELD!");
                events.haptic(false);
            } else {
                bobs++;
                bonus += 10;
                combo++;
                comboTimer = 1.2f;
                particles.sparkle(b.x, b.y, -b.d, combo % 5 == 0 ? 0xFFF59D : 0xFF6B57, 12);
                events.sound(SFX_COIN, Math.min(1f + combo * 0.035f, 1.7f));
            }
        }
    }

    private void updateBandits(float h) {
        for (Bandit b : level.bandits) {
            if (!b.alive) {
                b.deathTime += h;
                if (!b.stomped) {
                    b.d += 7 * h;
                    b.vy -= GRAVITY * h;
                    b.y += b.vy * h;
                    b.x += b.knockX * h;
                    b.spin += h * 14;
                }
                continue;
            }
            float ahead = b.d - hero.d;
            if (ahead < -15) continue;
            if (!b.active && ahead < 44 && state == State.PLAYING) b.active = true;
            if (!b.active || state == State.MENU) continue;
            if (state == State.PLAYING) {
                b.d -= BANDIT_SPEED * h;
                b.phase += h * 10;
            }
            if (!level.hasGround(b.d)) {
                b.alive = false;
                b.vy = -2;
                b.deathTime = 0;
                particles.splash(b.x, -0.8f, -b.d);
                continue;
            }
            if (state != State.PLAYING || hero.sinking >= 0) continue;
            if (Math.abs(b.d - hero.d) > 0.8f || Math.abs(b.x - hero.x) > 0.8f) continue;
            float banditTop = 1.7f;
            if (!hero.grounded && hero.vy < 0 && hero.y > banditTop - 0.8f) {
                stomp(b);
            } else if (hero.y < banditTop - 0.1f) {
                knockOut(b);
                if (hero.shield <= 0 && hero.invulnerable <= 0) hurt();
            }
        }
    }

    private void stomp(Bandit b) {
        b.alive = false;
        b.stomped = true;
        b.deathTime = 0;
        hero.vy = 11.5f;
        hero.grounded = false;
        bonus += 75;
        kills++;
        shake = Math.max(shake, 0.25f);
        particles.poof(b.x, 0.2f, -b.d, 0xFFFFFF, 14);
        particles.sparkle(b.x, 1.2f, -b.d, 0xFFE082, 14);
        events.sound(SFX_STOMP, 1f);
        events.haptic(false);
    }

    private void knockOut(Bandit b) {
        b.alive = false;
        b.deathTime = 0;
        b.vy = 8f;
        b.knockX = (random.nextFloat() * 2 - 1) * 4f;
        bonus += 50;
        kills++;
        particles.poof(b.x, 0.6f, -b.d, 0xFFFFFF, 12);
        particles.sparkle(b.x, 1.3f, -b.d, 0x80DEEA, 12);
        events.sound(SFX_BANDIT, 1f);
    }

    private void updateRings(float h) {
        Iterator<Ring> it = rings.iterator();
        while (it.hasNext()) {
            Ring r = it.next();
            r.d += RING_SPEED * h;
            r.life -= h;
            r.spin += h * 22;
            boolean hit = false;
            for (Bandit b : level.bandits) {
                if (b.alive && b.active && Math.abs(b.d - r.d) < 1.1f && Math.abs(b.x - r.x) < 0.8f && r.y < 2f) {
                    knockOut(b);
                    hit = true;
                    break;
                }
            }
            if (!hit) {
                for (int i = obstacleCursor; i < level.obstacles.size(); i++) {
                    Obstacle o = level.obstacles.get(i);
                    if (o.d - o.halfDepth > r.d + 0.4f) break;
                    if (o.broken || !o.breakable() || Math.abs(o.d - r.d) > o.halfDepth + 0.4f) continue;
                    if (Math.abs(o.x - r.x) > o.halfWidth || r.y < o.bottom || r.y > o.top) continue;
                    smash(o);
                    bonus += 20;
                    hit = true;
                    break;
                }
            }
            if (hit || r.life <= 0) {
                if (hit) particles.sparkle(r.x, r.y, -r.d, 0x4FC3F7, 8);
                it.remove();
            }
        }
    }

    private void report(boolean won) {
        if (reported) return;
        reported = true;
        state = State.OVER;
        score = (int) Math.min(hero.d, level.length) + bonus;
        hudScore = score;
        events.finished(won, level.number, score, bobs, level.totalBobs(), kills);
    }
}
