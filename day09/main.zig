const std = @import("std");
const util = @import("../util.zig");

const Coord = @Vector(2, i32);
const UnpackedCoord = [2]i32;
const Mask = std.bit_set.DynamicBitSet;




const Rope = struct{
    alloc: std.mem.Allocator,
    previous: Coord,
    current: Coord,
    visited: Mask,
    dim: usize,
    staged: bool = false,
    pub fn init(alloc: std.mem.Allocator, dim: usize) !Rope {
        var mask = try Mask.initEmpty(alloc, dim * dim);
        return .{
            .alloc = alloc,
            .current = .{0,0},
            .previous = .{0,0},
            .visited = mask,
            .dim = dim
        };
    }
    pub fn deinit(self: *Rope) void {
        self.visited.deinit();
    }
    fn updateMask(self: *Rope) void {
        const mid = @intCast(i32, @divFloor(self.dim, 2));
        // translate to middle
        const coord : UnpackedCoord = self.previous + Coord{mid, mid};
        const i_index = coord[0] + coord[1] * @intCast(i32, self.dim);
        std.debug.assert(i_index > 0);
        const index = @intCast(u32, i_index);
        self.visited.set(index);
    }
    fn movedTooFar(self: *Rope, rope: Coord) bool {
        const diff : UnpackedCoord = rope - self.previous;
        const x = std.math.absCast(diff[0]);
        const y = std.math.absCast(diff[1]);
        const too_far = x > 1 or y > 1;
        return too_far;
    }
    pub fn move(self: *Rope, direction: u8, count: u32) void {
        const delta : Coord = switch(direction) {
            'U' => .{0, -1},
            'D' => .{0, 1},
            'L' => .{-1, 0},
            'R' => .{1, 0},
            else => unreachable,
        };
        var i: u32 = count;
        while (i > 0) : (i -= 1) {
            var rope = self.current;
            self.current = self.current + delta;
            // don't set visitor mask on first move
            if (self.movedTooFar(self.current)) {
                self.previous = rope;
                self.updateMask();
                self.staged = false;
            }
        }
        // if (count == 1) self.staged = true;
    }
    pub fn show(self: *const Rope) void {
        var y: usize = 0;
        while (y < self.dim) {
            var x: usize = 0;
            while (x < self.dim) {
                if (self.visited.isSet(x + y * self.dim)) {
                    std.debug.print("#", .{});
                } else {
                    std.debug.print(" ", .{});
                }
                x+=1;
            }
            std.debug.print("\n", .{});
            y += 1;
        }
    }
};

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    var lines = std.mem.tokenize(u8, input, "\n");
    var rope = try Rope.init(alloc, 500);
    defer rope.deinit();

    while (lines.next()) |line| {
        const direction = line[0];
        const count = try std.fmt.parseInt(u32, line[2..], 10);

        std.debug.print("{c} -> {d}\n", .{direction, count});
        rope.move(direction, count);
        // rope.show();
    } 
    const part1 = @truncate(u32, rope.visited.count()) + 1;

    return .{part1,0};
    // 6180
    // 6192
}


pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    // var result = try util.benchmark(allocator, solve, .{allocator, @embedFile("input.txt")}, .{});
    // defer result.deinit();
    // result.printSummary();
}

test "test-input" {
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
