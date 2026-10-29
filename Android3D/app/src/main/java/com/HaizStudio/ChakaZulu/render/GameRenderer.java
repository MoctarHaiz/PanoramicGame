package com.HaizStudio.ChakaZulu.render;

import android.opengl.GLES30;
import android.opengl.GLSurfaceView;
import android.opengl.Matrix;

import com.HaizStudio.ChakaZulu.game.Hero;
import com.HaizStudio.ChakaZulu.game.Level;
import com.HaizStudio.ChakaZulu.game.Level.Bandit;
import com.HaizStudio.ChakaZulu.game.Level.Bob;
import com.HaizStudio.ChakaZulu.game.Level.Obstacle;
import com.HaizStudio.ChakaZulu.game.World;
import com.HaizStudio.ChakaZulu.gl.Mesh;
import com.HaizStudio.ChakaZulu.gl.MeshBuilder;
import com.HaizStudio.ChakaZulu.gl.Shader;
import com.HaizStudio.ChakaZulu.gl.Shaders;
import com.HaizStudio.ChakaZulu.gl.ShadowMap;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

/** Draws the world. Also advances it: the game runs on the GL thread. */
public final class GameRenderer implements GLSurfaceView.Renderer {

    private static final float[] SUN = normalize(-0.55f, 0.42f, -0.72f);
    private static final float[] SUN_COLOR = {1.02f, 0.86f, 0.64f};
    private static final float[] SKY_AMBIENT = {0.40f, 0.45f, 0.58f};
    private static final float[] GROUND_AMBIENT = {0.30f, 0.22f, 0.15f};
    private static final float FOG_NEAR = 50, FOG_FAR = 165;
    private static final float SHADOW_RADIUS = 34;
    private static final int SHADOW_SIZE = 2048;

    private final World world;
    private final Models models = new Models();
    private final Rig rig = new Rig();
    private final CameraRig camera = new CameraRig();
    private final MeshBuilder builder = new MeshBuilder();
    private final Map<Integer, Mesh[]> chunks = new HashMap<>();
    private Level chunkLevel;
    private ChunkBuilder chunkBuilder;

    private Shader lit, depth, sky, particle;
    private ShadowMap shadow;
    private int emptyVao;

    private final float[] view = new float[16], proj = new float[16], viewProj = new float[16], invViewProj = new float[16];
    private final float[] lightView = new float[16], lightProj = new float[16], lightViewProj = new float[16];
    private final float[] model = new float[16], identity = new float[16];
    private final float[] right = new float[3], up = new float[3], tmp4 = new float[4], tmp4b = new float[4];
    private int width = 1, height = 1;
    private long lastFrame;

    /** Set from the UI thread: freezes the game (the picture keeps drawing). */
    public volatile boolean paused;

    public GameRenderer(World world) {
        this.world = world;
        Matrix.setIdentityM(identity, 0);
    }

    private static float[] normalize(float x, float y, float z) {
        float l = (float) Math.sqrt(x * x + y * y + z * z);
        return new float[]{x / l, y / l, z / l};
    }

    // --------------------------------------------------------- GL lifecycle

    @Override
    public void onSurfaceCreated(GL10 unused, EGLConfig config) {
        lit = new Shader(Shaders.LIT_VERTEX, Shaders.LIT_FRAGMENT);
        depth = new Shader(Shaders.DEPTH_VERTEX, Shaders.DEPTH_FRAGMENT);
        sky = new Shader(Shaders.SKY_VERTEX, Shaders.SKY_FRAGMENT);
        particle = new Shader(Shaders.PARTICLE_VERTEX, Shaders.PARTICLE_FRAGMENT);
        shadow = new ShadowMap(SHADOW_SIZE);
        int[] ids = new int[1];
        GLES30.glGenVertexArrays(1, ids, 0);
        emptyVao = ids[0];
        models.build();
        world.particles.initGl();
        chunks.clear(); // the old GL context and its meshes are gone
        chunkLevel = null;
        camera.reset();
        lastFrame = System.nanoTime();
        GLES30.glEnable(GLES30.GL_DEPTH_TEST);
        GLES30.glDepthFunc(GLES30.GL_LEQUAL);
    }

    @Override
    public void onSurfaceChanged(GL10 unused, int w, int h) {
        width = Math.max(1, w);
        height = Math.max(1, h);
        GLES30.glViewport(0, 0, width, height);
    }

    @Override
    public void onDrawFrame(GL10 unused) {
        long now = System.nanoTime();
        float dt = (now - lastFrame) / 1e9f;
        lastFrame = now;

        if (!paused) world.update(dt);

        Level level = world.level;
        if (level == null) {
            GLES30.glClearColor(0.98f, 0.82f, 0.6f, 1);
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT | GLES30.GL_DEPTH_BUFFER_BIT);
            return;
        }
        if (level != chunkLevel) {
            for (Mesh[] c : chunks.values()) deleteChunk(c);
            chunks.clear();
            chunkLevel = level;
            chunkBuilder = new ChunkBuilder(level);
        }
        updateChunks(level);

        camera.update(world, paused ? 0 : dt, width / (float) height, view, proj);
        Matrix.multiplyMM(viewProj, 0, proj, 0, view, 0);
        Matrix.invertM(invViewProj, 0, viewProj, 0);
        right[0] = view[0];
        right[1] = view[4];
        right[2] = view[8];
        up[0] = view[1];
        up[1] = view[5];
        up[2] = view[9];
        computeLight();

        shadowPass(level);
        mainPass(level);
    }

    // --------------------------------------------------------------- chunks

    private void updateChunks(Level level) {
        float d = world.hero.d;
        int last = (int) ((level.length + 90) / ChunkBuilder.LENGTH);
        int first = Math.max(-3, (int) Math.floor((d - 30) / ChunkBuilder.LENGTH)); // also behind the start line
        int end = Math.min(last, (int) Math.floor((d + 200) / ChunkBuilder.LENGTH));

        Iterator<Map.Entry<Integer, Mesh[]>> it = chunks.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<Integer, Mesh[]> e = it.next();
            if (e.getKey() < first - 1 || e.getKey() > end + 1) {
                deleteChunk(e.getValue());
                it.remove();
            }
        }
        // Build what is missing: everything at once at the start, then one chunk per frame.
        boolean all = chunks.isEmpty();
        for (int i = first; i <= end; i++) {
            if (chunks.containsKey(i)) continue;
            builder.clear();
            chunkBuilder.terrain(builder, i);
            Mesh terrain = builder.build();
            builder.clear();
            chunkBuilder.water(builder, i);
            Mesh water = builder.floatCount() > 0 ? builder.build() : null;
            chunks.put(i, new Mesh[]{terrain, water});
            if (!all) break;
        }
    }

    private static void deleteChunk(Mesh[] c) {
        for (Mesh m : c)
            if (m != null) m.delete();
    }

    // ---------------------------------------------------------------- light

    private void computeLight() {
        Hero h = world.hero;
        Matrix.setLookAtM(lightView, 0, SUN[0] * 100, SUN[1] * 100, SUN[2] * 100, 0, 0, 0, 0, 1, 0);
        tmp4[0] = h.x * 0.3f;
        tmp4[1] = 0;
        tmp4[2] = -(h.d + 15);
        tmp4[3] = 1;
        Matrix.multiplyMV(tmp4b, 0, lightView, 0, tmp4, 0);
        float texel = SHADOW_RADIUS * 2 / SHADOW_SIZE;
        float cx = (float) Math.floor(tmp4b[0] / texel) * texel, cy = (float) Math.floor(tmp4b[1] / texel) * texel;
        float cz = -tmp4b[2];
        Matrix.orthoM(lightProj, 0, cx - SHADOW_RADIUS, cx + SHADOW_RADIUS, cy - SHADOW_RADIUS, cy + SHADOW_RADIUS,
                cz - 120, cz + 120);
        Matrix.multiplyMM(lightViewProj, 0, lightProj, 0, lightView, 0);
    }

    private void shadowPass(Level level) {
        shadow.begin();
        GLES30.glDisable(GLES30.GL_CULL_FACE);
        depth.use();
        depth.setMatrix("uViewProj", lightViewProj);
        float d = world.hero.d;
        depth.setMatrix("uModel", identity);
        for (Map.Entry<Integer, Mesh[]> e : chunks.entrySet()) {
            float c0 = e.getKey() * ChunkBuilder.LENGTH;
            if (c0 > d + 60 || c0 + ChunkBuilder.LENGTH < d - 20) continue;
            e.getValue()[0].draw();
        }
        drawObjects(depth, level, d - 15, d + 55, true);
        shadow.end(width, height);
    }

    // ------------------------------------------------------------ main pass

    private void mainPass(Level level) {
        GLES30.glClearColor(0.98f, 0.82f, 0.6f, 1);
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT | GLES30.GL_DEPTH_BUFFER_BIT);
        float[] eye = camera.eye;

        // Sky
        GLES30.glDisable(GLES30.GL_DEPTH_TEST);
        GLES30.glDepthMask(false);
        sky.use();
        sky.setMatrix("uInvViewProj", invViewProj);
        sky.set("uCamPos", eye);
        sky.set("uSunDir", SUN);
        GLES30.glBindVertexArray(emptyVao);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);
        GLES30.glDepthMask(true);
        GLES30.glEnable(GLES30.GL_DEPTH_TEST);
        GLES30.glEnable(GLES30.GL_CULL_FACE);

        lit.use();
        lit.setMatrix("uViewProj", viewProj);
        lit.setMatrix("uLightViewProj", lightViewProj);
        lit.set("uCamPos", eye);
        lit.set("uSunDir", SUN);
        lit.set("uSunColor", SUN_COLOR);
        lit.set("uSkyAmbient", SKY_AMBIENT);
        lit.set("uGroundAmbient", GROUND_AMBIENT);
        lit.set("uTime", world.time);
        lit.setInt("uShadowMap", 0);
        lit.set("uShadowTexel", 1f / SHADOW_SIZE);
        shadow.bind(0);
        defaults();

        // Mountains and clouds ride with the camera so they never come closer.
        lit.set("uFog", 90, 720);
        Matrix.setIdentityM(model, 0);
        Matrix.translateM(model, 0, eye[0], 0, eye[2]);
        lit.setMatrix("uModel", model);
        models.mountains.draw();
        Matrix.rotateM(model, 0, world.time * 0.4f, 0, 1, 0);
        lit.setMatrix("uModel", model);
        lit.set("uEmissive", 0.7f);
        models.clouds.draw();
        lit.set("uEmissive", 0);

        lit.set("uFog", FOG_NEAR, FOG_FAR);
        lit.setMatrix("uModel", identity);
        for (Mesh[] c : chunks.values()) c[0].draw();

        lit.set("uWave", 1);
        lit.set("uSpecular", 0.9f);
        lit.set("uEmissive", 0.06f);
        for (Mesh[] c : chunks.values())
            if (c[1] != null) c[1].draw();
        defaults();

        float d = world.hero.d;
        drawObjects(lit, level, d - 12, d + 165, false);

        // Shield bubble
        Hero h = world.hero;
        if (h.shield > 0 && world.state == World.State.PLAYING) {
            float pulse = 1 + (float) Math.sin(world.time * 6) * 0.04f;
            Matrix.setIdentityM(model, 0);
            Matrix.translateM(model, 0, h.x, h.y + (h.sliding() ? 0.5f : 1.0f), -h.d);
            Matrix.scaleM(model, 0, pulse, pulse * (h.sliding() ? 0.7f : 1f), pulse);
            GLES30.glEnable(GLES30.GL_BLEND);
            GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE);
            GLES30.glDepthMask(false);
            lit.setMatrix("uModel", model);
            float fade = Math.min(1, h.shield / 1.5f);
            float blink = h.shield < 2 && ((int) (world.time * 8)) % 2 == 0 ? 0.4f : 1f;
            lit.set("uAlpha", 0.22f * fade * blink);
            lit.set("uEmissive", 0.8f);
            models.shieldBubble.draw();
            GLES30.glDepthMask(true);
            GLES30.glDisable(GLES30.GL_BLEND);
            defaults();
        }

        GLES30.glDisable(GLES30.GL_CULL_FACE);
        world.particles.render(particle, viewProj, right, up, world.time);
        GLES30.glBindVertexArray(0);
    }

    private void defaults() {
        lit.set("uEmissive", 0);
        lit.set("uSpecular", 0);
        lit.set("uFlash", 0);
        lit.set("uAlpha", 1);
        lit.set("uTint", 1, 1, 1);
        lit.set("uWave", 0);
    }

    // -------------------------------------------------------------- objects

    private void drawObjects(Shader s, Level level, float from, float to, boolean shadowPass) {
        boolean main = !shadowPass;

        for (Obstacle o : level.obstacles) {
            if (o.broken || o.d < from || o.d > to) continue;
            Mesh mesh;
            switch (o.type) {
                case Obstacle.LOG: mesh = o.halfWidth > 1.5f ? models.logWide : models.logLane; break;
                case Obstacle.CRATES: mesh = o.top > 2.5f ? models.crates3 : models.crates2; break;
                case Obstacle.ROCK: mesh = models.rock; break;
                default: mesh = models.gate; break;
            }
            Matrix.setIdentityM(model, 0);
            Matrix.translateM(model, 0, o.x, 0, -o.d);
            if (o.type == Obstacle.ROCK) Matrix.rotateM(model, 0, o.variant * 70, 0, 1, 0);
            s.setMatrix("uModel", model);
            mesh.draw();
        }

        // Finish arch and the HOME log
        if (level.length + 30 > from && level.length - 20 < to) {
            Matrix.setIdentityM(model, 0);
            Matrix.translateM(model, 0, 0, 0, -level.length);
            s.setMatrix("uModel", model);
            models.finishArch.draw();
            Matrix.setIdentityM(model, 0);
            Matrix.translateM(model, 0, 0, -0.45f, -(level.length + 23));
            s.setMatrix("uModel", model);
            models.home.draw();
        }

        // Red bobs
        float t = world.time;
        for (Bob b : level.bobs) {
            if (b.taken || b.d < from || b.d > to) continue;
            Matrix.setIdentityM(model, 0);
            Matrix.translateM(model, 0, b.x, b.y + (float) Math.sin(t * 3 + b.d) * 0.1f, -b.d);
            if (b.golden) {
                Matrix.rotateM(model, 0, t * 140, 0, 1, 0);
                if (main) {
                    s.set("uEmissive", 0.45f + (float) Math.sin(t * 8) * 0.15f);
                    s.set("uSpecular", 1f);
                }
                s.setMatrix("uModel", model);
                models.goldenBob.draw();
            } else {
                Matrix.rotateM(model, 0, (float) Math.sin(t * 2.2f + b.d) * 28, 0, 1, 0);
                float pop = 1 + (float) Math.sin(t * 6 + b.d * 1.7f) * 0.04f;
                Matrix.scaleM(model, 0, pop, pop, pop);
                if (main) {
                    s.set("uEmissive", 0.12f);
                    s.set("uSpecular", 0.6f);
                }
                s.setMatrix("uModel", model);
                models.bob.draw();
            }
        }
        if (main) {
            s.set("uEmissive", 0);
            s.set("uSpecular", 0);
        }

        // Rings in flight
        if (main) s.set("uEmissive", 0.25f);
        for (World.Ring r : world.rings) {
            Matrix.setIdentityM(model, 0);
            Matrix.translateM(model, 0, r.x, r.y, -r.d);
            Matrix.rotateM(model, 0, (float) Math.toDegrees(r.spin), 1, 0, 0);
            Matrix.rotateM(model, 0, 90, 0, 0, 1);
            s.setMatrix("uModel", model);
            models.ring.draw();
        }
        if (main) s.set("uEmissive", 0);

        // Characters
        rig.use(s);
        for (Bandit b : level.bandits) {
            if (b.d < from || b.d > to) continue;
            rig.bandit(models, b, world);
        }
        Hero h = world.hero;
        if (h.sinking < 0.5f) { // hidden once under water
            boolean blink = main && h.invulnerable > 0 && world.state == World.State.PLAYING && ((int) (t * 14)) % 2 == 0;
            if (blink) s.set("uFlash", 0.55f);
            rig.hero(models, h, world);
            if (blink) s.set("uFlash", 0);
        }
    }

}
