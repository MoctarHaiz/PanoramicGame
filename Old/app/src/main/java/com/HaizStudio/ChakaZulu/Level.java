package com.HaizStudio.ChakaZulu;

import android.graphics.RectF;

import java.util.ArrayList;

/**
 * Created by almoctar on 18/06/2017.
 */
public class Level {
    private ArrayList<Tile> tilearray = new ArrayList<Tile>();
    private ArrayList<Tile> tilearrayInScreen = new ArrayList<Tile>();
    private int x, y;
    private int speed;


    public Level(int x, int y, int speed) {
        this.x = x;
        this.y = y;
        this.speed = speed;
        this.tilearray = new ArrayList<Tile>();
    }


    int firstTileInSreen = 0; //Save the Position of the First visible Tile in the current Screen

    public void updateTilearrayInScreen() {
        firstTileInSreen = 0;
        tilearrayInScreen.clear();
        int tileAraySize = this.getTilearray().size();

        //Search the first visible Tile( X>0 )
        while (firstTileInSreen < tileAraySize && ((Tile) this.getTilearray().get(firstTileInSreen)).getTileX() + Assets.TILE_SIDE_WIDTH < 0)
            firstTileInSreen++;


        // Then consider only the 20*30 next Tiles
        for (int i = firstTileInSreen; i <= firstTileInSreen + (Assets.WINDOW_WIDTH / Assets.TILE_SIDE_WIDTH) * (1 + Assets.WINDOW_HEIGHT / Assets.TILE_SIDE_HEIGHT) + Assets.TILE_SIDE_WIDTH && i < this.getTilearray().size(); i++) {
            Tile t = (Tile) this.getTilearray().get(i);
            if (t.getType() != Tile.Type.none) {
                {
                    tilearrayInScreen.add(t);
                }
            }
        }

        //Delete Tiles that disappeared
        for (int i = 0; i < firstTileInSreen - 30 && i < this.getTilearray().size(); i++) {
            //tilearray.get(i).nullify();
           // tilearray.remove(i);
        }


    }

    public void removeTile(Tile tile) {

        tilearrayInScreen.remove(tile);
        tilearray.remove(tile);
    }

    public Tile checkCollisionTopGrass(RectF rectangle) {
        Tile result = null;
        for (int i = 0; i < tilearrayInScreen.size(); i++) {
            Tile t = (Tile) tilearrayInScreen.get(i);
            t.getmRectangle().set(t.getTileX(), t.getTileY(), t.getTileX() + Assets.TILE_SIDE_WIDTH, t.getTileY() + Assets.TILE_SIDE_HEIGHT);
            Tile.Type type = t.getType();
            if (RectF.intersects(rectangle, t.getmRectangle()) &&
                    (type == Tile.Type.tileGrass1
                          /*  || type == Tile.Type.tileGrass2
                            || type == Tile.Type.tileGrass3
                            || type == Tile.Type.tileGrass7
                            || type == Tile.Type.tileGrass11
                            || type == Tile.Type.tileGrass13
                            || type == Tile.Type.tileGrass14
                            || type == Tile.Type.tileGrass15*/

                    )) {
                result = t;
            }
        }
        return result;
    }

    public Tile checkCollisionSideGrass(RectF rectangle) {
        Tile result = null;
        for (int i = 0; i < tilearrayInScreen.size(); i++) {
            Tile t = (Tile) tilearrayInScreen.get(i);
            t.getmRectangle().set(t.getTileX(), t.getTileY(), t.getTileX() + Assets.TILE_SIDE_WIDTH - 10, t.getTileY() + Assets.TILE_SIDE_HEIGHT - 10);
            Tile.Type type = t.getType();
            if (RectF.intersects(rectangle, t.getmRectangle()) &&
                    (type == Tile.Type.tileGrass2 || type == Tile.Type.tileGrass3)) {
                result = t;
            }
        }

        return result;
    }

    public Tile checkCollisionBubble(RectF rectangle) {
        Tile result = null;
        for (int i = 0; i < tilearrayInScreen.size(); i++) {
            Tile t = (Tile) tilearrayInScreen.get(i);
            t.getmRectangle().set(t.getTileX(), t.getTileY(), t.getTileX() + Assets.TILE_SIDE_WIDTH, t.getTileY() + Assets.TILE_SIDE_HEIGHT);
            Tile.Type type = t.getType();
            if (RectF.intersects(rectangle, t.getmRectangle()) &&
                    (type == Tile.Type.bubble1 || type == Tile.Type.bubble2)) {
                result = t;
            }
        }
        return result;
    }

    public Tile checkCollisionTopWater(RectF rectangle) {
        Tile result = null;
        for (int i = 0; i < tilearrayInScreen.size(); i++) {
            Tile t = (Tile) tilearrayInScreen.get(i);
            t.getmRectangle().set(t.getTileX(), t.getTileY(), t.getTileX() + Assets.TILE_SIDE_WIDTH, t.getTileY() + Assets.TILE_SIDE_HEIGHT);
            Tile.Type type = t.getType();
            if (RectF.intersects(rectangle, t.getmRectangle()) &&
                    (type == Tile.Type.waterTop)) {
                result = t;
            }
        }
        return result;
    }


    public int getX() {
        return x;
    }

    public void setX(int x) {
        this.x = x;
    }

    /**
     * Move all Tiles
     */
    public void moveTiles() {
        this.speed = GameScreen.getmBackgroung().getSpeedX() * 4;
        for (int i = 0; i < tilearray.size(); i++) {
            Tile t = (Tile) tilearray.get(i);
            t.setSpeedX(speed);
            t.setTileX(t.getTileX() + t.getSpeedX());
        }


        //Move LevelEnd also
        Assets.RECT_LEVEL_END.offset(speed,0);
        Assets.RECT_LEVEL_END_HOME.offset(speed,0);

    }
    public void stopTiles() {
        this.speed = 0;
        for (int i = 0; i < tilearray.size(); i++) {
            Tile t = (Tile) tilearray.get(i);
            t.setSpeedX(speed);
            t.setTileX(t.getTileX() + t.getSpeedX());
        }


        //Move LevelEnd also
        Assets.RECT_LEVEL_END.offset(speed,0);
        Assets.RECT_LEVEL_END_HOME.offset(speed,0);

    }

    public int getY() {
        return y;
    }

    public void setY(int y) {
        this.y = y;
    }

    public int getSpeed() {
        return speed;
    }

    public void setSpeed(int speed) {
        this.speed = speed;
    }

    public ArrayList<Tile> getTilearray() {
        return tilearray;
    }

    public void setTilearray(ArrayList<Tile> tilearray) {
        this.tilearray = tilearray;
    }

    public ArrayList<Tile> getTilearrayInScreen() {
        return tilearrayInScreen;
    }

}
