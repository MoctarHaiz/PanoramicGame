package com.HaizStudio.framework.implementation;

import android.content.Context;
import android.view.View;

import com.HaizStudio.framework.Input;

import java.util.List;

public class InputAndroid implements Input {
    TouchHandler touchHandler;

    public InputAndroid(Context context, View view, float scaleX, float scaleY) {
        touchHandler = new MultiTouchHandler(context,view, scaleX, scaleY);


    }

    @Override
    public boolean isTouchDown(int pointer) {
        return touchHandler.isTouchDown(pointer);
    }

    @Override
    public int getTouchX(int pointer) {
        return touchHandler.getTouchX(pointer);
    }

    @Override
    public int getTouchY(int pointer) {
        return touchHandler.getTouchY(pointer);
    }

    @Override
    public List<TouchEvent> getTouchEvents() {
        return touchHandler.getTouchEvents();
    }

    @Override
    public MultiTouchHandler.Direction getSwipeDirection() {
        return touchHandler.getSwipeDirection();
    }

    public boolean isShootRequested(){
        return touchHandler.isShootRequested();
    }


}
