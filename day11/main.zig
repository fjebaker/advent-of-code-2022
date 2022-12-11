const std = @import("std");
const util = @import("../util.zig");

const Fifo = std.fifo.LinearFifo(u64, .Dynamic);

const Operation = struct {
    value: u64,
    op: enum { mult, add, square },

    pub fn apply(self: *const Operation, value: u64) u64 {
        return switch (self.op) {
            .square => value * value,
            .mult => value * self.value,
            .add => value + self.value,
        };
    }
};

fn lcm(a: u64, b: u64) u64 {
    const gcd = std.math.gcd(a, b);
    return a * b / gcd;
}

const Monkey = struct {
    items: Fifo,
    op: Operation,
    testval: u64,
    monkey1: usize,
    monkey2: usize,
    inspected: u64 = 0,

    pub fn parseFromText(alloc: std.mem.Allocator, text: []const u8) !Monkey {
        var itt = std.mem.tokenize(u8, text, "\n");
        // discard first line
        _ = itt.next();
        // read starting items
        var fifo = Fifo.init(alloc);
        errdefer fifo.deinit();
        {
            const line = itt.next().?;
            const i = std.mem.indexOf(u8, line, ":").? + 1;
            var item_itt = std.mem.tokenize(u8, line[i..], ",");
            while (item_itt.next()) |item| {
                try fifo.writeItem(try std.fmt.parseInt(u8, item[1..], 10));
            }
        }
        // find operation
        var op: Operation = blk: {
            const line = itt.next().?;
            const i = std.mem.indexOf(u8, line, "=").? + 1;
            var tokens = std.mem.tokenize(u8, line[i..], " ");
            // get operation information
            const lhs = tokens.next().?;
            const op_char = tokens.next().?[0];
            const rhs = tokens.next().?;
            // square operations will have `old` in both positions
            if (std.mem.eql(u8, lhs, rhs)) break :blk .{ .value = 1, .op = .square };

            const rhs_val = try std.fmt.parseInt(u64, rhs, 10);
            break :blk switch (op_char) {
                '+' => .{ .value = rhs_val, .op = .add },
                '*' => .{ .value = rhs_val, .op = .mult },
                else => unreachable,
            };
        };

        const testval: u64 = blk: {
            const line = itt.next().?;
            const i = std.mem.indexOf(u8, line, "by ").? + 3;
            break :blk try std.fmt.parseInt(u8, line[i..], 10);
        };

        const monkey1: usize = blk: {
            const line = itt.next().?;
            const i = std.mem.indexOf(u8, line, "key ").? + 4;
            break :blk try std.fmt.parseInt(u8, line[i..], 10);
        };

        const monkey2: usize = blk: {
            const line = itt.next().?;
            const i = std.mem.indexOf(u8, line, "key ").? + 4;
            break :blk try std.fmt.parseInt(u8, line[i..], 10);
        };

        return .{
            .items = fifo,
            .op = op,
            .testval = testval,
            .monkey1 = monkey1,
            .monkey2 = monkey2,
        };
    }
    pub fn deinit(self: *Monkey) void {
        self.items.deinit();
    }
    pub fn give(self: *Monkey, item: u64) !void {
        try self.items.writeItem(item);
    }
    pub fn inspectNext(self: *Monkey, monkeys: []Monkey) !void {
        // select first item
        const item = self.items.readItem().?;
        const worry = @divFloor(self.op.apply(item), 3);
        if (worry % self.testval == 0) {
            try monkeys[self.monkey1].give(worry);
        } else {
            try monkeys[self.monkey2].give(worry);
        }
        self.inspected += 1;
    }
    pub fn inspectAll(self: *Monkey, monkeys: []Monkey) !void {
        while (self.items.count > 0) {
            try self.inspectNext(monkeys);
        }
    }
};

fn parseAll(alloc: std.mem.Allocator, input: []const u8) ![]Monkey {
    var monkey_text = std.mem.split(u8, input, "\n\n");

    var list = std.ArrayList(Monkey).init(alloc);
    errdefer list.deinit();
    errdefer for (list.items) |*m| m.deinit();

    while (monkey_text.next()) |lines| {
        if (lines.len == 0) continue;
        var monkey = try Monkey.parseFromText(alloc, lines);
        try list.append(monkey);
    }
    return list.toOwnedSlice();
}

fn doRound(monkeys: []Monkey) !void {
    for (monkeys) |*monkey| {
        try monkey.inspectAll(monkeys);
    }
}

fn showHoldings(monkeys: []const Monkey) void {
    for (monkeys) |*monkey, j| {
        std.debug.print("Monkey {d}:", .{j});
        var i: usize = 0;
        while (i < monkey.items.count) : (i += 1) {
            std.debug.print(" {d}", .{monkey.items.peekItem(i)});
        }
        std.debug.print("\n", .{});
    }
}

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]u64 {
    var monkeys = try parseAll(alloc, input);
    defer alloc.free(monkeys);
    defer for (monkeys) |*m| m.deinit();

    showHoldings(monkeys);
    var i: u64 = 0;
    while (i < 20) : (i += 1) {
        try doRound(monkeys);
    }
    showHoldings(monkeys);

    var accum = std.ArrayList(u64).init(alloc);
    errdefer accum.deinit();
    for (monkeys) |*monkey| {
        try accum.append(monkey.inspected);
    }
    var counts = try accum.toOwnedSlice();
    defer alloc.free(counts);

    std.sort.sort(u64, counts, {}, std.sort.desc(u64));

    const part1 = counts[0] * counts[1];

    return .{ part1, 0 };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const sol = try solve(allocator, @embedFile("input.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });

    // var result = try util.benchmark(allocator, solve, .{ allocator, @embedFile("input.txt") }, .{});
    // defer result.deinit();
    // result.printSummary();
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(std.testing.allocator, @embedFile("test.txt"));
    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ sol[0], sol[1] });
}
