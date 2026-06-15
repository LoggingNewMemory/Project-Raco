package android.app;
public class ActivityTaskManager {
    public static ActivityTaskManager getService() { throw new RuntimeException("Stub!"); }
    public RootTaskInfo getFocusedRootTaskInfo() { throw new RuntimeException("Stub!"); }
    public static class RootTaskInfo {
        public int taskId;
    }
}
