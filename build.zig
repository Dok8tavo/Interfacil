
const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "interfacil",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/interfacil.zig" },
    });

    const doc = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc",
    });

    const tests = b.addTest(.{
        .optimize = optimize,
        .target = target,
        .root_source_file = .{ .path = "src/interfacil.zig" },
    });

    const test_step = b.step("test", "Run all tests");
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    const doc_step = b.step("doc", "Generate documentation");
    doc_step.dependOn(&lib.step);
    doc_step.dependOn(&doc.step);

    _ = b.addModule("interfacil", .{
        .root_source_file = .{ .path = "src/interfacil.zig" },
    });
}
