# ⚡ Interfacil

Interfacil is a Zig package for making and using interfaces easily in Zig. I'm doing a rewrite because the possible removal of the `usingnamespace` keyword.

Here are a few projects with similar purpose:

- [zig_interfaces by yglcode](https://github.com/yglcode/zig_interfaces),
- [zimpl by permutationlock](https://github.com/permutationlock/zimpl),
- [zig-interface by bluesillybeard](https://github.com/bluesillybeard/zig-interface),

## ℹ️ Usage

Make sure you're using zig 0.13.0. If you have trouble managing your zig versions, I can recommand one of those:

- [zvm](https://github.com/tristanisham/zvm)
- [zigup](https://github.com/marler8997/zigup)

1. Fetch the interfacil package into your `build.zig.zon`:

In your project folder with your `build.zig` and `build.zig.zon`, run this command:

```
zig fetch --save=interfacil https://api.github.com/repos/Dok8tavo/Interfacil/tarball
```

2. Get the interfacil module inside your `build.zig`:

In your `build.zig` file, in the `fn (b: *std.Build) !void` function, write:

```zig
const interfacil = b.dependency("interfacil", .{}).module("interfacil");
```

3. Link the interfacil module to your executable/library/test artifact, or your module:

```zig
your_build_artifact.root_module.addImport("interfacil", interfacil);
your_module.addImport("interfacil", interfacil);
```

4. Use the interfacil module in your source code using `@import("interfacil")`.

## 👍 Implemented interfaces

- [Iterators](https://github.com/Dok8tavo/Interfacil/blob/main/src/iteration.zig#L27-L31): from `next` get:
  - `all/any`,
  - `nall/none`,
  - `collectAlloc/collectBuffer`,
  - `filter` and more,
  - `map` and more,
  - `reduce` and more,

## 📃 License

MIT License

Copyright (c) 2024 Dok8tavo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
