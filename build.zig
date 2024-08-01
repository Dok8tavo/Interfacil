// MIT License
//
// Copyright (c) 2024 Dok8tavo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const std = @import("std");

pub fn build(b: *std.Build) !void {
    // options
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // artifacts
    const library = b.addStaticLibrary(.{
        .name = "interfacil",
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    _ = b.addModule("interfacil", .{
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const documentation = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = library.getEmittedDocs(),
    });

    const build_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const run_tests = b.addRunArtifact(build_tests);

    // steps
    run_tests.step.dependOn(&build_tests.step);

    b.installArtifact(library);

    b.step("zls_step", "Ran by zls to speed it up").dependOn(&library.step);
    b.step("docs", "Emit documentation").dependOn(&documentation.step);
    b.step("test", "Build & run tests").dependOn(&run_tests.step);

    // when on release mode, depends on tests!
    if (optimize != .Debug) library.step.dependOn(&run_tests.step);
}
