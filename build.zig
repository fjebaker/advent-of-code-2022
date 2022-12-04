const std = @import("std");

pub fn setup_day(
    b: *std.build.Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
    day: u32,
) void {
    const path = b.fmt("day{:0>2}", .{day});
    const root_src = b.fmt("{s}/main.zig", .{path});
    const exe = b.addExecutable(path, root_src);

    exe.setMainPkgPath("");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(path, "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_test = b.addTest(root_src);
    exe_test.setMainPkgPath("");
    exe_test.setTarget(target);
    exe_test.setBuildMode(mode);

    const test_step = b.step(b.fmt("test_{s}", .{path}), "Run tests for given day.");
    test_step.dependOn(&exe_test.step);
}

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    setup_day(b, target, mode, 1);
    setup_day(b, target, mode, 2);
    setup_day(b, target, mode, 3);
    setup_day(b, target, mode, 4);
}
