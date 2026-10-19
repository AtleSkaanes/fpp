const std = @import("std");
const Io = std.Io;

const Args = @import("Args.zig");

const prep = @import("prep.zig");

pub fn main(init: std.process.Init) !void {
    var argv_iter = init.minimal.args.iterate();

    const args = Args.parse(init.gpa, init.io, &argv_iter) catch {
        std.process.exit(1);
    };
    defer args.deinit(init.gpa);

    if (args.help) {
        try Args.printHelp(init.io);
        return;
    }

    const cwd = Io.Dir.cwd();

    const in_file = if (std.mem.eql(u8, args.in, "-")) Io.File.stdin() else f: {
        break :f cwd.openFile(init.io, args.in, .{}) catch |e| {
            std.log.err("Failed to open file '{s}': {t}", .{ args.in, e });
            std.process.exit(1);
        };
    };
    defer in_file.close(init.io);

    var file_buf: [128]u8 = undefined;
    var file_reader = in_file.reader(init.io, &file_buf);

    var alloc_writer = Io.Writer.Allocating.init(init.gpa);
    defer alloc_writer.deinit();

    prep.preprocess(&file_reader.interface, &alloc_writer.writer, args.relax) catch |e| {
        switch (e) {
            error.MissingF => {},
            else => std.log.err("Failed to process stream: {t}", .{e}),
        }
        std.process.exit(1);
    };

    const out_file = if (std.mem.eql(u8, args.out, "-")) Io.File.stdout() else f: {
        break :f cwd.createFile(init.io, args.out, .{}) catch |e| {
            std.log.err("Failed to open file '{s}': {t}", .{ args.out, e });
            std.process.exit(1);
        };
    };
    defer out_file.close(init.io);

    var file_writer = out_file.writer(init.io, &file_buf);
    try file_writer.interface.writeAll(alloc_writer.written());
    file_writer.interface.flush() catch {};
}
