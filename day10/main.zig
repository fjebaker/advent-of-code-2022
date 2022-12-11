const std = @import("std");
const util = @import("../util.zig");

const CRTDisplay = struct {
    const interupts = [6]u32{ 20, 60, 100, 140, 180, 220 };
    ip: usize = 0,
    outputs: [6]u32 = .{ 0, 0, 0, 0, 0, 0 },

    clock: u32 = 0,
    reg_x: i32 = 1,
    scan_line: [40]u8 = .{0} ** 40,

    fn checkInterrupts(self: *CRTDisplay) void {
        // ignore if outputs are full
        if (self.ip >= self.outputs.len) return;

        const intrp = CRTDisplay.interupts[self.ip];
        if (self.clock >= intrp) {
            self.outputs[self.ip] = @intCast(u32, self.reg_x) * intrp;
            self.ip += 1;
        }
    }

    fn drawSprite(self: *CRTDisplay) void {
        const s_index = self.clock % self.scan_line.len;
        const offset = std.math.absCast(self.reg_x - @intCast(i32, s_index));
        // draw characters
        self.scan_line[@intCast(usize, s_index)] = if (offset <= 1) '#' else ' ';
        if (s_index == self.scan_line.len - 1) {
            self.drawLine();
        }

        self.clock += 1;

        // for part 1
        self.checkInterrupts();
    }

    pub fn drawLine(self: *const CRTDisplay) void {
        std.debug.print("{s}\n", .{self.scan_line});
    }

    pub fn outputFull(self: *const CRTDisplay) bool {
        return self.ip >= self.outputs.len;
    }

    pub fn addx(self: *CRTDisplay, x: i32) void {
        self.drawSprite();
        self.drawSprite();
        self.reg_x += x;
    }
    pub fn noop(self: *CRTDisplay) void {
        self.drawSprite();
    }
};

fn solve(input: []const u8) !u32 {
    var lines = std.mem.split(u8, input, "\n");

    var crt = CRTDisplay{};

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        // handle next instruction
        const opcode = line[0];
        switch (opcode) {
            'a' => {
                const delta = try std.fmt.parseInt(i32, line[5..], 10);
                crt.addx(delta);
            },
            'n' => crt.noop(),
            else => unreachable,
        }
    }
    // sum outputs
    var total: u32 = 0;
    for (crt.outputs) |o| total += o;

    return total;
}

pub fn main() !void {
    const sol = try solve(@embedFile("input.txt"));
    std.debug.print("Part 1: {d}\n", .{sol});
}

test "test-input" {
    std.debug.print("\n", .{});
    const sol = try solve(@embedFile("test.txt"));
    std.debug.print("Part 1: {d}\n", .{sol});
}
