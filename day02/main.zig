const std = @import("std");
const util = @import("../util.zig");

const Outcome = enum(u8) {
    win = 6,
    draw = 3,
    lose = 0,

    pub fn fromChar(c: u8) Outcome {
        return switch (c) {
            'X' => .lose,
            'Y' => .draw,
            'Z' => .win,
            else => unreachable,
        };
    }
};

const Hand = enum(u8) {
    rock = 1,
    paper = 2,
    scissors = 3,

    pub fn fromChar(c: u8) Hand {
        return switch (c) {
            'A' => .rock,
            'X' => .rock,
            'B' => .paper,
            'Y' => .paper,
            'C' => .scissors,
            'Z' => .scissors,
            else => unreachable,
        };
    }

    pub fn outcome(self_hand: Hand, other_hand: Hand) Outcome {
        const comp: i8 = @intCast(i8, @enumToInt(other_hand)) - @intCast(i8, @enumToInt(self_hand));
        return switch (comp) {
            0 => .draw,
            -1 => .win,
            2 => .win,
            else => .lose,
        };
    }

};

const Round = struct {
    const Self = @This();
    their_hand: Hand,
    our_hand: Hand,
    outcome: ?Outcome = null,

    pub fn part1(theirs: u8, ours: u8) Round {
        return .{ .their_hand = Hand.fromChar(theirs), .our_hand = Hand.fromChar(ours) };
    }

    fn handFromOutcome(their_hand: Hand, outcome: Outcome) Hand {
        return switch (outcome) {
            .draw => their_hand,
            .win => switch(their_hand) {
                .rock => .paper,
                .scissors => .rock,
                .paper => .scissors,
            },
            .lose => switch(their_hand) {
                .rock => .scissors,
                .scissors => .paper,
                .paper => .rock,
            },
        };
    }

    pub fn part2(theirs: u8, ours: u8) Round {
        const their_hand = Hand.fromChar(theirs);
        const outcome = Outcome.fromChar(ours);
        const our_hand = handFromOutcome(their_hand, outcome);
        return .{
            .their_hand = their_hand,
            .our_hand = our_hand,
            .outcome = outcome,
        };
    }

    fn calcScore(self: *const Self, outcome: Outcome) u32 {
        return @enumToInt(outcome) + @enumToInt(self.our_hand);
    }

    pub fn score(self: *const Round) u32 {
        const outcome = self.outcome orelse self.our_hand.outcome(self.their_hand);
        return self.calcScore(outcome);
    }
};

fn solve(input: []const u8) [2]u32 {
    var lines = std.mem.tokenize(u8, input, "\n");

    var total1: u32 = 0;
    var total2: u32 = 0;
    while (lines.next()) |line| {
        var itt = std.mem.tokenize(u8, line, " ");

        const in1 = itt.next().?[0];
        const in2 = itt.next().?[0];

        const round1 = Round.part1(in1, in2);
        const round2 = Round.part2(in1, in2);
        // std.debug.print("THEIR: {}, OURS: {} -> {}\n", .{round.their_hand, round.our_hand, round.score()});
        total1 += round1.score();
        total2 += round2.score();
    }

    return .{total1, total2};
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
}

fn checkParsePart1(line: []const u8, out1: Hand, out2: Hand) !void {
    var itt = std.mem.tokenize(u8, line, " ");
    const in1 = itt.next().?[0];
    const in2 = itt.next().?[0];
    const round = Round.part1(in1, in2);
    try std.testing.expect(
        round.our_hand == out1,
    );
    try std.testing.expect(
        round.their_hand == out2,
    );
}

test "parsing" {
    try checkParsePart1("A X", .rock, .rock);
    try checkParsePart1("B Y", .paper, .paper);
    try checkParsePart1("C Z", .scissors, .scissors);

    try std.testing.expect(
        Hand.fromChar('A') == .rock,
    );
    try std.testing.expect(
        Hand.fromChar('X') == .rock,
    );
}

test "win-conditions" {
    try std.testing.expect(
        Hand.rock.outcome(.paper) == .lose,
    );
    try std.testing.expect(
        Hand.rock.outcome(.rock) == .draw,
    );
    try std.testing.expect(
        Hand.rock.outcome(.scissors) == .win,
    );
    try std.testing.expect(
        Hand.scissors.outcome(.rock) == .lose,
    );
    try std.testing.expect(
        Hand.scissors.outcome(.paper) == .win,
    );
}
