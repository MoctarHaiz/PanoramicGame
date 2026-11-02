package com.HaizStudio.ChakaZulu;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.RectF;
import android.graphics.drawable.VectorDrawable;

import com.HaizStudio.framework.Input;

public final class Utils {

    private Utils(){};

    public static boolean inBounds(Input.TouchEvent event, int x, int y, int width, int height) {
        return (event.x > x && event.x < x + width - 1 && event.y > y  && event.y < y + height - 1) ? true : false;
    }

    public static boolean inBounds(Input.TouchEvent event, float x, float y, float width, float height) {
        return (event.x > x && event.x < x + width - 1 && event.y > y  && event.y < y + height - 1) ? true : false;
    }

    public static boolean inBounds(Input.TouchEvent event, RectF rect) {
        return (event.x > rect.left && event.x <  rect.right - 1 && event.y > rect.top  && event.y < rect.bottom - 1) ? true : false;
    }

    public static RectF createRectangle(float x, float y , float width, float height){
        return new RectF(x, y, x+ width, y+height);
    }

    public static Bitmap getBitmap(VectorDrawable vectorDrawable) {
        Bitmap bitmap = Bitmap.createBitmap(vectorDrawable.getIntrinsicWidth(),
                vectorDrawable.getIntrinsicHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        vectorDrawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        vectorDrawable.draw(canvas);
        return bitmap;
    }


    public static  void scale(RectF rect, float scaleX, float scaleY){

        rect.left*= scaleX;
        rect.right*= scaleX;
        rect.top*= scaleY;
        rect.bottom*= scaleY;

    }

}
