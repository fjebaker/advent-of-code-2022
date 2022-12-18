const std = @import("std");
const util = @import("../util.zig");

const ChamberRow = u8;
const Shapes = enum { horizontal, plus, lshape, vertical, square };

const Rock = union(Shapes) {
    horizontal: struct {
        pub const mask: [1]ChamberRow = .{
            0b1111,
        };
        pub const width = 4;
    },
    plus: struct {
        pub const mask: [3]ChamberRow = .{
            0b010,
            0b111,
            0b010,
        };
        pub const width = 3;
    },
    lshape: struct {
        pub const mask: [3]ChamberRow = .{
            // defined in reverse
            0b111,
            0b100,
            0b100,
        };
        pub const width = 3;
    },
    vertical: struct {
        pub const mask: [4]ChamberRow = .{
            0b1,
            0b1,
            0b1,
            0b1,
        };
        pub const width = 1;
    },
    square: struct {
        pub const mask: [2]ChamberRow = .{
            0b11,
            0b11,
        };
        pub const width = 2;
    },
    // surely there is a nicer way to do this??
    pub fn get(self: Rock) []const ChamberRow {
        return switch (self) {
            .horizontal => |shape| &@TypeOf(shape).mask,
            .plus => |shape| &@TypeOf(shape).mask,
            .lshape => |shape| &@TypeOf(shape).mask,
            .vertical => |shape| &@TypeOf(shape).mask,
            .square => |shape| &@TypeOf(shape).mask,
        };
    }
    pub fn width(self: Rock) usize {
        return switch (self) {
            .horizontal => |shape| @TypeOf(shape).width,
            .plus => |shape| @TypeOf(shape).width,
            .lshape => |shape| @TypeOf(shape).width,
            .vertical => |shape| @TypeOf(shape).width,
            .square => |shape| @TypeOf(shape).width,
        };
    }
};

const Chamber = struct {
    jets: []const u8,
    index: usize = 0,
    cycle: usize = 0,

    max_height: usize = 0,
    rows: std.ArrayList(ChamberRow),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, input: []const u8) !Chamber {
        const offset = std.mem.indexOf(u8, input, "\n").?;
        var rows = std.ArrayList(ChamberRow).init(alloc);
        // add the floor at y = 0
        try rows.append(0b11111111);
        return .{
            .jets = input[0..offset],
            .rows = rows,
            .alloc = alloc,
        };
    }
    pub fn deinit(self: *Chamber) void {
        self.rows.deinit();
    }
    fn fillVoid(self: *Chamber) !void {
        const still_needed = self.max_height + 4 -| (self.rows.items.len - 1);
        var i: usize = 0;
        while (i <= still_needed) : (i += 1) {
            try self.rows.append(0);
        }
    }
    pub fn dropRock(self: *Chamber) !void {
        // ensure we have capacity
        try self.fillVoid();
        // get next rock shape
        var rock: Rock = @intToEnum(Shapes, @rem(self.cycle, 5));
        self.cycle += 1;
        // x from 0 to 6
        var x: usize = 2;
        // 0 is floor
        var y: usize = self.max_height + 4;
        // first shift
        x = self.shift(x, y, rock);
        while (self.checkCollision(x, y - 1, rock)) {
            y -= 1;
            x = self.shift(x, y, rock);
        }
        self.fix(x, y, rock);
        self.max_height = self.getMaxHeight();
    }
    fn getMaxHeight(self: *const Chamber) usize {
        for (self.rows.items[self.max_height..]) |row, i| {
            if (row & 0b11111111 == 0) return self.max_height + i - 1;
        }
        unreachable;
    }
    fn shift(self: *Chamber, x: usize, y: usize, rock: Rock) usize {
        if (self.index == self.jets.len) {
            self.index = 0;
        }
        const c = self.jets[self.index];
        self.index += 1;
        const dx: i32 = switch (c) {
            '>' => 1,
            '<' => -1,
            else => unreachable,
        };
        // ensure x is valid
        var new_x = @intCast(usize, std.math.clamp(
            @intCast(i32, x) + dx,
            0,
            @intCast(i32, 7 - rock.width()),
        ));
        if (self.checkCollision(new_x, y, rock)) return new_x;
        return x;
    }
    fn fix(self: *Chamber, x: usize, y: usize, rock: Rock) void {
        const rows = rock.get();
        const offset = @intCast(u3, x);
        for (rows) |row, i| {
            // shift into right location
            const mask = row << offset;
            // get current row
            const current = self.rows.items[y + i];
            self.rows.items[y + i] = current | mask;
        }
    }
    fn checkCollision(self: *const Chamber, x: usize, y: usize, rock: Rock) bool {
        if (y > self.max_height + 1) return true;
        const rows = rock.get();
        const offset = @intCast(u3, x);
        for (rows) |row, i| {
            // shift into right location
            const mask = row << offset;
            // check with row below current
            const current = self.rows.items[y + i];
            const collision = mask & current;
            if (collision != 0) return false;
        }
        return true;
    }
    const CycleInfo = struct { mu: usize, lambda: usize };
    pub fn findCycle(self: *const Chamber) ?CycleInfo {
        // add a favourite prime heuristic since we know the cycle frequency must
        // be at least the shape frequency, else will underestimate lambda
        const heuristic = 13;
        // use Floyd's algorithm
        const f = self.rows.items;
        // miss out the floor
        var tortoise: usize = 2;
        var hare: usize = 3;
        while (!std.mem.eql(
            u8,
            f[tortoise .. tortoise + heuristic],
            f[hare .. hare + heuristic],
        )) {
            tortoise += 1;
            hare += 2;
            if (hare + heuristic >= f.len) return null;
        }
        // find first position of cycle
        var mu: usize = 1;
        tortoise = 1;
        while (!std.mem.eql(
            u8,
            f[tortoise .. tortoise + heuristic],
            f[hare .. hare + heuristic],
        )) {
            tortoise += 1;
            hare += 1;
            mu += 1;
            if (hare + heuristic >= f.len) return null;
        }
        // find length of cycle
        var lambda: usize = 1;
        hare = tortoise + 1;

        while (!std.mem.eql(
            u8,
            f[tortoise .. tortoise + heuristic],
            f[hare .. hare + heuristic],
        )) {
            hare += 1;
            lambda += 1;
        }
        return .{ .mu = mu, .lambda = lambda };
    }
};

pub fn printAll(items: []const u8) void {
    var i: usize = items.len - 1;
    while (i > 0) : (i -= 1) {
        std.debug.print("{d:>3}  ", .{i});
        const row = items[i];
        printRow(row);
        std.debug.print("\n", .{});
    }
    std.debug.print("     0 . 2 . 4 . 6 \n", .{});
}

fn printRow(row: u8) void {
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const mask = @shlExact(@as(u8, 1), @intCast(u3, i));
        const val = row & mask;
        const c: u8 = if (val != 0) '#' else ' ';
        std.debug.print("{c} ", .{c});
    }
}

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]usize {
    var chamber = try Chamber.init(alloc, input);
    defer chamber.deinit();

    const target = 1000000000000;
    var part1: usize = 0;

    var i: usize = 0;
    const cycle = blk: {
        while (i < target) : (i += 1) {
            try chamber.dropRock();
            // start at 0 so we do 2021
            if (i == 2021) {
                part1 = chamber.max_height;
            } else if (i > 2021) {
                if (chamber.findCycle()) |cycle| break :blk cycle;
            }
        }
        unreachable;
    };
    const rock_period = blk: {
        // keep going until we've rounded off the cycle, accounting for floor
        while (@rem(chamber.max_height - (cycle.mu - 1), cycle.lambda) != 0) {
            try chamber.dropRock();
        }
        // drop a rock for good luck (also to get into the cycle)
        var count: usize = 1;
        try chamber.dropRock();
        // now measure
        while (@rem(chamber.max_height - (cycle.mu - 1), cycle.lambda) != 0) {
            try chamber.dropRock();
            count += 1;
        }
        break :blk count;
    };

    // maffs
    const target_diff = target - chamber.cycle;
    const cycles_remaining = @divTrunc(target_diff, rock_period);

    // and drop the rest
    var remainder = @rem(target_diff, rock_period);
    while (remainder > 0) : (remainder -= 1) {
        try chamber.dropRock();
    }
    const part2 = chamber.max_height + (cycle.lambda * cycles_remaining);
    return .{ part1, part2 };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(allocator, solve, .{ allocator, @embedFile("input.txt") }, .{ .warmup = 5, .trials = 10 });
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
