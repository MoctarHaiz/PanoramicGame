package com.HaizStudio.framework;

import android.graphics.Canvas;

public abstract class Screen {
    public static  Jeu game;

    public Screen(Jeu jeu) {
        this.game = jeu;
    }

    public abstract void update(float deltaTime);

    public abstract void paint(float deltaTime);
    public abstract void paintNew(float deltaTime, Canvas canvas);

    public abstract void pause();

    public abstract void resume();

    public abstract void dispose();
   
    public abstract void backButton();
}
 