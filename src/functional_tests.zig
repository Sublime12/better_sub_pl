const std = @import("std");

const TestCase = struct {
    name: []const u8,
    file_path: []const u8,
    expected_stdout: []const u8,
};

const test_cases = [_]TestCase{
    .{
        .name = "helloworld put_char(65)",
        .file_path = "examples/helloworld.sub",
        .expected_stdout = "A",
    },
};

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.page_allocator;
    const io = init.io;

    var failed: usize = 0;

    for (test_cases) |tc| {
        const compile_res = try std.process.run(alloc, io, .{
            .argv = &.{ "./zig-out/bin/sub2_lang", "--gen", tc.file_path },
        });
        defer alloc.free(compile_res.stdout);
        defer alloc.free(compile_res.stderr);

        if (compile_res.term != .exited or compile_res.term.exited != 0) {
            std.debug.print("[FAIL] {s}: compiler exited with {}\n{s}\n", .{
                tc.name,
                compile_res.term,
                compile_res.stderr,
            });
            failed += 1;
            continue;
        }

        const run_res = try std.process.run(alloc, io, .{
            .argv = &.{"./build/output"},
        });
        defer alloc.free(run_res.stdout);
        defer alloc.free(run_res.stderr);

        if (run_res.term != .exited or run_res.term.exited != 0) {
            std.debug.print("[FAIL] {s}: binary exited with {}\n", .{ tc.name, run_res.term });
            failed += 1;
            continue;
        }

        if (!std.mem.eql(u8, tc.expected_stdout, run_res.stdout)) {
            std.debug.print(
                "[FAIL] {s}: expected stdout \"{s}\", got \"{s}\"\n",
                .{ tc.name, tc.expected_stdout, run_res.stdout },
            );
            failed += 1;
            continue;
        }

        std.debug.print("[PASS] {s}\n", .{tc.name});
    }

    if (failed > 0) {
        std.process.exit(1);
    }
}
