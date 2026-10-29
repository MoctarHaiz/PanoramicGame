package com.HaizStudio.ChakaZulu.game;

/** Panoramic, the hero. Plain state; the rules live in {@link World}. */
public final class Hero {

    public static final float HEIGHT = 1.75f;
    public static final float SLIDE_HEIGHT = 0.8f;
    public static final float HALF_WIDTH = 0.32f;
    public static final float HALF_DEPTH = 0.35f;

    public float d, x, y, vy;
    public int lane;
    public boolean grounded = true;

    public float speed;
    public float slideTime;        // > 0 while sliding
    public float jumpBuffer;       // jump pressed shortly before landing
    public boolean slideOnLanding; // swipe down while in the air
    public float coyote;           // can still jump shortly after leaving the ground
    public float invulnerable;     // after a hit
    public float shield;           // golden bob
    public float stumble;          // slowed down after a hit
    public float sinking = -1;     // > 0 while falling into water
    public float throwCooldown, throwAnim;
    public int lives = 3;

    // Animation
    public float runPhase, lean, squash, airTime, deadTime, celebrate;

    public void reset() {
        d = 0;
        x = y = vy = 0;
        lane = 0;
        grounded = true;
        speed = 0;
        slideTime = jumpBuffer = coyote = invulnerable = shield = stumble = 0;
        slideOnLanding = false;
        sinking = -1;
        throwCooldown = throwAnim = 0;
        lives = 3;
        runPhase = lean = squash = airTime = deadTime = celebrate = 0;
    }

    public boolean sliding() {
        return slideTime > 0;
    }

    public float height() {
        return sliding() ? SLIDE_HEIGHT : HEIGHT;
    }
}
