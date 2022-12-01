const util = @import("../util.zig");
const std = @import("std");
const input = @embedFile("input.txt");

pub fn main() !void {
    var lines = std.mem.split(u8, input, "\n");

    var max : u32 = 0;
    var max2 : u32 = 0;
    var max3 : u32 = 0;
    var current : u32 = 0;
    while (lines.next()) |line| {
        // std.debug.print("{s}\n", .{line});
        if (line.len == 0) {
            // std.debug.print("-> {d}\n", .{current});
            if (current > max) {
                max3 = max2;
                max2 = max;
                max = current;
            } else if (current > max2) {
                max3 = max2;
                max2 = current;
            } else if (current > max3) {
                max3 = current;
            }
            current = 0;
            continue;
        }
        const num = try std.fmt.parseInt(u32, line, 10);
        current += num;
    }
    if (current > max) {
        max3 = max2;
        max2 = max;
        max = current;
    } else if (current > max2) {
        max3 = max2;
        max2 = current;
    } else if (current > max3) {
        max3 = current;
    }

    std.debug.print("Part 1: {d}\n", .{max});
    std.debug.print("Part 2: {d} + {d} + {d} = {d}\n", .{max, max2, max3, max + max2 + max3});
}
