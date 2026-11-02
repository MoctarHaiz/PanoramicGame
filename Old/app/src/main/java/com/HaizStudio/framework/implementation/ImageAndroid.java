package com.HaizStudio.framework.implementation;

import android.graphics.Bitmap;

import com.HaizStudio.framework.Graphics.ImageFormat;
import com.HaizStudio.framework.Image;


	public class ImageAndroid implements Image {
	    Bitmap bitmap;
	    ImageFormat format;
	   
	    public ImageAndroid(Bitmap bitmap, ImageFormat format) {
	        this.bitmap = bitmap;
	        this.format = format;
	    }

	    @Override
	    public int getWidth() {
	        return bitmap.getWidth();
	    }

	    @Override
	    public int getHeight() {
	        return bitmap.getHeight();
	    }

	    @Override
	    public ImageFormat getFormat() {
	        return format;
	    }

	    @Override
	    public void dispose() {
	        bitmap.recycle();
	    }
		@Override
		public Bitmap getBitmap(){
			return this.bitmap;
		}
		@Override
		public void setBitmap(Bitmap bitmap){
			this.bitmap = bitmap;
		}

	}
	 

