const std = @import("std");
const util = @import("../util.zig");

const DIST_MAX = std.math.inf_u32;

const Coord = struct { x: usize, y: usize };

const Tile = struct {
    coord: Coord,
    distance: u32,
    value: u8,
    previous: ?*Tile = null,
};

fn minimum_distance(_: void, a: *Tile, b: *Tile) std.math.Order {
    return std.math.order(a.distance, b.distance);
}
const PriorityQueue = std.PriorityQueue(*Tile, void, minimum_distance);

const Iterator = struct {
    tiles: [4]?*Tile,
    index: usize = 0,
    pub fn next(self: *Iterator) ?*Tile {
        while (self.index < self.tiles.len) {
            defer self.index += 1;
            if (self.tiles[self.index]) |tile| {
                return tile;
            }
        }
        return null;
    }
};

const HeightMap = struct {
    const ConditionProto = fn (u8, u8) bool;
    rows: usize,
    cols: usize,
    map: [][]Tile,
    alloc: std.mem.Allocator,
    condition: *const ConditionProto,

    fn translate(i: u8) u8 {
        if (i == 'E') return 'z';
        if (i == 'S') return 'a';
        return i;
    }

    pub fn initFromInput(
        alloc: std.mem.Allocator,
        input: []const u8,
        cond: *const ConditionProto,
    ) !HeightMap {
        var lines = std.mem.split(u8, input, "\n");

        var rowlist = std.ArrayList([]Tile).init(alloc);
        defer rowlist.deinit();
        defer for (rowlist.items) |item| alloc.free(item);

        var j: usize = 0;
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var tiles = try alloc.alloc(Tile, line.len);
            errdefer alloc.free(tiles);
            for (line) |c, i| {
                // create tile
                tiles[i] = .{
                    .coord = .{ .x = i, .y = j },
                    .distance = DIST_MAX,
                    .value = c,
                };
            }
            try rowlist.append(tiles);
            j += 1;
        }

        var map = try rowlist.toOwnedSlice();
        return .{
            .map = map,
            .alloc = alloc,
            .rows = map.len,
            .cols = map[0].len,
            .condition = cond,
        };
    }

    pub fn deinit(self: *HeightMap) void {
        for (self.map) |row| {
            self.alloc.free(row);
        }
        self.alloc.free(self.map);
    }

    pub fn reset(self: *HeightMap) void {
        for (self.map) |row| for (row) |*item| {
            item.distance = DIST_MAX;
            item.previous = null;
        };
    }

    fn getNeighbour(self: *const HeightMap, current: *const Tile, dx: i8, dy: i8) ?*Tile {
        const x = @intCast(i32, current.coord.x) + dx;
        const y = @intCast(i32, current.coord.y) + dy;
        if (x >= 0 and y >= 0 and x < self.cols and y < self.rows) {
            const j = @intCast(usize, y);
            const i = @intCast(usize, x);
            // get neighbour
            var next = &self.map[j][i];
            // ensure we can only go up 1 or down any
            if (self.condition(translate(next.value), translate(current.value))) {
                return next;
            }
        }
        return null;
    }

    pub fn getRoutes(self: *const HeightMap, current: *const Tile) Iterator {
        var itt = .{ .tiles = [_]?*Tile{
            self.getNeighbour(current, 0, -1),
            self.getNeighbour(current, 1, 0),
            self.getNeighbour(current, 0, 1),
            self.getNeighbour(current, -1, 0),
        } };
        return itt;
    }

    pub fn find(self: *const HeightMap, value: u8) *Tile {
        for (self.map) |row| for (row) |*item| {
            if (item.value == value) return item;
        };
        unreachable;
    }
};

fn contains(queue: *const PriorityQueue, tile: *const Tile) bool {
    const coord = tile.coord;
    for (queue.items[0..queue.len]) |item| {
        const other = item.coord;
        if (other.x == coord.x and other.y == coord.y) return true;
    }
    return false;
}

fn upsert(queue: *PriorityQueue, tile: *Tile) !void {
    if (contains(queue, tile)) {
        try queue.update(tile, tile);
    } else {
        try queue.add(tile);
    }
}

fn dijkstra(map: HeightMap, queue: *PriorityQueue, start: *Tile, target: u8) !u32 {
    // init staring tile
    start.distance = 0;
    try queue.add(start);

    const target_node: *Tile = blk: {
        while (queue.removeOrNull()) |current| {
            if (current.value == target) break :blk current;
            // get all possible routes
            var neighbours = map.getRoutes(current);
            while (neighbours.next()) |neighbour| {
                // cost is always 1
                const alt = 1 + current.distance;
                if (alt < neighbour.distance) {
                    neighbour.distance = alt;
                    neighbour.previous = current;
                    try upsert(queue, neighbour);
                }
            }
        }
        unreachable;
    };
    var count: u32 = 0;
    var current = target_node;
    while (current.previous) |parent| {
        current = parent;
        count += 1;
    }
    return count;
}

fn ascending(next: u8, current: u8) bool {
    return @intCast(i16, next) - current <= 1;
}
fn descending(next: u8, current: u8) bool {
    return ascending(current, next);
}

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    var map = try HeightMap.initFromInput(alloc, input, ascending);
    defer map.deinit();
    var queue = PriorityQueue.init(alloc, {});
    defer queue.deinit();

    const part1 = try dijkstra(map, &queue, map.find('S'), 'E');

    map.reset();
    map.condition = descending;

    const part2 = try dijkstra(map, &queue, map.find('E'), 'a');

    return .{ part1, part2 };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
