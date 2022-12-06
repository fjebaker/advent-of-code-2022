const std = @import("std");
const util = @import("../util.zig");

const BitMask = std.bit_set.IntegerBitSet(26);

fn findMarker(input: []const u8, comptime size: u32) u32 {
    var mask = BitMask.initEmpty();
    // set all inital bits
    for (input[0..size]) |c| {
        mask.toggle(c - 'a');
    }
    // toggle extremal
    for (input[size..]) |c, i| {
        mask.toggle(input[i] - 'a');
        mask.toggle(c - 'a');
        if (mask.count() == size) return @truncate(u32, i + size + 1);
    }
    @panic("No marker found!");
}

fn solve(input: []const u8) [2]u32 {
    const part1 = findMarker(input, 4);
    const part2 = findMarker(input, 14);
    return .{ part1, part2 };
}

pub fn main() !void {
    // const sol = solve(@embedFile("input.txt"));
    // std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();

    var result = try util.benchmark(alloc, solve, .{@embedFile("input.txt")}, .{});
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    try testSolve("mjqjpqmgbljsphdztnvjfqwrcgsmlb", 7, 19);
    try testSolve("bvwbjplbgvbhsrlpgdmjqwftvncz", 5, 23);
    try testSolve("nppdvjthqldpwncqszvftbrmjlhg", 6, 23);
    try testSolve("nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg", 10, 29);
    try testSolve("zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw", 11, 26);

    var result = try util.benchmark(std.testing.allocator, solve, .{@embedFile("input.txt")}, .{});
    defer result.deinit();
    result.printSummary();
}

fn testSolve(input: []const u8, p1: u32, p2: u32) !void {
    const sol = solve(input);
    try std.testing.expect(sol[0] == p1);
    try std.testing.expect(sol[1] == p2);
}
