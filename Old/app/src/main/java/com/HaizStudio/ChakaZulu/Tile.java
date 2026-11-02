package com.HaizStudio.ChakaZulu;

import android.graphics.Bitmap;
import android.graphics.Rect;
import android.graphics.RectF;

import java.util.ArrayList;

public class Tile {

    private float tileX, tileY;
    private float speedX;
    private Type type;
    public Bitmap bitmap;
    private int id;
    private Background bg = GameScreen.getmBackgroung();
    private Actor actor = GameScreen.getPanoramic();
    private RectF mRectangle;

    public RectF getRect() {
        return mRectangle;
    }

    public enum Type {
        tileGrass1, tileGrass2, tileGrass3, tileGrass4, tileGrass5, tileGrass6, tileGrass7, tileGrass8, tileGrass9, tileGrass10, tileGrass11, tileGrass12, tileGrass13, tileGrass14, tileGrass15, tileGrass16,
        tileTreeSmall1, tileTreeSmall2, tileTreeSmall3, tileTreeSmall4,
        tileTreeBig1, tileTreeBig2, tileTreeBig3, tileTreeBig4,
        mushroom1, mushroom2,
        treeTrunk,
        signArrow, signRectangle,
        box,
        grass1, grass2,
        grass3, grass4,
        grass5, grass6,
        grass7, grass8,
        waterTop, waterBottom,
        bubble1, bubble2,
        none
    }


    public Tile(int id, float x, float y, float tileWidth, float tileHeight, Bitmap bitmap) {
        this.tileX = x * tileWidth;
        this.tileY = y * tileHeight;
        this.id = id;
        //this.type = type;
        this.bitmap = bitmap;
        mRectangle = new RectF();

        if (id >= 1 && id <=3) {
              type = Type.tileGrass1;
        } else if (id == 2) {
            // type = Type.tileGrass2;
        } else if (id == 3) {
            // type = Type.tileGrass3;
        } else if (id == 4) {
            type = Type.waterTop;
        } else if (id == 5) {
            type = Type.tileTreeSmall1;
        } else if (id == 6) {
            type = Type.tileTreeSmall2;
        } else if (id == 7) {
            type = Type.mushroom1;
        } else if (id == 8) {
            type = Type.treeTrunk;
        } else if (id == 9) {
            //    type = Type.tileGrass3;
        } else if (id == 10) {
            //   type = Type.tileGrass1;
        } else if (id == 11) {
            // type = Type.tileGrass2;
        } else if (id == 12) {
            type = Type.tileGrass4;
        } else if (id == 13) {
            type = Type.tileGrass2;
        } else if (id == 14) {
            type = Type.tileGrass2;
        } else if (id == 15) {
            type = Type.tileGrass2;
        } else if (id == 16) {
            type = Type.waterBottom;
        } else if (id == 17) {
            type = Type.tileTreeSmall4;
        } else if (id == 18) {
            type = Type.mushroom2;
        } else if (id == 19) {
            type = Type.signArrow;
        } else if (id == 20) {
            type = Type.signRectangle;
        } else if (id == 21) {
            type = Type.box;
        } else if (id == 22) {
            type = Type.tileGrass1;
        } else if (id == 23) {
            type = Type.tileGrass8;
        } else if (id == 24) {
            type = Type.tileGrass1;
        } else if (id == 25) {
            type = Type.tileGrass2;
        } else if (id == 26) {
            type = Type.tileGrass2;
        } else if (id == 27) {
            type = Type.tileGrass2;
        } else if (id == 28) {
            type = Type.tileGrass1;
        } else if (id == 29) {
            type = Type.grass1;
        } else if (id == 30) {
            type = Type.grass2;
        } else if (id == 31) {
            type = Type.grass3;
        } else if (id == 32) {
            type = Type.grass4;
        } else if (id == 33) {
            type = Type.tileGrass12;
        } else if (id == 34) {
            type = Type.tileGrass13;
        } else if (id == 35) {
            type = Type.tileGrass14;
        } else if (id == 36) {
            type = Type.tileGrass15;
        } else if (id >= 37 && id <= 39) {
            type =Type.tileGrass1;
        } else if (id == 40) {
            type = Type.grass5;
        } else if (id == 41) {
            type = Type.grass6;
        } else if (id == 42) {
            type = Type.grass7;
        } else if (id == 43) {
            type = Type.grass8;
        } else if (id == 44) {
            // type = Type.tileGrass3;
        } else if (id == 45) {
            //  type = Type.tileGrass1;
        } else if (id == 46) {
            // type = Type.tileGrass2;
        } else if (id == 47) {
            //type = Type.tileGrass3;
        } else if (id >= 48 && id <= 59) {
            type = Type.tileGrass1;

        } else if (id >= 60 && id <= 71) {
            type = Type.tileGrass2;

        } else if (id >= 72 && id <= 83) {
            type = Type.tileGrass3;

        } else if (id == 84) {
            type = Type.bubble1;

        } else if (id == 85) {
            type = Type.bubble2;

        } else {
            type = Type.none;
        }


    }


    public float getTileX() {
        return tileX;
    }

    public void setTileX(float tileX) {
        this.tileX = tileX;
    }

    public float getTileY() {
        return tileY;
    }

    public void setTileY(float tileY) {
        this.tileY = tileY;
    }

    public Bitmap getTileImage() {
        return bitmap;
    }

    public void setTileImage(Bitmap bitmap) {
        this.bitmap = bitmap;
    }


    public static ArrayList<Rect> lrect = new ArrayList<Rect>();


    public static ArrayList<Rect> l = new ArrayList<Rect>();


    //**Getter and Setters**//

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public float getSpeedX() {
        return speedX;
    }

    public void setSpeedX(float speedX) {
        this.speedX = speedX;
    }

    public Type getType() {
        return type;
    }

    public void setType(Type type) {
        this.type = type;
    }

    public Background getBg() {
        return bg;
    }

    public void setBg(Background bg) {
        this.bg = bg;
    }

    public Actor getActor() {
        return actor;
    }

    public void setActor(Actor actor) {
        this.actor = actor;
    }

    public RectF getmRectangle() {
        return mRectangle;
    }

    public void setmRectangle(RectF mRectangle) {
        this.mRectangle = mRectangle;
    }

    public void nullify() {
        this.mRectangle = null;
        this.bitmap = null;
        this.bg = null;
        this.actor = null;
    }
}
