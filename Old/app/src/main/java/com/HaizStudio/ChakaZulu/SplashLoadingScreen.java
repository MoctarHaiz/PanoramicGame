package com.HaizStudio.ChakaZulu;

import android.graphics.Canvas;
import android.graphics.Color;

import com.HaizStudio.framework.Graphics;
import com.HaizStudio.framework.Jeu;
import com.HaizStudio.framework.Screen;

public class SplashLoadingScreen extends Screen {
	public SplashLoadingScreen(Jeu game) {

		super(game);
		final Jeu gameTemp = game;
		Assets.mWaitHandler.postDelayed(new Runnable() {
			@Override
			public void run() {
				try {
					gameTemp.setScreen(new MainMenuScreen(gameTemp));
				} catch (Exception ignored) {
					ignored.printStackTrace();
				}
			}
		}, Assets.spashScreenTime);

	}

	@Override
	public void update(float deltaTime) {
		Graphics g = game.getGraphics();

		//game.setScreen(new LoadingScreen(game));

	}

	@Override
	public void paint(float deltaTime) {

	}

	@Override
	public void paintNew(float deltaTime, Canvas canvas) {
		Graphics g = game.getGraphics();
		g.setCanvas(canvas);
		g.clearScreen(Color.WHITE);
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
}
