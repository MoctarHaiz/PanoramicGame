package com.HaizStudio.ChakaZulu;

import android.Manifest;
import android.animation.ObjectAnimator;
import android.animation.PropertyValuesHolder;
import android.animation.ValueAnimator;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.opengl.GLSurfaceView;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.view.animation.OvershootInterpolator;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;

import com.HaizStudio.ChakaZulu.game.World;
import com.HaizStudio.ChakaZulu.platform.Ads;
import com.HaizStudio.ChakaZulu.platform.Save;
import com.HaizStudio.ChakaZulu.platform.Sounds;
import com.HaizStudio.ChakaZulu.render.GameRenderer;
import com.HaizStudio.ChakaZulu.render.MsaaConfigChooser;
import com.HaizStudio.ChakaZulu.ui.OutlineTextView;
import com.HaizStudio.ChakaZulu.ui.SwipeInput;
import com.google.firebase.FirebaseApp;

import java.util.Locale;

/** The only screen: a 3D view with the menus and HUD drawn over it. */
public class Starting extends ComponentActivity implements World.Events, SwipeInput.Listener {

    private enum Screen {MENU, PLAYING, PAUSED, RESULT}

    private static final int INTERSTITIAL_EVERY = 3;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private GLSurfaceView glView;
    private GameRenderer renderer;
    private World world;
    private Sounds sounds;
    private Save save;
    private Ads ads;

    private View menu, hud, touchLayer, pauseOverlay, resultOverlay, shieldTrack, shieldFill, progressTrack, progressFill;
    private View pausePanel, resultPanel, play;
    private TextView tutorial, bobsText, scoreText, levelText, bestText, resultTitle, resultScore, resultDetail, resultNewBest;
    private OutlineTextView toast, title;
    private LinearLayout hearts, levelStars, resultStars;
    private Button resultNext, resultAgain;
    private ImageButton musicButton, soundButton, levelPrev, levelNext;
    private FrameLayout adContainer;

    private Screen screen = Screen.MENU;
    private int selectedLevel, currentLevel, shownLives = 3, lostRuns;
    private boolean lastRunLost;
    private ObjectAnimator playPulse;

    // ------------------------------------------------------------- lifecycle

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            getWindow().getAttributes().layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        setContentView(R.layout.activity_main);

        save = new Save(this);
        sounds = new Sounds(this);
        sounds.setMusic(save.music());
        sounds.setSfx(save.sfx());

        world = new World(this);
        renderer = new GameRenderer(world);
        glView = new GLSurfaceView(this);
        glView.setEGLContextClientVersion(3);
        glView.setEGLConfigChooser(new MsaaConfigChooser());
        glView.setPreserveEGLContextOnPause(true);
        glView.setRenderer(renderer);
        FrameLayout root = findViewById(R.id.root);
        root.addView(glView, 0, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        bindViews();
        selectedLevel = save.unlockedLevel();
        glView.queueEvent(() -> world.showMenu(selectedLevel));
        showMenu(false);

        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                switch (screen) {
                    case PLAYING: pauseGame(); break;
                    case PAUSED: resumeGame(); break;
                    case RESULT: goHome(); break;
                    default: finish(); break;
                }
            }
        });

        ads = new Ads(this, adContainer);
        ads.start(this::requestNotificationPermission);
        debugLaunch();
    }

    /**
     * Debug builds only, for testing: adb shell am start -n <package>/com.HaizStudio.ChakaZulu.Starting
     * --ei play 2 --ef skip 300 --ez god true   (level, start distance, invincible)
     */
    private void debugLaunch() {
        if ((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) == 0 || !getIntent().hasExtra("play")) return;
        int level = getIntent().getIntExtra("play", 1);
        float skip = getIntent().getFloatExtra("skip", 0);
        boolean god = getIntent().getBooleanExtra("god", false);
        ui.postDelayed(() -> {
            startGame(level);
            glView.queueEvent(() -> {
                world.godMode = god;
                world.skipTo(skip);
                Log.d("ChakaZulu3D", world.describe());
            });
        }, 1200);
    }

    private void bindViews() {
        menu = findViewById(R.id.menu);
        hud = findViewById(R.id.hud);
        touchLayer = findViewById(R.id.touch_layer);
        pauseOverlay = findViewById(R.id.pause_overlay);
        pausePanel = findViewById(R.id.pause_panel);
        resultOverlay = findViewById(R.id.result_overlay);
        resultPanel = findViewById(R.id.result_panel);
        shieldTrack = findViewById(R.id.shield_track);
        shieldFill = findViewById(R.id.shield_fill);
        progressTrack = findViewById(R.id.progress_track);
        progressFill = findViewById(R.id.progress_fill);
        tutorial = findViewById(R.id.tutorial);
        bobsText = findViewById(R.id.bobs);
        scoreText = findViewById(R.id.score);
        levelText = findViewById(R.id.level);
        bestText = findViewById(R.id.best);
        resultTitle = findViewById(R.id.result_title);
        resultScore = findViewById(R.id.result_score);
        resultDetail = findViewById(R.id.result_detail);
        resultNewBest = findViewById(R.id.result_new_best);
        toast = findViewById(R.id.toast);
        title = findViewById(R.id.title);
        hearts = findViewById(R.id.hearts);
        levelStars = findViewById(R.id.level_stars);
        resultStars = findViewById(R.id.result_stars);
        resultNext = findViewById(R.id.result_next);
        resultAgain = findViewById(R.id.result_again);
        musicButton = findViewById(R.id.music);
        soundButton = findViewById(R.id.sound);
        levelPrev = findViewById(R.id.level_prev);
        levelNext = findViewById(R.id.level_next);
        adContainer = findViewById(R.id.ad_container);
        play = findViewById(R.id.play);

        touchLayer.setOnTouchListener(new SwipeInput(this, getResources().getDisplayMetrics().density));
        play.setOnClickListener(v -> startGame(selectedLevel));
        findViewById(R.id.pause).setOnClickListener(v -> pauseGame());
        findViewById(R.id.resume).setOnClickListener(v -> resumeGame());
        findViewById(R.id.pause_home).setOnClickListener(v -> goHome());
        findViewById(R.id.result_home).setOnClickListener(v -> afterResult(this::goHome));
        resultAgain.setOnClickListener(v -> afterResult(() -> startGame(currentLevel)));
        resultNext.setOnClickListener(v -> afterResult(() -> startGame(currentLevel + 1)));
        levelPrev.setOnClickListener(v -> selectLevel(selectedLevel - 1));
        levelNext.setOnClickListener(v -> selectLevel(selectedLevel + 1));
        musicButton.setOnClickListener(v -> {
            save.setMusic(!save.music());
            sounds.setMusic(save.music());
            updateAudioButtons();
        });
        soundButton.setOnClickListener(v -> {
            save.setSfx(!save.sfx());
            sounds.setSfx(save.sfx());
            updateAudioButtons();
        });
        updateAudioButtons();
    }

    @Override
    protected void onResume() {
        super.onResume();
        glView.onResume();
        sounds.resume();
        ads.resume();
        hideSystemBars();
    }

    @Override
    protected void onPause() {
        if (screen == Screen.PLAYING) pauseGame();
        glView.onPause();
        sounds.pause();
        ads.pause();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        ui.removeCallbacksAndMessages(null);
        sounds.release();
        ads.destroy();
        super.onDestroy();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) hideSystemBars();
    }

    @SuppressWarnings("deprecation")
    private void hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setDecorFitsSystemWindows(false);
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                c.hide(WindowInsets.Type.systemBars());
                c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        }
    }

    // ---------------------------------------------------------------- screens

    private void showMenu(boolean animate) {
        screen = Screen.MENU;
        renderer.paused = false;
        hud.setVisibility(View.GONE);
        touchLayer.setVisibility(View.GONE);
        tutorial.setVisibility(View.GONE);
        pauseOverlay.setVisibility(View.GONE);
        resultOverlay.setVisibility(View.GONE);
        adContainer.setVisibility(View.VISIBLE);
        menu.setVisibility(View.VISIBLE);
        updateLevelUi();
        title.setScaleX(0.6f);
        title.setScaleY(0.6f);
        title.setAlpha(0);
        title.animate().scaleX(1).scaleY(1).alpha(1).setDuration(animate ? 500 : 700).setStartDelay(animate ? 0 : 300)
                .setInterpolator(new OvershootInterpolator(2.2f)).start();
        if (playPulse == null) {
            playPulse = ObjectAnimator.ofPropertyValuesHolder(play, PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.07f),
                    PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.07f));
            playPulse.setDuration(700);
            playPulse.setRepeatCount(ValueAnimator.INFINITE);
            playPulse.setRepeatMode(ValueAnimator.REVERSE);
        }
        playPulse.start();
    }

    private void selectLevel(int level) {
        int clamped = Math.max(1, Math.min(save.unlockedLevel(), level));
        if (clamped == selectedLevel) return;
        selectedLevel = clamped;
        glView.queueEvent(() -> world.showMenu(clamped));
        updateLevelUi();
    }

    private void updateLevelUi() {
        levelText.setText(getString(R.string.level, selectedLevel));
        setStars(levelStars, save.stars(selectedLevel));
        levelPrev.setAlpha(selectedLevel > 1 ? 1f : 0.3f);
        levelNext.setAlpha(selectedLevel < save.unlockedLevel() ? 1f : 0.3f);
        bestText.setText(getString(R.string.best, format(save.best())));
    }

    private void updateAudioButtons() {
        musicButton.setImageResource(save.music() ? R.drawable.ic_music : R.drawable.ic_music_off);
        soundButton.setImageResource(save.sfx() ? R.drawable.ic_volume : R.drawable.ic_volume_off);
    }

    private void startGame(int level) {
        currentLevel = level;
        selectedLevel = level;
        screen = Screen.PLAYING;
        renderer.paused = false;
        if (playPulse != null) playPulse.cancel();
        menu.animate().alpha(0).setDuration(250).withEndAction(() -> {
            menu.setVisibility(View.GONE);
            menu.setAlpha(1);
        }).start();
        resultOverlay.setVisibility(View.GONE);
        pauseOverlay.setVisibility(View.GONE);
        adContainer.setVisibility(View.GONE);
        hud.setVisibility(View.VISIBLE);
        hud.setAlpha(0);
        hud.animate().alpha(1).setDuration(400).start();
        touchLayer.setVisibility(View.VISIBLE);
        shownLives = 3;
        updateHearts(3, false);
        glView.queueEvent(() -> world.start(level));
        if (!save.tutorialSeen()) {
            tutorial.setVisibility(View.VISIBLE);
            tutorial.setAlpha(0);
            tutorial.animate().alpha(1).setStartDelay(600).setDuration(400).start();
            ui.postDelayed(() -> {
                tutorial.animate().alpha(0).setDuration(500).withEndAction(() -> tutorial.setVisibility(View.GONE)).start();
                save.setTutorialSeen();
            }, 7000);
        }
        ui.removeCallbacks(hudTick);
        ui.post(hudTick);
    }

    private void pauseGame() {
        if (screen != Screen.PLAYING) return;
        screen = Screen.PAUSED;
        renderer.paused = true;
        touchLayer.setVisibility(View.GONE);
        pauseOverlay.setVisibility(View.VISIBLE);
        popIn(pausePanel);
    }

    private void resumeGame() {
        if (screen != Screen.PAUSED) return;
        screen = Screen.PLAYING;
        renderer.paused = false;
        pauseOverlay.setVisibility(View.GONE);
        touchLayer.setVisibility(View.VISIBLE);
    }

    private void goHome() {
        ui.removeCallbacks(hudTick);
        int level = Math.min(selectedLevel, save.unlockedLevel());
        selectedLevel = level;
        glView.queueEvent(() -> world.showMenu(level));
        showMenu(true);
    }

    /** Every few lost runs, an interstitial plays when the player leaves the result screen. */
    private void afterResult(Runnable then) {
        if (lastRunLost && lostRuns % INTERSTITIAL_EVERY == 0) {
            lastRunLost = false;
            ads.showInterstitial(then);
        } else {
            then.run();
        }
    }

    private static void popIn(View v) {
        v.setScaleX(0.7f);
        v.setScaleY(0.7f);
        v.setAlpha(0);
        v.animate().scaleX(1).scaleY(1).alpha(1).setDuration(380).setInterpolator(new OvershootInterpolator(2f)).start();
    }

    // ------------------------------------------------------------------- HUD

    private final Runnable hudTick = new Runnable() {
        @Override
        public void run() {
            if (screen != Screen.PLAYING && screen != Screen.PAUSED) return;
            scoreText.setText(format(world.hudScore));
            bobsText.setText(String.valueOf(world.hudBobs));
            int width = progressTrack.getWidth();
            setWidth(progressFill, (int) (width * world.hudProgress));
            float shield = world.hudShield;
            shieldTrack.setVisibility(shield > 0 ? View.VISIBLE : View.INVISIBLE);
            setWidth(shieldFill, (int) (shieldTrack.getWidth() * shield));
            int lives = world.hudLives;
            if (lives != shownLives) {
                updateHearts(lives, lives < shownLives);
                shownLives = lives;
            }
            ui.postDelayed(this, 80);
        }
    };

    private static void setWidth(View v, int width) {
        if (v.getLayoutParams().width == width) return;
        v.getLayoutParams().width = width;
        v.requestLayout();
    }

    private void updateHearts(int lives, boolean lost) {
        for (int i = 0; i < hearts.getChildCount(); i++) {
            ImageView heart = (ImageView) hearts.getChildAt(i);
            boolean full = i < lives;
            heart.setImageResource(full ? R.drawable.ic_heart : R.drawable.ic_heart_empty);
            if (lost && i == lives) {
                heart.setScaleX(1.8f);
                heart.setScaleY(1.8f);
                heart.animate().scaleX(1).scaleY(1).setDuration(450).setInterpolator(new OvershootInterpolator(3)).start();
            }
        }
    }

    private void setStars(LinearLayout row, int stars) {
        for (int i = 0; i < row.getChildCount(); i++)
            ((ImageView) row.getChildAt(i)).setImageResource(i < stars ? R.drawable.ic_star : R.drawable.ic_star_empty);
    }

    private static String format(int n) {
        return String.format(Locale.US, "%,d", n);
    }

    // ------------------------------------------------------- World.Events (GL thread)

    @Override
    public void sound(int id, float rate) {
        sounds.play(id, rate);
    }

    @Override
    public void haptic(boolean strong) {
        ui.post(() -> glView.performHapticFeedback(strong ? HapticFeedbackConstants.LONG_PRESS : HapticFeedbackConstants.KEYBOARD_TAP));
    }

    @Override
    public void toast(String text) {
        ui.post(() -> {
            toast.setText(text);
            toast.setVisibility(View.VISIBLE);
            toast.setAlpha(0);
            toast.setScaleX(0.3f);
            toast.setScaleY(0.3f);
            toast.animate().cancel();
            toast.animate().alpha(1).scaleX(1).scaleY(1).setDuration(320).setStartDelay(0).setInterpolator(new OvershootInterpolator(3))
                    .withEndAction(() -> toast.animate().alpha(0).scaleX(1.25f).scaleY(1.25f).setStartDelay(550).setDuration(300)
                            .withEndAction(() -> toast.setVisibility(View.GONE)).start())
                    .start();
        });
    }

    @Override
    public void finished(boolean won, int level, int score, int bobs, int totalBobs, int kills) {
        ui.post(() -> showResult(won, level, score, bobs, totalBobs, kills));
    }

    private void showResult(boolean won, int level, int score, int bobs, int totalBobs, int kills) {
        if (screen != Screen.PLAYING && screen != Screen.PAUSED) return;
        ui.removeCallbacks(hudTick);
        screen = Screen.RESULT;
        renderer.paused = false;
        float ratio = totalBobs == 0 ? 1 : bobs / (float) totalBobs;
        int stars = won ? 1 + (ratio >= 0.5f ? 1 : 0) + (ratio >= 0.8f ? 1 : 0) : 0;
        boolean newBest = save.record(level, won, score, stars);
        lastRunLost = !won;
        if (!won) lostRuns++;
        if (won) selectedLevel = level + 1;

        touchLayer.setVisibility(View.GONE);
        tutorial.setVisibility(View.GONE);
        pauseOverlay.setVisibility(View.GONE);
        hud.animate().alpha(0).setDuration(300).withEndAction(() -> hud.setVisibility(View.GONE)).start();
        adContainer.setVisibility(View.VISIBLE);

        resultTitle.setText(won ? getString(R.string.level_complete, level) : getString(R.string.game_over));
        resultTitle.setTextColor(won ? 0xFF2E7D32 : 0xFFC62828);
        resultDetail.setText(getString(R.string.bobs_collected, bobs, totalBobs, kills));
        resultNewBest.setVisibility(View.GONE);
        resultNext.setVisibility(won ? View.VISIBLE : View.GONE);
        resultAgain.setText(won ? R.string.again : R.string.retry);
        resultStars.setVisibility(won ? View.VISIBLE : View.GONE);
        setStars(resultStars, 0);

        resultOverlay.setVisibility(View.VISIBLE);
        resultOverlay.setAlpha(0);
        resultOverlay.animate().alpha(1).setDuration(300).setStartDelay(won ? 300 : 0).start();
        popIn(resultPanel);

        ValueAnimator count = ValueAnimator.ofInt(0, score);
        count.setDuration(1100);
        count.setStartDelay(400);
        count.addUpdateListener(a -> resultScore.setText(format((int) a.getAnimatedValue())));
        count.start();
        for (int i = 0; i < stars; i++) {
            ImageView star = (ImageView) resultStars.getChildAt(i);
            float pitch = 1f + i * 0.18f;
            ui.postDelayed(() -> {
                star.setImageResource(R.drawable.ic_star);
                star.setScaleX(0);
                star.setScaleY(0);
                star.animate().scaleX(1).scaleY(1).setDuration(420).setInterpolator(new OvershootInterpolator(3.5f)).start();
                sounds.play(World.SFX_COIN, pitch);
            }, 700 + i * 350L);
        }
        if (newBest) {
            ui.postDelayed(() -> {
                resultNewBest.setVisibility(View.VISIBLE);
                popIn(resultNewBest);
            }, 1600);
        }
    }

    // ------------------------------------------------------- SwipeInput.Listener

    @Override
    public void onSwipe(int direction) {
        glView.queueEvent(() -> {
            switch (direction) {
                case SwipeInput.LEFT: world.left(); break;
                case SwipeInput.RIGHT: world.right(); break;
                case SwipeInput.UP: world.up(); break;
                default: world.down(); break;
            }
        });
    }

    @Override
    public void onTap() {
        glView.queueEvent(world::tap);
    }

    // ------------------------------------------------------------------ misc

    /** Android 13+: ask once to show push notifications, only if Firebase is set up. */
    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !FirebaseApp.getApps(this).isEmpty()
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1);
    }
}
