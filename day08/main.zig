const std = @import("std");
const util = @import("../util.zig");
const AtProto = fn (usize, usize) usize;

const Direction = enum { left, right, up, down };

pub fn Forrest(comptime size: comptime_int) type {
    return struct {
        const Self = @This();
        input: []const [size + 1]u8,
        visible: *std.bit_set.ArrayBitSet(usize, size * size),

        fn nextInbounds(_: *const Self, x: usize, y: usize) bool {
            return x > 0 and y > 0 and y < size - 1 and x < size - 1;
        }

        pub fn scoreVisible(self: *Self, x: usize, y: usize, direction: Direction) u64 {
            var score: u64 = 1;
            const tree = self.input[y][x];
            var i: usize = x;
            var j: usize = y;
            var k: u64 = 0;
            while (true) {
                switch (direction) {
                    .left => i -= 1,
                    .right => i += 1,
                    .up => j -= 1,
                    .down => j += 1,
                }
                const neighbour = self.input[j][i];
                if (tree <= neighbour) break;
                if (!self.nextInbounds(i, j)) {
                    self.visible.set(x + y * size);
                    break;
                }
                k += 1;
            }
            score *= k + 1;
            return score;
        }
    };
}

fn solve(comptime input: []const u8) [2]u64 {
    const size = comptime std.mem.indexOf(u8, input, "\n").?;
    std.debug.print("SIZE {d}\n", .{size});
    const VisMask = std.bit_set.ArrayBitSet(usize, size * size);
    var visible = VisMask.initEmpty();

    const matrix_input = std.mem.bytesAsSlice([size + 1]u8, input);
    var forrest: Forrest(size) = .{ .input = matrix_input, .visible = &visible };

    var x: usize = 1;
    var part2: u64 = 0;
    const dim = size - 1;
    while (x < dim) : (x += 1) {
        var y: usize = 1;
        while (y < dim) : (y += 1) {
            var total: u64 = 1;
            inline for ([_]Direction{ .up, .down, .left, .right }) |dir| {
                const score = forrest.scoreVisible(x, y, dir);
                total *= score;
            }
            part2 = @maximum(total, part2);
        }
    }

    const part1 = visible.count() + (4 * size) - 4;

    return .{ part1, part2 };
}

pub fn main() !void {
    const sol = solve(@embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    // var result = try util.benchmark(alloc, solve, .{@embedFile("input.txt")}, .{});
    // defer result.deinit();
    // result.printSummary();
}

test "test-input" {
    const sol = solve(@embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
