package com.HaizStudio.framework.implementation;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

import com.HaizStudio.ChakaZulu.Assets;
import com.HaizStudio.framework.Image;

public class AndroidFastRenderView extends SurfaceView implements Runnable {
    JeuAndroid game;
    Bitmap framebuffer;
    Thread renderThread = null;
    SurfaceHolder holder;
    volatile boolean running = false;

    public AndroidFastRenderView(JeuAndroid game, Bitmap framebuffer) {
        super(game);
        this.game = game;
        this.framebuffer = framebuffer;
        this.holder = getHolder();
    }

    public void resume() {
        running = true;
        renderThread = new Thread(this);
        renderThread.start();
    }

    //double FPS = 0, timeFPS, deltaTime;
    //int count = 0;
    // float fps = 60;
    long previousTime = System.currentTimeMillis();


    //int FRAMES_PER_SECOND = 30;
    //int SKIP_TICKS = 1000 / FRAMES_PER_SECOND;
    long next_game_tick = System.currentTimeMillis();
    // long sleep_time = 0;


    double previous = System.currentTimeMillis();
    float lag = 0.0f;


   // int TICKS_PER_SECOND = 25;
   // float SKIP_TICKS = 1000 / TICKS_PER_SECOND;
    int MAX_FRAMESKIP = 5;
    int loops;
    float interpolation;


    int UPDATE_PER_SECOND = 40;
    float MS_PER_UPDATE = 1000 / UPDATE_PER_SECOND;

    public void run() {
        Canvas canvas = null;
        try {
            Rect dstRect = new Rect();
            //long startTime = System.nanoTime();
            //timeFPS = System.nanoTime();
            while (running) {
                loops = 0;
                previousTime = System.currentTimeMillis();


                double current = System.currentTimeMillis();
                double elapsed = current - previous;
                previous = current;
                lag += elapsed;

                //next_game_tick = System.currentTimeMillis();
                //count++;
                // double deltaTimeFPS = (System.nanoTime() - timeFPS) * 10e-9;
                /*if (Assets._DEBUG) {
                    if (deltaTimeFPS > 1) {
                        FPS = count / (deltaTimeFPS);
                        count = 0;
                        timeFPS = System.nanoTime();
                    }
                }

*/
                if (!holder.getSurface().isValid())
                    continue;


                //float deltaTime = (System.nanoTime() - startTime) / 10000000.000f;
                //startTime = System.nanoTime();

                //if (deltaTime > 3.15) {
                //   deltaTime = (float) 3.15;
                //}


                //while (System.currentTimeMillis() > next_game_tick && loops < MAX_FRAMESKIP) {

                while (lag >= MS_PER_UPDATE) {
                    game.getCurrentScreen().update(0);
                    lag -= MS_PER_UPDATE;
                    //next_game_tick += SKIP_TICKS;
                    loops++;
                    //Log.i("loops: ", " " + loops);
                }
                //game.getCurrentScreen().update(deltaTime);


                //deltaTimeFPS = System.nanoTime();


                canvas = holder.lockCanvas();

                if (canvas == null) {
                    try {
                        Thread.sleep(1);
                    } catch (Exception ie) {

                    } finally {
                        continue;
                    }
                } //Log.i("Frame lock Time: ", " " + (System.nanoTime() - deltaTimeFPS) * 10e-6 + " ms");
                else {

                    // deltaTimeFPS = System.nanoTime();
                    canvas.getClipBounds(dstRect);
                    //Log.i("Frame clip Time: ", " " + (System.nanoTime() - deltaTimeFPS) * 10e-6 + " ms");


                    //interpolation = (System.currentTimeMillis() + SKIP_TICKS - next_game_tick)
                      //      / SKIP_TICKS;
                    //Log.i("interpolation: ", " " + interpolation);

                    interpolation = lag / MS_PER_UPDATE;
                    //Log.i("interpolation: ", " " + interpolation);

                    //deltaTimeFPS = System.nanoTime();
                    game.getCurrentScreen().paintNew(interpolation, canvas);
                    //game.getCurrentScreen().paint(deltaTime);
                    // Log.i("Fame paint Time: ", " " + (System.nanoTime() - deltaTimeFPS) * 10e-6 + " ms");


                    //deltaTimeFPS = System.nanoTime();
                    //canvas =  game.getGraphics().getCanvas();
                    //canvas.drawBitmap(framebuffer, null, dstRect, null);
                    //Log.i("DrawOld: ", " " + (System.nanoTime() - deltaTimeFPS) * 10e-6 + " ms");


                    //deltaTimeFPS = System.nanoTime();
                    holder.unlockCanvasAndPost(canvas);

                    // Log.i("Fame unlock: ", " " + (System.nanoTime() - deltaTimeFPS) * 10e-6 + " ms");


                    //   long currentTimeMillis = System.currentTimeMillis();
                    // long elapsedTimeMs = currentTimeMillis - previousTime;
                    //long sleepTimeMs = (long) (1000f / fps - elapsedTimeMs);

                }


               /* next_game_tick += SKIP_TICKS;
                sleep_time = next_game_tick - System.currentTimeMillis();
                //Log.i("sleep_time: ", " " + sleep_time);

                if (sleep_time >= 0) {
                    try {
                        Thread.sleep(sleep_time);
                        //Log.i("sleep_timeX: ", " " + sleep_time);
                    } catch (Exception ie) {
                        Log.i("sleep_time: ", " CAtch EXception");
                    } finally {

                    }
                } else {
                    // Shit, we are running behind!
                }
*/

                if (!Assets._DEBUG) {
                    long currentTimeMillis = System.currentTimeMillis();
                    long elapsedTimeMs = currentTimeMillis - previousTime;
                    float fps = (1000f / elapsedTimeMs);
                    //Log.i("FPS: ", " " + fps);
                }
            }

        } catch (IllegalArgumentException ie) {
            ie.printStackTrace();
        } finally {
            if (canvas != null) {
                //                holder.unlockCanvasAndPost(canvas);
            }
        }

    }


    public void pause() {
        running = false;
        while (true) {
            try {
                renderThread.join();
                break;
            } catch (InterruptedException e) {
                // retry
            }

        }
    }


    public void drawImage(Image Image, Rect rect, Canvas canvas) {
        canvas.drawBitmap(((ImageAndroid) Image).bitmap, rect.left, rect.top, null);

    }

}
