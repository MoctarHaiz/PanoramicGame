package com.HaizStudio.framework.implementation;

import java.io.IOException;

import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.media.MediaPlayer.OnSeekCompleteListener;
import android.media.MediaPlayer.OnVideoSizeChangedListener;

import com.HaizStudio.framework.Music;

public class MusicAndroid implements Music, OnCompletionListener,
		OnSeekCompleteListener, OnPreparedListener, OnVideoSizeChangedListener {

	MediaPlayer mediaPlayer;
	boolean estPret = false;

	public MusicAndroid(AssetFileDescriptor assetDescriptor) {
		mediaPlayer = new MediaPlayer();
		try {
			mediaPlayer.setDataSource(assetDescriptor.getFileDescriptor(),
					assetDescriptor.getStartOffset(),
					assetDescriptor.getLength());
			mediaPlayer.prepare();
			estPret = true;
			mediaPlayer.setOnCompletionListener(this);
			mediaPlayer.setOnSeekCompleteListener(this);
			mediaPlayer.setOnPreparedListener(this);
			mediaPlayer.setOnVideoSizeChangedListener(this);

		} catch (Exception e) {
			throw new RuntimeException("Ne peut pas charger la musique");
		}
	}

	@Override
	public void dispose() {

		if (this.mediaPlayer.isPlaying()) {
			this.mediaPlayer.stop();
		}
		this.mediaPlayer.release();
	}

	@Override
	public boolean isLooping() {
		return mediaPlayer.isLooping();
	}

	@Override
	public boolean isPlaying() {
		return this.mediaPlayer.isPlaying();
	}

	@Override
	public boolean isStopped() {
		return !estPret;
	}

	@Override
	public void pause() {
		if (this.mediaPlayer.isPlaying())
			mediaPlayer.pause();
	}

	@Override
	public void play() {
		if (this.mediaPlayer.isPlaying())
			return;

		try {
			synchronized (this) {
				if (!estPret)
					mediaPlayer.prepare();
				mediaPlayer.start();
			}
		} catch (IllegalStateException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	@Override
	public void setLooping(boolean isLooping) {
		mediaPlayer.setLooping(isLooping);
	}

	@Override
	public void setVolume(float volume) {
		mediaPlayer.setVolume(volume, volume);
	}

	@Override
	public void stop() {
		if (this.mediaPlayer.isPlaying() == true) {
			this.mediaPlayer.stop();

			synchronized (this) {
				estPret = false;
			}
		}
	}

	@Override
	public void onCompletion(MediaPlayer player) {
		synchronized (this) {
			estPret = false;
		}
	}

	@Override
	public void seekBegin() {
		mediaPlayer.seekTo(0);

	}

	@Override
	public void onPrepared(MediaPlayer player) {

		synchronized (this) {
			estPret = true;
		}

	}

	@Override
	public void onSeekComplete(MediaPlayer player) {
		// TODO Auto-generated method stub

	}

	@Override
	public void onVideoSizeChanged(MediaPlayer player, int width, int height) {
		// TODO Auto-generated method stub

	}

}
