package com.HaizStudio.ChakaZulu.platform;

import android.content.Context;
import android.content.SharedPreferences;

/** Progress and settings stored on the phone. */
public final class Save {

    private final SharedPreferences prefs;

    public Save(Context context) {
        prefs = context.getSharedPreferences("chakazulu3d", Context.MODE_PRIVATE);
    }

    public int unlockedLevel() {
        return Math.max(1, prefs.getInt("unlocked", 1));
    }

    public int stars(int level) {
        return prefs.getInt("stars_" + level, 0);
    }

    public int best() {
        return prefs.getInt("best", 0);
    }

    /** Records a finished run; returns true if it is a new best score. */
    public boolean record(int level, boolean won, int score, int stars) {
        SharedPreferences.Editor e = prefs.edit();
        boolean newBest = score > best();
        if (newBest) e.putInt("best", score);
        if (won) {
            e.putInt("unlocked", Math.max(unlockedLevel(), level + 1));
            e.putInt("stars_" + level, Math.max(stars(level), stars));
        }
        e.apply();
        return newBest;
    }

    public boolean music() {
        return prefs.getBoolean("music", true);
    }

    public boolean sfx() {
        return prefs.getBoolean("sfx", true);
    }

    public void setMusic(boolean on) {
        prefs.edit().putBoolean("music", on).apply();
    }

    public void setSfx(boolean on) {
        prefs.edit().putBoolean("sfx", on).apply();
    }

    public boolean tutorialSeen() {
        return prefs.getBoolean("tutorial", false);
    }

    public void setTutorialSeen() {
        prefs.edit().putBoolean("tutorial", true).apply();
    }
}
