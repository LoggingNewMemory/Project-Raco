#include <stdio.h>
#include <string.h>

int main() {
    char focus_line[] = "  mCurrentFocus=Window{59542ba u0 com.netease.newspike/com.netease.game.MessiahNativeActivity}";
    char current_pkg[256] = {0};

    char *slash = strchr(focus_line, '/');
    if (slash) {
        *slash = '\0';
        char *space = strrchr(focus_line, ' ');
        if (space) {
            strncpy(current_pkg, space + 1, sizeof(current_pkg) - 1);
        }
    }
    printf("PKG: '%s'\n", current_pkg);
    return 0;
}
