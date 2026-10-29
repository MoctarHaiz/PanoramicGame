package com.HaizStudio.ChakaZulu.platform;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.media.SoundPool;

import com.HaizStudio.ChakaZulu.game.World;

/** Music and sound effects. play() is safe to call from the game thread. */
public final class Sounds {

    private static final String[] FILES = new String[12];

    static {
        FILES[World.SFX_COIN] = "coin.ogg";
        FILES[World.SFX_GOLD] = "gold.ogg";
        FILES[World.SFX_JUMP] = "jump.ogg";
        FILES[World.SFX_SLIDE] = "slide.ogg";
        FILES[World.SFX_THROW] = "projectile.ogg";
        FILES[World.SFX_BANDIT] = "enemy.ogg";
        FILES[World.SFX_STOMP] = "stomp.ogg";
        FILES[World.SFX_CRASH] = "crash.ogg";
        FILES[World.SFX_SPLASH] = "splash.ogg";
        FILES[World.SFX_SMASH] = "smash.ogg";
        FILES[World.SFX_WIN] = "win.ogg";
        FILES[World.SFX_LOSE] = "lose.ogg";
    }

    private static final float[] VOLUME = {0.55f, 0.8f, 0.45f, 0.5f, 0.6f, 0.8f, 0.8f, 0.9f, 0.8f, 0.7f, 0.9f, 0.9f};

    private final SoundPool pool;
    private final int[] ids = new int[FILES.length];
    private MediaPlayer music;
    private volatile boolean sfxOn = true;
    private boolean musicOn = true;
    private boolean musicWanted;

    public Sounds(Context context) {
        AudioAttributes attributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build();
        pool = new SoundPool.Builder().setMaxStreams(8).setAudioAttributes(attributes).build();
        for (int i = 0; i < FILES.length; i++) {
            try (AssetFileDescriptor fd = context.getAssets().openFd("audio/" + FILES[i])) {
                ids[i] = pool.load(fd, 1);
            } catch (Exception e) {
                ids[i] = 0;
            }
        }
        try (AssetFileDescriptor fd = context.getAssets().openFd("audio/chaka.mp3")) {
            music = new MediaPlayer();
            music.setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build());
            music.setDataSource(fd.getFileDescriptor(), fd.getStartOffset(), fd.getLength());
            music.setLooping(true);
            music.setVolume(0.42f, 0.42f);
            music.prepare();
        } catch (Exception e) {
            music = null;
        }
    }

    public void play(int id, float rate) {
        if (!sfxOn || id < 0 || id >= ids.length || ids[id] == 0) return;
        pool.play(ids[id], VOLUME[id], VOLUME[id], 1, 0, Math.max(0.5f, Math.min(2f, rate)));
    }

    public void setSfx(boolean on) {
        sfxOn = on;
    }

    public void setMusic(boolean on) {
        musicOn = on;
        update();
    }

    /** Music plays while the app is in front. */
    public void resume() {
        musicWanted = true;
        update();
    }

    public void pause() {
        musicWanted = false;
        update();
    }

    private void update() {
        if (music == null) return;
        if (musicOn && musicWanted) {
            if (!music.isPlaying()) music.start();
        } else if (music.isPlaying()) {
            music.pause();
        }
    }

    public void release() {
        pool.release();
        if (music != null) music.release();
    }
}
