const std = @import("std");
const util = @import("../util.zig");

const Elf = struct { low: u8, high: u8 };

fn parseElf(range: []const u8) !Elf {
    const sep = std.mem.indexOfScalar(u8, range, '-').?;
    return .{
        .low = try std.fmt.parseInt(u8, range[0..sep], 10),
        .high = try std.fmt.parseInt(u8, range[sep + 1 ..], 10),
    };
}

fn overlap(elf1: Elf, elf2: Elf) bool {
    // if subtracted range contains zero, i.e. differences has
    // opposite signs
    const diff1 = @intCast(i16, elf1.low) - elf2.low;
    const diff2 = @intCast(i16, elf1.high) - elf2.high;
    // will be exactly 0 if the two ranges are the same
    return diff1 * diff2 <= 0;
}

fn overlapAtAll(elf1: Elf, elf2: Elf) bool {
    const diff1 = @intCast(i16, elf1.high) - elf2.low;
    const diff2 = @intCast(i16, elf1.low) - elf2.high;
    return diff1 * diff2 <= 0;
}

fn solve(input: []const u8) ![2]u32 {
    var lines = std.mem.split(u8, input, "\n");

    var part1: u32 = 0;
    var part2: u32 = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        // aaaaah input can have multiple digits
        const sep = std.mem.indexOfScalar(u8, line, ',').?;
        const elf1 = try parseElf(line[0..sep]);
        const elf2 = try parseElf(line[sep + 1 ..]);
        // solve parts
        if (overlap(elf1, elf2)) part1 += 1;
        if (overlapAtAll(elf1, elf2)) part2 += 1;
    }

    return .{ part1, part2 };
}

pub fn main() !void {
    const sol = try solve(@embedFile("input.txt"));
    std.debug.print("Part 1: {d}\n Part 2: {d}\n", .{ sol[0], sol[1] });
}

test "test-input" {
    const sol = try solve(@embedFile("test.txt"));
    std.debug.print("Part 1: {d}\n Part 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(std.testing.allocator, solve, .{@embedFile("input.txt")}, .{});
    defer result.deinit();
    result.printSummary();
}

// lol this would have been plenty

// if (elf1.low >= elf2.low and elf1.high <= elf2.high or elf1.low <= elf1.low and elf1.high >= elf2.high) {
//     part1 += 1;
// }

// // is there any overlap
// if (elf1.high >= elf2.low and elf1.low <= elf2.high) {
//     part2 += 1;
// }
