# Red only
service call SurfaceFlinger 1015 i32 1 f 1.0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 1

# Green only
service call SurfaceFlinger 1015 i32 1 f 0 f 0 f 0 f 0 f 0 f 1.0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 1

# Blue only
service call SurfaceFlinger 1015 i32 1 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 0 f 1.0 f 0 f 0 f 0 f 0 f 1

# Screen Saturation
service call SurfaceFlinger 1022 f 2.0