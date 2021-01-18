const bld = @import("std").build;

pub fn buildLib(b: *bld.Builder, comptime prefix_path: []const u8) *bld.LibExeObjStep {
    const lib = b.addStaticLibrary("stb", null);
    if (prefix_path.len > 0) lib.addIncludeDir(prefix_path ++ "src");
    lib.linkLibC();
    lib.setBuildMode(b.standardReleaseOptions());
    lib.addCSourceFile(prefix_path ++ "src/stb.c", &[_][]const u8{});
    return lib;
}

pub fn build(b: *bld.Builder) void {
    _ = buildLib(b, "");
}