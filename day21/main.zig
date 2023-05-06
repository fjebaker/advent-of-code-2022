const std = @import("std");
const util = @import("../util.zig");

const T = u128;

const Operator = enum { Mul, Add, Sub, Div };
const Equation = struct{
    x1: T = 1,
    x0: T = 0,
    pub fn addRHS(self: *Equation, op: Operator, rhs: T) void {
        switch (op) {
            .Div => self.x1 /= rhs,
            .Mul => self.x1 *= rhs,
            .Add => self.x0 += rhs,
            .Sub => selx.x0 -= rhs,
        }
    }
};

const Monkey = union(enum) {
    op: struct {
        monkey1: *const [4]u8,
        monkey2: *const [4]u8,
        op: Operator,
        pub fn evaluate(self: *const @This(), m1: T, m2: T) T {
            return switch (self.op) {
                .Mul => m1 * m2,
                .Add => m1 + m2,
                .Sub => m1 - m2,
                .Div => m1 / m2,
            };
        }
    },
    num: T,
    fn getValue(self: *const Monkey, lookup: MonkeyLookup) T {
        switch (self.*) {
            .op => |monkey| {
                const val1 = stringLookup(monkey.monkey1, lookup).getValue(lookup);
                const val2 = stringLookup(monkey.monkey2, lookup).getValue(lookup);
                return monkey.evaluate(val1, val2);
            },
            .num => return self.num,
        }
    }
    fn stringLookup(m: *const [] u8, lookup: MonkeyLookup) Monkey {
        return lookup.get(&m).?;
    }
    fn needsHuman(self: *const Monkey) bool {
        switch(self.*) {
            .op => |monkey| {
                if (std.mem.eql(u8, monkey.monkey1.*, "humn") or std.mem.eql(u8, monkey.monkey2.*, "humn")) {
                    return true;
                }
                const m1 = stringLookup(monkey.monkey1, lookup); 
                const m2 = stringLookup(monkey.monkey2, lookup);
                return m1.needsHuman() or m2.needsHuman();

            },
            .num => return false,
        }
    }
    fn solve(self: *Monkey, lookup: MonkeyLookup, eqn: *Equation) void {
        // self is contextually root
        switch(self.*) {
            .op => |monkey| {
                const m1 = monkey.monkey1.*;
                const m2 = monkey.monkey2.*;
                const val2 = stringLookup(m2, lookup).getValue(lookup);
                if (std.mem.eql(u8, m1, "humn")) {
                    eqn.addRHS(monkey.op, val);
                } else {
                    const val1 = stringLookup(m1, lookup).getValue(lookup);
                }
            },
            .num => self.num
        }
    }
};

const MonkeyLookup = std.StringHashMap(Monkey);
fn parseMonkeys(alloc: std.mem.Allocator, input: []const u8) !MonkeyLookup {
    var lines = std.mem.split(u8, input, "\n");
    var lookup = MonkeyLookup.init(alloc);
    errdefer lookup.deinit();
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const name = line[0..4];
        if (line[6] >= '0' and line[6] <= '9') {
            const value = try std.fmt.parseInt(T, line[6..], 10);
            try lookup.put(name, .{ .num = value });
        } else {
            const monkey1 = line[6..10];
            const op: Operator = switch (line[11]) {
                '*' => .Mul,
                '+' => .Add,
                '-' => .Sub,
                '/' => .Div,
                else => unreachable,
            };
            const monkey2 = line[13..];
            try lookup.put(name, .{ .op = .{
                .monkey1 = monkey1,
                .op = op,
                .monkey2 = @ptrCast(*const [4]u8, monkey2),
            } });
        }
    }
    return lookup;
}

fn solve(alloc: std.mem.Allocator, input: []const u8) ![2]T {
    var monkeys = try parseMonkeys(alloc, input);
    defer monkeys.deinit();

    const root = monkeys.get("root").?;
    const part1 = root.getValue(monkeys);

    return .{ part1, 0 };
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
