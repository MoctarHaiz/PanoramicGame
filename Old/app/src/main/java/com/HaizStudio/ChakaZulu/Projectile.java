package com.HaizStudio.ChakaZulu;

import android.graphics.RectF;

public class Projectile {

    private float x, y, speedX;
    private boolean visible;
    private RectF r;

    public Projectile(float startX, float startY) {
        x = startX;
        y = startY;
        speedX = 20;
        visible = true;
        r = new RectF(0, 0, 0, 0);
        GameScreen.click.play(5);
    }

    public void update() {
        x += speedX;
        r.set(x, y, x + 34, y + 50);


        if (x > Assets.WINDOW_WIDTH) {
            visible = false;
            r = null;
        }
        else {
            verifierCollision();
        }

    }

    private void verifierCollision() {

        for (Enemi e : GameScreen.listOfEnemies) {
            if (RectF.intersects(r, e.getRectangle())) {

                visible = false;
                GameScreen.clickEnemy.play(5);
                e.isTouched = true;


                if (e.sante > 0) {
                    e.sante -= 1;
                }
                if (e.sante == 0) {
                    e.setCenterX(-100);
                    // GameScreen.score += 5;
                }

            }
        }
    }

    public float getX() {
        return x;
    }

    public float getY() {
        return y;
    }

    public float getSpeedX() {
        return speedX;
    }

    public boolean isVisible() {
        return visible;
    }

    public void setX(int x) {
        this.x = x;
    }

    public void setY(int y) {
        this.y = y;
    }

    public void setSpeedX(int speedX) {
        this.speedX = speedX;
    }

    public void setVisible(boolean visible) {
        this.visible = visible;
    }
}
