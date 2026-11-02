package com.HaizStudio.ChakaZulu;

public class Background {

	public int bgX, bgY, speedX;

	public Background(int x, int y, int speed) {
		bgX = x;
		bgY = y;
		speedX = speed;
	}

	
	public void update(){
	  bgX += speedX;
	}
	
	public int getBgX() {
		return bgX;
	}

	public int getBgY() {
		return bgY;
	}

	public int getSpeedX() {
		
		return speedX;
	}

	public void setBgX(int bgX) {
		
		this.bgX = bgX;
	}

	public void setBgY(int bgY) {
		this.bgY = bgY;
	}

	public void setSpeedX(int speedX) {
		
		this.speedX = speedX;

	}

}
