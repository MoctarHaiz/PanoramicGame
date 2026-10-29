package com.HaizStudio.ChakaZulu.ui;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.widget.TextView;

/** Big game-style text: a thick dark outline and a gold vertical gradient fill. */
public final class OutlineTextView extends TextView {

    private int outlineColor = 0xFF4A2511;
    private float outlineWidth;
    private int topColor = 0xFFFFF3B0, bottomColor = 0xFFFF9F1C;

    public OutlineTextView(Context context, AttributeSet attrs) {
        super(context, attrs);
        outlineWidth = 6 * getResources().getDisplayMetrics().density;
    }

    public void setColors(int top, int bottom, int outline) {
        topColor = top;
        bottomColor = bottom;
        outlineColor = outline;
        invalidate();
    }

    private boolean drawing;

    /** setTextColor() inside onDraw() must not schedule another draw. */
    @Override
    public void invalidate() {
        if (!drawing) super.invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        drawing = true;
        Paint p = getPaint();
        p.setShader(null);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeJoin(Paint.Join.ROUND);
        p.setStrokeWidth(outlineWidth);
        setTextColor(outlineColor);
        super.onDraw(canvas);

        p.setStyle(Paint.Style.FILL);
        p.setStrokeWidth(0);
        p.setShader(new LinearGradient(0, getPaddingTop(), 0, getHeight() - getPaddingBottom(), topColor, bottomColor,
                Shader.TileMode.CLAMP));
        setTextColor(0xFFFFFFFF);
        super.onDraw(canvas);
        p.setShader(null);
        drawing = false;
    }
}
