const std = @import("std");
const util = @import("../util.zig");

const Hand = enum(u8) { rock = 1, paper = 2, scissors = 3 };
const Outcome = enum(u8) { lose = 0, draw = 3, win = 6 };

fn charToOutcome(c: u8) Outcome {
    return switch (c) {
        'X' => .lose,
        'Y' => .draw,
        'Z' => .win,
        else => unreachable,
    };
}

pub fn charsToOutcome(theirs: u8, ours: u8) Outcome {
    return ([_]Outcome{ .win, .lose, .draw })[(ours - theirs) % 3];
}

pub fn charsToHand(theirs: u8, outcome: u8) Hand {
    return ([_]Hand{.scissors, .rock, .paper})[(theirs + outcome) % 3];
}

pub fn charToHand(c: u8) Hand {
    return switch (c) {
        'A', 'X' => .rock,
        'B', 'Y' => .paper,
        'C', 'Z' => .scissors,
        else => unreachable,
    };
}

const Round = struct {
    const Self = @This();
    their_hand: Hand,
    our_hand: Hand,
    outcome: Outcome,

    pub fn part1(theirs: u8, ours: u8) Round {
        const outcome = charsToOutcome(theirs, ours);
        return .{ .their_hand = charToHand(theirs), .our_hand = charToHand(ours), .outcome = outcome };
    }

    pub fn part2(theirs: u8, outcome: u8) Round {
        return .{ .their_hand = charToHand(theirs), .our_hand = charsToHand(theirs, outcome), .outcome = charToOutcome(outcome) };
    }

    pub fn score(self: *const Round) u32 {
        return @enumToInt(self.outcome) + @enumToInt(self.our_hand);
    }
};

fn solve(input: []const u8) [2]u32 {
    var lines = std.mem.tokenize(u8, input, "\n");

    var total1: u32 = 0;
    var total2: u32 = 0;
    while (lines.next()) |line| {
        const in1 = line[0];
        const in2 = line[2];

        const round1 = Round.part1(in1, in2);
        const round2 = Round.part2(in1, in2);
        // std.debug.print("THEIR: {}, OURS: {} -> {}\n", .{round.their_hand, round.our_hand, round.score()});
        total1 += round1.score();
        total2 += round2.score();
    }

    return .{ total1, total2 };
}

pub fn main() void {
    const score = solve(@embedFile("input.txt"));
    std.debug.print("Part 1: {d}\n", .{score[0]});
    std.debug.print("Part 2: {d}\n", .{score[1]});
}

test "test-input" {
    const score = solve(@embedFile("test.txt"));
    try std.testing.expect(
        score[0] == 15,
    );
    try std.testing.expect(
        score[1] == 12,
    );

    var result = try util.benchmark(std.testing.allocator, solve, .{@embedFile("input.txt")}, .{});
    defer result.deinit();
    result.printSummary();
}

fn checkOutcomes(theirs: u8, ours: u8, outcome: Outcome) !void {
    try std.testing.expect(charsToOutcome(theirs, ours) == outcome);
}

test "test-outcomes" {
    try checkOutcomes('A', 'X', .draw);
}
