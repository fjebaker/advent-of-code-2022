const std = @import("std");
const util = @import("../util.zig");

const TOTAL_SPACE = 70000000;
const MINIMUM_SPACE = 30000000;

const File = struct { size: u64, name: []const u8 };
const Info = ?u64;

pub fn Tree(comptime InfoType: type, comptime LeafType: type) type {
    return struct {
        const Self = @This();
        const Lookup = std.StringHashMap(Self);

        branches: Lookup,
        leafs: []LeafType,
        parent: ?*Self,
        alloc: std.mem.Allocator,
        info: InfoType,

        pub fn init(alloc: std.mem.Allocator, parent: ?*Self, info: InfoType) Self {
            return .{
                .branches = Lookup.init(alloc),
                .leafs = &[0]File{},
                .parent = parent,
                .alloc = alloc,
                .info = info,
            };
        }
        pub fn deinit(self: *Self) void {
            var itt = self.branches.iterator();
            while (itt.next()) |entry| {
                entry.value_ptr.deinit();
            }
            self.branches.deinit();
            self.alloc.free(self.leafs);
        }
        pub fn branchIterator(self: *Self) Lookup.Iterator {
            return self.branches.iterator();
        }
    };
}

const FileTree = Tree(Info, File);
fn treeSize(tree: *FileTree) u64 {
    // have we got it cached?
    if (tree.info) |size| {
        return size;
    }
    var total: u64 = 0;
    var itt = tree.branchIterator();
    while (itt.next()) |entry| {
        total += treeSize(entry.value_ptr);
    }
    for (tree.leafs) |leaf| {
        total += leaf.size;
    }
    tree.info = total;
    return total;
}
pub fn walkSizes(tree: *FileTree, sizelist: *std.ArrayList(u64)) !void {
    const tree_size = treeSize(tree);
    try sizelist.append(tree_size);
    var itt = tree.branchIterator();
    while (itt.next()) |entry| {
        try walkSizes(entry.value_ptr, sizelist);
    }
}

pub fn assembleFiles(alloc: std.mem.Allocator, lines: *std.mem.TokenIterator(u8)) ![]File {
    var files = std.ArrayList(File).init(alloc);
    // parse lines until next line is '$'
    while (lines.next()) |line| {
        var itt = std.mem.tokenize(u8, line, " ");
        const info = itt.next().?;
        const name = itt.next().?;
        // check if new dir
        if (info[0] != 'd') {
            const file_size = try std.fmt.parseInt(u64, info, 10);
            try files.append(.{ .size = file_size, .name = name });
        }
        if (lines.peek()) |peek| if (peek[0] == '$') break;
    }
    return files.toOwnedSlice();
}

fn solve(input: []const u8, alloc: std.mem.Allocator) ![2]u64 {
    // parse line by line
    var lines = std.mem.tokenize(u8, input, "\n");

    var root = FileTree.init(alloc, null, null);
    defer root.deinit();
    var cwd: *FileTree = &root;
    // skip first cd command
    _ = lines.next().?;

    while (lines.next()) |line| {
        var itt = std.mem.tokenize(u8, line, " ");
        if (itt.next().?[0] != '$') @panic("not a command");

        const cmd = itt.next().?;
        if (cmd[0] == 'c') {
            // change directory
            const name = itt.next().?;
            if (name[0] == '.') {
                cwd = cwd.parent.?;
            } else {
                try cwd.branches.put(name, FileTree.init(alloc, cwd, null));
                cwd = cwd.branches.getEntry(name).?.value_ptr;
            }
        } else {
            // list
            var file_list = try assembleFiles(alloc, &lines);
            cwd.leafs = file_list;
        }
    }

    // get sizes
    var sizelist = std.ArrayList(u64).init(alloc);
    defer sizelist.deinit();
    try walkSizes(&root, &sizelist);

    const space_needed = MINIMUM_SPACE - (TOTAL_SPACE - sizelist.items[0]);
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

    var result = try util.benchmark(allocator, solve, .{ @embedFile("input.txt"), allocator }, .{});
    defer result.deinit();
    result.printSummary();
}

test "test-input" {
    const sol = try solve(@embedFile("test.txt"), std.testing.allocator);
    std.debug.print("Part 1: {d}\n Part 2: {d}\n", .{ sol[0], sol[1] });

    try std.testing.expect(sol[0] == 95437);
    try std.testing.expect(sol[1] == 24933642);
}
