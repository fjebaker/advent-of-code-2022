const util = @import("../util.zig");
const std = @import("std");

pub fn updateMax(max: []u32, current: u32) void {
    if (current > max[0]) {
        max[2] = max[1];
        max[1] = max[0];
        max[0] = current;
    } else if (current > max[1]) {
        max[2] = max[1];
        max[1] = current;
    } else if (current > max[2]) {
        max[2] = current;
    }
}

pub fn solve(input: []const u8) ![3]u32 {
    var lines = std.mem.split(u8, input, "\n");

    var max: [3]u32 = .{ 0, 0, 0 };
    var current: u32 = 0;
    while (lines.next()) |line| {
        if (line.len == 0) {
            updateMax(&max, current);
            current = 0;
        } else {
            const num = try std.fmt.parseInt(u32, line, 10);
            current += num;
        }
    }
    // make sure we get the last elf
    updateMax(&max, current);
    return max;
}

pub fn main() !void {
    const max = try solve(@embedFile("input.txt"));
    const total = @reduce(.Add, @as(@Vector(3, u32), max));
    std.debug.print("Part 1: {d}\n", .{max[0]});
    std.debug.print("Part 2: {any} = {d}\n", .{ max, total });
}

test "test-input" {
    const max = try solve(@embedFile("test.txt"));
    const total = @reduce(.Add, @as(@Vector(3, u32), max));
    try std.testing.expectEqual(max[0], 24000);
    try std.testing.expectEqual(total, 45000);

    var result = try util.benchmark(std.testing.allocator, solve, .{@embedFile("input.txt")}, .{});
    defer result.deinit();
    result.printSummary();
}
