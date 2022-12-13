const std = @import("std");
const util = @import("../util.zig");

const Order = std.math.Order;

const CharIterator = struct {
    buffer: []const u8,
    index: usize = 0,
    pub fn from(buffer: []const u8) CharIterator {
        return .{ .buffer = buffer };
    }
    pub fn next(self: *CharIterator) ?u8 {
        if (self.buffer.len > self.index) {
            self.index += 1;
            return self.buffer[self.index - 1];
        } else return null;
    }
    pub fn peek(self: *CharIterator) ?u8 {
        if (self.buffer.len > self.index) {
            return self.buffer[self.index];
        } else return null;
    }
};

const Packet = union(enum) {
    list: struct {
        alloc: std.mem.Allocator,
        children: []Packet,
    },
    integer: u32,

    fn recursiveParse(alloc: std.mem.Allocator, itt: *CharIterator) !Packet {
        // temporary buffer for reading multi digit integers
        var buffer: [16]u8 = undefined;
        var i: usize = 0;
        // list to allocate children into
        var children = std.ArrayList(Packet).init(alloc);
        defer children.deinit();
        errdefer for (children.items) |*child| child.deinit();

        while (itt.next()) |c| {
            switch (c) {
                '[' => try children.append(try recursiveParse(alloc, itt)),
                ']' => break,
                ',' => continue,
                else => {
                    buffer[i] = c;
                    i += 1;
                    while (itt.peek()) |nc| {
                        if (nc >= '0' and nc <= '9') {
                            buffer[i] = nc;
                            i += 1;
                            _ = itt.next().?;
                        } else break;
                    }
                    try children.append(.{ .integer = try std.fmt.parseInt(u32, buffer[0..i], 10) });
                    i = 0;
                },
            }
        }
        return .{ .list = .{ .alloc = alloc, .children = try children.toOwnedSlice() } };
    }

    pub fn initFromText(alloc: std.mem.Allocator, input: []const u8) !Packet {
        var chars = CharIterator.from(input[1 .. input.len - 1]);
        return recursiveParse(alloc, &chars);
    }

    pub fn deinit(self: *Packet) void {
        switch (self.*) {
            .list => |*p| {
                for (p.children) |*child| child.deinit();
                p.alloc.free(p.children);
            },
            .integer => {},
        }
    }

    fn listIntegerOrder(list: []const Packet, integer: u32) Order {
        // promote and treat as list list
        return listListOrder(list, &[1]Packet{.{ .integer = integer }});
    }

    fn listListOrder(list1: []const Packet, list2: []const Packet) Order {
        var i: usize = 0;
        while (i < list1.len) : (i += 1) {
            // right list ran out of items first
            if (i >= list2.len) return .gt;
            const state = order(&list1[i], &list2[i]);
            if (state != .eq) {
                return state;
            }
        }
        if (list1.len == list2.len) return .eq;
        // left list ran out of order first
        return .lt;
    }

    pub fn order(self: *const Packet, other: *const Packet) Order {
        return switch (self.*) {
            .integer => |i| switch (other.*) {
                .integer => |j| if (i == j) .eq else if (i < j) .lt else .gt,
                .list => |*list2| listIntegerOrder(list2.children, i).invert(),
            },
            .list => |*list1| switch (other.*) {
                .list => |*list2| listListOrder(list1.children, list2.children),
                .integer => |j| listIntegerOrder(list1.children, j),
            },
        };
    }
};

fn lessThan(_: void, left: Packet, right: Packet) bool {
    return left.order(&right).compare(.lt);
}

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u32 {
    var lines = std.mem.split(u8, input, "\n");

    var accum = std.ArrayList(Packet).init(alloc);
    defer accum.deinit();
    defer for (accum.items) |*packet| packet.deinit();

    var total: u32 = 0;
    var pair_index: u32 = 1;
    while (lines.next()) |left| {
        if (left.len == 0) {
            pair_index += 1;
            continue;
        }
        const right = lines.next().?;

        var l_packet = try Packet.initFromText(alloc, left);
        var r_packet = try Packet.initFromText(alloc, right);

        try accum.append(l_packet);
        try accum.append(r_packet);

        const outcome = l_packet.order(&r_packet);
        switch (outcome) {
            .lt => total += pair_index,
            else => {},
        }
    }

    // add divider packets
    var div1 = try Packet.initFromText(alloc, "[2]");
    var div2 = try Packet.initFromText(alloc, "[6]");
    {
        errdefer div1.deinit();
        errdefer div2.deinit();
        try accum.append(div1);
        try accum.append(div2);
    }

    var all_packets = try accum.toOwnedSlice();
    defer alloc.free(all_packets);
    defer for (all_packets) |*packet| packet.deinit();
    // sort packets
    std.sort.sort(Packet, all_packets, {}, lessThan);

    // find indexes of dividers
    var div1_index: ?u32 = null;
    var div2_index: ?u32 = null;
    for (all_packets) |packet, i| {
        if (div1_index) |_| {} else {
            if (packet.order(&div1) == .eq) div1_index = @intCast(u32, i + 1);
        }
        if (div2_index) |_| {} else {
            if (packet.order(&div2) == .eq) div2_index = @intCast(u32, i + 1);
        }
    }
    return .{ total, div1_index.? * div2_index.? };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    var result = try util.benchmark(allocator, solve, .{ allocator, @embedFile("input.txt") }, .{});
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}

fn testSinglePacket(expected: Order, p1: []const u8, p2: []const u8) !void {
    var alloc = std.testing.allocator;
    var l_packet = try Packet.initFromText(alloc, p1);
    defer l_packet.deinit();
    var r_packet = try Packet.initFromText(alloc, p2);
    defer r_packet.deinit();
    return std.testing.expect(l_packet.order(&r_packet) == expected);
}

test "parsing-single" {
    try testSinglePacket(.lt, "[1,1,3,1,1]", "[1,1,5,1,1]");
    try testSinglePacket(.lt, "[[1],[2,3,4]]", "[[1],4]");
    try testSinglePacket(.gt, "[9]", "[[8,7,6]]");
    try testSinglePacket(.lt, "[[4,4],4,4]", "[[4,4],4,4,4]");
    try testSinglePacket(.gt, "[7,7,7,7]", "[7,7,7]");
    try testSinglePacket(.lt, "[]", "[3]");
    try testSinglePacket(.gt, "[[[]]]", "[[]]");
    try testSinglePacket(.gt, "[1,[2,[3,[4,[5,6,7]]]],8,9]", "[1,[2,[3,[4,[5,6,0]]]],8,9]");
}
