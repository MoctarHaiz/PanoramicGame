package com.HaizStudio.ChakaZulu;

import android.graphics.RectF;

public class Enemy {

    public int sante = 2;
    public static float height = Assets.enemi1.getHeight(); //the length of the robot in the sprite
    public static float width = Assets.enemi1.getWidth(); //the length of the robot in the sprite
    private float puissance, speedX = 1,speedY = 0, centerX, centerY;
    private Background bg = GameScreen.getmBackgroung();
    private Actor actor = GameScreen.getPanoramic();
    private float vitesseDeMouvement = 10; //The enemi mmoving speed in relation to the background
    private RectF r = new RectF(0, 0, 0, 0);
    public boolean isTouched = false;
    int marge = 10;
    public boolean isJumping = false;
    public boolean isGoingBack = false;
    public boolean hasTouchedPanoramicOnce = false;


    public void update() {

        //moving to left
        speedX  -= vitesseDeMouvement;
        centerX += speedX;


        //Enemy pesanteur
        centerY += speedY;
        speedY += Assets.EnemyPesanteur;


        r.set(centerX - width / 2, centerY - height / 2, centerX + width / 2 , centerY + height /2 );

       /* if (RectF.intersects(r, Actor.rectBody)) {
            checkCollisionWithRobot();
        }*/
    }

   /* private void checkCollisionWithRobot() {
        if (RectF.intersects(r, Actor.rectHautCorps) || RectF.intersects(r, Actor.rectBasCorps) && !hasTouchedPanoramicOnce) {
            GameScreen.clickEnemy.play(5);
        }
    }
*/
    public void jump() {
        if (isJumping == false) {
            speedY = -Assets.EnemyJumpSpeed;
            isJumping = true;
        }
    }

    public boolean getIsJumping() {
        return isJumping;
    }

    public void moveLeft(int delta){
        this.centerX += delta;
        r.set(centerX - width / 2, centerY - height / 2, centerX + width / 2 , centerY + height /2 );
    }

    public void setJumping(boolean jumping) {
        isJumping = jumping;
    }

    public void mourir() {

    }
    public RectF getRectangle(){
        return r;
    }

    public void attaquer() {

    }

    public float getPuissance() {
        return puissance;
    }

    public float getSpeedX() {
        return speedX;
    }

    public float getCenterX() {
        return centerX;
    }

    public float getSpeedY() {
        return speedY;
    }

    public void setSpeedY(float speedY) {
        this.speedY = speedY;
    }

    public float getCenterY() {
        return centerY;
    }

    public Background getBg() {
        return bg;
    }

    public void setPuissance(float puissance) {
        this.puissance = puissance;
    }

    public void setSpeedX(float speedX) {
        this.speedX = speedX;
    }

    public void setCenterX(float centerX) {
        this.centerX = centerX;
    }

    public void setCenterY(float centerY) {
        this.centerY = centerY;
    }

    public void setBg(Background bg) {
        this.bg = bg;
    }

}
