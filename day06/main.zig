const std = @import("std");
const util = @import("../util.zig");

const BitMask = std.bit_set.IntegerBitSet(26);

fn findMarker(input: []const u8, size: u32) u32 {
    const trimmed_size = input.len - size;
    var start: u32 = 0;
    while (start < trimmed_size) : (start += 1) {
        var mask = BitMask.initEmpty();
        const end = start + size;
        for (input[start..end]) |c| {
            mask.set(c - 'a');
        }
        if (mask.count() == size) {
            return end;
        }
    }
    unreachable;
}

fn solve(input: []const u8) [2]u32 {
    const part1 = findMarker(input, 4);
    const part2 = findMarker(input, 14);
    return .{ part1, part2 };
}

pub fn main() void {
    const sol = solve(@embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}

test "test-input" {
    try testSolve("mjqjpqmgbljsphdztnvjfqwrcgsmlb", 7, 19);
    try testSolve("bvwbjplbgvbhsrlpgdmjqwftvncz", 5, 23);
    try testSolve("nppdvjthqldpwncqszvftbrmjlhg", 6, 23);
    try testSolve("nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg", 10, 29);
    try testSolve("zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw", 11, 26);
}

fn testSolve(input: []const u8, p1: u32, p2: u32) !void {
    const sol = solve(input);
    try std.testing.expect(sol[0] == p1);
    try std.testing.expect(sol[1] == p2);
}
