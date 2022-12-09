const std = @import("std");
const util = @import("../util.zig");

const VisMask = std.bit_set.DynamicBitSet;
const Direction = enum { left, right, up, down };

const Forest = struct {
    const Self = @This();
    input: [][]const u8,
    size: usize,
    visible: *VisMask,

    fn nextInbounds(self: *const Self, x: usize, y: usize) bool {
        return x > 0 and y > 0 and y < self.size - 1 and x < self.size - 1;
    }

    pub fn scoreVisible(self: *Self, x: usize, y: usize, comptime direction: Direction) u64 {
        const tree = self.input[y][x];
        var i: usize = x;
        var j: usize = y;
        var score: u64 = 0;
        while (score < self.size) : (score += 1) {
            switch (direction) {
                .left => i -= 1,
                .right => i += 1,
                .up => j -= 1,
                .down => j += 1,
            }
            if (tree <= self.input[j][i]) break;
            if (!self.nextInbounds(i, j)) {
                self.visible.set(x + y * self.size);
                break;
            }
        }
        return score + 1;
    }
};

fn unpack(alloc: std.mem.Allocator, input: [] const u8) ![][]const u8 {
    var acc = std.ArrayList([]const u8).init(alloc);
    errdefer acc.deinit();
    var lines = std.mem.tokenize(u8, input, "\n");
    while (lines.next()) |line| {
        try acc.append(line);
    }
    return acc.toOwnedSlice();
}

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u64 {
    const size = std.mem.indexOf(u8, input, "\n").?;

    var visible = try VisMask.initEmpty(alloc, size * size);
    defer visible.deinit();

    var matrix_input = try unpack(alloc, input);
    defer alloc.free(matrix_input);

    var forest: Forest = .{ .input = matrix_input, .size = size, .visible = &visible };

    var part2: u64 = 0;

    var x: usize = 1;
    const dim = size - 1;
    while (x < dim) : (x += 1) {
        var y: usize = 1;
        while (y < dim) : (y += 1) {
            var total: u64 = 1;
            inline for ([_]Direction{ .up, .down, .left, .right }) |dir| {
                const score = forest.scoreVisible(x, y, dir);
                total *= score;
            }
            part2 = @maximum(total, part2);
        }
    }

    const part1 = visible.count() + (4 * size) - 4;
    return .{ part1, part2 };
}

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // var allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(allocator, solve, .{allocator, @embedFile("input.txt")}, .{});
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
