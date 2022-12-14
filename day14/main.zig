const std = @import("std");

const Grid = struct {
    const Self = @This();
    const EMPTY = ' ';
    const BLOCKED = '#';
    const SAND = 'o';

    alloc: std.mem.Allocator,
    grid: []u8,
    x_size: usize,
    y_size: usize,
    xoffset: usize,
    last_y_block: usize = 0,
    floor: bool = false,

    pub fn init(alloc: std.mem.Allocator, x_size: usize, y_size: usize, x_mid: usize) !Grid {
        var grid = try alloc.alloc(u8, x_size * y_size);
        for (grid) |*item| item.* = EMPTY;
        return .{
            .grid = grid,
            .x_size = x_size,
            .y_size = y_size,
            .xoffset = x_mid - @divFloor(x_size, 2),
            .alloc = alloc,
        };
    }

    const Coord = struct {
        x: usize,
        y: usize,
        pub fn fromText(text: []const u8) !Coord {
            const i = std.mem.indexOf(u8, text, ",").?;
            const x = try std.fmt.parseInt(usize, text[0..i], 10);
            const y = try std.fmt.parseInt(usize, text[i + 1 ..], 10);
            return .{ .x = x, .y = y };
        }
        pub fn vectorTo(self: *const Coord, other: Coord) Delta {
            const dx: i32 = @intCast(i32, other.x) - @intCast(i32, self.x);
            const dy: i32 = @intCast(i32, other.y) - @intCast(i32, self.y);
            // clamp within -1 and 1
            const dx_norm = @intCast(i8, std.math.clamp(dx, -1, 1));
            const dy_norm = @intCast(i8, std.math.clamp(dy, -1, 1));
            return .{ .dx = dx_norm, .dy = dy_norm };
        }
    };

    pub fn addBlock(self: *Self, line: []const u8) !void {
        var coord_list = std.ArrayList(Coord).init(self.alloc);
        defer coord_list.deinit();
        var text = std.mem.tokenize(u8, line, " -> ");
        while (text.next()) |t| try coord_list.append(try Coord.fromText(t));

        const coords = coord_list.items;
        for (coords) |*coord, i| {
            // stop at last item
            if (i == coords.len - 1) break;
            const next = coords[i + 1];
            const delta = coord.vectorTo(next);
            while (coord.x != next.x or coord.y != next.y) {
                self.grid[self.at(coord.x, coord.y)] = BLOCKED;
                coord.x = @intCast(usize, @intCast(i32, coord.x) + delta.dx);
                coord.y = @intCast(usize, @intCast(i32, coord.y) + delta.dy);
            }
            self.grid[self.at(next.x, next.y)] = BLOCKED;
            // update track of where void is
            if (coord.y > self.last_y_block) self.last_y_block = coord.y;
            if (next.y > self.last_y_block) self.last_y_block = next.y;
        }
    }

    pub fn at(self: *Self, x: usize, y: usize) usize {
        const x_adjusted = x - self.xoffset;
        if (x_adjusted >= 0 and x_adjusted < self.x_size and y >= 0 and y < self.y_size) {
            return x_adjusted + y * self.x_size;
        } else @panic("Out of bounds!");
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.grid);
    }

    const Delta = struct { dx: i8, dy: i8 };
    fn nextStep(self: *Self, x: usize, y: usize) ?Delta {
        if (self.reachedVoid(y)) return null;

        if (self.grid[self.at(x, y + 1)] == EMPTY) {
            return .{ .dx = 0, .dy = 1 };
        }
        if (self.grid[self.at(x - 1, y + 1)] == EMPTY) {
            return .{ .dx = -1, .dy = 1 };
        }
        if (self.grid[self.at(x + 1, y + 1)] == EMPTY) {
            return .{ .dx = 1, .dy = 1 };
        }
        return null;
    }

    pub fn dropSand(self: *Self, x_init: usize) bool {
        var x: usize = x_init;
        var y: usize = 0;
        while (self.nextStep(x, y)) |delta| {
            x = @intCast(usize, @intCast(i32, x) + delta.dx);
            y = @intCast(usize, @intCast(i32, y) + delta.dy);
        }
        if (self.floor) {
            // top of sand
            if (y == 0) return true;
        } else {
            if (self.reachedVoid(y)) return true;
        }
        self.grid[self.at(x, y)] = SAND;
        return false;
    }

    fn reachedVoid(self: *const Self, y: usize) bool {
        return y > self.last_y_block;
    }

    pub fn prettyPrint(self: *Self) void {
        var y: usize = 0;
        while (y < self.y_size) : (y += 1) {
            var x: usize = self.xoffset;
            while (x < self.x_size + self.xoffset) : (x += 1) {
                std.debug.print("{c}", .{self.grid[self.at(x, y)]});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn reset(self: *Self) void {
        for (self.grid) |*item| {
            if (item.* == SAND) item.* = EMPTY;
        }
    }
};

pub fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    var grid = try Grid.init(alloc, 1000, 1000, 500);
    defer grid.deinit();
    var lines = std.mem.tokenize(u8, input, "\n");
    while (lines.next()) |line| try grid.addBlock(line);

    var part1: u32 = 0;
    while (!grid.dropSand(500)) {
        part1 += 1;
    }
    grid.reset();
    grid.floor = true;

    // add 1 for the top of the pyramid
    var part2: u32 = 1;
    while (!grid.dropSand(500)) {
        part2 += 1;
    }

    return .{ part1, part2 };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    // var result = try util.benchmark(allocator, solve, .{ allocator, @embedFile("input.txt") }, .{});
    // defer result.deinit();
    // result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
