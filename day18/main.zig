const std = @import("std");
const util = @import("../util.zig");

const Grid3D = struct {
    grid: []u8,
    dim: usize,
    alloc: std.mem.Allocator,
    pub fn fromInput(alloc: std.mem.Allocator, dim: usize, input: []const u8) !Grid3D {
        var grid = try alloc.alloc(u8, dim * dim * dim);
        std.mem.set(u8, grid, 0);
        var grid3d = Grid3D{
            .grid = grid,
            .dim = dim,
            .alloc = alloc,
        };
        errdefer grid3d.deinit();
        var lines = std.mem.split(u8, input, "\n");
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var tokens = std.mem.tokenize(u8, line, ",");
            const x = try std.fmt.parseInt(u8, tokens.next().?, 10);
            const y = try std.fmt.parseInt(u8, tokens.next().?, 10);
            const z = try std.fmt.parseInt(u8, tokens.next().?, 10);
            grid3d.set(x, y, z, 1);
        }
        return grid3d;
    }
    pub fn deinit(self: *Grid3D) void {
        self.alloc.free(self.grid);
    }
    pub fn at(self: *const Grid3D, x: usize, y: usize, z: usize) usize {
        return (z * self.dim * self.dim) + (y * self.dim) + x;
    }
    pub fn get(self: *const Grid3D, x: usize, y: usize, z: usize) u8 {
        return self.grid[self.at(x, y, z)];
    }
    pub fn getSafe(self: *const Grid3D, x: usize, y: usize, z: usize) ?u8 {
        const index = self.at(x, y, z);
        if (index >= 0 and index < self.grid.len) {
            return self.grid[index];
        }
        return null;
    }
    pub fn set(self: *Grid3D, x: usize, y: usize, z: usize, value: u8) void {
        self.grid[self.at(x, y, z)] = value;
    }
    fn calcAdjecent(
        self: *const Grid3D,
        comptime indexer: fn (*const Grid3D, usize, usize, usize) usize,
    ) u32 {
        // if i could be bothered, this would be really nice to vectorize
        var total: u32 = 0;
        var i: usize = 0;
        while (i < self.dim) : (i += 1) {
            var j: usize = 0;
            while (j < self.dim) : (j += 1) {
                var k: usize = 0;
                while (k < self.dim) : (k += 1) {
                    const value = self.grid[indexer(self, i, j, k)];
                    const cmp = if (k == 0) 0 ^ value else self.grid[indexer(self, i, j, k - 1)] ^ value;
                    total += @intCast(u32, @popCount(cmp));
                }
            }
        }
        return total;
    }
    fn _xaxis(self: *const Grid3D, y: usize, z: usize, x: usize) usize {
        return self.at(x, y, z);
    }
    fn _yaxis(self: *const Grid3D, z: usize, x: usize, y: usize) usize {
        return self.at(x, y, z);
    }
    fn _zaxis(self: *const Grid3D, x: usize, y: usize, z: usize) usize {
        return self.at(x, y, z);
    }
    pub fn surfaceArea(self: *const Grid3D) u32 {
        var total: u32 = 0;
        // along the x axis
        total += self.calcAdjecent(_xaxis);
        // along the y axis
        total += self.calcAdjecent(_yaxis);
        // along the z axis
        total += self.calcAdjecent(_zaxis);
        return total;
    }

    fn checkDirection(self: *const Grid3D, visited: *std.bit_set.DynamicBitSet, stack: *std.ArrayList([3]usize), x: usize, y: usize, z: usize) u32 {
        const value = self.getSafe(x, y, z);
        if (value) |val| {
            if (visited.isSet(self.at(x, y, z))) return 0;
            if (val == 1) {
                return 1;
            }
            visited.set(self.at(x, y, z));
            stack.appendAssumeCapacity([3]usize{ x, y, z });
        }
        return 0;
    }
    pub fn floodFill(self: *Grid3D) !u32 {
        var stack = try std.ArrayList([3]usize).initCapacity(self.alloc, self.dim * self.dim * self.dim);
        defer stack.deinit();
        var visited = try std.bit_set.DynamicBitSet.initEmpty(self.alloc, self.dim * self.dim * self.dim);
        defer visited.deinit();
        stack.appendAssumeCapacity([3]usize{ 0, 0, 0 });
        visited.set(self.at(0, 0, 0));
        var total: u32 = 0;
        while (stack.popOrNull()) |index| {
            // check canonical directions
            total += self.checkDirection(&visited, &stack, index[0] + 1, index[1], index[2]);
            total += self.checkDirection(&visited, &stack, index[0] -| 1, index[1], index[2]);
            total += self.checkDirection(&visited, &stack, index[0], index[1] + 1, index[2]);
            total += self.checkDirection(&visited, &stack, index[0], index[1] -| 1, index[2]);
            total += self.checkDirection(&visited, &stack, index[0], index[1], index[2] + 1);
            total += self.checkDirection(&visited, &stack, index[0], index[1], index[2] -| 1);
        }
        std.debug.print("Visited: {d}\n", .{visited.count()});
        return total;
    }
};

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    // guess a hardcoded size for the grid
    var grid = try Grid3D.fromInput(alloc, 24, input);
    defer grid.deinit();
    const part1 = grid.surfaceArea();
    // can't really reuse any of part 1 for part 2
    const part2 = try grid.floodFill();
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
