const std = @import("std");
const util = @import("../util.zig");

const Bag = std.bit_set.IntegerBitSet(26 * 2);

fn priorityScore(c: u8) u8 {
    return if (c >= 'a') c - 'a' else c - 'A' + 26;
}

fn setRepr(bag: []const u8) Bag {
    var set = Bag.initEmpty();
    for (bag) |item| {
        set.set(priorityScore(item));
    }
    return set;
}

fn unpack(bag: Bag) u32 {
    // add 1 for offset
    return @intCast(u32, bag.findFirstSet().?) + 1;
}

fn solvePart1(line: []const u8) u32 {
    const mid = line.len / 2;
    var set = setRepr(line[0..mid]);
    set.setIntersection(setRepr(line[mid..]));
    return unpack(set);
}

fn solve(input: []const u8) ![2]u32 {
    // iterate for each line
    var lines = std.mem.split(u8, input, "\n");

    var part1: u32 = 0;
    var part2: u32 = 0;
    var group = Bag.initFull();
    var i: u8 = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        part1 += solvePart1(line);

        const bag = setRepr(line);
        group.setIntersection(bag);

        i += 1;
        if (i == 3) {
            part2 += unpack(group);
            // reset
            group = Bag.initFull();
            i = 0;
        }
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
}
