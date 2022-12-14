const std = @import("std");
const util = @import("../util.zig");

const Coord = util.Coord;

fn coordFromText(text: []const u8) !Coord {
    const i = std.mem.indexOf(u8, text, ",").?;
    const x = try std.fmt.parseInt(usize, text[0..i], 10);
    const y = try std.fmt.parseInt(usize, text[i + 1 ..], 10);
    return .{ x, y };
}

const Cavern = struct {
    const Self = @This();
    const EMPTY = ' ';
    const BLOCKED = '#';
    const SAND = 'o';
    const GridType = util.GridT(u8);

    grid: GridType,
    x_offset: usize,
    last_y: usize = 0,
    block_count: u32 = 0,

    pub fn init(
        alloc: std.mem.Allocator,
        x_size: usize,
        y_size: usize,
        x_mid: usize,
    ) !Self {
        var grid = try GridType.initWithValue(alloc, x_size, y_size, EMPTY);
        return .{ .grid = grid, .x_offset = x_mid - @divFloor(x_size, 2) };
    }

    pub fn deinit(self: *Self) void {
        self.grid.deinit();
    }

    // translate x coordinate
    fn xlt(self: *const Self, x: usize) usize {
        return x - self.x_offset;
    }

    fn _fillWallGaps(self: *Self, x: usize, y: usize, v: *u8) bool {
        const mid = v.*;
        const left = self.grid.get(x - 1, y);
        const right = self.grid.get(x + 1, y);
        if (mid == BLOCKED) {
            self.block_count += 1;
            if (left == mid and right == mid) {
                self.grid.set(x, y + 1, BLOCKED);
            }
        }
        return y < self.last_y + 2;
    }

    pub fn fillWallGaps(self: *Self) void {
        self.grid.forEachPadded(_fillWallGaps, self, 1, 0);
    }

    pub fn addBlock(self: *Self, line: []const u8) !void {
        var coord_list = std.ArrayList(Coord).init(self.grid.alloc);
        defer coord_list.deinit();
        // parse input line
        var text = std.mem.tokenize(u8, line, " -> ");
        while (text.next()) |t| {
            try coord_list.append(try coordFromText(t));
        }

        const coords = coord_list.items;
        for (coords) |*p_coord, i| {
            var coord = p_coord.*;
            // stop at last item
            if (i == coords.len - 1) break;
            const next = coords[i + 1];
            const delta = util.vecTo(coord, next);
            while (@reduce(.Or, coord != next)) {
                self.grid.set(
                    self.xlt(util.getX(coord)),
                    util.getY(coord),
                    BLOCKED,
                );
                coord = util.addUnit(coord, delta);
            }
            self.grid.set(
                self.xlt(util.getX(coord)),
                util.getY(coord),
                BLOCKED,
            );
            const c_y = util.getY(coord);
            if (c_y > self.last_y) self.last_y = c_y;
            const n_y = util.getY(next);
            if (n_y > self.last_y) self.last_y = n_y;
        }
    }

    fn reachedVoid(self: *const Self, y: usize) bool {
        return y > self.last_y;
    }

    fn nextStep(self: *Self, c: Coord) ?util.UnitVec {
        const x = util.getX(c);
        const y = util.getY(c);
        if (self.reachedVoid(y)) return null;
        if (self.grid.get(x, y + 1) == EMPTY) {
            return .{ 0, 1 };
        }
        if (self.grid.get(x - 1, y + 1) == EMPTY) {
            return .{ -1, 1 };
        }
        if (self.grid.get(x + 1, y + 1) == EMPTY) {
            return .{ 1, 1 };
        }
        return null;
    }

    pub fn dropSand(self: *Self, x_init: usize) bool {
        var coord = Coord{ self.xlt(x_init), 0 };
        while (self.nextStep(coord)) |step| {
            coord = util.addUnit(coord, step);
        }
        const y = util.getY(coord);
        if (y == 0 or self.reachedVoid(y)) return true;
        const x = util.getX(coord);
        self.grid.set(x, y, SAND);
        return false;
    }
};

pub fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    var cavern = try Cavern.init(alloc, 1000, 1000, 500);
    defer cavern.deinit();

    var lines = std.mem.tokenize(u8, input, "\n");
    while (lines.next()) |line| {
        try cavern.addBlock(line);
    }

    var part1: u32 = 0;
    while (!cavern.dropSand(500)) {
        part1 += 1;
    }

    cavern.fillWallGaps();
    const part2 = @intCast(u32, std.math.pow(usize, (cavern.last_y + 2), 2)) - cavern.block_count;
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
}
