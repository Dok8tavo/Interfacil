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

    const examples_path = b.pathFromRoot("src/examples");
    var examples_dir = try std.fs.openDirAbsolute(examples_path, .{ .iterate = true });
    defer examples_dir.close();
    var examples_walker = try examples_dir.walk(b.allocator);
    while (try examples_walker.next()) |entry| switch (entry.kind) {
        .file => {
            const example_file = entry.basename;
            if (!std.mem.endsWith(u8, example_file, ".zig")) continue;
            const example_name = example_file[0 .. example_file.len - 4];
            const example_path = std.fmt.allocPrint(
                b.allocator,
                "{s}/{s}",
                .{ examples_path, entry.path },
            ) catch @panic("OOM!");
            const example = b.addExecutable(.{
                .name = example_name,
                .target = target,
                .optimize = optimize,
                .root_source_file = .{ .path = example_path },
            });
            addInterfacil(b, example, "interfacil");
            const run_example = b.addRunArtifact(example);
            const example_step = b.step(example_name, "Run the example!");
            example_step.dependOn(&run_example.step);
        },
        else => continue,
    };
}

pub fn addInterfacil(b: *std.Build, to: *std.Build.Step.Compile, name: []const u8) void {
    const module = b.createModule(.{
        .root_source_file = .{ .path = "src/interfacil.zig" },
    });

    to.root_module.addImport(name, module);
}
