#include raco.h

RacoConfig config;
const char *RACO_CONFIG = "/data/ProjectRaco/raco.txt";

// The Assembly Wrappers

void rawrite(const char *val, const char *path) {
    raco_write(path, val, strlen(val));
}


void rakakikomi(const char *val, const char *path) {
    raco_kakikomi(path, val, strlen(val));
}

void raread(const char *path) {
    raco_read(path);
}

// FREQ Parser & Quick Sort

int compare_freq_desc (const void *a, const void *b) {
    FreqData *fa = (FreqData *)a;
    FreqData *fb = (FreqData *)b;

    if (fb->freq > fa->freq) return 1;
    if (fb->freq < fa->freq) return -1;
    return 0;
}

FreqData get_target_freq(const char *path, int mode) {
    FILE *file = fopen 
}