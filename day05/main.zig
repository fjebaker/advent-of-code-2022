const std = @import("std");
const util = @import("../util.zig");

const CharStack = std.ArrayList(u8);
fn freeCharStacks(allocator: std.mem.Allocator, stacks: []CharStack) void {
    for (stacks) |*stack| {
        stack.deinit();
    }
    allocator.free(stacks);
}
const Instruction = struct { number: u8, from: u8, to: u8 };
const Problem = struct {
    instructions: []Instruction,
    stacks: []CharStack,
    alloc: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) !Problem {
        const split_loc = std.mem.indexOf(u8, input, "\n\n").?;
        // iterate backwards to push stacks as they come
        var stack_itt = std.mem.splitBackwards(u8, input[0..split_loc], "\n");
        // +2 to avoid the new lines we split on
        const instruction_input = input[split_loc + 2 ..];
        // how many stacks have we got
        const num_stacks = blk: {
            const line = stack_itt.next().?;
            var line_itt = std.mem.splitBackwards(u8, line, " ");
            while (line_itt.next()) |item| {
                if (item.len == 0) continue;
                break :blk try std.fmt.parseInt(usize, item, 10);
            }
            unreachable;
        };

        var stacks = try assembleStacks(allocator, &stack_itt, num_stacks);
        errdefer freeCharStacks(allocator, stacks);
        var instructions = try assembleInstructions(allocator, instruction_input);
        return .{ .instructions = instructions, .stacks = stacks, .alloc = allocator };
    }

    fn readSolution(self: *Problem) ![]u8 {
        // read off the top of each
        var sol = try self.alloc.alloc(u8, self.stacks.len);
        errdefer self.alloc.free(sol);
        for (self.stacks) |*s, i| {
            sol[i] = s.items[s.items.len - 1];
        }
        return sol;
    }

    pub fn part1(self: *Problem) ![]u8 {
        for (self.instructions) |instruction| {
            try self.runInstruction9000(instruction);
        }
        return self.readSolution();
    }
    pub fn part2(self: *Problem) ![]u8 {
        for (self.instructions) |instruction| {
            try self.runInstruction9001(instruction);
        }
        return self.readSolution();
    }

    pub fn runInstruction9001(self: *Problem, instruction: Instruction) !void {
        var from_stack = &self.stacks[instruction.from];
        var to_stack = &self.stacks[instruction.to];
        const offset = from_stack.items.len - instruction.number;
        const items = from_stack.items[offset..];
        try to_stack.appendSlice(items);
        // remove
        var i: u8 = 0;
        while (i < instruction.number) : (i += 1) {
            _ = from_stack.pop();
        }
    }

    pub fn runInstruction9000(self: *Problem, instruction: Instruction) !void {
        var from_stack = &self.stacks[instruction.from];
        var to_stack = &self.stacks[instruction.to];
        var i: u8 = 0;
        while (i < instruction.number) : (i += 1) {
            try to_stack.append(from_stack.popOrNull().?);
        }
    }

    pub fn deinit(self: *Problem) void {
        freeCharStacks(self.alloc, self.stacks);
        self.alloc.free(self.instructions);
    }
};

const STACK_LEN = 4;
fn assembleStacks(allocator: std.mem.Allocator, itt: *std.mem.SplitBackwardsIterator(u8), num_stacks: usize) ![]CharStack {
    // init memory
    var stacks = try allocator.alloc(CharStack, num_stacks);
    for (stacks) |_, i| {
        stacks[i] = CharStack.init(allocator);
    }
    errdefer freeCharStacks(allocator, stacks);

    while (itt.next()) |line| {
        if (line.len == 0) continue;
        var i: usize = 0;
        while (i < num_stacks) : (i += 1) {
            const item_pos = i * STACK_LEN + 1;
            const item = line[item_pos];
            if (item != ' ') try stacks[i].append(item);
        }
    }

    return stacks;
}

fn assembleInstructions(allocator: std.mem.Allocator, input: []const u8) ![]Instruction {
    var instructions = std.ArrayList(Instruction).init(allocator);
    errdefer instructions.deinit();

    var itt = std.mem.tokenize(u8, input, "\n");
    while (itt.next()) |line| {
        var line_itt = std.mem.tokenize(u8, line, " ");
        // skip "move"
        _ = line_itt.next().?;
        const number = try std.fmt.parseInt(u8, line_itt.next().?, 10);
        // skip "from"
        _ = line_itt.next().?;
        const from = try std.fmt.parseInt(u8, line_itt.next().?, 10);
        // skip "to"
        _ = line_itt.next().?;
        const to = try std.fmt.parseInt(u8, line_itt.next().?, 10);
        // subtract 1 to make array indices
        try instructions.append(.{ .number = number, .from = from - 1, .to = to - 1 });
    }

    return instructions.toOwnedSlice();
}

const Solution = struct {
    alloc: std.mem.Allocator,
    part1: []u8,
    part2: []u8,
    pub fn deinit(self: *Solution) void {
        self.alloc.free(self.part1);
        self.alloc.free(self.part2);
    }
};

fn solve(allocator: std.mem.Allocator, input: []const u8) !Solution {
    var prob = try Problem.init(allocator, input);
    defer prob.deinit();

    var part1 = try prob.part1();
    // poor persons's reset
    prob.deinit();
    prob = try Problem.init(allocator, input);

    var part2 = try prob.part2();
    return .{ .alloc = allocator, .part1 = part1, .part2 = part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    var sol = try solve(allocator, @embedFile("input.txt"));
    defer sol.deinit();

    std.debug.print("Part1: {s}\nPart2: {s}\n", .{ sol.part1, sol.part2 });
}

test "test-input" {
    var prob = try Problem.init(std.testing.allocator, @embedFile("test.txt"));
    defer prob.deinit();

    // try prob.runInstruction(prob.instructions[0]);
    var p1 = try prob.part1();
    defer prob.alloc.free(p1);
    std.debug.print("\n\n{s}\n\n", .{p1});

    // reset
    prob.deinit();
    prob = try Problem.init(std.testing.allocator, @embedFile("test.txt"));
    var p2 = try prob.part2();
    defer prob.alloc.free(p2);
    std.debug.print("\n\n{s}\n\n", .{p2});
}
