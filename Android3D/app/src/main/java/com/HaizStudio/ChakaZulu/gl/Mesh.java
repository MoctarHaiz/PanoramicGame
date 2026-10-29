package com.HaizStudio.ChakaZulu.gl;

import android.opengl.GLES30;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;

/**
 * Static triangle mesh on the GPU. Vertex layout: position (3), normal (3), colour (3).
 */
public final class Mesh {

    public static final int FLOATS_PER_VERTEX = 9;
    private static final int STRIDE = FLOATS_PER_VERTEX * 4;

    private final int vao;
    private final int vbo;
    private final int vertexCount;

    public Mesh(float[] data, int floatCount) {
        vertexCount = floatCount / FLOATS_PER_VERTEX;
        FloatBuffer buffer = ByteBuffer.allocateDirect(floatCount * 4).order(ByteOrder.nativeOrder()).asFloatBuffer();
        buffer.put(data, 0, floatCount).position(0);

        int[] ids = new int[1];
        GLES30.glGenVertexArrays(1, ids, 0);
        vao = ids[0];
        GLES30.glGenBuffers(1, ids, 0);
        vbo = ids[0];

        GLES30.glBindVertexArray(vao);
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo);
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, floatCount * 4, buffer, GLES30.GL_STATIC_DRAW);
        GLES30.glEnableVertexAttribArray(0);
        GLES30.glVertexAttribPointer(0, 3, GLES30.GL_FLOAT, false, STRIDE, 0);
        GLES30.glEnableVertexAttribArray(1);
        GLES30.glVertexAttribPointer(1, 3, GLES30.GL_FLOAT, false, STRIDE, 12);
        GLES30.glEnableVertexAttribArray(2);
        GLES30.glVertexAttribPointer(2, 3, GLES30.GL_FLOAT, false, STRIDE, 24);
        GLES30.glBindVertexArray(0);
    }

    public void draw() {
        if (vertexCount == 0) return;
        GLES30.glBindVertexArray(vao);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, vertexCount);
    }

    public void delete() {
        GLES30.glDeleteBuffers(1, new int[]{vbo}, 0);
        GLES30.glDeleteVertexArrays(1, new int[]{vao}, 0);
    }
}
