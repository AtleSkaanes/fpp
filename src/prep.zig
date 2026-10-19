const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Error = error{ MissingF, ReadFailed, StreamTooLong } || Allocator.Error || Io.Reader.Error || Io.Writer.Error;

/// Preprocess the input of a reader, and write the result to a writer
pub fn preprocess(in: *Io.Reader, out: *Io.Writer, relax: bool) Error!void {
    var line_num: u32 = 1;
    while (try in.takeDelimiter('\n')) |line| : (line_num += 1) {
        try processLine(out, line, line_num, relax);
        try out.writeByte('\n');
    }

    out.flush() catch {};
}

/// Process one line of input, and write the result to a writer
fn processLine(out: *Io.Writer, line: []const u8, line_num: u32, relax: bool) Error!void {
    var in_word = false;

    var start_idx: usize = 0;

    for (line, 0..) |ch, i| {
        const ch_is_word = isWordChar(ch);

        // Was in word, and still in a word
        if (in_word and ch_is_word) {
            continue;
        }

        // Was in word, but is no longer in word
        if (in_word and !ch_is_word) {
            handleWord(out, line[start_idx..i], relax) catch |e| {
                switch (e) {
                    error.MissingF => std.log.err(
                        "{}:{}: Word '{s}' doesn't start with 'f'",
                        .{ line_num, start_idx + 1, line[start_idx..i] },
                    ),
                    else => {},
                }
                return e;
            };
            in_word = false;
            start_idx = i;
            continue;
        }

        // Was not in word, is now in word
        if (!in_word and ch_is_word) {
            // Print the non-word chars
            try out.writeAll(line[start_idx..i]);
            in_word = true;
            start_idx = i;
            continue;
        }
    }

    // If the line ended in a word, or in a non-word
    if (in_word) {
        handleWord(out, line[start_idx..], relax) catch |e| {
            switch (e) {
                error.MissingF => std.log.err(
                    "{}:{}: Word '{s}' doesn't start with 'f'",
                    .{ line_num, start_idx + 1, line[start_idx..] },
                ),
                else => {},
            }
            return e;
        };
    } else {
        try out.writeAll(line[start_idx..]);
    }
}

fn handleWord(out: *Io.Writer, word: []const u8, relax: bool) Error!void {
    const start: usize = if (word[0] == 'f' or word[0] == 'F')
        1
    else if (relax or std.ascii.isDigit(word[0]) or word[0] == '_')
        0
    else {
        return Error.MissingF;
    };

    // If a word only consists of an f, then it is allowed to stay
    if (word.len == 1) {
        try out.writeAll(word);
    } else {
        try out.writeAll(word[start..]);
    }
}

fn isWordChar(ch: u8) bool {
    return std.ascii.isAlphanumeric(ch) or ch == '_';
}
