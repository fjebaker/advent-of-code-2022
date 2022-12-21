const std = @import("std");

const ResourceList = struct {
    geode: u32 = 0,
    obsidian: u32 = 0,
    clay: u32 = 0,
    ore: u32 = 0,

    pub fn subtract(self: *ResourceList, other: ResourceList) void {
        inline for (ResourceFields) |field| {
            @field(self, field.name) -= @field(other, field.name);
        }
    }

    pub fn add(self: *ResourceList, other: ResourceList) void {
        inline for (ResourceFields) |field| {
            @field(self, field.name) += @field(other, field.name);
        }
    }

    pub fn mult(self: ResourceList, factor: u32) ResourceList {
        var copy: ResourceList = self;
        inline for (ResourceFields) |field| {
            @field(copy, field.name) *= factor;
        }
        return copy;
    }
};
const ResourceFields = @typeInfo(ResourceList).Struct.fields;

const BotType = enum { geode, obsidian, clay, ore };

const Blueprint = struct {
    id: u32,
    // costs of each robot
    costs: struct {
        geode: ResourceList = .{},
        obsidian: ResourceList = .{},
        clay: ResourceList = .{},
        ore: ResourceList = .{},
    },
    fn parseCost(input: []const u8) !ResourceList {
        var tokens = std.mem.tokenize(u8, input, " ");
        while (tokens.next()) |token| {
            if (std.mem.eql(u8, token, "costs")) break;
        }
        var cost = ResourceList{};
        while (tokens.next()) |token| {
            if (std.mem.eql(u8, token, "and")) continue;
            const amount = try std.fmt.parseInt(u32, token, 10);
            const resource = tokens.next().?;
            switch (resource[1]) {
                'l' => cost.clay += amount,
                'b' => cost.obsidian += amount,
                'r' => cost.ore += amount,
                else => unreachable,
            }
        }
        return cost;
    }
    pub fn fromInput(input: []const u8) !Blueprint {
        const id = try std.fmt.parseInt(u32, input[10..11], 10);
        var cost_info = std.mem.tokenize(u8, input[12..], ".");
        return .{ .id = id, .costs = .{
            .ore = try parseCost(cost_info.next().?),
            .clay = try parseCost(cost_info.next().?),
            .obsidian = try parseCost(cost_info.next().?),
            .geode = try parseCost(cost_info.next().?),
        } };
    }
};

const FactoryState = struct {
    parent: ?*Factory,
    factory: Factory,

    pub fn score(state: *const FactoryState) u32 {
        return state.factory.res.geode;
    }

    pub fn recursiveSolve(state: *FactoryState) u32 {
        // algorithm: at each step of the solve, we calculate
        // how long until we can produce each robot
        // provided
        //   - we have time
        //   - there is a reasonable chance the new robot improves the
        //     score of the factory
        // create a copy with the updated time, bot counts, production
        // etc.
        // assing the copy of the factory state as a node in the network
        // attempt recursively solve
        // also have the fiducial case where we don't do anything and let the timer run out
        var best_score: u32 = state.score();

        const time_remaining = state.factory.time_remaining;
        if (time_remaining == 0) return best_score;
        // keep building until there is no time left

        inline for (ResourceFields) |_, i| {
            const resource = @intToEnum(BotType, i);
            const time = state.factory.timeToBuild(resource);
            if (time) |t| {
                // skip if we don't have time
                const have_time = t <= time_remaining;
                if (have_time) {
                    var copy: Factory = state.factory;
                    copy.buildBot(resource, t);
                    // tally how many geodes we have
                    var new_state: FactoryState = .{
                        .parent = &state.factory,
                        .factory = copy,
                    };
                    const new_score = recursiveSolve(&new_state);
                    best_score = @max(new_score, best_score);
                }
            }
        }

        const no_new_bots = best_score == state.score();
        if (no_new_bots) {
            state.factory.fastForwardRemaining();
            return state.score();
        }
        return best_score;
    }
};

const Factory = struct {
    // bot counts i.e. production
    bots: ResourceList,
    // resources counts
    res: ResourceList,
    time_remaining: u32 = 24,
    blueprint: Blueprint,

    pub fn new(blueprint: Blueprint) Factory {
        return .{ .bots = .{ .ore = 1 }, .res = .{}, .blueprint = blueprint };
    }

    pub fn buildBot(self: *Factory, bot: BotType, time: u32) void {
        // std.debug.print("Building {} in {d} minutes", .{ bot, time });
        self.updateProduction(time);
        const cost = blk: {
            switch (bot) {
                .ore => {
                    self.bots.ore += 1;
                    break :blk self.blueprint.costs.ore;
                },
                .clay => {
                    self.bots.clay += 1;
                    break :blk self.blueprint.costs.clay;
                },
                .obsidian => {
                    self.bots.obsidian += 1;
                    break :blk self.blueprint.costs.obsidian;
                },
                .geode => {
                    self.bots.geode += 1;
                    break :blk self.blueprint.costs.geode;
                },
            }
        };
        self.res.subtract(cost);
        self.time_remaining -= time;
    }
    pub fn fastForwardRemaining(self: *Factory) void {
        if (self.time_remaining > 0) {
            self.updateProduction(self.time_remaining);
            self.time_remaining = 0;
        }
    }

    pub fn updateProduction(self: *Factory, time: u32) void {
        self.res.add(self.bots.mult(time));
    }

    pub fn timeToBuild(self: *const Factory, bot: BotType) ?u32 {
        // (cost of bot - amount we have) / production == time
        const cost = switch (bot) {
            .geode => self.blueprint.costs.geode,
            .obsidian => self.blueprint.costs.obsidian,
            .clay => self.blueprint.costs.clay,
            .ore => self.blueprint.costs.ore,
        };
        var longest: u32 = 1;
        inline for (ResourceFields) |field| {
            const diff = @field(cost, field.name) -| @field(self.res, field.name);
            // if we already have all the resources
            if (diff != 0) {
                const production = @field(self.bots, field.name);
                // if we aren't producing
                if (production == 0) return null;
                const carry: u32 = if (diff % production != 0) 1 else 0;
                // plus one for the build time
                longest = @max(longest, @divFloor(diff, production) + carry + 1);
            }
        }
        return longest;
    }

    pub fn depthFirstSolve(self: *Factory) u32 {
        var state = FactoryState{ .parent = null, .factory = self.* };
        return state.recursiveSolve();
    }

    pub fn prettyPrint(self: *const Factory) void {
        std.debug.print(
            \\ Factory: Time-Remaining {d} (id={d})
            \\ Bots:       ORE {d:3>} : CLAY {d:3>} : OBS {d:3>} : GEODE {d:3>}
            \\ Resources:  ORE {d:3>} : CLAY {d:3>} : OBS {d:3>} : GEODE {d:3>}
            \\
        , .{
            self.time_remaining,
            self.blueprint.id,
            self.bots.ore,
            self.bots.clay,
            self.bots.obsidian,
            self.bots.geode,
            self.res.ore,
            self.res.clay,
            self.res.obsidian,
            self.res.geode,
        });
    }
};

test "test-parsing" {
    std.debug.print("\n\n", .{});
    const input = @embedFile("test.txt");
    var lines = std.mem.split(u8, input, "\n");
    _ = lines.next();
    var bp = try Blueprint.fromInput(lines.next().?);
    var factory = Factory.new(bp);
    // {
    //     const time = factory.timeToBuild(.ore).?;
    //     try std.testing.expectEqual(time, 5);
    // }
    // {
    //     const time = factory.timeToBuild(.clay).?;
    //     try std.testing.expectEqual(time, 3);
    // }
    // {
    //     const time = factory.timeToBuild(.obsidian);
    //     try std.testing.expect(time == null);
    // }

    factory.prettyPrint();
    // factory.buildBot(.clay, factory.timeToBuild(.clay).?);
    // factory.prettyPrint();
    // factory.buildBot(.clay, factory.timeToBuild(.clay).?);
    // factory.prettyPrint();
    // factory.buildBot(.clay, factory.timeToBuild(.clay).?);
    // factory.prettyPrint();
    // std.debug.print("{any}\n", .{factory});
    const best = factory.depthFirstSolve();
    std.debug.print("Best: {d}\n", .{best});
}
