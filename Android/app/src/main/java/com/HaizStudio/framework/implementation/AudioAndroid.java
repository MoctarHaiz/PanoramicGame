package com.HaizStudio.framework.implementation;

import java.io.IOException;

import android.app.Activity;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.SoundPool;

import com.HaizStudio.framework.Audio;
import com.HaizStudio.framework.Music;
import com.HaizStudio.framework.Sound;

public class AudioAndroid implements Audio {

	AssetManager assets;
	SoundPool soundPool;

	public AudioAndroid(Activity activity) {
		activity.setVolumeControlStream(AudioManager.STREAM_MUSIC);
		this.assets = activity.getAssets();

		createNewSoundPool();
	}



	protected void createSoundPool() {

	}

	protected void createNewSoundPool(){
		AudioAttributes attributes = new AudioAttributes.Builder()
				.setUsage(AudioAttributes.USAGE_GAME)
				.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
				.build();
		this.soundPool = new SoundPool.Builder()
				.setMaxStreams(2)
				.setAudioAttributes(attributes)
				.build();
	}












	@Override
	public Music createMusic(String filename) {
		try {
			AssetFileDescriptor assetDescriptor = assets.openFd(filename);
			return new MusicAndroid(assetDescriptor);
		} catch (IOException e) {
			throw new RuntimeException("Ne peut pas charger la Musique'" + filename + "'");
		}
	}

	@Override
	public Sound createSound(String filename) {
		try {
			AssetFileDescriptor assetDescriptor = assets.openFd(filename);
			int soundId = soundPool.load(assetDescriptor, 1);
			return new SoundAndroid(soundPool, soundId);
		} catch (IOException e) {
			throw new RuntimeException("Ne peut pas charger le son '" + filename + "'");
		}
	}
}
