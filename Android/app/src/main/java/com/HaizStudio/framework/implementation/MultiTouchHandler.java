package com.HaizStudio.framework.implementation;

import android.content.Context;
import android.util.Log;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;

import com.HaizStudio.ChakaZulu.Assets;
import com.HaizStudio.framework.Input.TouchEvent;
import com.HaizStudio.framework.Pool;
import com.HaizStudio.framework.Pool.PoolObjectFactory;

import java.util.ArrayList;
import java.util.List;

public class MultiTouchHandler implements TouchHandler, GestureDetector.OnGestureListener,
        GestureDetector.OnDoubleTapListener {
    private static final int MAX_TOUCHPOINTS = 10;

    boolean[] isTouched = new boolean[MAX_TOUCHPOINTS];
    int[] touchX = new int[MAX_TOUCHPOINTS];
    int[] touchY = new int[MAX_TOUCHPOINTS];
    int[] id = new int[MAX_TOUCHPOINTS];
    Pool<TouchEvent> touchEventPool;
    List<TouchEvent> touchEvents = new ArrayList<TouchEvent>();
    List<TouchEvent> touchEventsBuffer = new ArrayList<TouchEvent>();
    float scaleX;
    float scaleY;
    Direction swipeDirection;
    private final float LONG_SWIPE_THRESHOLD = 400;
    private boolean shootRequested = false;

    public MultiTouchHandler(Context context, View view, float scaleX, float scaleY) {
        PoolObjectFactory<TouchEvent> factory = new PoolObjectFactory<TouchEvent>() {
            @Override
            public TouchEvent createObject() {
                return new TouchEvent();
            }
        };
        touchEventPool = new Pool<TouchEvent>(factory, 100);
        view.setOnTouchListener(this);
        mDetector = new GestureDetector(context, this);
        mDetector.setOnDoubleTapListener(this);
        this.scaleX = scaleX;
        this.scaleY = scaleY;
    }

    @Override
    public boolean onTouch(View v, MotionEvent event) {
        synchronized (this) {
            int action = event.getAction() & MotionEvent.ACTION_MASK;
            int pointerIndex = (event.getAction() & MotionEvent.ACTION_POINTER_INDEX_MASK) >> MotionEvent.ACTION_POINTER_INDEX_SHIFT;
            int pointerCount = event.getPointerCount();
            TouchEvent touchEvent;
            this.mDetector.onTouchEvent(event);

            for (int i = 0; i < MAX_TOUCHPOINTS; i++) {
                if (i >= pointerCount) {
                    isTouched[i] = false;
                    id[i] = -1;
                    continue;
                }
                int pointerId = event.getPointerId(i);
                if (event.getAction() != MotionEvent.ACTION_MOVE
                        && i != pointerIndex) {
                    // if it's an up/down/cancel/out event, mask the id to see
                    // if we should process it for this touch
                    // point
                    continue;
                }
                switch (action) {
                    case MotionEvent.ACTION_DOWN:
                    case MotionEvent.ACTION_POINTER_DOWN:
                        touchEvent = touchEventPool.newObject();
                        touchEvent.type = TouchEvent.TOUCH_DOWN;
                        touchEvent.pointer = pointerId;
                        touchEvent.x = touchX[i] = (int) (event.getX(i) * scaleX);
                        touchEvent.y = touchY[i] = (int) (event.getY(i) * scaleY);
                        isTouched[i] = true;
                        id[i] = pointerId;
                        touchEventsBuffer.add(touchEvent);
                        break;

                    case MotionEvent.ACTION_UP:
                    case MotionEvent.ACTION_POINTER_UP:
                    case MotionEvent.ACTION_CANCEL:
                        touchEvent = touchEventPool.newObject();
                        touchEvent.type = TouchEvent.TOUCH_UP;
                        touchEvent.pointer = pointerId;
                        touchEvent.x = touchX[i] = (int) (event.getX(i) * scaleX);
                        touchEvent.y = touchY[i] = (int) (event.getY(i) * scaleY);
                        isTouched[i] = false;
                        id[i] = -1;
                        touchEventsBuffer.add(touchEvent);
                        break;

                    case MotionEvent.ACTION_MOVE:
                        touchEvent = touchEventPool.newObject();
                        touchEvent.type = TouchEvent.TOUCH_DRAGGED;
                        touchEvent.pointer = pointerId;
                        touchEvent.x = touchX[i] = (int) (event.getX(i) * scaleX);
                        touchEvent.y = touchY[i] = (int) (event.getY(i) * scaleY);
                        isTouched[i] = true;
                        id[i] = pointerId;
                        touchEventsBuffer.add(touchEvent);
                        break;
                }
            }
            return true;
        }
    }

    @Override
    public boolean isTouchDown(int pointer) {
        synchronized (this) {
            int index = getIndex(pointer);
            if (index < 0 || index >= MAX_TOUCHPOINTS)
                return false;
            else
                return isTouched[index];
        }
    }

    @Override
    public int getTouchX(int pointer) {
        synchronized (this) {
            int index = getIndex(pointer);
            if (index < 0 || index >= MAX_TOUCHPOINTS)
                return 0;
            else
                return touchX[index];
        }
    }

    @Override
    public int getTouchY(int pointer) {
        synchronized (this) {
            int index = getIndex(pointer);
            if (index < 0 || index >= MAX_TOUCHPOINTS)
                return 0;
            else
                return touchY[index];
        }
    }

    @Override
    public List<TouchEvent> getTouchEvents() {
        synchronized (this) {
            int len = touchEvents.size();
            for (int i = 0; i < len; i++)
                touchEventPool.free(touchEvents.get(i));
            touchEvents.clear();
            touchEvents.addAll(touchEventsBuffer);
            touchEventsBuffer.clear();
            return touchEvents;
        }
    }

    // returns the index for a given pointerId or -1 if no index.
    private int getIndex(int pointerId) {
        for (int i = 0; i < MAX_TOUCHPOINTS; i++) {
            if (id[i] == pointerId) {
                return i;
            }
        }
        return -1;
    }


    public enum TouchType {
        flyingUp, flyingUpLong, flyingDown, flyingDownBottom, flyingRight, flingLeft


    }

    public boolean isShootRequested() {
        boolean temp = shootRequested;
        shootRequested = false;

        return temp;
    }

    public void setShootRequested(boolean shootRequested) {
        this.shootRequested = shootRequested;
    }

    private static final String DEBUG_TAG = "Gestures";
    private GestureDetector mDetector;
    private TouchType touchtype;


    @Override
    public boolean onDown(MotionEvent event) {
        //if (Assets._DEBUG)
            //Log.d(DEBUG_TAG, "onDown: " + event.toString());
        return true;
    }

    @Override
    public boolean onFling(MotionEvent event1, MotionEvent event2,
                           float velocityX, float velocityY) {

        // Grab two events located on the plane at e1=(x1, y1) and e2=(x2, y2)
        // Let e1 be the initial event
        // e2 can be located at 4 different positions, consider the following diagram
        // (Assume that lines are separated by 90 degrees.)
        //
        //
        //         \ A  /
        //          \  /
        //       D   e1   B
        //          /  \
        //         / C  \
        //
        // So if (x2,y2) falls in region:
        //  A => it's an UP swipe
        //  B => it's a RIGHT swipe
        //  C => it's a DOWN swipe
        //  D => it's a LEFT swipe
        //

        float x1 = event1.getX();
        float y1 = event1.getY();

        float x2 = event2.getX();
        float y2 = event2.getY();

        /*boolean isLongSwipe = false;
        if (Math.abs(y1 - y2) > LONG_SWIPE_THRESHOLD)
            isLongSwipe = true;*/
        swipeDirection = getDirection(x1, y1, x2, y2);
      //  if (Assets._DEBUG)
          //  Log.d(DEBUG_TAG, "onFling: " + event1.toString() + event2.toString());

        return true;


    }

    public Direction getSwipeDirection() {
        Direction temp = swipeDirection;
        swipeDirection = null;
        return temp;
    }

    @Override
    public void onLongPress(MotionEvent event) {
        swipeDirection = Direction.longUp;
        //if (Assets._DEBUG)
         //   Log.d(DEBUG_TAG, "onLongPress: " + event.toString());
    }

    @Override
    public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
       // if (Assets._DEBUG)
         //   Log.d(DEBUG_TAG, "onScroll: " + e1.toString() + e2.toString());
        return true;
    }

    @Override
    public void onShowPress(MotionEvent event) {
        //if (Assets._DEBUG)
       //     Log.d(DEBUG_TAG, "onShowPress: " + event.toString());
    }

    @Override
    public boolean onSingleTapUp(MotionEvent event) {
        //if (Assets._DEBUG)
       //     Log.d(DEBUG_TAG, "onSingleTapUp: " + event.toString());
        shootRequested = true;
        return true;
    }

    @Override
    public boolean onDoubleTap(MotionEvent event) {
        //if (Assets._DEBUG)
          //  Log.d(DEBUG_TAG, "onDoubleTap: " + event.toString());

        return true;
    }

    @Override
    public boolean onDoubleTapEvent(MotionEvent event) {
        //if (Assets._DEBUG)
          //  Log.d(DEBUG_TAG, "onDoubleTapEvent: " + event.toString());
        return true;
    }

    @Override
    public boolean onSingleTapConfirmed(MotionEvent event) {
        //if (Assets._DEBUG)
            //Log.d(DEBUG_TAG, "onSingleTapConfirmed: " + event.toString());

        return true;
    }

    /**
     * Given two points in the plane p1=(x1, x2) and p2=(y1, y1), this method
     * returns the direction that an arrow pointing from p1 to p2 would have.
     *
     * @param x1 the x position of the first point
     * @param y1 the y position of the first point
     * @param x2 the x position of the second point
     * @param y2 the y position of the second point
     * @return the direction
     */
    public Direction getDirection(float x1, float y1, float x2, float y2) {
        double angle = getAngle(x1, y1, x2, y2);
        return Direction.get(angle);
    }

    /**
     * Finds the angle between two points in the plane (x1,y1) and (x2, y2)
     * The angle is measured with 0/360 being the X-axis to the right, angles
     * increase counter clockwise.
     *
     * @param x1 the x position of the first point
     * @param y1 the y position of the first point
     * @param x2 the x position of the second point
     * @param y2 the y position of the second point
     * @return the angle between two points
     */
    public double getAngle(float x1, float y1, float x2, float y2) {

        double rad = Math.atan2(y1 - y2, x2 - x1) + Math.PI;
        return (rad * 180 / Math.PI + 180) % 360;
    }


    public enum Direction {
        up,
        down,
        left,
        right,
        longUp,
        longDown;

        /**
         * Returns a direction given an angle.
         * Directions are defined as follows:
         * <p/>
         * Up: [45, 135]
         * Right: [0,45] and [315, 360]
         * Down: [225, 315]
         * Left: [135, 225]
         *
         * @param angle an angle from 0 to 360 - e
         * @return the direction of an angle
         */
        public static Direction get(double angle) {
            if (inRange(angle, 45, 135)) {
                return Direction.up;
            } else if (inRange(angle, 0, 45) || inRange(angle, 315, 360)) {
                return Direction.right;
            } else if (inRange(angle, 225, 315)) {
                return Direction.down;
            } else {
                return Direction.left;
            }

        }

        /**
         * @param angle an angle
         * @param init  the initial bound
         * @param end   the final bound
         * @return returns true if the given angle is in the interval [init, end).
         */
        private static boolean inRange(double angle, float init, float end) {
            return (angle >= init) && (angle < end);
        }
    }

}