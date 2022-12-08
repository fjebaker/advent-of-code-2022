const std = @import("std");
const util = @import("../util.zig");

const TOTAL_SPACE = 70000000;
const MINIMUM_SPACE = 30000000;

fn fileSize(line: []const u8) u64 {
    var itt = std.mem.tokenize(u8, line, " ");
    const string = itt.next().?;
    return std.fmt.parseInt(u64, string, 10) catch return 0;
}

fn dirSize(lines: *std.mem.TokenIterator(u8), size_list: *std.ArrayList(u64)) !u64 {
    var sum: u64 = 0;
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "$ cd ..")) break;
        const size = if (line.len > 4 and std.mem.eql(u8, line[0..4], "$ cd")) try dirSize(lines, size_list) else fileSize(line);
        sum += size;
    }
    try size_list.append(sum);
    return sum;
}

fn solve(input:[] const u8, alloc: std.mem.Allocator) ![2]u64 {
    var size_list = std.ArrayList(u64).init(alloc);
    defer size_list.deinit();

    var lines = std.mem.tokenize(u8, input, "\n");
    const sum = try dirSize(&lines, &size_list);

    const space_needed = MINIMUM_SPACE - (TOTAL_SPACE - sum);
    var part1: u64 = 0;
    var part2: u64 = TOTAL_SPACE;
    for (size_list.items) |size| {
        if (size <= 100000) part1 += size;
        if (size >= space_needed and size < part2) part2 = size;
    }

    // root.print(0);
    return .{ part1, part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    const sol = try solve(@embedFile("input.txt"), allocator);
    std.debug.print("Part 1: {d}\n Part 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(allocator, solve, .{ @embedFile("input.txt"), allocator }, .{});
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    const sol = try solve(@embedFile("test.txt"), std.testing.allocator);
    std.debug.print("Part 1: {d}\n Part 2: {d}\n", .{ sol[0], sol[1] });

    try std.testing.expect(sol[0] == 95437);
    try std.testing.expect(sol[1] == 24933642);
}
