const std = @import("std");
const util = @import("../util.zig");

const Mask = std.bit_set.IntegerBitSet(64);

const ValveLookup = struct {
    const Table = std.StringHashMap(usize);
    table: Table,
    pub fn init(alloc: std.mem.Allocator) ValveLookup {
        return .{ .table = Table.init(alloc) };
    }
    pub fn get(self: *ValveLookup, name: []const u8) !usize {
        if (self.table.get(name)) |entry| {
            return entry;
        } else {
            const new_index = self.table.count();
            try self.table.put(name, new_index);
            return new_index;
        }
    }
    pub fn deinit(self: *ValveLookup) void {
        self.table.deinit();
    }
};

const PipeSystem = struct {
    alloc: std.mem.Allocator,
    network: [][]u8,
    flowrate: []u32,
    lookup: ValveLookup,
    cache: std.AutoHashMap(Args, u32),

    fn addValveFromText(self: *PipeSystem, line: []const u8) !void {
        const name = line[6..8];
        const rate_offset = std.mem.indexOf(u8, line, ";").?;
        const flowrate = try std.fmt.parseInt(u32, line[23..rate_offset], 10);
        const connection_offset = if (std.mem.indexOf(u8, line, "valves ")) |offset|
            offset + 7
        else
            std.mem.indexOf(u8, line, "valve ").? + 6;
        // map connections
        var itt = std.mem.tokenize(u8, line[connection_offset..], ", ");
        const i = try self.lookup.get(name);
        self.network[i][i] = 0;
        while (itt.next()) |other| {
            const j = try self.lookup.get(other);
            self.network[j][i] = 1;
        }
        self.flowrate[i] = flowrate;
    }
    pub fn parseFromInput(alloc: std.mem.Allocator, input: []const u8) !PipeSystem {
        // count how many rooms we have
        const num_rooms = std.mem.count(u8, input, "\n");
        // allocate storage
        var network = try alloc.alloc([]u8, num_rooms);
        errdefer alloc.free(network);
        for (network) |*entry| {
            entry.* = try alloc.alloc(u8, num_rooms);
            for (entry.*) |*v| v.* = 255;
        }
        errdefer for (network) |entry| alloc.free(entry);
        // flowrate
        var flowrates = try alloc.alloc(u32, num_rooms);
        errdefer alloc.free(flowrates);
        // need way of mapping valves to rows/cols
        var lookup = ValveLookup.init(alloc);
        errdefer lookup.deinit();
        // set 'AA' to 0
        try lookup.table.put("AA", 0);

        var cache = std.AutoHashMap(Args, u32).init(alloc);
        errdefer cache.deinit();

        var pipes = PipeSystem{
            .alloc = alloc,
            .network = network,
            .flowrate = flowrates,
            .lookup = lookup,
            .cache = cache,
        };

        // parse input
        var lines = std.mem.split(u8, input, "\n");
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            try pipes.addValveFromText(line);
        }

        return pipes;
    }
    pub fn solveShortestPaths(self: *PipeSystem) void {
        // floyd-warshall to quickly populate adjacency matrix
        const dim = self.flowrate.len;
        var i: usize = 0;
        while (i < dim) : (i += 1) {
            var j: usize = 0;
            while (j < dim) : (j += 1) {
                var k: usize = 0;
                while (k < dim) : (k += 1) {
                    // saturating addition
                    const new_dist = self.network[j][i] +| self.network[i][k];
                    self.network[j][k] = @min(self.network[j][k], new_dist);
                }
            }
        }
    }
    pub fn deinit(self: *PipeSystem) void {
        for (self.network) |col| {
            self.alloc.free(col);
        }
        self.alloc.free(self.network);
        self.alloc.free(self.flowrate);
        self.lookup.deinit();
        self.cache.deinit();
    }

    // args struct to use in hash map
    const Args = struct {
        current: usize,
        time: u32,
        visited: Mask,
        elephants: bool = false,
    };

    pub fn recursiveSolve(self: *PipeSystem, args: Args) !u32 {
        if (self.cache.get(args)) |cached| return cached;
        var copy = Mask{ .mask = args.visited.mask };
        copy.set(args.current);

        var best: u32 = 0;
        for (self.flowrate) |f, i| {
            // skip no flow, if visited, or if takes too long
            const dist = self.network[args.current][i] + 1;
            if (f == 0 or copy.isSet(i) or dist > args.time) continue;
            const score = f * (args.time - dist) + if (dist != args.time)
                try self.recursiveSolve(.{
                    .current = i,
                    .time = args.time - dist,
                    .visited = copy,
                    .elephants = args.elephants,
                })
            else
                0;
            best = @max(score, best);
        }
        if (args.elephants) {
            best = @max(best, try self.recursiveSolve(.{
                .current = 0,
                .time = 26,
                .visited = copy,
                .elephants = false,
            }));
        }

        try self.cache.put(args, best);
        return best;
    }

    pub fn solve(self: *PipeSystem, elephants: bool) !u32 {
        var mask = Mask.initEmpty();
        var args = Args{
            .time = if (elephants) 26 else 30,
            .visited = mask,
            .current = 0,
            .elephants = elephants,
        };
        return self.recursiveSolve(args);
    }
};

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    var pipes = try PipeSystem.parseFromInput(alloc, input);
    defer pipes.deinit();

    pipes.solveShortestPaths();
    const part1 = try pipes.solve(false);
    const part2 = try pipes.solve(true);

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
