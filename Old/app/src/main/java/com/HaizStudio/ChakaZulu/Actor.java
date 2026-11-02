package com.HaizStudio.ChakaZulu;

import android.graphics.RectF;

import java.util.ArrayList;

public class Actor {
    public static final int sante = 4;

    public static int tileAndFeetShading = 15;
    public float height; //the length of the robot in the sprite
    public float width;  //the length of the robot in the sprite
    //public static int trueWidth = 100;//The true width of the actor body, retrieved from illustrator
    //public static int trueHeight = 154;//The true height of the actor body, retrieved from illustrator
    public static RectF rectHautCorps = new RectF(0, 0, 0, 0);
    public static RectF rectBasCorps = new RectF(0, 0, 0, 0);
    public static RectF rectBody = new RectF(0, 0, 0, 0);
    public static RectF rectGlobal = new RectF(0, 0, 0, 0);
    public static RectF rectDust = new RectF(0, 0, 0, 0);
    private static Background bg1 = GameScreen.getmBackgroung();

    public int VITESSESAUT ;
    public int VITESSESAUTPLUS ;
    final int VITESSEMOUVEMENT = 15;
    public boolean Saute = false;
    public boolean bougeAGauche = false;
    public boolean isSticked = false, bougeADroite = false;
    public boolean baisse = false;
    private float centerX = 150;
    private float centerY = 100; // 382
    private boolean pretATire = true;
    private float speedX = 0;
    private float speedY = 0;
    private ArrayList<Projectile> projectiles = new ArrayList<Projectile>();
    public static boolean isColliding_bottom;
    public static boolean isColliding_right;
    public static boolean isCovered;


    public Actor(float width, float height, int VITESSESAUT, int VITESSESAUTPLUS) {
        this.width = width;
        this.height = height;
        this.VITESSESAUT = VITESSESAUT;
        this.VITESSESAUTPLUS=VITESSESAUTPLUS;
    }


    public void update() {




        // Mouvement du joueur ou de la scene.
        if (speedX < 0) {
           // centerX += speedX;
        }
       /* if (speedX == 0 || speedX < 0) {

            bg1.setSpeedX(0);
            bg2.setSpeedX(0);
        }*/

        //block robot at the beginning of the screen


        if (speedX > 0 && centerX > 350) {
           // System.out.println("SpeedX robot: " + speedX);
            //bg1.setSpeedX(-VITESSEMOUVEMENT / 5);
            //System.out.println("SpeedX background1" + bg1.getSpeedX());
        }

        if (centerY <= 0) {
            collerHaut();
        } else {
            centerY += speedY;
            speedY += 3;
        }
        /*if (speedY > 100) { ///30
            Saute = true;
        }*/


        // Ne pas aller a gauche de l'ecran
        if (centerX + speedX <= 60) {
            centerX = 61;

        }

        rectHautCorps.set(centerX - width / 4, centerY - height / 2, centerX + width / 4, centerY);
        rectBasCorps.set(centerX - width / 4, rectHautCorps.bottom, centerX + width / 4, rectHautCorps.bottom + height / 2);
        rectBody.set(centerX - width / 2, centerY - height / 2, centerX + width / 2, centerY + height / 2);

        rectGlobal.set(centerX - width / 2, centerY - height / 2, centerX + width / 2, centerY + height / 2);
        rectDust.set(centerX - width / 2, centerY, centerX + width / 2, centerY + height);

    }

    public void allerADroite() {
        if (baisse == false) {
            speedX = +VITESSEMOUVEMENT;
            centerX += speedX;
        }
    }

    /*
    Colide with Ennemy only if ennemy center enters the second half enemy rectangle
     */

    public boolean isCollidingWith(Enemy e) {
        if (RectF.intersects(e.getRectangle(), Actor.rectHautCorps) || RectF.intersects(e.getRectangle(), Actor.rectBasCorps)
                && this.centerX >= e.getCenterX() && this.centerY >= e.getCenterY())

            return true;

        return false;
    }

    public boolean iscolle() {
        return isSticked;
    }

    private void setSticked(boolean sticked) {
        this.isSticked = sticked;
    }

    public void collerHaut() {

        setSticked(true);
        setSaute(false);
        //setBaisse(false);
        centerY = 0;
        speedY = 0;


    }

    public void allerAGauche() {
        if (baisse == false) {
            speedX = -VITESSEMOUVEMENT;
        }

    }

    public void arreterADroite() {
        setBougeADroite(false);
        stopper();

    }

    public void arreterAGauche() {
        setBougeAGauche(false);
        stopper();

    }

    public void stopper() {
        if (isBougeADroite() == false && isBougeAGauche() == false) {
            speedX = 0;
        }
        if (isBougeADroite() == false && isBougeAGauche() == true) {
            allerAGauche();
        }
        if (isBougeADroite() == true && isBougeAGauche() == false) {
            allerADroite();
        }
    }

    public void sauter() {
        if (Saute == false) {
            speedY = VITESSESAUT;
            Saute = true;
            baisse = false;
        }
    }

    // ////////////////////////
    public void sauterPlus() {
        if (Saute == false) {
            speedY = VITESSESAUTPLUS;
            Saute = true;
            baisse = false;
        }
    }

    // //////////////////////////

    public void shoot() {

        if (pretATire) {
            Projectile p = new Projectile(centerX + 40, centerY);

            projectiles.add(p);
        }
    }

    public ArrayList<Projectile> getProjectiles() { // //////mod
        return projectiles;
    }

    // /lES GETTERS
    public float getCenterX() {
        return centerX;
    }

    // /LEs SETTERS
    public void setCenterX(int centerX) {
        this.centerX = centerX;
    }


    public static void setIsColliding_bottom(boolean isColliding) {
        Actor.isColliding_bottom = isColliding;
    }

    public static void setIsColliding_right(boolean isColliding) {
        Actor.isColliding_right = isColliding;
    }

    public static void setIsCovered(boolean isCovered) {
        Actor.isCovered = isCovered;
    }

    public float getCenterY() {
        return centerY;
    }

    public void setCenterY(float centerY) {
        this.centerY = centerY;
    }

    public float getSpeedX() {
        return speedX;
    }

    public void setSpeedX(int speedX) {
        this.speedX = speedX;
    }

    public float getSpeedY() {
        return speedY;
    }

    public void setSpeedY(int speedY) {
        this.speedY = speedY;
    }

    public boolean isJumping() {
        return Saute;
    }

    public void setSaute(boolean aSaute) {
        this.Saute = aSaute;
    }

    public boolean isBaisse() {
        return baisse;
    }

    public void setBaisse(boolean baisse) {
        this.baisse = baisse;
    }

    public boolean isBougeADroite() {
        return bougeADroite;
    }

    public void setBougeADroite(boolean bougeADroite) {
        this.bougeADroite = bougeADroite;
    }

    public boolean isBougeAGauche() {
        return bougeAGauche;
    }

    public void setBougeAGauche(boolean bougeAGauche) {
        this.bougeAGauche = bougeAGauche;
    }

    public boolean fallen() {
        return rectHautCorps.top > Assets.WINDOW_HEIGHT;
    }

    public boolean isPretATire() {
        return pretATire;
    }

    public void setPretATire(boolean pretATire) {
        this.pretATire = pretATire;
    }

}
