const std = @import("std");
const util = @import("../util.zig");

const Node = struct{
    value: i64,
    previous: ?*Node,
    next: ?*Node,
    pub fn getNthLink(self: *Node, n: i64) *Node {
        if (n == 0) {
            return self;
        } else if (n > 0) {
            return self.next.?.getNthLink(n - 1);
        } else {
            return self.previous.?.getNthLink(n + 1);
        }
    }
    pub fn insertRight(self: *Node, new: *Node) void {
        var next = self.next.?;
        // update this node
        next.previous = new;
        self.next = new;
        // update new node
        new.previous = self;
        new.next = next;
    }
    pub fn cycle(self: *Node, mod: i64) void {
        var remainder = @rem(self.value, mod);
        // skip if we are 0
        if (remainder == 0) return;
        // get new neighbour (one further if negative cus we insert right)
        const value = if (remainder < 0) 
            remainder - 1 
        else 
            remainder;
        var new = self.getNthLink(value);
        // remove self from the chain
        self.previous.?.next = self.next;
        self.next.?.previous = self.previous;
        new.insertRight(self);
    }
};

const Mixer = struct{
    nodes: []Node,
    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator, input: []const i64) !Mixer {
        var nodes = try alloc.alloc(Node, input.len);
        errdefer alloc.free(nodes);
        for (input) |n, i| {
            const node :Node = switch(i) {
                0 => .{.value = n, .previous = null, .next = null},
                else => .{.value = n, .previous = &nodes[i-1], .next = null},
            };
            nodes[i] = node;
        }
        nodes[0].previous = &nodes[nodes.len-1];
        for (nodes) |*node, i| {
            if (i == nodes.len - 1) continue;
            node.next = &nodes[i+1];
        }
        nodes[nodes.len-1].next = &nodes[0];
        return .{.nodes = nodes, .alloc = alloc};
    }
    pub fn deinit(self: *Mixer) void {
        self.alloc.free(self.nodes);
    }
    pub fn decrypt(self: *Mixer) void {
        // we do mod - 1 to avoid moving over self
        const mod = @intCast(i64, self.nodes.len) - 1;
        for (self.nodes) |*node| {
            node.cycle(mod);
        }
    }
    pub fn print(self: *const Mixer) void {
        var i : usize = 0;
        var start = &self.nodes[0];
        while (i < self.nodes.len ) : (i += 1) {
            std.debug.print("{d} -> ", .{start.value});
            start = start.next.?;
        }
        std.debug.print("\n", .{});
    }
    pub fn readOut(self: *Mixer) u64 {
        // find our 0
        var zero = blk: {
            for (self.nodes) |node| {
                if (node.value == 0) break :blk node;
            }
            unreachable;
        };

        var total: i64 = 0;
        var i: usize = 1;
        while (i < 4) : (i += 1) {
            // how many complete loops do we end up doing
            var cycle = @intCast(i64, @rem(i * 1000, self.nodes.len));
            const number = zero.getNthLink(cycle).value;
            total += number;
        }
        return std.math.absCast(total);
    }
};

fn solve(alloc: std.mem.Allocator, input: [] const u8) ![2]u64 {
    var lines = std.mem.split(u8, input, "\n");
    var numbers = std.ArrayList(i64).init(alloc);
    defer numbers.deinit();
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try numbers.append(try std.fmt.parseInt(i64, line, 10));
    }
    var mixer = try Mixer.init(alloc, numbers.items);
    defer mixer.deinit();

    mixer.decrypt();

    // rescale numbers
    for (numbers.items) |*n| {
        n.* *= 811589153;
    }
    var mixer2 = try Mixer.init(alloc, numbers.items);
    defer mixer2.deinit();

    var i:usize = 0;
    while (i < 10) : (i += 1) {
        mixer2.decrypt();
    }

    const part1 = mixer.readOut();
    const part2 = mixer2.readOut();
    return .{part1,part2};
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
