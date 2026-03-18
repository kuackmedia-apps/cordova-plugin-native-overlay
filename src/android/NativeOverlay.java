package com.kuackmedia.nativeoverlay;

import android.animation.ArgbEvaluator;
import android.animation.ValueAnimator;
import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.PixelCopy;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.ProgressBar;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;

import java.io.File;
import java.io.FileOutputStream;

public class NativeOverlay extends CordovaPlugin {

    private static final int OVERLAY_ID = 78432;
    private static final int FEEDBACK_ID = 78433;
    private static final String SCREENSHOT_FILENAME = "nativeoverlay_screenshot.jpg";
    private boolean feedbackShown = false;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if ("show".equals(action)) {
            show(callbackContext);
            return true;
        } else if ("hide".equals(action)) {
            hide(callbackContext);
            return true;
        } else if ("save".equals(action)) {
            save(callbackContext);
            return true;
        } else if ("showSaved".equals(action)) {
            showSaved(callbackContext);
            return true;
        } else if ("deleteSaved".equals(action)) {
            deleteSaved(callbackContext);
            return true;
        }
        return false;
    }

    private File getScreenshotFile() {
        return new File(cordova.getActivity().getFilesDir(), SCREENSHOT_FILENAME);
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

    private void save(final CallbackContext callbackContext) {
        final Activity activity = cordova.getActivity();
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ViewGroup decorView = getDecorView();
                if (decorView.findViewById(OVERLAY_ID) != null) {
                    callbackContext.error("Overlay is visible, skipping capture");
                    return;
                }

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
                                    saveBitmapToFile(bitmap, callbackContext);
                                } else {
                                    Bitmap canvasBitmap = captureWithCanvas(rootView);
                                    saveBitmapToFile(canvasBitmap, callbackContext);
                                }
                            }
                        }, new Handler(Looper.getMainLooper()));
                    } catch (Exception e) {
                        Bitmap canvasBitmap = captureWithCanvas(rootView);
                        saveBitmapToFile(canvasBitmap, callbackContext);
                    }
                } else {
                    Bitmap canvasBitmap = captureWithCanvas(rootView);
                    saveBitmapToFile(canvasBitmap, callbackContext);
                }
            }
        });
    }

    private void showSaved(final CallbackContext callbackContext) {
        final Activity activity = cordova.getActivity();
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                File file = getScreenshotFile();
                if (!file.exists()) {
                    callbackContext.error("No saved screenshot");
                    return;
                }

                Bitmap bitmap = BitmapFactory.decodeFile(file.getAbsolutePath());
                if (bitmap == null) {
                    callbackContext.error("Failed to decode screenshot");
                    return;
                }

                removeOverlay();
                feedbackShown = false;
                addOverlay(bitmap);
                addTouchFeedbackListener();
                callbackContext.success();
            }
        });
    }

    private void addTouchFeedbackListener() {
        View overlay = getDecorView().findViewById(OVERLAY_ID);
        if (overlay == null) return;

        overlay.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (feedbackShown) return;
                feedbackShown = true;
                showFeedbackOverlay();
            }
        });
    }

    private void showFeedbackOverlay() {
        final Activity activity = cordova.getActivity();
        View overlay = getDecorView().findViewById(OVERLAY_ID);
        if (overlay == null) return;

        FrameLayout feedback = new FrameLayout(activity);
        feedback.setId(FEEDBACK_ID);
        feedback.setBackgroundColor(Color.TRANSPARENT);

        ProgressBar spinner = new ProgressBar(activity);
        spinner.setIndeterminate(true);
        FrameLayout.LayoutParams spinnerParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
        );
        spinnerParams.gravity = Gravity.CENTER;
        feedback.addView(spinner, spinnerParams);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        );
        getDecorView().addView(feedback, params);

        ValueAnimator animator = ValueAnimator.ofObject(new ArgbEvaluator(),
                Color.TRANSPARENT, Color.argb(77, 0, 0, 0));
        animator.setDuration(300);
        animator.addUpdateListener(new ValueAnimator.AnimatorUpdateListener() {
            @Override
            public void onAnimationUpdate(ValueAnimator animation) {
                feedback.setBackgroundColor((int) animation.getAnimatedValue());
            }
        });
        animator.start();
    }

    private void deleteSaved(final CallbackContext callbackContext) {
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                File file = getScreenshotFile();
                if (file.exists()) {
                    file.delete();
                }
                callbackContext.success();
            }
        });
    }

    private Bitmap captureWithCanvas(View rootView) {
        Bitmap bitmap = Bitmap.createBitmap(rootView.getWidth(), rootView.getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        rootView.draw(canvas);
        return bitmap;
    }

    private void saveBitmapToFile(final Bitmap bitmap, final CallbackContext callbackContext) {
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                try {
                    File tmpFile = new File(cordova.getActivity().getFilesDir(), SCREENSHOT_FILENAME + ".tmp");
                    FileOutputStream fos = new FileOutputStream(tmpFile);
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 70, fos);
                    fos.flush();
                    fos.close();
                    bitmap.recycle();

                    File finalFile = getScreenshotFile();
                    if (finalFile.exists()) {
                        finalFile.delete();
                    }
                    if (tmpFile.renameTo(finalFile)) {
                        callbackContext.success();
                    } else {
                        callbackContext.error("Failed to rename temp file");
                    }
                } catch (Exception e) {
                    callbackContext.error("Failed to save: " + e.getMessage());
                }
            }
        });
    }

    private void addOverlayWithCanvas(View rootView) {
        Bitmap bitmap = Bitmap.createBitmap(rootView.getWidth(), rootView.getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        rootView.draw(canvas);
        addOverlay(bitmap);
    }

    private ViewGroup getDecorView() {
        return (ViewGroup) cordova.getActivity().getWindow().getDecorView();
    }

    private void addOverlay(Bitmap bitmap) {
        ImageView overlay = new ImageView(cordova.getActivity());
        overlay.setId(OVERLAY_ID);
        overlay.setImageBitmap(bitmap);
        overlay.setScaleType(ImageView.ScaleType.FIT_XY);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        );

        getDecorView().addView(overlay, params);
    }

    private void removeOverlay() {
        ViewGroup decorView = getDecorView();
        View feedback = decorView.findViewById(FEEDBACK_ID);
        if (feedback != null) {
            decorView.removeView(feedback);
        }
        View overlay = decorView.findViewById(OVERLAY_ID);
        if (overlay != null) {
            decorView.removeView(overlay);
        }
        feedbackShown = false;
    }
}