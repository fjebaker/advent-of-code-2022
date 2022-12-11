const std = @import("std");
const util = @import("../util.zig");

const Coord = @Vector(2, i32);
const UnpackedCoord = [2]i32;
const Mask = std.bit_set.DynamicBitSet;

const RopeSection = struct {
    current: Coord,

    pub fn update(self: *RopeSection, current: Coord) bool {
        const diff = current - self.current;
        const coord_one = Coord{ 1, 1 };
        // clamp within [-1, 1]
        const tmp = @select(i32, diff > coord_one, coord_one, diff);
        const delta = @select(i32, tmp < -coord_one, -coord_one, tmp);

        const modify = @reduce(.Or, delta != diff);
        if (modify) self.current += delta;
        return modify;
    }
};

const Rope = struct {
    alloc: std.mem.Allocator,
    sections: []RopeSection,
    visited: Mask,
    current: Coord,
    dim: usize,

    pub fn init(alloc: std.mem.Allocator, dim: usize, num_sections: usize) !Rope {
        var sections = std.ArrayList(RopeSection).init(alloc);
        errdefer sections.deinit();
        // populate all sections
        var i: usize = 0;
        while (i < num_sections) : (i += 1) {
            try sections.append(.{ .current = .{ 0, 0 } });
        }
        // keep grid of all possible locations
        var mask = try Mask.initEmpty(alloc, dim * dim);
        return .{ .alloc = alloc, .sections = try sections.toOwnedSlice(), .visited = mask, .current = .{ 0, 0 }, .dim = dim };
    }

    pub fn deinit(self: *Rope) void {
        self.visited.deinit();
        self.alloc.free(self.sections);
    }

    pub fn move(self: *Rope, direction: u8, count: u32) void {
        const delta: Coord = switch (direction) {
            'U' => .{ 0, -1 },
            'D' => .{ 0, 1 },
            'L' => .{ -1, 0 },
            'R' => .{ 1, 0 },
            else => unreachable,
        };
        var i: u32 = count;
        while (i > 0) : (i -= 1) {
            self.current = self.current + delta;
            self.updateSections();
        }
    }

    pub fn updateSections(self: *Rope) void {
        var current = self.current;
        for (self.sections) |*section| {
            // if we didn't update, no need to continue
            if (!section.update(current)) return;
            current = section.current;
        }
        self.updateMask(current);
    }

    fn updateMask(self: *Rope, position: Coord) void {
        // translate to middle since coords can be negative
        const mid = @intCast(i32, @divFloor(self.dim, 2));
        const coord: UnpackedCoord = position + Coord{ mid, mid };
        const index = @intCast(u32, coord[0] + coord[1] * @intCast(i32, self.dim));
        self.visited.set(index);
    }
};

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    var single_rope = try Rope.init(alloc, 500, 1);
    defer single_rope.deinit();

    var full_rope = try Rope.init(alloc, 500, 9);
    defer full_rope.deinit();

    var lines = std.mem.tokenize(u8, input, "\n");
    while (lines.next()) |line| {
        const direction = line[0];
        const count = try std.fmt.parseInt(u32, line[2..], 10);

        single_rope.move(direction, count);
        full_rope.move(direction, count);
    }
    const part1 = @truncate(u32, single_rope.visited.count()) + 1;
    const part2 = @truncate(u32, full_rope.visited.count()) + 1;

    return .{ part1, part2 };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(allocator, solve, .{ allocator, @embedFile("input.txt") }, .{});
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
    const sol2 = try solve(std.testing.allocator, @embedFile("test2.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol2[0], sol2[1] });
}
