package com.HaizStudio.ChakaZulu;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.text.TextPaint;
import android.util.Log;

import com.HaizStudio.framework.Graphics;
import com.HaizStudio.framework.Input;
import com.HaizStudio.framework.Input.TouchEvent;
import com.HaizStudio.framework.Jeu;
import com.HaizStudio.framework.Screen;
import com.HaizStudio.framework.Sound;
import com.HaizStudio.framework.implementation.ImageAndroid;
import com.HaizStudio.framework.implementation.MultiTouchHandler;

import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;

public class GameScreen extends Screen {

    enum EtatDuJeu {
        EnCours, Pret, Pause, GameOver
    }

    EtatDuJeu etat = EtatDuJeu.EnCours;
    public static ArrayList<Enemi> listOfEnemies = new ArrayList<Enemi>();
    private static Background mBackgroung;
    public static Sound clickEnemy, click;
    private Level level1 = new Level(0, 0, 0);
    Paint paint, paint2;
    TextPaint paintTotalRdBob;
    boolean isInWater = false;
    Tile collingTileSideChest;
    Tile collingTileSideFoot;
    Tile collingTile;


    public GameScreen(Jeu game) {
        super(game);

        if (Assets._DEBUG_STICKED)
            Assets.BACKGROUND_SPEED = -3;

        mBackgroung = new Background(0, 0, Assets.BACKGROUND_SPEED);

        //Adding levelEnd
        float positionLevelEnd = 1;//26.5f;
        Assets.RECT_LEVEL_END = Utils.createRectangle(Assets.LEVEL_WIDTH - positionLevelEnd * Assets.WINDOW_WIDTH, 0, Assets.WINDOW_WIDTH, Assets.WINDOW_HEIGHT);
        Assets.RECT_LEVEL_END_HOME = Utils.createRectangle(Assets.LEVEL_WIDTH - positionLevelEnd * Assets.WINDOW_WIDTH + Assets.WINDOW_WIDTH / 20, Assets.WINDOW_HEIGHT - Assets.WINDOW_HEIGHT / 3, Assets.WINDOW_HEIGHT / 3, Assets.WINDOW_HEIGHT / 3);


        //Adding enemies
        int temp = 0;
        for (int i = 0; i < Assets.nbEnnemies; i++) {
            temp += (int) Assets.LEVEL_WIDTH / Assets.nbEnnemies;
            listOfEnemies.add(new Enemi(temp, Assets.WINDOW_HEIGHT - Assets.TILE_SIDE_WIDTH * 3));
            //listOfEnemies.add(new Enemi(temp, 0));  Comming from top
        }

        //Getting sound
        click = Assets.click;
        clickEnemy = Assets.clickEnemy;

        //Loading Map
        loadMap(Starting.map);

        paint = new Paint();
        paint.setTextSize(30);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setAntiAlias(true);
        paint.setColor(Color.WHITE);

        paint2 = new Paint();
        paint2.setTextSize(100);
        paint2.setTextAlign(Paint.Align.CENTER);
        paint2.setAntiAlias(true);
        paint2.setColor(Color.BLACK);


        paintTotalRdBob = new TextPaint();
        paintTotalRdBob.setTextSize(32);
        paintTotalRdBob.setTextAlign(Paint.Align.CENTER);
        paintTotalRdBob.setColor(Color.WHITE);
        paintTotalRdBob.setTypeface(Typeface.create("Arial", Typeface.BOLD));

    }

    /**
     * Loading the tileset map
     *
     * @param path the path
     */
    private void loadMap(String path) {

        ArrayList<String> lignes = new ArrayList<String>();
        int width = 0;
        int height = 0;

        Scanner scanner = new Scanner(path);
        while (scanner.hasNextLine()) {
            String ligne = scanner.nextLine();
            // no more lines to read
            if (ligne == null) {
                break;
            }
            if (!ligne.startsWith("!")) { ///not a comment
                lignes.add(ligne);
                width = Math.max(width, ligne.length());
            }
        }

        height = lignes.size();


        String[][] lines = new String[height][];
        for (int j = 0; j < height; j++) {
            String ligne = (String) lignes.get(j);
            lines[j] = ligne.split(",");
        }


        // width = Math.max(width, numbers.length);
        for (int i = 0; i < width; i++) {
            for (int j = 0; j < height; j++) {
                if (i < lines[j].length) {
                    if (!lines[j][i].equals("")) {

                        int id = Integer.parseInt(lines[j][i]);
                        if (id == -1)
                            id = 0;
                       /* int stepX = id % Assets.TILESET_NUMBER_OF_COLUMN;
                        int stepY = id / Assets.TILESET_NUMBER_OF_COLUMN;


                        //Get the tile from the tilese
                        Bitmap tileImage = Bitmap.createBitmap(
                                ((ImageAndroid) Assets.tileSet).getBitmap(),
                                (int) (stepX * 32),//Assets.TILE_SIDE_WIDTH),
                                (int) (stepY * 32),// Assets.TILE_SIDE_HEIGHT),
                                (int) 32,// Assets.TILE_SIDE_WIDTH,
                                (int) 32);//Assets.TILE_SIDE_HEIGHT);
                        //scale the tile

                        //+1 to add one more pixel since casting to int add spaces between pixels
                       tileImage = Bitmap.createScaledBitmap(tileImage, (int) Assets.TILE_SIDE_WIDTH+1, 1+(int) Assets.TILE_SIDE_HEIGHT, true);
*/
                        Tile t = new Tile(id, i, j, Assets.TILE_SIDE_WIDTH, Assets.TILE_SIDE_HEIGHT, Assets.tiles[id].getBitmap());//Assets.TILE_SIDE_WIDTH, Assets.TILE_SIDE_HEIGHT, tileImage);
                        level1.getTilearray().add(t);
                    }
                }

            }
        }


    }


    @Override
    public void update(float deltaTime) {
        List<TouchEvent> touchEvents = game.getInput().getTouchEvents();
        //Back to the menu is requested from the UI thread, done here on the game thread
        if (backToMenuRequested) {
            nullify();
            goToMainMenuScreen();
            return;
        }
        //One state per update: a tap that pauses the game must not also resume it
        if (etat == EtatDuJeu.Pret)
            updateReady(touchEvents);
        else if (etat == EtatDuJeu.EnCours)
            updateRunning(touchEvents, game.getInput(), deltaTime);
        else if (etat == EtatDuJeu.Pause)
            updatePaused(touchEvents);
        else if (etat == EtatDuJeu.GameOver)
            updateGameOver(touchEvents);
    }


    /**
     * The game begins when the user click on the screen
     * Then one  changes the state to EtatDuJeu.EnCours
     *
     * @param touchEvents
     */
    private void updateReady(List<TouchEvent> touchEvents) {
        if (touchEvents.size() > 0)
            etat = EtatDuJeu.EnCours;
    }

    /**
     * The main running function of the game
     *
     * @param touchEvents
     * @param input
     * @param deltaTime
     */
    private void updateRunning(List<TouchEvent> touchEvents, Input input, float deltaTime) {

        //Pause button (top right). Touch events are in 960x640 game units, RECT_PAUSE in screen pixels.
        RectF pauseArea = new RectF(Assets.RECT_PAUSE.left / Assets.scaleX, Assets.RECT_PAUSE.top / Assets.scaleY,
                Assets.RECT_PAUSE.right / Assets.scaleX, Assets.RECT_PAUSE.bottom / Assets.scaleY);
        pauseArea.inset(-32, -32);
        for (TouchEvent event : touchEvents) {
            if (event.type == TouchEvent.TOUCH_UP && Utils.inBounds(event, pauseArea)) {
                input.isShootRequested(); // this tap is not a shot
                pause();
                return;
            }
        }

        //Handling the swipe behaviour
        MultiTouchHandler.Direction swipeDirection = input.getSwipeDirection();
        if (swipeDirection != null) {
            switch (swipeDirection) {
                case down:
                    if (Assets.Panoramic.isSticked) {
                        //Panoramic descends
                        Assets.Panoramic.isSticked = false;
                        float temp = Assets.Panoramic.getCenterY();
                        Assets.Panoramic.setCenterY(++temp);

                    } else {
                        Assets.PanoramicCurrentAnimation = Assets.PanoramicAnimationAccroupi;
                        Assets.Panoramic.setBaisse(true);
                        //Assets.Panoramic.setSpeedX(0);
                    }
                    break;

                case up:
                    Assets.Panoramic.sauter();
                    isInWater = false;  // When Panoramic is fallen in water and it jumps, rescue him
                    // PanoramicCurrentImage = PanoramicAnimationNormal.getImage();
                    Assets.Panoramic.setIsColliding_bottom(false); //We assume that whenever panoramic jumps, ther is no collision
                    break;

                case left:
                    //TODO
                    break;


                case right:
                    Assets.Panoramic.allerADroite();
                    break;
                case longUp:
                    // Assets.Panoramic.collerHaut();
                    // PanoramicCurrentImage = PanoramicAnimationNormal.getImage();

                    break;
            }
        }

        //Handling Shoot: Check if user has clicked
        if (input.isShootRequested()) {
            Assets.Panoramic.shoot();
        }

        updateProjectiles();
        updatePanoramic();
        updateBackground();
        updateTiles();
        updateAllEnemies(listOfEnemies);
        checkCollisions();
        animate();


    }


    private void updateProjectiles() {
        ArrayList<Projectile> projectiles = Assets.Panoramic.getProjectiles();
        for (int i = 0; i < projectiles.size(); i++) {
            Projectile p = (Projectile) projectiles.get(i);
            if (p.isVisible() == true) {
                p.update();
            } else {
                projectiles.remove(i);
            }
        }
    }

    private void updatePanoramic() {
        Assets.Panoramic.update();
        if (Assets.Panoramic.isJumping()) {
            Assets.PanoramicCurrentAnimation = Assets.PanoramicAnimationJumped;
        } else if (Assets.Panoramic.isSticked) {
            Assets.PanoramicCurrentAnimation = Assets.PanoramicAnimationSticked;
        } else if (Assets.Panoramic.isJumping() == false && Assets.Panoramic.isBaisse() == false && Assets.Panoramic.isSticked == false) {
            Assets.PanoramicCurrentAnimation = Assets.PanoramicAnimationNormal;
        }
        //Panoramic falls in a hole
        if (Assets.Panoramic.fallen()) {
            etat = EtatDuJeu.GameOver;
        }
    }

    private void updateBackground() {
        mBackgroung.update();
    }

    private void updateTiles() {

        if (Assets.NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH_COUNTER % Assets.NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH == 0) {
            Assets.Panoramic.setIsCovered(false);
            Assets.NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH_COUNTER = 0;
        }

        //update and get The visible Tiles
        level1.updateTilearrayInScreen();
    }

    private void checkCollisions() {

        //Checking top grass collision Actor
        collingTile = level1.checkCollisionTopGrass(Assets.Panoramic.rectBody);
        if (collingTile != null) { //Collision detected
            Assets.Panoramic.setSaute(false);
            Assets.Panoramic.setSpeedY(0);
            Assets.Panoramic.setCenterY(collingTile.getTileY() - Assets.Panoramic.height / 2);
            Assets.Panoramic.setIsColliding_bottom(true);
        } else {
            Assets.Panoramic.setIsColliding_bottom(false);
        }

        if (Assets._DEBUG_STICKED)
            Assets.Panoramic.collerHaut();


        //Checking side grass collision Actor
        collingTileSideChest = level1.checkCollisionSideGrass(Assets.Panoramic.rectHautCorps);
        collingTileSideFoot = level1.checkCollisionSideGrass(Assets.Panoramic.rectBasCorps);
        if (collingTileSideChest != null || collingTileSideFoot != null) {
            //Collision detected
            // Assets.Panoramic.setCenterX(collingTileSide.getTileX());
            //Assets.Panoramic.setSpeedX(0);
            level1.stopTiles();
            GameScreen.getmBackgroung().setSpeedX(0);
            Assets.Panoramic.setIsColliding_right(true);


        } else if (Assets.RECT_LEVEL_END.right + 2 * Assets.BACKGROUND_SPEED <= Assets.WINDOW_WIDTH) {  // Assets.BACKGROUND_SPEED because there is a translation of delta  +Assets.BACKGROUND_SPEED
            //Block screen
            GameScreen.getmBackgroung().setSpeedX(0);
            //Actor keeps running
            Assets.Panoramic.allerADroite();
        } else {
            Assets.Panoramic.setIsColliding_right(false);

            //Move Level
            //level1.setX(level1.getX() + GameScreen.getmBackgroung().getSpeedX() * 1);
            //Move Tiles
            level1.moveTiles();
            //Move Background
            GameScreen.getmBackgroung().setSpeedX(Assets.BACKGROUND_SPEED);
        }


        //Checking water collision Actor
        Tile collisionWithWater = level1.checkCollisionTopWater(Assets.Panoramic.rectBody);
        if (collisionWithWater != null) { //Collision detected
            if (collisionWithWater.getmRectangle().left <= Assets.Panoramic.rectBody.right - 10)
                isInWater = true;

        }


        //Check red Bob collision with actor
        Tile bubble = level1.checkCollisionBubble(Assets.Panoramic.rectBody);
        if (bubble != null) {// && !isInWater) { //Collision detected
            level1.removeTile(bubble);
            Assets.TOTAL_RED_BOB++;
            Assets.Panoramic.setIsCovered(true);
        } else {
            Assets.NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH_COUNTER++;
        }

        //Checking side grass collision Fire
        ArrayList<Projectile> projectiles = Assets.Panoramic.getProjectiles();
        for (int i = 0; i < projectiles.size(); i++) {
            Projectile p = (Projectile) projectiles.get(i);
            if (p.isVisible() == true) {
                Tile collingTile = level1.checkCollisionSideGrass(new RectF(p.getX(), p.getY(), p.getX() + Assets.RECT_FIRE.width(), p.getY() + Assets.RECT_FIRE.height()));
                if (collingTile != null) {
                    projectiles.remove(i);
                }
            }
        }
    }

    private void updateAllEnemies(ArrayList<Enemi> list) {
        ArrayList<Enemi> toRemove = new ArrayList<>();


        for (Enemi e : listOfEnemies) {
            //Handle collision only if it is in screen
            if (inScreen(e.getRectangle())) {

                //Checking top grass collision Enemy
                Tile tile = level1.checkCollisionTopGrass(e.getRectangle());
                if (tile != null) { //Collision detected
                    e.setSpeedY(0);
                    e.setCenterY(tile.getmRectangle().top - e.height / 2);
                }


                //Checking side grass collision Enemy
                tile = level1.checkCollisionSideGrass(e.getRectangle());
                if (tile != null) { //Collision detected
                    e.setCenterX(tile.getmRectangle().right + e.width);
                    e.setSpeedY(Assets.EnemyJumpSpeed);
                }

                //Checking water collision Enemy
                //And stop him
               /* tile = level1.checkCollisionTopWater(e.getRectangle());
                if (tile != null) { //Collision detected
                    e.setCenterX(tile.getmRectangle().right + e.width);
                    e.isGoingBack = true;
                    e.setSpeedY(0);
                }

*/
                if (e.getRectangle().right < 0 || e.getRectangle().top > Assets.WINDOW_HEIGHT) //Save enemis if they are no longer in the screen
                    toRemove.add(e);
                else {

                    e.setSpeedX(level1.getSpeed());                        //Normal behavior
                    e.update();
                }

                //Check ennemy collision with actor
                if (Assets.Panoramic.isCollidingWith(e) && !e.hasTouchedPanoramicOnce) {
                    GameScreen.clickEnemy.play(5);
                    e.hasTouchedPanoramicOnce = true;
                    //Draw LifePan
                    switch (Assets.lifePanState) {
                        case lifePan1:
                            etat = EtatDuJeu.GameOver;
                            Assets.lifePanState = Assets.LifePanState.lifePan3;
                            break;
                        case lifePan2:
                            Assets.lifePanState = Assets.LifePanState.lifePan1;
                            break;
                        case lifePan3:
                            //Game over
                            Assets.lifePanState = Assets.LifePanState.lifePan2;
                            break;
                    }

                }

            } else {
                //Move it in x-axis according to the level

                e.moveLeft(level1.getSpeed()); //Normal behavior

            }


        }


        //then remove them
        for (Enemi e : toRemove) {
            list.remove(e);
        }
        toRemove.clear();


    }

    public void animate() {
        Assets.PanoramicAnimationNormal.update(10);
        Assets.PanoramicAnimationJumped.update(10);
        Assets.PanoramicAnimationSticked.update(10);
        Assets.enemiAnimation.update(50);
        Assets.enemiAnimationDied.update(50);
        Assets.bubbleAnimation.update(10);
        Assets.dustAnimation.update(150);
        Assets.coverAnimation.update(50);
        Assets.fireAnimation.update(50);
    }


    /**
     * Paused: any tap continues the game (the back button goes to the menu).
     */
    private void updatePaused(List<TouchEvent> touchEvents) {
        for (TouchEvent event : touchEvents) {
            if (event.type == TouchEvent.TOUCH_UP) {
                game.getInput().isShootRequested(); // this tap is not a shot
                etat = EtatDuJeu.EnCours;
                return;
            }
        }
    }

    private void updateGameOver(List<TouchEvent> touchEvents) { // /mod
        Assets.gameOverStarAnimation.update(15);
        Assets.gameOverBackGgroundAnimation.update(15);

        //Ignore taps during the first second, so a player still tapping does not skip the screen
        if (gameOverSince == 0)
            gameOverSince = System.currentTimeMillis();
        if (System.currentTimeMillis() - gameOverSince < 1000)
            return;

        for (TouchEvent event : touchEvents) {
            if (event.type == TouchEvent.TOUCH_DOWN) {
                //Interstitial ad every few game overs, when leaving the game over screen
                Assets.ADS_SHOW_AFTER_X_GAMEOVER_COUNTER++;
                if (Assets.ADS_SHOW_AFTER_X_GAMEOVER_COUNTER >= Assets.ADS_SHOW_AFTER_X_GAMEOVER) {
                    Assets.ADS_SHOW_AFTER_X_GAMEOVER_COUNTER = 0;
                    game.showInterstitial();
                }
                nullify();
                goToMainMenuScreen();
                return;
            }
        }
    }

    private long gameOverSince = 0;

    private void nullify() {
        // Set all variables to null. You will be recreating them in the
        // constructor.
        paint = null;
        paint2 = null;
        mBackgroung = null;
        Assets.Panoramic = null;
        listOfEnemies.clear();
        Assets.reset();
        // Call garbage collector to clean up memory.
        System.gc();
        // runfinalizesonexit(true);

    }

    private void goToMainMenuScreen() {
        game.setScreen(new MainMenuScreen(game));
    }


    @Override
    public void paint(float deltaTime) {


    }

    @Override
    public void paintNew(float deltaTime, Canvas canvas) {
        //if (etat == EtatDuJeu.Pret)
        //drawReadyUI(canvas);
        //else
        if (etat == EtatDuJeu.EnCours)
            drawRunningUI(deltaTime, canvas);
        else if (etat == EtatDuJeu.Pause) {
            drawRunningUI(deltaTime, canvas);  //Frozen game behind
            drawPausedUI(canvas);
        }
        else if (etat == EtatDuJeu.GameOver) {
            // drawRunningUI(canvas);  //Draw running UI behind
            drawGameOverUI(canvas);
        }
    }

    /**
     * Function to draw the tileSet
     *
     * @param g
     */
    private void paintTiles(float deltaTime, Graphics g) {


        //Paint Level End
        g.drawImage(Assets.levelEndHome, Assets.RECT_LEVEL_END_HOME);
        //g.drawImage(Assets.levelEnd1, Assets.RECT_LEVEL_END);


        for (int i = 0; i < level1.getTilearrayInScreen().size(); i++) {
            Tile t = (Tile) level1.getTilearrayInScreen().get(i);

            float x = t.getTileX() + t.getSpeedX() * deltaTime;
            //Log.i("Speed: ",  " " + t.getSpeedX());            //Draw bubble
            if (t.getType() == Tile.Type.bubble1) {

                g.drawImage(Assets.bubbleAnimation.getImage(), x, t.getTileY());

            } else if (t.getType() != Tile.Type.none) {
                {
                    //int stepX = t.getId() % Assets.TILESET_NUMBER_OF_COLUMN;
                    //int stepY = t.getId() / Assets.TILESET_NUMBER_OF_COLUMN;
                    //g.drawImage(Assets.tileSet, t.getTileX(), t.getTileY(), stepX * Assets.TILE_SIDE_WIDTH, stepY * Assets.TILE_SIDE_HEIGHT, Assets.TILE_SIDE_WIDTH, Assets.TILE_SIDE_HEIGHT);

                    g.drawImage(new ImageAndroid(t.bitmap, Graphics.ImageFormat.ARGB8888), x, t.getTileY());
                }
            }
        }


    }


    public void animateGameOver() {
        Assets.gameOverStarAnimation.update(50);
    }


    private void drawReadyUI() {
        Graphics g = game.getGraphics();

        g.drawARGB(155, 0, 0, 0);
        g.drawString("Click to play", 400, 240, paint);

    }


    private void drawRunningUI(float deltaTime, Canvas canvas) {
        Graphics g = game.getGraphics();
        g.setCanvas(canvas);
        g.clearScreen(Color.BLACK);
        paintBackground(deltaTime, g);
        paintProjectiles(g);
        paintTiles(deltaTime, g);

        g.drawImage(Assets.levelEnd1, Assets.RECT_LEVEL_END);
        paintPanoramic(g);
        g.drawImage(Assets.levelEnd2, Assets.RECT_LEVEL_END);
        paintEnemies(g);
        paintOtherUIElements(g);

    }


    private void paintBackground(float deltaTime, Graphics g) {

        float x = mBackgroung.getBgX() + mBackgroung.getSpeedX() * deltaTime;
        //float delta = (lastX - x);

        //if (delta != 0)
        //  Log.i("lastX: ", " " + delta);
        g.drawImage(Assets.background, x, mBackgroung.getBgY());
        //lastX = x;
    }

    private void paintProjectiles(Graphics g) {
        //Paint Projectiles
        ArrayList<Projectile> projectiles = Assets.Panoramic.getProjectiles();
        for (int i = 0; i < projectiles.size(); i++) {
            Projectile p = (Projectile) projectiles.get(i);
            if (Assets._DEBUG)
                g.drawRect(p.getX(), p.getY(), Assets.RECT_FIRE.width(), Assets.RECT_FIRE.height(), Color.YELLOW);
            g.drawImage(Assets.fireAnimation.getImage(), p.getX(), p.getY());

        }

    }

    private void paintPanoramic(Graphics g) {
        if (Assets._DEBUG) {
            g.drawRect(Actor.rectBody, Color.YELLOW);
            g.drawRect(Actor.rectHautCorps, Color.BLUE);
            g.drawRect(Actor.rectBasCorps, Color.RED);
        }

        //Paint Panoramic and maybe dust
        g.drawImage(Assets.PanoramicCurrentAnimation.getImage(), Assets.Panoramic.getCenterX() - Assets.Panoramic.width / 2, Assets.Panoramic.getCenterY() - Assets.Panoramic.height / 2 + Actor.tileAndFeetShading);
        if (Assets.Panoramic.isColliding_bottom) {
            g.drawImage(Assets.dustAnimation.getImage(), Assets.Panoramic.rectDust);
            if (Assets._DEBUG) {
                g.drawRect(collingTile.getRect(), Color.RED);
            }
        }
        if (Assets.Panoramic.isColliding_right) {

            if (Assets._DEBUG) {
                g.drawRect(Actor.rectBasCorps, Color.GREEN);
                if (collingTileSideFoot != null)
                    g.drawRect(collingTileSideFoot.getRect(), Color.BLUE);
                if (collingTileSideChest != null)
                    g.drawRect(collingTileSideChest.getRect(), Color.BLACK);

            }
        }
        if (Assets.Panoramic.isCovered) {
            g.drawImage(Assets.coverAnimation.getImage(), Assets.Panoramic.rectGlobal);
        }


        //Draw yellow line on top
        if (Assets.Panoramic.isSticked)
            g.drawRect(Assets.Panoramic.getCenterX() - Assets.Panoramic.width / 2, Assets.Panoramic.getCenterY(), Assets.Panoramic.width, Assets.Panoramic.height / 10, Color.YELLOW);


    }

    private void paintEnemies(Graphics g) {
        if (Assets._DEBUG)
            for (Enemy e : listOfEnemies)
                g.drawRect(e.getRectangle(), Color.YELLOW);

        for (Enemi e : listOfEnemies) {
            if (!e.isTouched) {
                g.drawImage(Assets.enemiAnimation.getImage(), e.getRectangle());
            } else {
                g.drawImage(Assets.enemiAnimationDied.getImage(), e.getRectangle());
            }
        }
    }

    private void paintOtherUIElements(Graphics g) {
        //Draw shooting button
        g.fillCircle((int) Assets.RECT_SHOOTING_BUTTON.left, (int) Assets.RECT_SHOOTING_BUTTON.top, (int) Assets.RECT_SHOOTING_BUTTON.width(), Color.argb(150, 255, 255, 255));
        g.drawCircle((int) Assets.RECT_SHOOTING_BUTTON.left, (int) Assets.RECT_SHOOTING_BUTTON.top, (int) Assets.RECT_SHOOTING_BUTTON.width() + 10, Color.argb(150, 255, 255, 255));
        //Draw Pause
        g.drawImage(Assets.pause, Assets.RECT_PAUSE);


        //Draw TOTAL obtained red bob
        float textWidth = paintTotalRdBob.measureText(Integer.toString(Assets.TOTAL_RED_BOB));
        String cross = " x ";
        float crossWidth = paintTotalRdBob.measureText(cross);
        Assets.RECT_RED_BOB_TEXT_VALUE.set((int) (Assets.RECT_RED_BOB_IMAGE_SCORE.left - textWidth - crossWidth - 1), Assets.RECT_RED_BOB_IMAGE_SCORE.top, (int) (Assets.RECT_RED_BOB_IMAGE_SCORE.left - crossWidth), Assets.RECT_RED_BOB_IMAGE_SCORE.bottom);
        Assets.RECT_RED_BOB_TEXT_CROSS.set((int) (Assets.RECT_RED_BOB_IMAGE_SCORE.left - crossWidth - 1), Assets.RECT_RED_BOB_IMAGE_SCORE.top, (int) (Assets.RECT_RED_BOB_IMAGE_SCORE.left), Assets.RECT_RED_BOB_IMAGE_SCORE.bottom);
        if (Assets._DEBUG) {
            g.drawRect(Assets.RECT_RED_BOB_IMAGE_SCORE, Color.YELLOW);
            g.drawRect(Assets.RECT_RED_BOB_TEXT_VALUE, Color.RED);
            g.drawRect(Assets.RECT_RED_BOB_TEXT_CROSS, Color.BLUE);
        }
        g.drawImage(Assets.bubble1, Assets.RECT_RED_BOB_IMAGE_SCORE);
        g.drawString(Integer.toString(Assets.TOTAL_RED_BOB), Assets.RECT_RED_BOB_TEXT_VALUE, paintTotalRdBob);
        g.drawString(cross, Assets.RECT_RED_BOB_TEXT_CROSS, paintTotalRdBob);

        //Draw LifePan
        switch (Assets.lifePanState) {
            case lifePan1:
                g.drawImage(Assets.lifePan1, Assets.RECT_LIFEPAN);
                break;
            case lifePan2:
                g.drawImage(Assets.lifePan2, Assets.RECT_LIFEPAN);
                break;
            case lifePan3:
                g.drawImage(Assets.lifePan3, Assets.RECT_LIFEPAN);
                break;
        }

    }


    private void drawPausedUI(Canvas canvas) {
        Graphics g = game.getGraphics();
        g.setCanvas(canvas);
        // Darken the entire screen so you can display the Paused screen.
        g.drawARGB(155, 0, 0, 0);
        paint2.setColor(Color.WHITE);
        paint2.setTextSize(Assets.WINDOW_HEIGHT / 8);
        paint.setTextSize(Assets.WINDOW_HEIGHT / 18);
        g.drawString("Pause", (int) Assets.WINDOW_WIDTH / 2, (int) (Assets.WINDOW_HEIGHT * 0.45f), paint2);
        g.drawString("Tap to continue", (int) Assets.WINDOW_WIDTH / 2, (int) (Assets.WINDOW_HEIGHT * 0.6f), paint);
    }


    private void drawGameOverUI(Canvas canvas) {
        float marginHeight = Assets.WINDOW_HEIGHT / 10;
        Graphics g = game.getGraphics();
        g.setCanvas(canvas);

        //gameOver BackGground
        g.drawImage(Assets.gameOverBackGgroundAnimation.getImage(), 0, 0);

        //gameOver Stars
        g.drawImage(Assets.gameOverStarAnimation.getImage(), Assets.WINDOW_WIDTH / 10, Assets.WINDOW_HEIGHT / 10);
        g.drawImage(Assets.gameOverStarAnimation.getImage(), 8 * Assets.WINDOW_WIDTH / 10, 0 * Assets.WINDOW_HEIGHT / 10);
        g.drawImage(Assets.gameOverStarAnimation.getImage(), Assets.WINDOW_WIDTH / 10, 8 * Assets.WINDOW_HEIGHT / 10);
        g.drawImage(Assets.gameOverStarAnimation.getImage(), 7 * Assets.WINDOW_WIDTH / 10, 9 * Assets.WINDOW_HEIGHT / 10);

        //gameOver Rope
        int marginLeft = (int) Assets.WINDOW_WIDTH / 20;
        g.drawImage(Assets.gameOverStarRope, Assets.WINDOW_WIDTH - Assets.RECT_GAMEOVER_ROPE.width() - marginLeft, 0);

        //g.drawRect(0, 0, Assets.WINDOW_WIDTH+1, Assets.WINDOW_HEIGHT+1, Color.WHITE);
        //g.drawString("GAME OVER", (int)Assets.WINDOW_WIDTH/2, (int)Assets.WINDOW_HEIGHT/2, paint2);
        //g.drawString("Tap to restart", (int)Assets.WINDOW_WIDTH/2, (int)(Assets.WINDOW_HEIGHT/2 +marginHeight), paint);

    }

    @Override
    public void pause() {
        if (etat == EtatDuJeu.EnCours)
            etat = EtatDuJeu.Pause;

    }

    /**
     * Back in the app: stay on the pause screen until the player taps.
     */
    @Override
    public void resume() {
    }

    @Override
    public void dispose() {

    }

    @Override
    public void backButton() {
        if (etat == EtatDuJeu.EnCours)
            pause();
        else
            backToMenuRequested = true;
    }

    private volatile boolean backToMenuRequested = false;

    public static boolean inScreen(RectF r) {
        return r.intersect(new RectF(0, 0, Assets.WINDOW_WIDTH, Assets.WINDOW_HEIGHT));

    }

    public static Background getmBackgroung() {
        return mBackgroung;
    }

    public static Actor getPanoramic() {
        return Assets.Panoramic;
    }


}
