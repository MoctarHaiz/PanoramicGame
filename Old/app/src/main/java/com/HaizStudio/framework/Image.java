package com.HaizStudio.framework;

import android.graphics.Bitmap;

import com.HaizStudio.framework.Graphics.ImageFormat;

public interface Image {
	public int getWidth();
	public Bitmap getBitmap();
	public void setBitmap(Bitmap bitmap);
	public int getHeight();
	public ImageFormat getFormat();
	public void dispose();
}
