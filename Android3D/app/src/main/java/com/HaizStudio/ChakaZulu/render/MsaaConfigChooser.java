package com.HaizStudio.ChakaZulu.render;

import android.opengl.GLSurfaceView;

import javax.microedition.khronos.egl.EGL10;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.egl.EGLDisplay;

/** OpenGL ES 3 surface with 4x anti-aliasing when the device supports it. */
public final class MsaaConfigChooser implements GLSurfaceView.EGLConfigChooser {

    private static final int EGL_OPENGL_ES3_BIT = 0x40;

    @Override
    public EGLConfig chooseConfig(EGL10 egl, EGLDisplay display) {
        EGLConfig config = choose(egl, display, 4);
        if (config == null) config = choose(egl, display, 0);
        if (config == null) throw new IllegalStateException("No OpenGL ES 3 configuration");
        return config;
    }

    private static EGLConfig choose(EGL10 egl, EGLDisplay display, int samples) {
        int[] attributes = samples > 0
                ? new int[]{EGL10.EGL_RED_SIZE, 8, EGL10.EGL_GREEN_SIZE, 8, EGL10.EGL_BLUE_SIZE, 8, EGL10.EGL_DEPTH_SIZE, 24,
                EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL10.EGL_SAMPLE_BUFFERS, 1, EGL10.EGL_SAMPLES, samples, EGL10.EGL_NONE}
                : new int[]{EGL10.EGL_RED_SIZE, 8, EGL10.EGL_GREEN_SIZE, 8, EGL10.EGL_BLUE_SIZE, 8, EGL10.EGL_DEPTH_SIZE, 24,
                EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL10.EGL_NONE};
        int[] count = new int[1];
        EGLConfig[] configs = new EGLConfig[1];
        if (egl.eglChooseConfig(display, attributes, configs, 1, count) && count[0] > 0) return configs[0];
        return null;
    }
}
