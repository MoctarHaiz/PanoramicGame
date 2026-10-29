package com.HaizStudio.framework.implementation;

import java.io.IOException;
import java.io.InputStream;

import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.BitmapFactory;
import android.graphics.BitmapFactory.Options;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Paint.Style;
import android.graphics.Rect;
import android.graphics.RectF;
import android.text.TextPaint;

import com.HaizStudio.framework.Graphics;
import com.HaizStudio.framework.Image;


public class GraphiquesAndroid implements Graphics {

    AssetManager assets;
    Bitmap frameBuffer;
    Canvas canvas;
    Paint paint;
    RectF srcRect = new RectF();
    RectF dstRect = new RectF();

    public GraphiquesAndroid(AssetManager assets, Bitmap frameBuffer) {
        this.assets = assets;
        this.frameBuffer = frameBuffer;
        this.canvas = new Canvas(frameBuffer);
        this.paint = new Paint();
    }

    @Override
    public Image newImage(String fileName, ImageFormat format) {
        Config config = null;
        if (format == ImageFormat.RGB565)
            config = Config.RGB_565;
        else if (format == ImageFormat.ARGB4444)
            config = Config.ARGB_8888; // Android decodes ARGB_4444 as ARGB_8888 anyway
        else
            config = Config.ARGB_8888;

        Options options = new Options();
        options.inPreferredConfig = config;

        InputStream in = null;
        Bitmap bitmap = null;

        try {
            in = assets.open(fileName);
            bitmap = BitmapFactory.decodeStream(in, null, options);
            if (bitmap == null)
                throw new RuntimeException(
                        "ne peut pas charger le bitmap de l'asset '" + fileName
                                + "'");

        } catch (IOException e) {

            throw new RuntimeException("Couldn't load bitmap from asset '"
                    + fileName + "'");
        } finally {

            if (in != null) {
                try {
                    in.close();
                } catch (IOException e) {
                }
            }
        }
        if (bitmap.getConfig() == Config.RGB_565)
            format = ImageFormat.RGB565;
        else
            format = ImageFormat.ARGB8888;
        return new ImageAndroid(bitmap, format);
    }

    @Override
    public Image newImage(String fileName, ImageFormat format, RectF rect) {
        Config config = null;
        if (format == ImageFormat.RGB565)
            config = Config.RGB_565;
        else if (format == ImageFormat.ARGB4444)
            config = Config.ARGB_8888; // Android decodes ARGB_4444 as ARGB_8888 anyway
        else
            config = Config.ARGB_8888;

        Options options = new Options();
        options.inPreferredConfig = config;

        InputStream in = null;
        Bitmap bitmap = null;

        try {
            in = assets.open(fileName);

            bitmap = BitmapFactory.decodeStream(in, null, options);
            bitmap = Bitmap.createScaledBitmap(bitmap, (int)rect.width(), (int)rect.height(), true);
            if (bitmap == null)
                throw new RuntimeException(
                        "ne peut pas charger le bitmap de l'asset '" + fileName
                                + "'");

        } catch (IOException e) {

            throw new RuntimeException("Couldn't load bitmap from asset '"
                    + fileName + "'");
        } finally {

            if (in != null) {
                try {
                    in.close();
                } catch (IOException e) {
                }
            }
        }
        if (bitmap.getConfig() == Config.RGB_565)
            format = ImageFormat.RGB565;
        else
            format = ImageFormat.ARGB8888;
        return new ImageAndroid(bitmap, format);
    }


    @Override
    public void clearScreen(int color) {
        canvas.drawRGB((color & 0xff0000) >> 16, (color & 0xff00) >> 8,
                (color & 0xff));

    }

    @Override
    public void drawLine(int x, int y, int x2, int y2, int color) {
        paint.setColor(color);
        canvas.drawLine(x, y, x2, y2, paint);

    }


    @Override
    public void drawCircle(int x, int y, int r, int color) {
        paint.setColor(color);
        paint.setStyle(Style.STROKE);
        canvas.drawCircle(x, y, r, paint);
        paint.setStyle(Style.FILL);

    }

    @Override
    public void fillCircle(int x, int y, int r, int color) {
        paint.setColor(color);
        canvas.drawCircle(x, y, r, paint);

    }


    @Override
    public void drawRect(float x, float y, float width, float height, int color) {
        paint.setColor(color);
        paint.setStyle(Style.FILL);
        canvas.drawRect(x, y, x + width - 1, y + height - 1, paint);
    }

    @Override
    public void drawRect(RectF rect, int color) {
        paint.setColor(color);
        paint.setStyle(Style.FILL);
        canvas.drawRect(rect.left, rect.top, rect.right, rect.bottom, paint);
    }

    @Override
    public void drawImage(Image Image, float x, float y, float srcX, float srcY, float srcWidth, float srcHeight) {
        srcRect.left = srcX;
        srcRect.top = srcY;
        srcRect.right = srcX + srcWidth;
        srcRect.bottom = srcY + srcHeight;

        dstRect.left = x;
        dstRect.top = y;
        dstRect.right = x + srcWidth;
        dstRect.bottom = y + srcHeight;

        Rect r =new Rect();
        srcRect.round(r);
        canvas.drawBitmap(((ImageAndroid) Image).bitmap, r, dstRect, null);

    }

    @Override
    public void drawImage(Image Image, float x, float y) {
        canvas.drawBitmap(((ImageAndroid) Image).bitmap, x, y, null);

    }

    @Override
    public void drawImage(Image Image, RectF rect) {
        canvas.drawBitmap(((ImageAndroid) Image).bitmap, rect.left, rect.top, null);

    }

    @Override
    public void drawImage(Image Image, int x, int y, int width, int height) {
        canvas.drawBitmap(((ImageAndroid) Image).bitmap, x, y, null);
    }


    public void drawScaledImage(Image Image, int x, int y, int width,
                                int height, int srcX, int srcY, int srcWidth, int srcHeight) {

        srcRect.left = srcX;
        srcRect.top = srcY;
        srcRect.right = srcX + srcWidth;
        srcRect.bottom = srcY + srcHeight;

        dstRect.left = x;
        dstRect.top = y;
        dstRect.right = x + width;
        dstRect.bottom = y + height;

       // canvas.drawBitmap(((ImageAndroid) Image).bitmap, srcRect, dstRect, null);

    }

    @Override
    public void drawString(String text, int x, int y, Paint paint) {
        canvas.drawText(text, x, y, paint);

    }

    @Override
    public void drawString(String text, RectF rect, TextPaint paint) {
        canvas.drawText(text, rect.left + rect.width() / 2, rect.top + rect.height(), paint);

    }


    @Override
    public void drawARGB(int a, int r, int g, int b) {
        paint.setStyle(Style.FILL);
        canvas.drawARGB(a, r, g, b);

    }

    @Override
    public int getWidth() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public int getHeight() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public Canvas getCanvas() {
        return canvas;
    }

    public void setCanvas(Canvas canvas) {
        this.canvas = canvas;
    }

}
