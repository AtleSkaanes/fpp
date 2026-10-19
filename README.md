# F-Klubben Pre-Processor

This preprocessor fixes an important issue that is in nearly all languages, which is of course that not all words start with f!
You can run this preprocessor as a step before compilation

## Installation

fpp is made in zig v0.16, so the zig compiler is a neceary build dependency.
To build fpp, simply run:
```sh

$ zig build --release=fast
```

Which compiles fpp and puts it in `./zig-out/bin/fpp`.

