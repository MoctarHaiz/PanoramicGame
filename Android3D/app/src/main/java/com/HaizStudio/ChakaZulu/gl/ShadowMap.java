package com.HaizStudio.ChakaZulu.gl;

import android.opengl.GLES30;

/** Depth texture rendered from the sun, sampled with hardware comparison (soft PCF in the shader). */
public final class ShadowMap {

    public final int size;
    private int framebuffer;
    private int texture;

    public ShadowMap(int size) {
        this.size = size;
        int[] ids = new int[1];
        GLES30.glGenTextures(1, ids, 0);
        texture = ids[0];
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, texture);
        GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_DEPTH_COMPONENT24, size, size, 0,
                GLES30.GL_DEPTH_COMPONENT, GLES30.GL_UNSIGNED_INT, null);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_COMPARE_MODE, GLES30.GL_COMPARE_REF_TO_TEXTURE);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_COMPARE_FUNC, GLES30.GL_LEQUAL);

        GLES30.glGenFramebuffers(1, ids, 0);
        framebuffer = ids[0];
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffer);
        GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER, GLES30.GL_DEPTH_ATTACHMENT, GLES30.GL_TEXTURE_2D, texture, 0);
        GLES30.glDrawBuffers(1, new int[]{GLES30.GL_NONE}, 0);
        GLES30.glReadBuffer(GLES30.GL_NONE);
        int status = GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER);
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0);
        if (status != GLES30.GL_FRAMEBUFFER_COMPLETE)
            throw new RuntimeException("Shadow framebuffer incomplete: " + status);
    }

    public void begin() {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffer);
        GLES30.glViewport(0, 0, size, size);
        GLES30.glClear(GLES30.GL_DEPTH_BUFFER_BIT);
        GLES30.glEnable(GLES30.GL_POLYGON_OFFSET_FILL);
        GLES30.glPolygonOffset(2f, 4f);
    }

    public void end(int width, int height) {
        GLES30.glDisable(GLES30.GL_POLYGON_OFFSET_FILL);
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0);
        GLES30.glViewport(0, 0, width, height);
    }

    public void bind(int unit) {
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0 + unit);
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, texture);
    }
}
