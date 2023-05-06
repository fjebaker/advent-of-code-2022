const std = @import("std");
const util = @import("../util.zig");

const Coord = struct {
    x: i64,
    y: i64,
    fn diff(i: i64, j: i64) i64 {
        return std.math.absInt(i - j) catch unreachable;
    }
    pub fn manhattan(self: *const Coord, other: Coord) i64 {
        return diff(self.x, other.x) + diff(self.y, other.y);
    }
    pub fn distToHorizontal(self: *const Coord, y: i64) i64 {
        return diff(self.y, y);
    }
    pub fn fromText(text: []const u8) !Coord {
        const xi = std.mem.indexOf(u8, text, "x=").? + 2;
        const comma = std.mem.indexOf(u8, text[xi..], ",").? + xi;
        const x = try std.fmt.parseInt(i64, text[xi..comma], 10);
        const y = try std.fmt.parseInt(i64, text[comma + 4 ..], 10);
        return .{ .x = x, .y = y };
    }
};

const Range = struct {
    x1: i64,
    x2: i64,
    // binary operations assume sorted, i.e. self < other
    pub fn deintersect(self: *Range, other: *Range) void {
        // deal with ranges that entirely contain eachother by splitting domain
        if (self.x1 <= other.x1 and self.x2 >= other.x2) {
            other.x2 = self.x2;
            self.x2 = other.x1 - 1;
        }
        if (self.x2 >= other.x1) {
            self.x2 = other.x1 - 1;
        }
    }
    pub fn length(self: *const Range) i64 {
        return 1 + self.x2 - self.x1;
    }
};

const Sensor = struct {
    loc: Coord,
    beacon: Coord,
    radius: i64,
    pub fn initFromLine(line: []const u8) !Sensor {
        const i = std.mem.indexOf(u8, line, ":").?;
        const loc = try Coord.fromText(line[0..i]);
        const beacon = try Coord.fromText(line[i + 1 ..]);
        return .{ .loc = loc, .beacon = beacon, .radius = loc.manhattan(beacon) };
    }
    pub fn rangeOnHorizontal(self: *const Sensor, y: i64) ?Range {
        const depth = self.radius - self.loc.distToHorizontal(y);
        if (depth > 0) {
            return .{ .x1 = self.loc.x - depth, .x2 = self.loc.x + depth };
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
    fn ascending(_: void, r1: Range, r2: Range) bool {
        return r1.x1 < r2.x1;
    }
    fn countObscured(self: *State) i64 {
        var count: i64 = 0;
        std.sort.sort(Range, self.ranges.items, {}, ascending);
        for (self.ranges.items) |*range, i| {
            if (i + 1 < self.ranges.items.len) {
                const next = &self.ranges.items[i + 1];
                range.deintersect(next);
            }
            count += range.length();
        }
        return count - self.beacon_count;
    }
};

fn contains(sensors: []const Sensor, c: Coord) bool {
    for (sensors) |s| {
        if (s.loc.manhattan(c) <= s.radius) {
            return true;
        }
    }
    return false;
}

fn increment(map: *std.AutoHashMap(i64, u64), val: i64) !void {
    const new_value = if (map.get(val)) |old| old + 1 else 1;
    try map.put(val, new_value);
}

fn solveForEmpty(alloc: std.mem.Allocator, sensors: []const Sensor) !Coord {
    var a_coeffs = std.AutoHashMap(i64, u64).init(alloc);
    defer a_coeffs.deinit();
    var b_coeffs = std.AutoHashMap(i64, u64).init(alloc);
    defer b_coeffs.deinit();
    for (sensors) |s| {
        const extended = s.radius + 1;
        try increment(&a_coeffs, s.loc.y - s.loc.x + extended);
        try increment(&a_coeffs, s.loc.y - s.loc.x - extended);
        try increment(&b_coeffs, s.loc.y + s.loc.x + extended);
        try increment(&b_coeffs, s.loc.y + s.loc.x - extended);
    }
    var a_possible = std.ArrayList(i64).init(alloc);
    var b_possible = std.ArrayList(i64).init(alloc);
    defer a_possible.deinit();
    defer b_possible.deinit();
    {
        var a_itt = a_coeffs.iterator();
        while (a_itt.next()) |entry| {
            const a = entry.key_ptr.*;
            const n = entry.value_ptr.*;
            if (n >= 2) try a_possible.append(a);
        }
    }
    {
        var b_itt = b_coeffs.iterator();
        while (b_itt.next()) |entry| {
            const b = entry.key_ptr.*;
            const n = entry.value_ptr.*;
            if (n >= 2) try b_possible.append(b);
        }
    }
    for (a_possible.items) |a| {
        for (b_possible.items) |b| {
            if (a >= b) continue;
            const c: Coord = .{ .x = @divFloor(b - a, 2), .y = @divFloor(b + a, 2) };
            if (c.y < 0) continue;
            if (!contains(sensors, c)) return c;
        }
    }
    unreachable;
}

fn solve(alloc: std.mem.Allocator, input: []const u8, part1_row: i64) ![2]i64 {
    var sensors = try parseSensors(alloc, input);
    defer alloc.free(sensors);

    var state = State.init(alloc, part1_row);
    defer state.deinit();
    for (sensors) |sensor| try state.addSensor(sensor);

    const part1 = state.countObscured();

    const coord = try solveForEmpty(alloc, sensors);
    const part2 = coord.x * 4000000 + coord.y;

    return .{ part1, part2 };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"), 2000000);
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(allocator, solve, .{
        allocator,
        @embedFile("input.txt"),
        2000000,
    }, .{});
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"), 10);
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
