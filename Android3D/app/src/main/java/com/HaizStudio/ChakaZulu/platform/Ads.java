package com.HaizStudio.ChakaZulu.platform;

import android.app.Activity;
import android.view.Gravity;
import android.widget.FrameLayout;

import com.HaizStudio.ChakaZulu.R;
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

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * AdMob: GDPR consent first, then a banner (shown on menus only) and an interstitial
 * after every few game overs. Debug builds use Google's test ids.
 */
public final class Ads {

    private final Activity activity;
    private final FrameLayout bannerContainer;
    private final AtomicBoolean started = new AtomicBoolean(false);
    private ConsentInformation consent;
    private AdView banner;
    private InterstitialAd interstitial;
    private Runnable afterInterstitial;

    public Ads(Activity activity, FrameLayout bannerContainer) {
        this.activity = activity;
        this.bannerContainer = bannerContainer;
    }

    /** Shows the consent form if needed, then starts the ads. {@code then} runs once consent is settled. */
    public void start(Runnable then) {
        consent = UserMessagingPlatform.getConsentInformation(activity);
        consent.requestConsentInfoUpdate(activity, new ConsentRequestParameters.Builder().build(),
                () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity, error -> {
                    init();
                    then.run();
                }),
                error -> {
                    init();
                    then.run();
                });
        init();
    }

    private void init() {
        if (consent == null || !consent.canRequestAds() || !started.compareAndSet(false, true)) return;
        new Thread(() -> MobileAds.initialize(activity, status -> activity.runOnUiThread(() -> {
            loadBanner();
            loadInterstitial();
        }))).start();
    }

    private void loadBanner() {
        if (activity.isFinishing()) return;
        banner = new AdView(activity);
        banner.setAdUnitId(activity.getString(R.string.admob_banner_id));
        banner.setAdSize(AdSize.BANNER);
        bannerContainer.addView(banner, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER));
        banner.loadAd(new AdRequest.Builder().build());
    }

    private void loadInterstitial() {
        InterstitialAd.load(activity, activity.getString(R.string.admob_interstitial_id), new AdRequest.Builder().build(),
                new InterstitialAdLoadCallback() {
                    @Override
                    public void onAdLoaded(InterstitialAd ad) {
                        interstitial = ad;
                        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                            @Override
                            public void onAdDismissedFullScreenContent() {
                                done();
                            }

                            @Override
                            public void onAdFailedToShowFullScreenContent(AdError adError) {
                                done();
                            }
                        });
                    }

                    @Override
                    public void onAdFailedToLoad(LoadAdError error) {
                        interstitial = null;
                    }
                });
    }

    private void done() {
        interstitial = null;
        loadInterstitial();
        if (afterInterstitial != null) {
            Runnable r = afterInterstitial;
            afterInterstitial = null;
            r.run();
        }
    }

    /** Shows an interstitial if one is ready, then runs {@code then} (immediately if none). */
    public void showInterstitial(Runnable then) {
        if (interstitial == null) {
            if (started.get()) loadInterstitial();
            then.run();
            return;
        }
        afterInterstitial = then;
        interstitial.show(activity);
    }

    public void pause() {
        if (banner != null) banner.pause();
    }

    public void resume() {
        if (banner != null) banner.resume();
    }

    public void destroy() {
        if (banner != null) banner.destroy();
    }
}
