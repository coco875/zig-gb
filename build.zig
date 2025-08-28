const std = @import("std");
const utils = @import("utils.zig");

const emulator = "vbam";

fn buildImpl(b: *std.Build) !void {
    // Obtenir la racine du projet (cwd lors de l'invocation de zig build)
    const root_path = try std.process.getCwdAlloc(b.allocator);
    defer b.allocator.free(root_path);

    // Télécharge + extrait le toolchain GBDK si absent
    try utils.ensure_tar(
        b.allocator,
        root_path,
        "gbdk",
        "https://github.com/gbdk-2020/gbdk-2020/releases/download/4.4.0/gbdk-linux64.tar.gz",
    );

    const zig_out_folder_path = try std.fs.path.join(b.allocator, &.{ root_path, "zig-out" });

    try utils.ensure_file(b.allocator, zig_out_folder_path, "zig.h", "https://raw.githubusercontent.com/ziglang/zig/refs/tags/0.14.1/lib/zig.h");

    const folder = try std.fs.openDirAbsolute(root_path, .{});
    folder.makeDir("zig-out") catch {};

    const obj = b.addSystemCommand(&.{
        "../gbdk/bin/lcc",
        "-Wa-l",
        "-DUSE_SFR_FOR_REG",
        "-c",
        "-o",
        "zig-gb.o",
        "../src/main.c",
    });
    obj.cwd = b.path("zig-out");

    const gb = b.addSystemCommand(&.{
        "../gbdk/bin/lcc", "-Wa-l", "-DUSE_SFR_FOR_REG", "-o", "zig-gb.gb", "zig-gb.o",
    });
    gb.cwd = b.path("zig-out");

    b.default_step.dependOn(&gb.step);
    gb.step.dependOn(&obj.step);

    const run_step = b.step("run", "Run in Visual Boy Advance");
    const vbam = b.addSystemCommand(&.{ emulator, "-F", "zig-out/zig-gb.gb" });
    vbam.cwd = b.path(".");
    run_step.dependOn(&gb.step);
    run_step.dependOn(&vbam.step);
}

pub fn build(b: *std.Build) void {
    buildImpl(b) catch |err| {
        std.log.err("build failed: {s}", .{@errorName(err)});
    };
}
