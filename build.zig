const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "garlic",
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    // b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const exe_circles = b.addExecutable(.{
        .name = "circle-test",
        .root_source_file = .{ .path = "examples/circles.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_circles.addAnonymousModule("garlic", .{ .source_file = .{ .path = "./src/main.zig" } });
    const run_circles = b.addRunArtifact(exe_circles);
    const circles_step = b.step("example-circles", "run circle physics example");
    circles_step.dependOn(&run_circles.step);

    const exe_phys2d = b.addExecutable(.{
        .name = "circle-test",
        .root_source_file = .{ .path = "examples/phys2d.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_phys2d.addAnonymousModule("garlic", .{ .source_file = .{ .path = "./src/cl201.zig" } });
    const run_phys2d = b.addRunArtifact(exe_phys2d);
    const phys2d_step = b.step("example-phys2d", "run physics example");
    phys2d_step.dependOn(&run_phys2d.step);
}
