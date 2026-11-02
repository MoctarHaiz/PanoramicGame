package com.HaizStudio.framework;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.text.TextPaint;

public interface Graphics {
	public static enum ImageFormat {
		ARGB8888, ARGB4444, RGB565
	}

	public Image newImage(String fileName, ImageFormat format);

	public void clearScreen(int color);

	public void drawLine(int x, int y, int x2, int y2, int color);

	public void drawRect(float x, float y, float width, float height, int color);
	public void drawRect(RectF rect, int color);

	public void drawImage(Image image, float x, float y, float srcX, float srcY,
						  float srcWidth, float srcHeight);

	public void drawCircle(int x, int y, int r, int color) ;
    public void fillCircle(int x, int y, int r, int color) ;

	public void drawImage(Image Image, float x, float y);
	public void drawImage(Image Image, RectF rect);

	public void drawImage(Image Image, int x, int y, int width, int height);
	public Image newImage(String fileName, ImageFormat format, RectF rect);
	void drawString(String text, int x, int y, Paint paint);
	void drawString(String text, RectF rect, TextPaint paint);

	public int getWidth();

	public int getHeight();

	public void drawARGB(int i, int j, int k, int l);
	public Canvas getCanvas();

	public void setCanvas(Canvas canvas);
}
