package com.HaizStudio.ChakaZulu;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.Log;

import com.HaizStudio.framework.Graphics;
import com.HaizStudio.framework.Input.TouchEvent;
import com.HaizStudio.framework.Jeu;
import com.HaizStudio.framework.Screen;

import java.util.List;

public class MainMenuScreen extends Screen {
    public MainMenuScreen(Jeu game) {
        super(game);

        paint = new Paint();
        paint.setTextSize(100);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setAntiAlias(true);
        paint.setColor(Color.BLACK);
    }

    Paint paint;


    /*
    If the user has clicked on play go to GameScreen
     */
    @Override
    public void update(float deltaTime) {
        Graphics g = game.getGraphics();
        List<TouchEvent> touchEvents = game.getInput().getTouchEvents();

        try {
            int len = touchEvents.size();
            for (int i = 0; i < len; i++) {
                TouchEvent event = touchEvents.get(i);
                if (event.type == TouchEvent.TOUCH_DOWN) {
                    if (true) {//inBounds(event, Assets.RECT_MENU.left, Assets.RECT_MENU.top, Assets.RECT_MENU.width(), Assets.RECT_MENU.height())) {
                        game.setScreen(new GameScreen(game));
                    }

                }
            }
        } catch (Exception ie) {
            //Log.e("Exception ", ie.getMessage());
        }
    }

    private boolean inBounds(TouchEvent event, int x, int y, int width,
                             int height) {
        if (event.x > x && event.x < x + width - 1 && event.y > y
                && event.y < y + height - 1)
            return true;
        else
            return false;
    }

    @Override
    /*
    Draw the menu "jouer"
     */
    public void paint(float deltaTime) {

    }

    @Override
    public void paintNew(float deltaTime, Canvas canvas) {
        Graphics g = game.getGraphics();
        g.setCanvas(canvas);
        g.clearScreen(Color.WHITE);
        //if (Assets._DEBUG)
        //  g.drawRect(Assets.RECT_MENU, Color.YELLOW);
        g.drawImage(Assets.menu, Assets.RECT_SPLASH);


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
        android.os.Process.killProcess(android.os.Process.myPid());

    }
}
 