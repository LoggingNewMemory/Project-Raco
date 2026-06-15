package com.raco;

import android.app.ActivityTaskManager;
import android.content.Context;
import android.net.LocalServerSocket;
import android.net.LocalSocket;
import android.os.Looper;
import android.view.WindowManager;
import android.window.TaskFpsCallback;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.Executor;

public class RacoFpsDaemon {
    private static int currentFps = 0;
    private static int currentTaskId = -1;
    private static WindowManager wm;
    private static TaskFpsCallback callback;

    public static void main(String[] args) {
        System.out.println("Starting RacoFpsDaemon...");
        try {
            Looper.prepare();

            // Reflection to get system context
            Object activityThread = Class.forName("android.app.ActivityThread").getMethod("systemMain").invoke(null);
            Context ctx = (Context) activityThread.getClass().getMethod("getSystemContext").invoke(activityThread);
            wm = (WindowManager) ctx.getSystemService(Context.WINDOW_SERVICE);

            callback = new TaskFpsCallback() {
                @Override
                public void onFpsReported(float fps) {
                    currentFps = (int) fps;
                }
            };

            // Start socket server in background
            new Thread(() -> {
                try {
                    LocalServerSocket server = new LocalServerSocket("raco_fps_daemon");
                    System.out.println("Listening on raco_fps_daemon");
                    while (true) {
                        LocalSocket client = server.accept();
                        handleClient(client);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }).start();

            // Continuous monitor for task changes
            new Thread(() -> {
                while (true) {
                    try {
                        updateTaskFps();
                        Thread.sleep(1000);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }).start();

            Looper.loop();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void updateTaskFps() {
        try {
            Object iAtm = Class.forName("android.app.ActivityTaskManager").getMethod("getService").invoke(null);
            Object taskInfo = iAtm.getClass().getMethod("getFocusedRootTaskInfo").invoke(iAtm);
            if (taskInfo == null) return;
            int taskId = taskInfo.getClass().getField("taskId").getInt(taskInfo);

            if (taskId != currentTaskId) {
                if (currentTaskId != -1) {
                    try {
                        wm.getClass().getMethod("unregisterTaskFpsCallback", TaskFpsCallback.class).invoke(wm, callback);
                    } catch (Exception ignored) {}
                }
                currentTaskId = taskId;
                try {
                    wm.getClass().getMethod("registerTaskFpsCallback", int.class, Executor.class, TaskFpsCallback.class)
                            .invoke(wm, taskId, new Executor() {
                                @Override
                                public void execute(Runnable command) {
                                    command.run();
                                }
                            }, callback);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        } catch (Exception e) {
            // Ignore
        }
    }

    private static void handleClient(LocalSocket client) {
        try {
            InputStream in = client.getInputStream();
            OutputStream out = client.getOutputStream();
            byte[] buffer = new byte[16];
            int read = in.read(buffer);
            if (read > 0) {
                String cmd = new String(buffer, 0, read).trim();
                if (cmd.startsWith("GET_FPS")) {
                    out.write(String.valueOf(currentFps).getBytes());
                }
            }
            client.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
