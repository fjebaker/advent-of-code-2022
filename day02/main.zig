// alternative for performance
const std = @import("std");
const util = @import("../util.zig");

fn solve(input: [] const u8) [2]u32 {
    const lines = std.mem.bytesAsSlice([4]u8, input);
    var part1 : u32 = 0;
    var part2 : u32 = 0;
    for (lines) |line| {
        const theirs = line[0];
        const ours = line[2];
        part1 += 3 * ((ours - theirs - 1) % 3) + ours - 'X' + 1;
        part2 += ((ours + theirs - 1) % 3 + 1) + 3 * (ours - 'X');
    }
    return .{part1, part2};
}

pub fn main() void {
    const score = solve(@embedFile("input.txt"));
    std.debug.print("Part 1: {d}\n", .{score[0]});
    std.debug.print("Part 2: {d}\n", .{score[1]});
}

test "test-input" {
    var out = solve(@embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{out[0], out[1]});

    var result = try util.benchmark(std.testing.allocator, solve, .{@embedFile("input.txt")}, .{});
    defer result.deinit();
    result.printSummary();
}