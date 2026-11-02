package com.HaizStudio.ChakaZulu;

import java.util.ArrayList;

import com.HaizStudio.framework.Image;

public class Animation {

	private ArrayList<AnimFrame> frames; // ///////mod
	private int currentFrame;
	private long animTime;
	private long totalDuration;

	public Animation() {
		frames = new ArrayList<AnimFrame>(); // ///////mod
		totalDuration = 0;

		synchronized (this) {
			animTime = 0;
			currentFrame = 0;
		}
	}

	/**
	 * Add frame for animation
	 * @param image
	 * @param durree
     */
	public synchronized void addframes(Image image, long durree) {
		totalDuration += durree;
		frames.add(new AnimFrame(image, totalDuration));

	}

	public synchronized void update(long tempsEcoule) {
		if (frames.size() > 1) {
			animTime += tempsEcoule;
			if (animTime >= totalDuration) {
				animTime = animTime % totalDuration;
				currentFrame = 0;
			}

			while (animTime > getFrame(currentFrame).endTime) {
				currentFrame++;

			}

		}
	}



	public synchronized Image getImage() {
		if (frames.size() == 0) {
			return null;
		} else {
			return getFrame(currentFrame).image;
		}

	}

	private AnimFrame getFrame(int i) {
		return (AnimFrame) frames.get(i);

	}

	public  void reset(){
		currentFrame = 0;
	}

	private class AnimFrame {
		Image image;
		long endTime;

		public AnimFrame(Image image, long endTime) {
			this.image = image;
			this.endTime = endTime;

		}

	}

}