package com.HaizStudio.framework;

import android.content.Context;

public interface Jeu {
	public Audio getAudio();
	public Input getInput();
	public FileIO getFileIO();
	public Graphics getGraphics();
	public void setScreen(Screen screen);
	public Screen setCurrentScreen();
	public Screen setInitScreen();
	Screen getInitScreen();
	public Context getContext();
	public void showInterstitial();


}
