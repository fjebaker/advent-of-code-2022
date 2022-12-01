const std = @import("std");
pub const Map = std.AutoHashMap;

pub const BenchmarkOptions = struct {
    trials: u32 = 1000,
};

pub const BenchmarkResult = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    trials: []u64,

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.trials);
    }

    pub fn mean(self: *const Self) u64 {
        var sum: u64 = 0;
        for (self.trials) |t| {
            sum += t;
        }
        return sum / self.trials.len;
    }

    pub fn median(self: *const Self) u64 {
        const middle = @floatToInt(usize, @round(@intToFloat(f64, self.trials.len / 2)));
        return self.trials[middle];
    }

    pub fn printSummary(self: *const Self) void {
        const print = std.debug.print;
        print(
            \\ Benchmark summary for {d} trials:
            \\ Mean: {s}
            \\ Median: {s}
            \\
        , .{
            self.trials.len,
            std.fmt.fmtDuration(self.mean()),
            std.fmt.fmtDuration(self.median()),
        });
    }
};

fn invoke(comptime func: anytype, comptime args: std.meta.ArgsTuple(@TypeOf(func))) void {
    const ReturnType = @typeInfo(@TypeOf(func)).Fn.return_type.?;
    switch (@typeInfo(ReturnType)) {
        .ErrorUnion => {
            _ = @call(.{ .modifier = .never_inline }, func, args) catch {
                // std.debug.panic("Benchmarked function returned error {s}", .{err});

            };
        },
        else => _ = @call(.{ .modifier = .never_inline }, func, args),
    }
}

pub fn benchmark(
    alloc: std.mem.Allocator,
    comptime func: anytype,
    comptime args: std.meta.ArgsTuple(@TypeOf(func)),
    opts: BenchmarkOptions,
) !BenchmarkResult {
    var trials = std.ArrayList(u64).init(alloc);
    errdefer trials.deinit();
    try trials.ensureTotalCapacity(opts.trials);

    var count: u32 = 0;
    var timer = try std.time.Timer.start();
    while (count < opts.trials) : (count += 1) {
        timer.reset();
        invoke(func, args);
        const elapsed = timer.read();
        trials.appendAssumeCapacity(elapsed);
    }
    var trials_array = trials.toOwnedSlice();
    std.sort.sort(u64, trials_array, {}, std.sort.asc(u64));

    return .{ .alloc = alloc, .trials = trials_array };
}
