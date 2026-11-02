package com.HaizStudio.framework.implementation;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.Point;
import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.widget.FrameLayout;

import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;

import com.HaizStudio.ChakaZulu.Assets;
import com.HaizStudio.ChakaZulu.R;
import com.HaizStudio.framework.Audio;
import com.HaizStudio.framework.FileIO;
import com.HaizStudio.framework.Graphics;
import com.HaizStudio.framework.Input;
import com.HaizStudio.framework.Jeu;
import com.HaizStudio.framework.Screen;
import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.AdSize;
import com.google.android.gms.ads.AdView;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;
import com.google.firebase.FirebaseApp;

import java.util.concurrent.atomic.AtomicBoolean;

public abstract class JeuAndroid extends ComponentActivity implements Jeu {

    AndroidFastRenderView renderView;
    Graphics graphics;
    Audio audio;
    Input input;
    FileIO fileIO;
    Screen screen;
    Context context;

    // Ads
    private FrameLayout frameLayout;
    private AdView bannerView;
    private InterstitialAd interstitialAd;
    private ConsentInformation consentInformation;
    private final AtomicBoolean adsStarted = new AtomicBoolean(false);

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Draw under the camera notch too: the game fills the whole screen.
            getWindow().getAttributes().layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }

        boolean isPortrait = getResources().getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
        float frameBufferWidth = isPortrait ? Assets.WINDOW_HEIGHT : Assets.WINDOW_WIDTH;
        float frameBufferHeight = Assets.WINDOW_HEIGHT;
        Bitmap frameBuffer = Bitmap.createBitmap((int) frameBufferWidth, (int) frameBufferHeight, Config.RGB_565);

        Point display = fullScreenSize();
        float scaleX = frameBufferWidth / display.x;
        float scaleY = frameBufferHeight / display.y;
        Assets.reScaleGraphics(1.0f / scaleX, 1.0f / scaleY);  //1.0/x to fill the whole screen

        renderView = new AndroidFastRenderView(this, frameBuffer);
        graphics = new GraphiquesAndroid(getAssets(), frameBuffer);
        fileIO = new FichierIOAndroid(this);
        audio = new AudioAndroid(this);
        input = new InputAndroid(this, renderView, scaleX, scaleY);
        screen = getInitScreen();
        context = getApplicationContext();

        frameLayout = new FrameLayout(this);
        frameLayout.addView(renderView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        setContentView(frameLayout);
        hideSystemBars();

        // Back button and back gesture (including Android 16 predictive back)
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                if (screen != null)
                    screen.backButton();
            }
        });

        requestConsentThenStartAds();
    }

    /** Size of the whole screen in pixels, system bars included (they are hidden). */
    @SuppressWarnings("deprecation")
    private Point fullScreenSize() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Rect bounds = getWindowManager().getCurrentWindowMetrics().getBounds();
            return new Point(bounds.width(), bounds.height());
        }
        Point size = new Point();
        getWindowManager().getDefaultDisplay().getRealSize(size);
        return size;
    }

    @SuppressWarnings("deprecation")
    private void hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setDecorFitsSystemWindows(false);
            WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.systemBars());
                controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) hideSystemBars();
    }

    // ------------------------------------------------------------------ Ads

    /**
     * Asks for GDPR consent when the user is in a region that needs it (the message is
     * configured in AdMob > Privacy & messaging), then starts the ads.
     */
    private void requestConsentThenStartAds() {
        consentInformation = UserMessagingPlatform.getConsentInformation(this);
        consentInformation.requestConsentInfoUpdate(
                this,
                new ConsentRequestParameters.Builder().build(),
                () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(this, formError -> {
                    startAds();
                    requestNotificationPermission();
                }),
                requestError -> {
                    startAds();
                    requestNotificationPermission();
                });
        // Consent given in a previous session: start right away.
        startAds();
    }

    private void startAds() {
        if (!consentInformation.canRequestAds() || !adsStarted.compareAndSet(false, true))
            return;
        new Thread(() -> MobileAds.initialize(this, status -> runOnUiThread(() -> {
            loadBanner();
            loadInterstitial();
        }))).start();
    }

    private void loadBanner() {
        if (isFinishing() || isDestroyed())
            return;
        bannerView = new AdView(this);
        bannerView.setAdUnitId(getString(R.string.admob_banner_id));
        // Standard 320x50 banner, centred: small enough to keep the ground and the hero visible.
        bannerView.setAdSize(AdSize.BANNER);
        frameLayout.addView(bannerView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL));
        bannerView.loadAd(new AdRequest.Builder().build());
    }

    private void loadInterstitial() {
        InterstitialAd.load(this, getString(R.string.admob_interstitial_id), new AdRequest.Builder().build(),
                new InterstitialAdLoadCallback() {
                    @Override
                    public void onAdLoaded(InterstitialAd ad) {
                        interstitialAd = ad;
                        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                            @Override
                            public void onAdDismissedFullScreenContent() {
                                interstitialAd = null;
                                loadInterstitial(); // ready for next time
                            }

                            @Override
                            public void onAdFailedToShowFullScreenContent(AdError adError) {
                                interstitialAd = null;
                                loadInterstitial();
                            }
                        });
                    }

                    @Override
                    public void onAdFailedToLoad(LoadAdError loadAdError) {
                        interstitialAd = null;
                    }
                });
    }

    @Override
    public void showInterstitial() {
        runOnUiThread(() -> {
            if (interstitialAd != null) {
                interstitialAd.show(this);
            } else if (adsStarted.get()) {
                loadInterstitial(); // not ready: try to have one for the next game over
            }
        });
    }

    /** Android 13+: ask once to show push notifications, only if Firebase is set up. */
    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && !FirebaseApp.getApps(this).isEmpty()
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1);
        }
    }

    // ------------------------------------------------------------ Lifecycle

    @Override
    public void onDestroy() {
        if (bannerView != null)
            bannerView.destroy();
        super.onDestroy();
    }

    @Override
    public void onResume() {
        super.onResume();
        if (screen != null)
            screen.resume();
        if (renderView != null)
            renderView.resume();
        if (bannerView != null)
            bannerView.resume();
    }

    @Override
    public void onPause() {
        super.onPause();
        if (renderView != null)
            renderView.pause();
        if (screen != null)
            screen.pause();
        if (bannerView != null)
            bannerView.pause();
        if (isFinishing() && screen != null)
            screen.dispose();
    }

    // ------------------------------------------------------------- Jeu

    @Override
    public Audio getAudio() {
        return audio;
    }

    @Override
    public Input getInput() {
        return input;
    }

    @Override
    public Context getContext() {
        return context;
    }

    @Override
    public FileIO getFileIO() {
        return fileIO;
    }

    @Override
    public Graphics getGraphics() {
        return graphics;
    }

    @Override
    public void setScreen(Screen screen) {
        if (screen == null)
            throw new IllegalArgumentException("Screen ne doit pas etre null");

        this.screen.pause();
        this.screen.dispose();
        screen.resume();
        screen.update(0);
        this.screen = screen;
    }

    public Screen getCurrentScreen() {
        return screen;
    }

    @Override
    public Screen setCurrentScreen() {
        return null;
    }

    @Override
    public Screen setInitScreen() {
        return null;
    }

    @Override
    public Screen getInitScreen() {
        return null;
    }
}
