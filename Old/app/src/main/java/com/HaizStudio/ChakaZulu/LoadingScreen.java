package com.HaizStudio.ChakaZulu;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;

import com.HaizStudio.framework.Graphics;
import com.HaizStudio.framework.Graphics.ImageFormat;
import com.HaizStudio.framework.Jeu;
import com.HaizStudio.framework.Screen;
import com.HaizStudio.framework.implementation.ImageAndroid;

public class LoadingScreen extends Screen {
    public LoadingScreen(Jeu game) {
        super(game);

        //handling splash screen
        if (Assets.splash != null) {
            Assets.splash.dispose();
            Assets.splash = null;
        }
    }

    /**
     * Do the loading once here, then go to main menu screen
     *
     * @param deltaTime
     */
    @Override
    public void update(float deltaTime) {
        Graphics g = game.getGraphics();

        initTileSetUnscaled(g);
        initTileBitmap(g);
        initMenu(g);
        initGameOver(g);
        initBackground(g);
        initSplash(g);
        initPanoramic(g);
        initEnnemies(g);
        initFire(g);
        initREDBOB(g);
        initLifePan(g);
        initCover(g);
        initPause(g);
        initDust(g);
        initSound(g);
        initLevelEnd(g);

       /* Assets.tiledirt = g.newImage("tiledirt.png", ImageFormat.RGB565);
        Assets.tilegrassTop = g.newImage("tilegrasstop.png", ImageFormat.RGB565);
        Assets.tilegrassBot = g.newImage("tilegrassbot.png", ImageFormat.RGB565);
        Assets.tilegrassLeft = g.newImage("tilegrassleft.png", ImageFormat.RGB565);
        Assets.tilegrassRight = g.newImage("tilegrassright.png", ImageFormat.ARGB4444);
        */

        //Tileset
        //To check when needing to use svg
       /*Context context = ((JeuAndroid)game).getContext();
        Resources res = context.getResources();
        Drawable drawable = res.getDrawable(R.drawable.ic_level2);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            VectorDrawable vectorDrawable =  (VectorDrawable) drawable;
            Assets.tileSet =new ImageAndroid(Utils.getBitmap(vectorDrawable), ImageFormat.RGB565);
        } else {
            BitmapDrawable bitmapDrawable = (BitmapDrawable) drawable;
            Assets.tileSet =new ImageAndroid(bitmapDrawable.getBitmap(), ImageFormat.RGB565);
        }
*/


        //Don't use SVG because we convert it to bitmap anyway
        //And Png was more beatifull
        /*Resources res = game.getContext(). getResources();
        Drawable drawable = res.getDrawable(R.drawable.happy_bubble);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            VectorDrawable vectorDrawable =  (VectorDrawable) drawable;
            Assets.bubble1 = new ImageAndroid(Utils.getBitmap(vectorDrawable), ImageFormat.RGB565);
            Assets.bubble2 = new ImageAndroid(Utils.getBitmap(vectorDrawable), ImageFormat.RGB565);
        } else {
            BitmapDrawable bitmapDrawable = (BitmapDrawable) drawable;
            Assets.bubble1 = new ImageAndroid(bitmapDrawable.getBitmap(), ImageFormat.RGB565);
            Assets.bubble2 = new ImageAndroid(bitmapDrawable.getBitmap(), ImageFormat.RGB565);
        }
         */


        //game.setScreen(new MainMenuScreen(game));
        game.setScreen(new SplashLoadingScreen(game));
    }

    public int calculateInSampleSize(
            BitmapFactory.Options options, int reqWidth, int reqHeight) {
        // Raw height and width of image
        final int height = options.outHeight;
        final int width = options.outWidth;
        int inSampleSize = 1;

        if (height > reqHeight || width > reqWidth) {

            // Calculate ratios of height and width to requested height and width
            final int heightRatio = Math.round((float) height / (float) reqHeight);
            final int widthRatio = Math.round((float) width / (float) reqWidth);

            // Choose the smallest ratio as inSampleSize value, this will guarantee
            // a final image with both dimensions larger than or equal to the
            // requested height and width.
            inSampleSize = heightRatio < widthRatio ? heightRatio : widthRatio;
        }

        return inSampleSize;
    }

    @Override
    public void paint(float deltaTime) {
        Graphics g = game.getGraphics();
        g.drawImage(Assets.splash, 0, 0);
    }

    @Override
    public void pause() {

    }

    @Override
    public void resume() {

    }

    @Override
    public void dispose() {

    }

    @Override
    public void backButton() {

    }

    private void initPanoramic(Graphics g) {
        // Lists are static: empty them in case the activity was recreated
        Assets.personnage.clear();
        Assets.personnageSaute.clear();
        Assets.personnageSticked.clear();

        for (int i = 1; i <= 17; i++)
            Assets.personnage.add(g.newImage("running/panoramic" + i + ".png", ImageFormat.ARGB8888, Assets.RECT_PANORAMIC));

        for (int i = 1; i <= 15; i++)
            Assets.personnageSaute.add(g.newImage("jump/panoramicjump" + i + ".png", ImageFormat.ARGB8888, Assets.RECT_PANORAMIC));

        for (int i = 0; i <= 7; i++)
            Assets.personnageSticked.add(g.newImage("stick/stick" + i + ".png", ImageFormat.ARGB8888, Assets.RECT_PANORAMIC));

        Assets.personnageAccroupi = g.newImage("panoramicaccroupi.png", ImageFormat.ARGB8888, Assets.RECT_PANORAMIC);


        //Animations
        //Adding Panoramic normal frames
        Assets.PanoramicAnimationNormal = new Animation();
        int time = 10;
        for (int i = 0; i < Assets.personnage.size(); i++)
            Assets.PanoramicAnimationNormal.addframes(Assets.personnage.get(i), time);


        //Adding Panoramic sticked frames
        Assets.PanoramicAnimationSticked = new Animation();
        for (int i = 0; i <= 7; i++)
            Assets.PanoramicAnimationSticked.addframes(Assets.personnageSticked.get(i), 50);
        for (int i = 7; i >= 1; i--)
            Assets.PanoramicAnimationSticked.addframes(Assets.personnageSticked.get(i), 50);

        //Adding Panoramic Jump frames
        Assets.PanoramicAnimationJumped = new Animation();
        int timeJumped = 15;

        for (int i = 0; i < Assets.personnageSaute.size(); i++)
            Assets.PanoramicAnimationJumped.addframes(Assets.personnageSaute.get(i), time);

        Assets.PanoramicAnimationAccroupi = new Animation();
        Assets.PanoramicAnimationAccroupi.addframes(Assets.personnageAccroupi, time);


    }

    @Override
    public void paintNew(float deltaTime, Canvas canvas) {
        //Graphics g = game.getGraphics();
        //g.setCanvas(canvas);
        //g.drawImage(Assets.splash, 0, 0);
    }

    private void initEnnemies(Graphics g) {


        Assets.enemi1 = g.newImage("bandit/small/bandit1.png", ImageFormat.ARGB4444);
        Assets.enemi2 = g.newImage("bandit/small/bandit2.png", ImageFormat.ARGB4444);
        Assets.enemi3 = g.newImage("bandit/small/bandit3.png", ImageFormat.ARGB4444);
        Assets.enemi4 = g.newImage("bandit/small/bandit4.png", ImageFormat.ARGB4444);
        Assets.enemi5 = g.newImage("bandit/small/bandit5.png", ImageFormat.ARGB4444);
        Assets.enemi6 = g.newImage("bandit/small/bandit6.png", ImageFormat.ARGB4444);
        Assets.enemi7 = g.newImage("bandit/small/bandit7.png", ImageFormat.ARGB4444);
        Assets.enemi8 = g.newImage("bandit/small/bandit8.png", ImageFormat.ARGB4444);
        Assets.enemi9 = g.newImage("bandit/small/bandit9.png", ImageFormat.ARGB4444);
        Assets.enemi10 = g.newImage("bandit/small/bandit10.png", ImageFormat.ARGB4444);


        Assets.enemiMort1 = g.newImage("bandit/small/banditMort1.png", ImageFormat.ARGB4444);
        Assets.enemiMort2 = g.newImage("bandit/small/banditMort2.png", ImageFormat.ARGB4444);
        Assets.enemiMort3 = g.newImage("bandit/small/banditMort3.png", ImageFormat.ARGB4444);
        Assets.enemiMort4 = g.newImage("bandit/small/banditMort4.png", ImageFormat.ARGB4444);
        Assets.enemiMort5 = g.newImage("bandit/small/banditMort5.png", ImageFormat.ARGB4444);
        Assets.enemiMort6 = g.newImage("bandit/small/banditMort6.png", ImageFormat.ARGB4444);
        Assets.enemiMort7 = g.newImage("bandit/small/banditMort7.png", ImageFormat.ARGB4444);
        Assets.enemiMort8 = g.newImage("bandit/small/banditMort8.png", ImageFormat.ARGB4444);
        Assets.enemiMort9 = g.newImage("bandit/small/banditMort9.png", ImageFormat.ARGB4444);
        Assets.enemiMort10 = g.newImage("bandit/small/banditMort10.png", ImageFormat.ARGB4444);


        Assets.enemiAnimation = new Animation();
        int time = 20;
        Assets.enemiAnimation.addframes(Assets.enemi1, time);
        Assets.enemiAnimation.addframes(Assets.enemi2, time);
        Assets.enemiAnimation.addframes(Assets.enemi3, time);
        Assets.enemiAnimation.addframes(Assets.enemi4, time);
        Assets.enemiAnimation.addframes(Assets.enemi5, time);
        Assets.enemiAnimation.addframes(Assets.enemi6, time);
        Assets.enemiAnimation.addframes(Assets.enemi7, time);
        Assets.enemiAnimation.addframes(Assets.enemi8, time);
        Assets.enemiAnimation.addframes(Assets.enemi9, time);
        Assets.enemiAnimation.addframes(Assets.enemi10, time);

        Assets.enemiAnimationDied = new Animation();
        Assets.enemiAnimationDied.addframes(Assets.enemiMort1, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort2, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort3, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort4, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort5, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort6, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort7, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort8, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort9, time);
        Assets.enemiAnimationDied.addframes(Assets.enemiMort10, time);
    }

    private void initFire(Graphics g) {

        Assets.m1 = g.newImage("fire/n1.png", ImageFormat.ARGB4444, Assets.RECT_FIRE);
        Assets.m2 = g.newImage("fire/n2.png", ImageFormat.ARGB4444, Assets.RECT_FIRE);
        Assets.m3 = g.newImage("fire/n3.png", ImageFormat.ARGB4444, Assets.RECT_FIRE);
        Assets.m4 = g.newImage("fire/n4.png", ImageFormat.ARGB4444, Assets.RECT_FIRE);

        Assets.fireAnimation = new Animation();
        Assets.fireAnimation.addframes(Assets.m1, 100);
        Assets.fireAnimation.addframes(Assets.m2, 100);
        Assets.fireAnimation.addframes(Assets.m3, 100);
        Assets.fireAnimation.addframes(Assets.m4, 100);
    }


    private void initLifePan(Graphics g) {
//Life Pan
        Assets.lifePan1 = g.newImage("lifePan/lifePan1.png", ImageFormat.ARGB4444, Assets.RECT_LIFEPAN);
        Assets.lifePan2 = g.newImage("lifePan/lifePan2.png", ImageFormat.ARGB4444, Assets.RECT_LIFEPAN);
        Assets.lifePan3 = g.newImage("lifePan/lifePan3.png", ImageFormat.ARGB4444, Assets.RECT_LIFEPAN);
    }

    private void initMenu(Graphics g) {

        Assets.menu = g.newImage("menu.png", ImageFormat.RGB565, Assets.RECT_SPLASH);
    }


    private void initGameOver(Graphics g) {


        Assets.gameOver1 = g.newImage("gameOver/gameOver1.png", ImageFormat.RGB565, Assets.RECT_GAMEOVER_BACKGROUND1);
        Assets.gameOver2 = g.newImage("gameOver/gameOver2.png", ImageFormat.RGB565, Assets.RECT_GAMEOVER_BACKGROUND2);
        Assets.gameOver3 = g.newImage("gameOver/gameOver3.png", ImageFormat.RGB565, Assets.RECT_GAMEOVER_BACKGROUND3);

        Assets.gameOverBackGgroundAnimation = new Animation();
        Assets.gameOverBackGgroundAnimation.addframes(Assets.gameOver1, 100);
        Assets.gameOverBackGgroundAnimation.addframes(Assets.gameOver2, 100);
        Assets.gameOverBackGgroundAnimation.addframes(Assets.gameOver3, 100);


        Assets.gameOverStarRope = g.newImage("gameOver/gameOverRope.png", ImageFormat.RGB565, Assets.RECT_GAMEOVER_ROPE);


        Assets.gameOverStarAnimation = new Animation();
        Assets.gameOverStarAnimation.addframes(g.newImage("gameOver/star1.png", ImageFormat.ARGB8888, Assets.RECT_GAMEOVER_STAR1), 100);
        Assets.gameOverStarAnimation.addframes(g.newImage("gameOver/star2.png", ImageFormat.ARGB8888, Assets.RECT_GAMEOVER_STAR2), 100);
        Assets.gameOverStarAnimation.addframes(g.newImage("gameOver/star3.png", ImageFormat.ARGB8888, Assets.RECT_GAMEOVER_STAR3), 100);
        Assets.gameOverStarAnimation.addframes(g.newImage("gameOver/star4.png", ImageFormat.ARGB8888, Assets.RECT_GAMEOVER_STAR4), 100);
        Assets.gameOverStarAnimation.addframes(g.newImage("gameOver/star5.png", ImageFormat.ARGB8888, Assets.RECT_GAMEOVER_STAR5), 100);


    }

    private void initTileBitmap(Graphics g) {

        for (int i = -1; i < Assets.tiles.length; i++) {

            //Get the tile id
            int id = i;
            if (id == -1) //Empty tile
                id = 0;

            //Get the tile position
            int stepX = id % Assets.TILESET_NUMBER_OF_COLUMN;
            int stepY = id / Assets.TILESET_NUMBER_OF_COLUMN;


            //Crop the tile from the tileset
            Bitmap tileImage = Bitmap.createBitmap(
                    ((ImageAndroid) Assets.tileSet).getBitmap(),
                    (int) (stepX * 32),//Assets.TILE_SIDE_WIDTH),
                    (int) (stepY * 32),// Assets.TILE_SIDE_HEIGHT),
                    (int) 32,// Assets.TILE_SIDE_WIDTH,
                    (int) 32);//Assets.TILE_SIDE_HEIGHT);

            //scale the tile to appropriate sie
            //+1 to add one more pixel since casting to int add spaces between pixels
            tileImage = Bitmap.createScaledBitmap(tileImage, (int) Assets.TILE_SIDE_WIDTH + 1, 1 + (int) Assets.TILE_SIDE_HEIGHT, true);

            Assets.tiles[id] = new ImageAndroid(tileImage, ImageFormat.ARGB8888);

        }
    }


    private void initBackground(Graphics g) {
        //Assets.background = g.newImage("background.png", ImageFormat.RGB565);
        Assets.background = g.newImage("background.png", ImageFormat.RGB565, Assets.RECT_BACKGROUND);


    }

    private void initLevelEnd(Graphics g) {

        Assets.levelEnd1 = g.newImage("levelEnd/levelEnd1.png", ImageFormat.ARGB8888, Assets.RECT_LEVEL_END);
        Assets.levelEnd2 = g.newImage("levelEnd/levelEnd2.png", ImageFormat.ARGB8888, Assets.RECT_LEVEL_END);
        Assets.levelEndHome = g.newImage("levelEnd/levelEndHome.png", ImageFormat.ARGB8888, Assets.RECT_LEVEL_END_HOME);

    }


    //Cover
    private void initCover(Graphics g) {
        Assets.cover1 = g.newImage("cover/cover1.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);
        Assets.cover2 = g.newImage("cover/cover2.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);
        Assets.cover3 = g.newImage("cover/cover3.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);
        Assets.cover4 = g.newImage("cover/cover4.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);
        Assets.cover5 = g.newImage("cover/cover5.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);
        Assets.cover6 = g.newImage("cover/cover6.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);
        Assets.cover7 = g.newImage("cover/cover7.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);
        Assets.cover8 = g.newImage("cover/cover8.png", ImageFormat.ARGB4444, Assets.RECT_PANORAMIC);


        //cover
        int time = 50;
        Assets.coverAnimation = new Animation();
        Assets.coverAnimation.addframes(Assets.cover1, time);
        Assets.coverAnimation.addframes(Assets.cover2, time);
        Assets.coverAnimation.addframes(Assets.cover3, time);
        Assets.coverAnimation.addframes(Assets.cover4, time);
        Assets.coverAnimation.addframes(Assets.cover5, time);
        Assets.coverAnimation.addframes(Assets.cover6, time);
        Assets.coverAnimation.addframes(Assets.cover7, time);
        Assets.coverAnimation.addframes(Assets.cover8, time);
        Assets.coverAnimation.addframes(Assets.cover7, time);
        Assets.coverAnimation.addframes(Assets.cover6, time);
        Assets.coverAnimation.addframes(Assets.cover5, time);
        Assets.coverAnimation.addframes(Assets.cover4, time);
        Assets.coverAnimation.addframes(Assets.cover3, time);
        Assets.coverAnimation.addframes(Assets.cover2, time);

    }


    //bubble
    private void initREDBOB(Graphics g) {
        Assets.bubble1 = g.newImage("bubble/redbob1.png", ImageFormat.ARGB4444, Assets.RECT_RED_BOB_IMAGE_TO_TOUCH);
        Assets.bubble2 = g.newImage("bubble/redbob2.png", ImageFormat.ARGB4444, Assets.RECT_RED_BOB_IMAGE_TO_TOUCH);


        //bubble
        int time = 100;
        Assets.bubbleAnimation = new Animation();
        Assets.bubbleAnimation.addframes(Assets.bubble1, time);
        Assets.bubbleAnimation.addframes(Assets.bubble2, time);


    }


    //Pause
    private void initPause(Graphics g) {
        Assets.pause = g.newImage("pause.png", ImageFormat.RGB565);

    }


    private void initSplash(Graphics g) {
        Assets.splash = g.newImage("HaizStudioSplash.png", ImageFormat.RGB565, Assets.RECT_SPLASH);
    }

    //dust
    private void initDust(Graphics g) {
        Assets.dust1 = g.newImage("dust/dust1.png", ImageFormat.ARGB4444, Assets.RECT_DUST);
        Assets.dust2 = g.newImage("dust/dust2.png", ImageFormat.ARGB4444, Assets.RECT_DUST);
        Assets.dust3 = g.newImage("dust/dust3.png", ImageFormat.ARGB4444, Assets.RECT_DUST);
        Assets.dust4 = g.newImage("dust/dust4.png", ImageFormat.ARGB4444, Assets.RECT_DUST);

        int time = 100;
        Assets.dustAnimation = new Animation();
        Assets.dustAnimation.addframes(Assets.dust1, time);
        Assets.dustAnimation.addframes(Assets.dust2, time);
        Assets.dustAnimation.addframes(Assets.dust3, time);
        Assets.dustAnimation.addframes(Assets.dust4, time);
        Assets.dustAnimation.addframes(Assets.dust3, time);
        Assets.dustAnimation.addframes(Assets.dust2, time);
    }

    // pour creer un son
    private void initSound(Graphics g) {
        Assets.click = game.getAudio().createSound("audio/projectile.ogg");
        Assets.clickEnemy = game.getAudio().createSound("audio/enemy.ogg");

    }

    private void initTileSetUnscaled(Graphics g) {
        Assets.tileSet = g.newImage("level1Tileset.png", ImageFormat.RGB565);// Assets.RECT_TILESET);

    }

}