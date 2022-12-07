const std = @import("std");
const util = @import("../util.zig");

const File = struct { size: u64, name: []const u8 };

const DirMap = std.StringHashMap(Dir);

const TOTAL_SPACE = 70000000;
const MINIMUM_SPACE = 30000000;

const Dir = struct {
    name: []const u8,
    subdirs: DirMap,
    files: ?[]File,
    parent: ?*Dir,
    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator, parent: ?*Dir, name: []const u8, files: ?[]File) Dir {
        return .{
            .name = name,
            .subdirs = DirMap.init(alloc),
            .files = files,
            .parent = parent,
            .alloc = alloc,
        };
    }
    pub fn walkSizes(self: *const Dir, sizelist: *std.ArrayList(u64)) !void {
        const size = self.totalSize();
        try sizelist.append(size);
        var ditt = self.subdirs.valueIterator();
        while (ditt.next()) |d| {
            try walkSizes(d, sizelist);
        }
    }
    pub fn totalSize(self: *const Dir) u64 {
        var total: u64 = 0;
        for (self.files.?) |f| {
            total += f.size;
        }
        var ditt = self.subdirs.valueIterator();
        while (ditt.next()) |d| {
            total += d.totalSize();
        }

        return total;
    }
    pub fn deinit(self: *Dir) void {
        if (self.files) |files| self.alloc.free(files);
        var ditt = self.subdirs.valueIterator();
        while (ditt.next()) |d| {
            d.deinit();
        }
        self.subdirs.deinit();
    }
    fn printIndent(_: *const Dir, indent: u64) void {
        var i = indent;
        while (i > 0) : (i -= 1) {
            std.debug.print(" ", .{});
        }
    }
    pub fn print(self: *const Dir, indent: u64) void {
        self.printIndent(indent);
        std.debug.print("{s}\n", .{self.name});
        if (self.files) |files| for (files) |f| {
            self.printIndent(indent + 2);
            std.debug.print("- {d} {s}\n", .{ f.size, f.name });
        };
        var ditt = self.subdirs.valueIterator();
        while (ditt.next()) |d| {
            d.print(indent + 2);
        }
    }
    pub fn assembleFiles(self: *Dir, lines: *std.mem.TokenIterator(u8)) !void {
        var files = std.ArrayList(File).init(self.alloc);
        // parse lines until next line is '$'
        while (lines.next()) |line| {
            var itt = std.mem.tokenize(u8, line, " ");
            const info = itt.next().?;
            const name = itt.next().?;
            // check if new dir
            if (info[0] != 'd') {
                const size = try std.fmt.parseInt(u64, info, 10);
                try files.append(.{ .size = size, .name = name });
            }

            if (lines.peek()) |peek| {
                if (peek[0] == '$') break;
            }
        }
        self.files = files.toOwnedSlice();
    }
};

fn solve(input: []const u8, alloc: std.mem.Allocator) ![2]u64 {
    // parse line by line
    var lines = std.mem.tokenize(u8, input, "\n");

    var root = Dir.init(alloc, null, "/", null);
    defer root.deinit();
    var cwd: *Dir = &root;
    // skip first cd command
    _ = lines.next().?;

    while (lines.next()) |line| {
        var itt = std.mem.tokenize(u8, line, " ");
        const leader = itt.next().?;
        if (leader[0] != '$') @panic("not a command");
        const cmd = itt.next().?;

        if (cmd[0] == 'c') {
            // change directory
            const nwd = itt.next().?;
            if (nwd[0] == '.') {
                cwd = cwd.parent.?;
            } else {
                try cwd.subdirs.put(nwd, Dir.init(alloc, cwd, nwd, null));
                cwd = cwd.subdirs.getEntry(nwd).?.value_ptr;
            }
        } else {
            // list
            try cwd.assembleFiles(&lines);
        }
    }

    // get sizes
    var sizelist = std.ArrayList(u64).init(alloc);
    defer sizelist.deinit();
    try root.walkSizes(&sizelist);

    const space_needed = MINIMUM_SPACE - (TOTAL_SPACE - root.totalSize());

    var part1: u64 = 0;
    var part2: u64 = TOTAL_SPACE;
    for (sizelist.items) |size| {
        if (size <= 100000) {
            part1 += size;
        }
        if (size >= space_needed) {
            if (size < part2) part2 = size;
        }
    }

    // root.print(0);
    return .{ part1, part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    const sol = try solve(@embedFile("input.txt"), allocator);
    std.debug.print("Part 1: {d}\n Part 2: {d}\n", .{ sol[0], sol[1] });
}

test "test-input" {
    const sol = try solve(@embedFile("test.txt"), std.testing.allocator);
    std.debug.print("Part 1: {d}\n Part 2: {d}\n", .{ sol[0], sol[1] });
}
