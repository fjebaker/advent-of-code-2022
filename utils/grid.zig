const std = @import("std");

pub fn CoordT(comptime T: type) type {
    return @Vector(2, T);
}

pub const UnitVec = CoordT(i8);
pub const Coord = CoordT(usize);

pub fn vecTo(from: Coord, to: Coord) UnitVec {
    const delta = @intCast(CoordT(i64), to) - @intCast(CoordT(i64), from);
    var v: [2]i64 = delta;
    inline for (v) |*x| {
        x.* = std.math.clamp(x.*, -1, 1);
    }
    return .{ @intCast(i8, v[0]), @intCast(i8, v[1]) };
}

pub fn addUnit(c: Coord, u: UnitVec) Coord {
    const sub = @intCast(CoordT(i64), c) + @intCast(CoordT(i64), u);
    return @intCast(Coord, sub);
}

pub fn getY(c: Coord) usize {
    return @as([2]usize, c)[1];
}

pub fn getX(c: Coord) usize {
    return @as([2]usize, c)[0];
}

const GridErrors = error{OutOfBounds};

pub fn CallbackCtxType(comptime f: anytype) type {
    const F = @TypeOf(f);
    const args_info = @typeInfo(std.meta.ArgsTuple(F));
    switch (args_info) {
        .Struct => |A| {
            return A.fields[0].field_type;
        },
        else => @compileError("Cannot infer callback context type."),
    }
}

pub fn GridT(comptime T: type) type {
    return struct {
        const Self = @This();

        grid: []T,
        x_size: usize,
        y_size: usize,
        alloc: std.mem.Allocator,

        pub fn initWithValue(alloc: std.mem.Allocator, x_size: usize, y_size: usize, value: T) !Self {
            var grid = try Self.init(alloc, x_size, y_size);
            for (grid.grid) |*item| item.* = value;
            return grid;
        }

        pub fn init(alloc: std.mem.Allocator, x_size: usize, y_size: usize) !Self {
            var grid = try alloc.alloc(T, x_size * y_size);
            return .{
                .grid = grid,
                .x_size = x_size,
                .y_size = y_size,
                .alloc = alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.grid);
        }

        pub fn setChecked(self: *Self, x: usize, y: usize, v: T) GridErrors!void {
            if (self.inBounds(x, y)) {
                self.set(x, y, v);
            } else return .OutOfBounds;
        }

        pub fn set(self: *Self, x: usize, y: usize, v: T) void {
            self.grid[self.index(x, y)] = v;
        }

        pub fn cSet(self: *Self, c: Coord, v: T) void {
            const i: [2]usize = c;
            self.set(i[0], i[1], v);
        }

        pub fn inBounds(self: *const Self, x: usize, y: usize) void {
            return (x >= 0 and y >= 0 and x < self.x_size and y < self.y_size);
        }

        pub fn index(self: *const Self, x: usize, y: usize) usize {
            return x + y * self.x_size;
        }

        pub fn getChecked(self: *const Self, x: usize, y: usize) GridErrors!T {
            if (self.inBounds) {
                return self.get(x, y);
            } else return .OutOfBounds;
        }

        pub fn get(self: *const Self, x: usize, y: usize) T {
            return self.grid[self.index(x, y)];
        }

        pub fn getMutChecked(self: *Self, x: usize, y: usize) GridErrors!*T {
            if (self.inBounds) {
                return self.getMut(x, y);
            } else return .OutOfBounds;
        }

        pub fn getMut(self: *Self, x: usize, y: usize) *T {
            return &self.grid[self.index(x, y)];
        }

        pub fn forEach(self: *Self, comptime cb: anytype, ctx: CallbackCtxType(cb)) void {
            self.forEachPadded(cb, ctx, 0, 0);
        }

        pub fn forEachPadded(
            self: *Self,
            comptime cb: anytype,
            ctx: CallbackCtxType(cb),
            comptime pad_x: comptime_int,
            comptime pad_y: comptime_int,
        ) void {
            var y: usize = pad_y;
            while (y < self.y_size - pad_y) : (y += 1) {
                var x: usize = pad_x;
                while (x < self.x_size - pad_x) : (x += 1) {
                    if (!cb(ctx, x, y, self.getMut(x, y))) break;
                }
            }
        }

        pub fn debugPrint(self: *Self) void {
            var y: usize = 0;
            while (y < self.y_size) : (y += 1) {
                var x: usize = 0;
                while (x < self.x_size) : (x += 1) {
                    std.debug.print("{c}", .{self.get(x, y)});
                }
                std.debug.print("\n", .{});
            }
        }
    };
}
