const std = @import("std");

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
        std.debug.print("New shape: max height: {d}\n", .{self.max_height});
        try self.fillVoid();
        // get next rock shape
        var rock: Rock = @intToEnum(Shapes, @rem(self.cycle, 5));
        self.cycle += 1;
        // x from 0 to 6
        var x: usize = 2;
        // 0 is floor
        var y: usize = self.max_height + 4;
        // first shift
        // std.debug.print("({d}, {d})\n", .{x, y});
        x = self.shift(x, y, rock);
        while (self.checkCollision(x, y - 1, rock)) {
            y -= 1;
            // std.debug.print("({d}, {d})\n", .{x, y});
            x = self.shift(x, y, rock);
        }
        // std.debug.print("Collided! Fixing shape @ ({d}, {d}).\n\n", .{x, y});
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
        const width = rock.width();
        var new_x = @intCast(usize, std.math.clamp(
            @intCast(i32, x) + dx,
            0,
            @intCast(i32, 7 - width),
        ));
        if (self.checkCollision(new_x, y, rock)) return new_x;
        return x;
    }
    fn fix(self: *Chamber, x: usize, y: usize, rock: Rock) void {
        const rows = rock.get();
        const width = rock.width();
        const offset = @intCast(u3, @min(6 - width, x));
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
        const width = rock.width();
        // make sure we don't shift passed allowed domain
        const offset = @intCast(u3, @min(6 - width, x));
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
    pub fn printAll(self: *const Chamber) void {
        var i: usize = self.rows.items.len - 1;
        while (i > 0) : (i -= 1) {
            std.debug.print("{d:>3}  ", .{i});
            const row = self.rows.items[i];
            self.printRow(row);
            std.debug.print("\n", .{});
        }
        std.debug.print("     0 . 2 . 4 . 6 \n", .{});
    }
    fn printRow(_: *const Chamber, row: u8) void {
        var i: usize = 0;
        while (i < 8) : (i += 1) {
            const mask = @shlExact(@as(u8, 1), @intCast(u3, i));
            const val = row & mask;
            const c: u8 = if (val != 0) '#' else ' ';
            std.debug.print("{c} ", .{c});
        }
    }
};

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]usize {
    var chamber = try Chamber.init(alloc, input);
    defer chamber.deinit();
    var i: usize = 0;
    while (i < 11) : (i += 1) {
        try chamber.dropRock();
    }
    chamber.printAll();
    // std.debug.print("{s}\n", .{chamber.jets});
    return .{ chamber.max_height, 0 };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    // var result = try util.benchmark(allocator, solve, .{ allocator, @embedFile("input.txt") }, .{ .warmup = 5, .trials = 10 });
    // defer result.deinit();
    // result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
