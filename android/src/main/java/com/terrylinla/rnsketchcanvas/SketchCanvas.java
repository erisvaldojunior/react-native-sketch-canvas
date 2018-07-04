package com.terrylinla.rnsketchcanvas;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PointF;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.os.Environment;
import android.util.Base64;
import android.util.Log;
import android.view.View;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.events.RCTEventEmitter;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

public class SketchCanvas extends View {

    private Map<Integer, SketchPath> mPathsById = new HashMap<>();
    private ArrayList<SketchPoint> mPoints = new ArrayList<>();

    private ThemedReactContext mContext;
    private boolean mDisableHardwareAccelerated = false;

    private Paint mPaint = new Paint();
    private Bitmap mDrawingBitmap = null;
    private Canvas mDrawingCanvas = null;

    private boolean mNeedsFullRedraw = true;

    private int mOriginalWidth;
    private int mOriginalHeight;
    Bitmap mBackgroundImage;
    String mOriginalImagePath;

    public SketchCanvas(ThemedReactContext context) {
        super(context);
        mContext = context;
    }

    public boolean openImageFile(String localFilePath) {

        if(localFilePath != null) {
            BitmapFactory.Options bitmapOptions = new BitmapFactory.Options();
            Bitmap bitmap = BitmapFactory.decodeFile(localFilePath, bitmapOptions);
            if(bitmap != null) {
                mBackgroundImage = bitmap;
                mOriginalImagePath = localFilePath;
                mOriginalHeight = bitmap.getHeight();
                mOriginalWidth = bitmap.getWidth();

                invalidateCanvas(true);

                return true;
            }
        }
        return false;
    }

    public void clear() {
        mPathsById.clear();
        mPoints.clear();
        mNeedsFullRedraw = true;
        invalidateCanvas(true);
    }

    public void newPath(int id, int strokeColor, float strokeWidth) {
        SketchPath path = new SketchPath(id, strokeColor, strokeWidth);
        mPathsById.put(id, path);
        boolean isErase = strokeColor == Color.TRANSPARENT;
        if (isErase && mDisableHardwareAccelerated == false) {
            mDisableHardwareAccelerated = true;
            setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }
        invalidateCanvas(true);
    }

    public void addPoint(int pathId, float x, float y) {
        SketchPath path = mPathsById.get(pathId);
        if (path == null) {
            return;
        }

        SketchPoint point = path.addPoint(new PointF(x, y));
        mPoints.add(point);

        Rect updateRect = path.drawLastPoint(mDrawingCanvas);

        invalidate(updateRect);
    }

    public void addPath(int id, int strokeColor, float strokeWidth, ArrayList<PointF> points) {
        SketchPath path = mPathsById.get(id);
        if (path != null) {
            return;
        }

        SketchPath newPath = new SketchPath(id, strokeColor, strokeWidth);
        mPathsById.put(id, newPath);

        for (PointF point: points) {
            addPoint(id, point.x, point.y);
        }

        boolean isErase = strokeColor == Color.TRANSPARENT;
        if (isErase && mDisableHardwareAccelerated == false) {
            mDisableHardwareAccelerated = true;
            setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }

        invalidateCanvas(true);
    }

    public void deletePath(int id) {
        SketchPath path = mPathsById.get(id);
        if (path == null) {
            return;
        }

        mPathsById.remove(id);

        // Remove all points with this pathId
        ArrayList<SketchPoint> newPoints = new ArrayList<>();
        for (SketchPoint point: mPoints) {
            if (point.pathId != id) {
                newPoints.add(point);
            }
        }
        mPoints = newPoints;

        mNeedsFullRedraw = true;
        invalidateCanvas(true);
    }

    public void onSaved(boolean success, String path) {
        WritableMap event = Arguments.createMap();
        event.putBoolean("success", success);
        event.putString("path", path);
        mContext.getJSModule(RCTEventEmitter.class).receiveEvent(
            getId(),
            "topChange",
            event);
    }

    public void save(String format, String folder, String filename, boolean transparent) {
        File f = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES) + File.separator + folder);
        boolean success = true;
        if (!f.exists())   success = f.mkdirs();
        if (success) {
            Bitmap  bitmap = Bitmap.createBitmap(getWidth(), getHeight(), Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(bitmap);
            if (format.equals("png")) {
                canvas.drawARGB(transparent ? 0 : 255, 255, 255, 255);
            } else {
                canvas.drawARGB(255, 255, 255, 255);
            }

            if (mBackgroundImage != null) {
                Rect dstRect = new Rect();
                canvas.getClipBounds(dstRect);
                canvas.drawBitmap(mBackgroundImage, null, dstRect, null);
            }
            canvas.drawBitmap(mDrawingBitmap, 0, 0, mPaint);

            if (mBackgroundImage != null) {
                bitmap = Bitmap.createScaledBitmap(bitmap, mOriginalWidth, mOriginalHeight, false);
            }

            File file = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES) +
                File.separator + folder + File.separator + filename + (format.equals("png") ? ".png" : ".jpg"));
            try {
                bitmap.compress(
                    format.equals("png") ? Bitmap.CompressFormat.PNG : Bitmap.CompressFormat.JPEG,
                    format.equals("png") ? 100 : 90,
                    new FileOutputStream(file));
                this.onSaved(true, file.getPath());
            } catch (Exception e) {
                e.printStackTrace();
                onSaved(false, null);
            }
        } else {
            Log.e("SketchCanvas", "Failed to create folder!");
            onSaved(false, null);
        }
    }

    public void end() {
        // Nothing to do
    }

    public String getBase64(String format, boolean transparent) {
        WritableMap event = Arguments.createMap();
        Bitmap  bitmap = Bitmap.createBitmap(getWidth(), getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        if (format.equals("png")) {
            canvas.drawARGB(transparent ? 0 : 255, 255, 255, 255);
        } else {
            canvas.drawARGB(255, 255, 255, 255);
        }
        canvas.drawBitmap(mDrawingBitmap, 0, 0, mPaint);

        ByteArrayOutputStream byteArrayOS = new ByteArrayOutputStream();
        bitmap.compress(
            format.equals("png") ? Bitmap.CompressFormat.PNG : Bitmap.CompressFormat.JPEG,
            format.equals("png") ? 100 : 90,
            byteArrayOS);
        return Base64.encodeToString(byteArrayOS.toByteArray(), Base64.DEFAULT);
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);

        mDrawingBitmap = Bitmap.createBitmap(getWidth(), getHeight(),
                Bitmap.Config.ARGB_8888);
        mDrawingCanvas = new Canvas(mDrawingBitmap);

        mNeedsFullRedraw = true;
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        if (mNeedsFullRedraw && mDrawingCanvas != null) {
            mDrawingCanvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.MULTIPLY);
            for(SketchPoint point: mPoints) {
                SketchPath path = mPathsById.get(point.pathId);
                path.draw(mDrawingCanvas, point.index);
            }
            mNeedsFullRedraw = false;
        }

        if (mBackgroundImage != null) {
            Rect dstRect = new Rect();
            canvas.getClipBounds(dstRect);
            canvas.drawBitmap(mBackgroundImage, null, dstRect, null);
        }

        if (mDrawingBitmap != null) {
            canvas.drawBitmap(mDrawingBitmap, 0, 0, mPaint);
        }
    }

    private void invalidateCanvas(boolean shouldDispatchEvent) {
        if (shouldDispatchEvent) {
            WritableMap event = Arguments.createMap();
            event.putInt("pathsUpdate", mPathsById.size());
            mContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                getId(),
                "topChange",
                event);
        }
        invalidate();
    }
}
