const bld = @import("std").build;
const mem = @import("std").mem;
const zig = @import("std").zig;
const ArrayList = @import("std").ArrayList;

pub fn build(b: *bld.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-game", "src/main.zig");
    const sokol_lib = @import("deps/sokol/build.zig").buildSokol(b, "deps/sokol/");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibrary(sokol_lib);
    const stb_lib = @import("deps/stb/build.zig").buildLib(b, "deps/stb/");
    exe.linkLibrary(stb_lib);
    exe.addPackagePath("sokol", "deps/sokol/src/sokol/sokol.zig");
    exe.addPackagePath("stb", "deps/stb/src/stb.zig");
    exe.addPackagePath("zlm", "deps/zlm/zlm.zig");
    exe.addPackage(bld.Pkg{
        .name = "wavefront-obj",
        .path = "deps/wavefront-obj/wavefront-obj.zig",
        .dependencies = &[_]bld.Pkg{
            .{
                .name = "zlm",
                .path = "deps/zlm/zlm.zig",
            },
        },
    });

    // fontstash
    // exe.linkLibC();
    // const lib_cflags = &[_][]const u8{"-O3"};
    // exe.addCSourceFile("deps/fontstash/src/fontstash.c", lib_cflags);
    // exe.addPackage(.{
    //     .name = "fontstash",
    //     .path = "deps/fontstash/fontstash.zig",
    // });
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
