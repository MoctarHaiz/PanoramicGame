package com.HaizStudio.ChakaZulu;

public class Enemi extends Enemy {


	/**
	 * Creating the enemi
	 * @param centerX
	 * @param centerY
     */
	public Enemi(float centerX, float centerY) {
		setCenterX(centerX);
		setCenterY(centerY);
		update();
	}

}
