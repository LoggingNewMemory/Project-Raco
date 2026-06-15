#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int get_universal_fps(const char *pkg) {
    if (pkg == NULL || pkg[0] == '\0') {
        pkg = "SurfaceView";
    }

    char cmd_list[512];
    snprintf(cmd_list, sizeof(cmd_list), "adb shell dumpsys SurfaceFlinger --list | grep -i '%s'", pkg);
    FILE *fp_list = popen(cmd_list, "r");
    if (!fp_list) return 0;

    int max_fps = 0;
    char layer_name[256];

    while (fgets(layer_name, sizeof(layer_name), fp_list)) {
        layer_name[strcspn(layer_name, "\r\n")] = '\0';
        if (layer_name[0] == '\0') continue;

        if (strncmp(layer_name, "RequestedLayerState{", 20) == 0) {
            char *start = layer_name + 20;
            char *end = strrchr(start, '}');
            if (end) *end = '\0';
            
            char *suffix = strstr(start, " parentId=");
            if (suffix) *suffix = '\0';
            suffix = strstr(start, " relativeParentId=");
            if (suffix) *suffix = '\0';
            suffix = strstr(start, " z=");
            if (suffix) *suffix = '\0';
            suffix = strstr(start, " !handle");
            if (suffix) *suffix = '\0';
            
            memmove(layer_name, start, strlen(start) + 1);
        }

        char cmd[512];
        snprintf(cmd, sizeof(cmd), "adb shell dumpsys SurfaceFlinger --latency \\\"%s\\\"", layer_name);
        printf("Checking layer: %s\n", layer_name);
        FILE *fp = popen(cmd, "r");
        if (!fp) continue;

        char line[256];
        long long timestamps[128];
        int ts_count = 0;
        long long latest = 0;

        if (fgets(line, sizeof(line), fp)) { // skip refresh period
            long long t1, t2, t3;
            while (fgets(line, sizeof(line), fp) && ts_count < 128) {
                if (sscanf(line, "%lld\t%lld\t%lld", &t1, &t2, &t3) == 3) {
                    if (t2 != 0 && t2 != 9223372036854775807LL) {
                        timestamps[ts_count++] = t2;
                        if (t2 > latest) latest = t2;
                    }
                }
            }
        }
        pclose(fp);

        if (ts_count > 0 && latest > 0) {
            long long cutoff = latest - 1000000000LL;
            int layer_fps = 0;
            for (int i = 0; i < ts_count; i++) {
                if (timestamps[i] > cutoff) {
                    layer_fps++;
                }
            }
            printf("Layer: %s, FPS: %d\n", layer_name, layer_fps);
            if (layer_fps > max_fps) {
                max_fps = layer_fps;
            }
        }
    }
    pclose(fp_list);

    if (max_fps > 144) max_fps = 144;
    return max_fps;
}

int main() {
    printf("FPS for com.netease.newspike: %d\n", get_universal_fps("com.netease.newspike"));
    return 0;
}
