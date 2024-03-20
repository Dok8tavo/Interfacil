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

    const interfacil = b.addModule("interfacil", .{
        .root_source_file = .{ .path = "src/interfacil.zig" },
    });

    const examples_path = b.pathFromRoot("src/examples/");
    const examples_dir = try std.fs.openDirAbsolute(examples_path, .{ .iterate = true });
    var walker = examples_dir.walk(b.allocator) catch @panic("OOM!");

    while (walker.next() catch @panic("OOM!")) |entry| if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".zig")) {
        const name = entry.basename[0 .. entry.basename.len - ".zig".len];
        const example = b.addExecutable(.{
            .name = name,
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .path = std.fmt.allocPrint(
                b.allocator,
                "{s}/{s}",
                .{ examples_path, entry.path },
            ) catch @panic("OOM!") },
        });

        example.root_module.addImport("interfacil", interfacil);

        const run_example = b.addRunArtifact(example);
        if (b.args) |args| run_example.addArgs(args);
        const step = b.step(
            std.fmt.allocPrint(
                b.allocator,
                "interfacil-example-{s}",
                .{name},
            ) catch @panic("OOM!"),
            std.fmt.allocPrint(
                b.allocator,
                "Build & Run the interfacil example \"{s}\".",
                .{name},
            ) catch @panic("OOM!"),
        );

        step.dependOn(&run_example.step);
        run_example.step.dependOn(&example.step);
    };
}
