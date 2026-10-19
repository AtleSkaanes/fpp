const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Argv = std.process.Args.Iterator;

const Args = @This();

/// The path to the in file
in: []const u8 = &.{},
/// The path to the out file, if any
out: []const u8 = &.{},
relax: bool = false,
help: bool = false,

pub const help_message =
    \\F-klub Pre-Processor
    \\  Fixes EVERY language by making you put an 'f' in front of every alphanumeric word
    \\
    \\Usage: fpp [options] [file]
    \\
    \\Options:
    \\    -o, --out <PATH>    Specify the file to write to, set to '-' for stdout
    \\    -r, --relax         Do not error on words that don't start with 'f'
    \\    -h, --help          Show this help screen
    \\
;

pub fn deinit(a: Args, allocator: Allocator) void {
    allocator.free(a.in);

    allocator.free(a.out);
}

const ArgFields = std.meta.FieldEnum(Args);
const ArgSet = std.EnumSet(ArgFields);

pub const Error = error{
    UnknownArg,
    MissingValue,
    MissingArgs,
    InvalidState,
    AlreadySpecified,
} || Io.Writer.Error || Allocator.Error;

pub fn parse(allocator: Allocator, io: Io, iter: *Argv) Error!Args {
    var fields: ArgSet = .empty;
    var args: Args = .{};

    if (!iter.skip()) {
        try printHelp(io);
        return Error.MissingArgs;
    }

    var found_unknown_arg = false;

    while (iter.next()) |raw_arg| {
        const arg_tuple: struct { key: []const u8, val: ?[]const u8 } = blk: {
            if (std.mem.find(u8, raw_arg, "=")) |i| {
                break :blk .{ .key = raw_arg[0..i], .val = raw_arg[i + 1 ..] };
            } else {
                break :blk .{ .key = raw_arg, .val = null };
            }
        };

        const arg = arg_tuple.key;

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            fields.insert(.help);
            args.help = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--relax")) {
            fields.insert(.relax);
            args.relax = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--out")) {
            const val = if (arg_tuple.val) |v| v else iter.next() orelse {
                std.log.err("Missing value for {s} argument", .{arg});
                return Error.MissingValue;
            };
            if (fields.contains(.out)) {
                std.log.warn("The {s} argument has already been specified", .{arg});
                allocator.free(args.out);
            }

            fields.insert(.out);
            args.out = try allocator.dupe(u8, val);
            continue;
        }

        if (std.mem.startsWith(u8, arg, "-") and arg.len != 1) {
            std.log.err("Unknown argument {s}", .{arg});
            found_unknown_arg = true;
            continue;
        }

        if (fields.contains(.in)) {
            std.log.err("The input file has already been specified", .{});
            allocator.free(args.in);
            return Error.AlreadySpecified;
        }

        fields.insert(.in);
        args.in = try allocator.dupe(u8, raw_arg);
    }

    if (found_unknown_arg)
        return Error.UnknownArg;

    if (fields.eql(.empty)) {
        fields.insert(.in);
        args.in = try allocator.dupe(u8, "-");
    }

    if (!verifyArgs(fields))
        return Error.InvalidState;

    if (!fields.contains(.out)) {
        fields.insert(.out);
        args.out = try allocator.dupe(u8, "-");
    }

    return args;
}

pub fn verifyArgs(argset: ArgSet) bool {
    if (argset.contains(.help))
        return true;

    if (!argset.contains(.in)) {
        std.log.err("Missing input file", .{});
        return false;
    }

    return true;
}

pub fn printHelp(io: Io) Io.Writer.Error!void {
    var buf: [help_message.len]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);

    try stdout.interface.writeAll(help_message);
    try stdout.interface.flush();
}
