package com.HaizStudio.ChakaZulu.ui;

import android.annotation.SuppressLint;
import android.view.MotionEvent;
import android.view.View;

/**
 * Turns touches into game actions: a swipe fires as soon as the finger has moved far
 * enough (no waiting for release), a short tap throws, and a second finger also throws.
 */
public final class SwipeInput implements View.OnTouchListener {

    public interface Listener {
        void onSwipe(int direction); // 0 left, 1 right, 2 up, 3 down

        void onTap();
    }

    public static final int LEFT = 0, RIGHT = 1, UP = 2, DOWN = 3;

    private final Listener listener;
    private final float threshold;
    private float startX, startY;
    private long startTime;
    private boolean fired;

    public SwipeInput(Listener listener, float density) {
        this.listener = listener;
        this.threshold = 26 * density;
    }

    @SuppressLint("ClickableViewAccessibility")
    @Override
    public boolean onTouch(View v, MotionEvent e) {
        switch (e.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                startX = e.getX();
                startY = e.getY();
                startTime = e.getEventTime();
                fired = false;
                return true;
            case MotionEvent.ACTION_POINTER_DOWN:
                listener.onTap();
                return true;
            case MotionEvent.ACTION_MOVE:
                if (!fired) {
                    float dx = e.getX() - startX, dy = e.getY() - startY;
                    if (dx * dx + dy * dy > threshold * threshold) {
                        fired = true;
                        if (Math.abs(dx) > Math.abs(dy)) listener.onSwipe(dx > 0 ? RIGHT : LEFT);
                        else listener.onSwipe(dy > 0 ? DOWN : UP);
                    }
                }
                return true;
            case MotionEvent.ACTION_UP:
                if (!fired && e.getEventTime() - startTime < 350) listener.onTap();
                fired = true;
                return true;
            default:
                return true;
        }
    }
}
