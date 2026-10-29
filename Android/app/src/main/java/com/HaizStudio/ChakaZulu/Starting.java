package com.HaizStudio.ChakaZulu;

import android.util.Log;

import com.HaizStudio.framework.Screen;
import com.HaizStudio.framework.implementation.JeuAndroid;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

public class Starting extends JeuAndroid {


    public static String map;  //Our Level sheet
    boolean FirstCreation = true;

    @Override
    public Screen getInitScreen() {

        //Getting Assests
        if (FirstCreation) {
            Assets.load(this);
            FirstCreation = false;
        }

        //Getting Level Map
        InputStream is = getResources().openRawResource(R.raw.level);
        map = convertStreamToString(is);

        //return new SplashLoadingScreen(this);
        return new LoadingScreen(this);

    }

    private static String convertStreamToString(InputStream is) {

        BufferedReader reader = new BufferedReader(new InputStreamReader(is));
        StringBuilder sb = new StringBuilder();

        String line = null;
        try {
            while ((line = reader.readLine()) != null) {
                sb.append((line + "\n"));
            }
        } catch (IOException e) {
            //Log.w("LOG", e.getMessage());
        } finally {
            try {
                is.close();
            } catch (IOException e) {
              //  Log.w("LOG", e.getMessage());
            }
        }
        return sb.toString();
    }

    @Override
    public void onResume() {
        super.onResume();
        if (Assets.theme != null)
            Assets.theme.play();

    }

    @Override
    public void onPause() {
        super.onPause();
        if (Assets.theme != null)
            Assets.theme.pause();

    }

}
