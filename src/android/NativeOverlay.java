package com.kuackmedia.nativeoverlay;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.PixelCopy;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;

public class NativeOverlay extends CordovaPlugin {

    private static final int OVERLAY_ID = 78432;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if ("show".equals(action)) {
            show(callbackContext);
            return true;
        } else if ("hide".equals(action)) {
            hide(callbackContext);
            return true;
        }
        return false;
    }

    private void show(final CallbackContext callbackContext) {
        final Activity activity = cordova.getActivity();
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                removeOverlay();

                View rootView = activity.getWindow().getDecorView().getRootView();
                int width = rootView.getWidth();
                int height = rootView.getHeight();

                if (width == 0 || height == 0) {
                    callbackContext.error("View has zero dimensions");
                    return;
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    final Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                    try {
                        PixelCopy.request(activity.getWindow(), bitmap, new PixelCopy.OnPixelCopyFinishedListener() {
                            @Override
                            public void onPixelCopyFinished(int copyResult) {
                                if (copyResult == PixelCopy.SUCCESS) {
                                    addOverlay(bitmap);
                                    callbackContext.success();
                                } else {
                                    addOverlayWithCanvas(rootView);
                                    callbackContext.success();
                                }
                            }
                        }, new Handler(Looper.getMainLooper()));
                    } catch (Exception e) {
                        addOverlayWithCanvas(rootView);
                        callbackContext.success();
                    }
                } else {
                    addOverlayWithCanvas(rootView);
                    callbackContext.success();
                }
            }
        });
    }

    private void hide(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                removeOverlay();
                callbackContext.success();
            }
        });
    }

    private void addOverlayWithCanvas(View rootView) {
        Bitmap bitmap = Bitmap.createBitmap(rootView.getWidth(), rootView.getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        rootView.draw(canvas);
        addOverlay(bitmap);
    }

    private void addOverlay(Bitmap bitmap) {
        Activity activity = cordova.getActivity();

        ImageView overlay = new ImageView(activity);
        overlay.setId(OVERLAY_ID);
        overlay.setImageBitmap(bitmap);
        overlay.setScaleType(ImageView.ScaleType.FIT_XY);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        );

        activity.addContentView(overlay, params);
    }

    private void removeOverlay() {
        Activity activity = cordova.getActivity();
        View overlay = activity.findViewById(OVERLAY_ID);
        if (overlay != null && overlay.getParent() != null) {
            ((ViewGroup) overlay.getParent()).removeView(overlay);
        }
    }
}
