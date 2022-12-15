const std = @import("std");
const util = @import("../util.zig");

const Coord = struct {
    x: i64,
    y: i64,

    fn diff(i: i64, j: i64) i64 {
        return std.math.absInt(i - j) catch unreachable;
    }

    pub fn manhattan(self: *const Coord, other: Coord) i64 {
        const dx = diff(self.x, other.x);
        const dy = diff(self.y, other.y);
        return dx + dy;
    }

    pub fn distToHorizontal(self: *const Coord, y: i64) i64 {
        return diff(self.y, y);
    }
};

const Range = struct {
    x1: i64,
    x2: i64,
    // binary operations assume sorted
    pub fn deintersect(self: *Range, other: *Range) void {
        // deal with ranges that entirely contain eachother
        if (self.x1 <= other.x1 and self.x2 >= other.x2) {
            other.x2 = self.x2;
            self.x2 = other.x1 - 1;
        }
        if (self.x2 >= other.x1) {
            self.x2 = other.x1 - 1;
            if (self.x2 > other.x2) unreachable;
        }
        // else if (self.x1 <= other.x2) {
        //     self.x1 = other.x2 + 1;
        // }
    }
    // assumes other is before self
    pub fn trim(self: *Range, other: Range) void {
        if (other.x2 >= self.x1) {
            self.x1 = other.x2 + 1;
        }
    }
    pub fn length(self: *const Range) i64 {
        return 1 + self.x2 - self.x1;
    }
    pub fn gapBetween(self: *const Range, other: Range) bool {
        const x = @max(0, other.x1);
        return x > self.x1;
    }
};

fn parseTextToCoord(text: []const u8) !Coord {
    const xi = std.mem.indexOf(u8, text, "x=").? + 2;
    const comma = std.mem.indexOf(u8, text[xi..], ",").? + xi;
    const x = try std.fmt.parseInt(i64, text[xi..comma], 10);
    const y = try std.fmt.parseInt(i64, text[comma + 4 ..], 10);
    return .{ .x = x, .y = y };
}

const Sensor = struct {
    loc: Coord,
    beacon: Coord,
    // manhattan distance to closest beacon
    distance: i64,

    pub fn initFromLine(line: []const u8) !Sensor {
        const i = std.mem.indexOf(u8, line, ":").?;
        const sensor_info = line[0..i];
        const beacon_info = line[i + 1 ..];
        const loc = try parseTextToCoord(sensor_info);
        const beacon = try parseTextToCoord(beacon_info);
        return .{ .loc = loc, .beacon = beacon, .distance = loc.manhattan(beacon) };
    }

    pub fn halfPointsOnHorizontal(self: *const Sensor, y: i64) i64 {
        const depth = self.distance - self.loc.distToHorizontal(y);
        if (depth > 0) {
            return depth;
        }
        return 0;
    }

    pub fn rangeOnHorizontal(self: *const Sensor, y: i64) ?Range {
        const points = self.halfPointsOnHorizontal(y);
        if (points > 0) {
            const x1 = self.loc.x - points;
            const x2 = self.loc.x + points;
            return .{ .x1 = @min(x1, x2), .x2 = @max(x1, x2) };
        } else return null;
    }

    pub fn beaconOnHorizontal(self: *const Sensor, y: i64) bool {
        return self.beacon.y == y;
    }
};

fn parseSensors(alloc: std.mem.Allocator, input: []const u8) ![]Sensor {
    var sensor_list = std.ArrayList(Sensor).init(alloc);
    defer sensor_list.deinit();

    var lines = std.mem.split(u8, input, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const sensor = try Sensor.initFromLine(line);
        try sensor_list.append(sensor);
        // std.debug.print("{any}\n", .{sensor});
    }
    return sensor_list.toOwnedSlice();
}

const State = struct {
    const BeaconHashmap = std.AutoHashMap(Coord, bool);
    const RangeList = std.ArrayList(Range);

    map: BeaconHashmap,
    ranges: RangeList,
    y_row: i64 = 0,
    beacon_count: i64 = 0,

    pub fn init(alloc: std.mem.Allocator, row: i64) State {
        return .{
            .map = BeaconHashmap.init(alloc),
            .ranges = RangeList.init(alloc),
            .y_row = row,
        };
    }

    pub fn deinit(self: *State) void {
        self.map.deinit();
        self.ranges.deinit();
    }

    pub fn addSensor(self: *State, sensor: Sensor) !void {
        if (sensor.rangeOnHorizontal(self.y_row)) |range| {
            if (sensor.beaconOnHorizontal(self.y_row)) {
                if (!self.map.contains(sensor.beacon)) {
                    try self.map.put(sensor.beacon, true);
                    self.beacon_count += 1;
                }
            }
            try self.ranges.append(range);
        }
    }
};

fn ascending(_: void, r1: Range, r2: Range) bool {
    return r1.x1 < r2.x1;
}

pub fn uniquePoints(ranges: []Range) i64 {
    var count: i64 = 0;
    std.sort.sort(Range, ranges, {}, ascending);
    for (ranges) |*range, i| {
        if (i + 1 < ranges.len) {
            const next = &ranges[i + 1];
            range.deintersect(next);
        }
        count += range.length();
    }
    return count;
}

// const Y_ROW = 2000000;
// const MAX_COORD = 4000000;
fn solve(alloc: std.mem.Allocator, input: []const u8, part1_row: i64, max_coord: i64) ![2]i64 {
    var sensors = try parseSensors(alloc, input);
    defer alloc.free(sensors);

    var part1: ?i64 = null;
    var part2: ?Coord = null;
    var row: i64 = 10;
    while (row < max_coord) : (row += 1) {
        // std.debug.print("\n{d}:\n", .{row});
        var total_range = Range{ .x1 = 0, .x2 = max_coord };

        var state = State.init(alloc, row);
        defer state.deinit();
        for (sensors) |sensor| try state.addSensor(sensor);

        var ranges = try state.ranges.toOwnedSlice();
        defer alloc.free(ranges);

        // sort and trim ranges
        if (row == part1_row) {
            part1 = uniquePoints(ranges) - state.beacon_count;
        } else {
            _ = uniquePoints(ranges);
        }
        // shortcut
        if (part1 != null and part2 != null) break;

        // find if there are any gaps
        for (ranges) |range| {
            if (!total_range.gapBetween(range)) {
                // std.debug.print("{d} to {d}, range: {d} to {d}\n", .{ total_range.x1, total_range.x2, range.x1, range.x2 });
                total_range.trim(range);
            } else {
                // we found our coordinate
                if (part2 == null) {
                    part2 = .{ .x = total_range.x1, .y = row };
                    // skip directly to part 1
                    row = part1_row - 1;
                }
                break;
            }
        }
    }

    return .{ part1.?, part2.?.x * 4000000 + part2.?.y };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"), 2000000, 2 * 2000000);
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(allocator, solve, .{ allocator, @embedFile("input.txt"), 2000000, 2 * 2000000 }, .{ .warmup = 5, .trials = 10 });
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"), 10, 20);
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
