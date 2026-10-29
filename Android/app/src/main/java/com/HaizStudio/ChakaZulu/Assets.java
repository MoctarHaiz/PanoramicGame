/**
 * This Class contains all assets NAMES ( resources ) used further in this game
 * <p>
 * -Never create in Paint()
 */


package com.HaizStudio.ChakaZulu;

import android.graphics.RectF;
import android.os.Handler;
import android.os.Looper;

import com.HaizStudio.framework.Image;
import com.HaizStudio.framework.Music;
import com.HaizStudio.framework.Sound;

import java.util.ArrayList;


public class Assets {
    public static boolean _DEBUG = false;
    public static boolean _DEBUG_STICKED = false; //To stick Actor to the top, to see all the level for instance

    public static float LEVEL_NB_TILES_WIDTH = 800;
    public static float LEVEL_NB_TILES_HEIGHT = 20;
    public static float LEVEL_WIDTH;
    public static float LEVEL_HEIGHT;

    public static int spashScreenTime = 500;
    public static Handler mWaitHandler = new Handler(Looper.getMainLooper());
    public static float TILE_SIDE_WIDTH = 32;
    public static float TILE_SIDE_HEIGHT = 32;
    public static float WINDOW_WIDTH = TILE_SIDE_WIDTH * 30;//960=32*30;  Faux //32 is the tiles' side size
    public static float WINDOW_HEIGHT = TILE_SIDE_HEIGHT * 20;//480=32*20;
    public static int TILESET_NUMBER_OF_COLUMN = 12; //There are 12 tiles by row.
    public static int TILESET_NUMBER_OF_ROWS = 8; //There are 8 tiles by col.
    public static RectF RECT_BACKGROUND = Utils.createRectangle(0, 0, 16000, (int) (WINDOW_HEIGHT)); //16000 is the width of the backgroung image
    //tileSetpublic static RectF RECT_TILESET = Utils.createRectangle(0, 0, (int) (TILESET_NUMBER_OF_COLUMN * TILE_SIDE_WIDTH), (int) (TILESET_NUMBER_OF_ROWS * TILE_SIDE_HEIGHT));
    //  public static RectF RECT_MENU = Utils.createRectangle((int) (WINDOW_WIDTH / 8), (int) (WINDOW_HEIGHT / 2), (int) (WINDOW_HEIGHT) / 4, (int) (WINDOW_HEIGHT / 4));  //The position of the menu ( the Play button )
    public static RectF RECT_LIFEPAN = Utils.createRectangle((int) (WINDOW_WIDTH / 15), (int) (WINDOW_HEIGHT / 15), 92, 32);  //The position of the lifePan
    public static RectF RECT_GAMEOVER_STAR1 = Utils.createRectangle(0, 0, 79, 76);  //The position of the lifePan
    public static RectF RECT_GAMEOVER_STAR2 = Utils.createRectangle(0, 0, 80, 77);  //The position of the lifePan
    public static RectF RECT_GAMEOVER_STAR3 = Utils.createRectangle(0, 0, 82, 78);  //The position of the lifePan
    public static RectF RECT_GAMEOVER_STAR4 = Utils.createRectangle(0, 0, 83, 79);  //The position of the lifePan
    public static RectF RECT_GAMEOVER_STAR5 = Utils.createRectangle(0, 0, 84, 80);  //The position of the lifePan
    public static RectF RECT_GAMEOVER_ROPE = Utils.createRectangle(0, 0, 250, 500);  //The position of the lifePan

    public static RectF RECT_LEVEL_END;// = Utils.createRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
    public static RectF RECT_LEVEL_END_HOME;// = Utils.createRectangle(0, WINDOW_HEIGHT -WINDOW_HEIGHT/3, WINDOW_HEIGHT/3,WINDOW_HEIGHT/3);

    public static RectF RECT_PAUSE = Utils.createRectangle((int) (WINDOW_WIDTH - TILE_SIDE_WIDTH * 2), (int) (TILE_SIDE_HEIGHT), (int) (TILE_SIDE_WIDTH), (int) (TILE_SIDE_HEIGHT));  //The position of the Pause button
    public static RectF RECT_RED_BOB_IMAGE_SCORE = Utils.createRectangle((int) (WINDOW_WIDTH - TILE_SIDE_WIDTH * 4), (int) (TILE_SIDE_HEIGHT), (int) (TILE_SIDE_WIDTH), (int) (TILE_SIDE_HEIGHT));  //The position of total red Bob image
    public static RectF RECT_RED_BOB_TEXT_VALUE = Utils.createRectangle((int) (WINDOW_WIDTH - TILE_SIDE_WIDTH * 5), (int) (TILE_SIDE_HEIGHT * 2), (int) (TILE_SIDE_WIDTH), (int) (TILE_SIDE_HEIGHT));  //The position of total red Bob text
    public static RectF RECT_RED_BOB_TEXT_CROSS = Utils.createRectangle((int) (WINDOW_WIDTH - TILE_SIDE_WIDTH * 5), (int) (TILE_SIDE_HEIGHT), (int) (TILE_SIDE_WIDTH), (int) (TILE_SIDE_HEIGHT));  //The position of total red Bob text

    public static RectF RECT_RED_BOB_IMAGE_TO_TOUCH = Utils.createRectangle(0, 0, (int) (TILE_SIDE_WIDTH), (int) (TILE_SIDE_HEIGHT));  //The position of total red Bob image
    public static RectF RECT_SPLASH = Utils.createRectangle(0, 0, (int) (WINDOW_WIDTH), (int) (WINDOW_HEIGHT));
    public static RectF RECT_GAMEOVER_BACKGROUND1 = Utils.createRectangle(0, 0, (int) (WINDOW_WIDTH), (int) (WINDOW_HEIGHT));
    public static RectF RECT_GAMEOVER_BACKGROUND2 = Utils.createRectangle(0, 0, (int) (WINDOW_WIDTH) + 2, (int) (WINDOW_HEIGHT) + 2);
    public static RectF RECT_GAMEOVER_BACKGROUND3 = Utils.createRectangle(0, 0, (int) (WINDOW_WIDTH) + 4, (int) (WINDOW_HEIGHT) + 4);

    public static RectF RECT_SHOOTING_BUTTON = Utils.createRectangle((int) (7 * WINDOW_WIDTH / 8), (int) (3 * WINDOW_HEIGHT / 4), 30, 30);
    public static int TOTAL_RED_BOB = 0;
    public static int NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH = 10;
    public static int NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH_COUNTER = 0;
    public static boolean showCover = false;
    public static int BACKGROUND_SPEED = -2;

    //Ads: an interstitial every few game overs
    public static int ADS_SHOW_AFTER_X_GAMEOVER = 3;
    public static int ADS_SHOW_AFTER_X_GAMEOVER_COUNTER = 0;


    public static int nbEnnemies = 50;
    public static int EnemyPesanteur = 4;
    public static int EnemyJumpSpeed = -10;
    public static float scaleY, scaleX;
    private static boolean graphicsScaled = false;

    public static Animation
            PanoramicCurrentAnimation,
            PanoramicAnimationNormal,
            PanoramicAnimationSticked,
            PanoramicAnimationJumped,
            PanoramicAnimationAccroupi,
            enemiAnimation,
            enemiAnimationDied,
            fireAnimation,
            bubbleAnimation,
            dustAnimation,
            coverAnimation,
            gameOverStarAnimation,
            gameOverBackGgroundAnimation;
    private static double reducePanoramicBy = 2;
    public static RectF RECT_PANORAMIC = Utils.createRectangle(0, 0, (int) (WINDOW_WIDTH / 7.5 / reducePanoramicBy), (int) (WINDOW_HEIGHT / 2.5 / reducePanoramicBy)); //Image:128*192
    public static RectF RECT_FIRE = Utils.createRectangle(0, 0, RECT_PANORAMIC.width() / 5, RECT_PANORAMIC.width() / 5);  //The size of the fire
    public static RectF RECT_DUST = Utils.createRectangle(0, 0, RECT_PANORAMIC.width(), RECT_PANORAMIC.width()); //The dust under Panoramic
    public static Actor Panoramic;

    public enum LifePanState {
        lifePan1,
        lifePan2,
        lifePan3
    }

    public static int MAX_TILE_ID = 95 + 1;//+1 to consider The first which id is 0
    public static Image tiles[] = new Image[MAX_TILE_ID];


    public static LifePanState lifePanState = LifePanState.lifePan3;

    public enum BubbleState {
        bubble1,
        bubble2,
    }

    public static BubbleState bubbleState = BubbleState.bubble1;

    /**
     * Panoramic Assets
     */
    static ArrayList<Image> personnage = new ArrayList<>(), personnageSaute = new ArrayList<>(), personnageSticked = new ArrayList<>();
    public static Image
            menu,
            gameOver1, gameOver2, gameOver3,
            levelEnd1, levelEnd2, levelEndHome,
            splash,
            background,
            personnageAccroupi,
            enemi1, enemi2, enemi3, enemi4, enemi5, enemi6, enemi7, enemi8, enemi9, enemi10,
            enemiMort1, enemiMort2, enemiMort3, enemiMort4, enemiMort5, enemiMort6, enemiMort7, enemiMort8, enemiMort9, enemiMort10,
            lifePan1, lifePan2, lifePan3,
            bubble1, bubble2,
            pause,
            dust1, dust2, dust3, dust4,
            cover1, cover2, cover3, cover4, cover5, cover6, cover7, cover8,
            gameOverStarRope;

    /**
     * TileSet Assets
     */
    public static Image tileSet;
    public static Sound clickEnemy, click;
    public static Music theme;
    public static Image m1, m2, m3, m4;

    public static void load(Starting debutJeu) {

        theme = debutJeu.getAudio().createMusic("audio/chaka.mp3");
        theme.setLooping(true);
        theme.setVolume(0.5f);
        theme.play();

    }

    public static void reset() {

        TOTAL_RED_BOB = 0;
        NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH = 10;
        NUMBER_OF_UPDATE_FORM_LAST_REDBOB_TOUCH_COUNTER = 0;
        showCover = false;
        EnemyPesanteur = 4;
        EnemyJumpSpeed = -10;
        lifePanState = LifePanState.lifePan3;
        bubbleState = BubbleState.bubble1;

        Panoramic = new Actor(RECT_PANORAMIC.width(), RECT_PANORAMIC.height(),-(int) Assets.WINDOW_HEIGHT / 20,-(int) Assets.WINDOW_HEIGHT / 10);


    }

    /**
     * Rescale graphics according to the device resolution
     */
    public static void reScaleGraphics(float scaleX, float scaleY) {
        // Android can recreate the activity while these static values survive: scale only once.
        if (graphicsScaled) {
            Panoramic = new Actor(RECT_PANORAMIC.width(), RECT_PANORAMIC.height(), -(int) Assets.WINDOW_HEIGHT / 20, -(int) Assets.WINDOW_HEIGHT / 10);
            return;
        }
        graphicsScaled = true;

        Assets.scaleX = scaleX;
        Assets.scaleY = scaleY;
        Assets.WINDOW_WIDTH *= scaleX;
        Assets.WINDOW_HEIGHT *= scaleY;
        Assets.TILE_SIDE_WIDTH *= scaleX;
        Assets.TILE_SIDE_HEIGHT *= scaleY;
        //Utils.scale(Assets.RECT_TILESET, scaleX, scaleY);
        Utils.scale(Assets.RECT_SHOOTING_BUTTON, scaleX, scaleY);
        Utils.scale(Assets.RECT_PANORAMIC, scaleX, scaleY);
        Utils.scale(Assets.RECT_DUST, scaleX, scaleY);
        Utils.scale(Assets.RECT_SPLASH, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_BACKGROUND1, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_BACKGROUND2, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_BACKGROUND3, scaleX, scaleY);
        Utils.scale(Assets.RECT_FIRE, scaleX, scaleY);
        Utils.scale(Assets.RECT_LIFEPAN, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_STAR1, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_STAR2, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_STAR3, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_STAR4, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_STAR5, scaleX, scaleY);
        Utils.scale(Assets.RECT_GAMEOVER_ROPE, scaleX, scaleY);
        Utils.scale(Assets.RECT_RED_BOB_TEXT_VALUE, scaleX, scaleY);
        Utils.scale(Assets.RECT_PAUSE, scaleX, scaleY);
        Utils.scale(Assets.RECT_RED_BOB_IMAGE_SCORE, scaleX, scaleY);
        Utils.scale(Assets.RECT_RED_BOB_IMAGE_TO_TOUCH, scaleX, scaleY);
        Utils.scale(Assets.RECT_BACKGROUND, scaleX, scaleY);
        Utils.scale(Assets.RECT_RED_BOB_TEXT_CROSS, scaleX, scaleY);
        //Utils.scale(Assets.RECT_MENU, Math.max(scaleX, scaleY), Math.max(scaleX, scaleY));


        LEVEL_WIDTH = LEVEL_NB_TILES_WIDTH * Assets.TILE_SIDE_WIDTH;
        LEVEL_HEIGHT = LEVEL_NB_TILES_HEIGHT * Assets.TILE_SIDE_HEIGHT;
        RECT_LEVEL_END = Utils.createRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
        RECT_LEVEL_END_HOME = Utils.createRectangle(0, 0, WINDOW_HEIGHT / 3, WINDOW_HEIGHT / 3);
        //Utils.scale(Assets.RECT_LEVEL_END, scaleX, scaleY);
        //Utils.scale(Assets.RECT_LEVEL_END_HOME, scaleX, scaleY);


        Panoramic = new Actor(RECT_PANORAMIC.width(), RECT_PANORAMIC.height(),-(int) Assets.WINDOW_HEIGHT / 20,-(int) Assets.WINDOW_HEIGHT / 10);

    }


}