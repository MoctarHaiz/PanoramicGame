package com.HaizStudio.ChakaZulu.gl;

import android.opengl.GLES30;

import java.util.HashMap;
import java.util.Map;

/** A compiled GLSL program with cached uniform locations. */
public final class Shader {

    public final int program;
    private final Map<String, Integer> locations = new HashMap<>();

    public Shader(String vertexSource, String fragmentSource) {
        int vs = compile(GLES30.GL_VERTEX_SHADER, vertexSource);
        int fs = compile(GLES30.GL_FRAGMENT_SHADER, fragmentSource);
        program = GLES30.glCreateProgram();
        GLES30.glAttachShader(program, vs);
        GLES30.glAttachShader(program, fs);
        GLES30.glLinkProgram(program);
        int[] status = new int[1];
        GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, status, 0);
        if (status[0] == 0)
            throw new RuntimeException("Shader link failed: " + GLES30.glGetProgramInfoLog(program));
        GLES30.glDeleteShader(vs);
        GLES30.glDeleteShader(fs);
    }

    private static int compile(int type, String source) {
        int shader = GLES30.glCreateShader(type);
        GLES30.glShaderSource(shader, source);
        GLES30.glCompileShader(shader);
        int[] status = new int[1];
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0);
        if (status[0] == 0)
            throw new RuntimeException("Shader compile failed: " + GLES30.glGetShaderInfoLog(shader) + "\n" + source);
        return shader;
    }

    public void use() {
        GLES30.glUseProgram(program);
    }

    private int loc(String name) {
        Integer l = locations.get(name);
        if (l == null) {
            l = GLES30.glGetUniformLocation(program, name);
            locations.put(name, l);
        }
        return l;
    }

    public void set(String name, float v) {
        GLES30.glUniform1f(loc(name), v);
    }

    public void set(String name, float x, float y) {
        GLES30.glUniform2f(loc(name), x, y);
    }

    public void set(String name, float x, float y, float z) {
        GLES30.glUniform3f(loc(name), x, y, z);
    }

    public void set(String name, float[] v3) {
        GLES30.glUniform3f(loc(name), v3[0], v3[1], v3[2]);
    }

    public void setInt(String name, int v) {
        GLES30.glUniform1i(loc(name), v);
    }

    public void setMatrix(String name, float[] m) {
        GLES30.glUniformMatrix4fv(loc(name), 1, false, m, 0);
    }
}
