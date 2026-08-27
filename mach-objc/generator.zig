const std = @import("std");
const reg = @import("registry.zig");
const coverage = @import("generator_manifest.zig");

const Container = reg.Container;
const Enum = reg.Enum;
const EnumValue = reg.EnumValue;
const Method = reg.Method;
const Param = reg.Param;
const Property = reg.Property;
const Registry = reg.Registry;
const Type = reg.Type;
const TypeParam = reg.TypeParam;

var registry: Registry = undefined;

// ------------------------------------------------------------------------------------------------
pub const ParseError = error{
    UnexpectedCharacter,
    UnexpectedToken,
    UnsupportedArrayType,
    UnsupportedFunctionPointer,
    UnsupportedGenericObjectType,
    UnsupportedParenthesizedType,
};

pub const Token = struct {
    kind: Kind,
    text: []const u8,

    const Kind = enum {
        int,
        id,
        dot,
        comma,
        lparen,
        rparen,
        lbracket,
        rbracket,
        less,
        greater,
        caret,
        star,
        quote,
        hyphen,
        colon,
        semi_colon,
        plus,
        grave_accent,
        single_quote,
        kw_bool,
        kw_char,
        kw_class,
        kw_const,
        kw_double,
        kw_float,
        kw_id,
        kw_imp,
        kw_instancetype,
        kw_int,
        kw_int8_t,
        kw_int16_t,
        kw_int32_t,
        kw_int64_t,
        kw_kindof,
        kw_long,
        kw_nonnull,
        kw_nullable,
        kw_null_unspecified,
        kw_nullable_result,
        kw_short,
        kw_sel,
        kw_struct,
        kw_unsigned,
        kw_uint,
        kw_uint8_t,
        kw_uint16_t,
        kw_uint32_t,
        kw_uint64_t,
        kw_void,
        eof,
    };
};

fn isdigit(c: u8) bool {
    switch (c) {
        '0'...'9' => return true,
        else => return false,
    }
}

fn isalnum(c: u8) bool {
    switch (c) {
        'a'...'z', 'A'...'Z', '0'...'9' => return true,
        else => return false,
    }
}

pub const Lexer = struct {
    const Self = @This();

    source: []const u8,
    offset: usize = 0,

    pub fn next(self: *Self) !Token {
        while (true) {
            const start = self.offset;
            var c = self.peek();
            switch (c) {
                ' ', '\t', '\n', '\r' => {
                    self.skip();
                },
                '0'...'9' => {
                    self.skip();
                    c = self.peek();
                    while (isdigit(c)) {
                        self.skip();
                        c = self.peek();
                    }

                    return self.token(Token.Kind.int, start);
                },
                'a'...'z', 'A'...'Z', '_' => {
                    self.skip();
                    c = self.peek();
                    while (isalnum(c) or c == '_') {
                        self.skip();
                        c = self.peek();
                    }

                    const text = self.source[start..self.offset];
                    const kind = if (std.mem.eql(u8, text, "BOOL"))
                        Token.Kind.kw_bool
                    else if (std.mem.eql(u8, text, "char"))
                        Token.Kind.kw_char
                    else if (std.mem.eql(u8, text, "Class"))
                        Token.Kind.kw_class
                    else if (std.mem.eql(u8, text, "const"))
                        Token.Kind.kw_const
                    else if (std.mem.eql(u8, text, "double"))
                        Token.Kind.kw_double
                    else if (std.mem.eql(u8, text, "float"))
                        Token.Kind.kw_float
                    else if (std.mem.eql(u8, text, "id"))
                        Token.Kind.kw_id
                    else if (std.mem.eql(u8, text, "IMP"))
                        Token.Kind.kw_imp
                    else if (std.mem.eql(u8, text, "instancetype"))
                        Token.Kind.kw_instancetype
                    else if (std.mem.eql(u8, text, "int"))
                        Token.Kind.kw_int
                    else if (std.mem.eql(u8, text, "int8_t"))
                        Token.Kind.kw_int8_t
                    else if (std.mem.eql(u8, text, "int16_t"))
                        Token.Kind.kw_int16_t
                    else if (std.mem.eql(u8, text, "int32_t"))
                        Token.Kind.kw_int32_t
                    else if (std.mem.eql(u8, text, "int64_t"))
                        Token.Kind.kw_int64_t
                    else if (std.mem.eql(u8, text, "__kindof"))
                        Token.Kind.kw_kindof
                    else if (std.mem.eql(u8, text, "long"))
                        Token.Kind.kw_long
                    else if (std.mem.eql(u8, text, "_Nonnull"))
                        Token.Kind.kw_nonnull
                    else if (std.mem.eql(u8, text, "_Nullable"))
                        Token.Kind.kw_nullable
                    else if (std.mem.eql(u8, text, "_Null_unspecified"))
                        Token.Kind.kw_null_unspecified
                    else if (std.mem.eql(u8, text, "_Nullable_result"))
                        Token.Kind.kw_nullable_result
                    else if (std.mem.eql(u8, text, "SEL"))
                        Token.Kind.kw_sel
                    else if (std.mem.eql(u8, text, "short"))
                        Token.Kind.kw_short
                    else if (std.mem.eql(u8, text, "struct"))
                        Token.Kind.kw_struct
                    else if (std.mem.eql(u8, text, "uint8_t"))
                        Token.Kind.kw_uint8_t
                    else if (std.mem.eql(u8, text, "uint16_t"))
                        Token.Kind.kw_uint16_t
                    else if (std.mem.eql(u8, text, "uint32_t"))
                        Token.Kind.kw_uint32_t
                    else if (std.mem.eql(u8, text, "uint64_t"))
                        Token.Kind.kw_uint64_t
                    else if (std.mem.eql(u8, text, "unsigned"))
                        Token.Kind.kw_unsigned
                    else if (std.mem.eql(u8, text, "void"))
                        Token.Kind.kw_void
                    else
                        Token.Kind.id;

                    return self.token(kind, start);
                },
                '(' => {
                    self.skip();
                    return self.token(Token.Kind.lparen, start);
                },
                ')' => {
                    self.skip();
                    return self.token(Token.Kind.rparen, start);
                },
                '[' => {
                    self.skip();
                    return self.token(Token.Kind.lbracket, start);
                },
                ']' => {
                    self.skip();
                    return self.token(Token.Kind.rbracket, start);
                },
                '<' => {
                    self.skip();
                    return self.token(Token.Kind.less, start);
                },
                '>' => {
                    self.skip();
                    return self.token(Token.Kind.greater, start);
                },
                '^' => {
                    self.skip();
                    return self.token(Token.Kind.caret, start);
                },
                '*' => {
                    self.skip();
                    return self.token(Token.Kind.star, start);
                },
                '"' => {
                    self.skip();
                    return self.token(Token.Kind.quote, start);
                },
                '-' => {
                    self.skip();
                    return self.token(Token.Kind.hyphen, start);
                },
                ':' => {
                    self.skip();
                    return self.token(Token.Kind.colon, start);
                },
                ';' => {
                    self.skip();
                    return self.token(Token.Kind.semi_colon, start);
                },
                '+' => {
                    self.skip();
                    return self.token(Token.Kind.plus, start);
                },
                '`' => {
                    self.skip();
                    return self.token(Token.Kind.grave_accent, start);
                },
                '\'' => {
                    self.skip();
                    return self.token(Token.Kind.single_quote, start);
                },
                ',' => {
                    self.skip();
                    return self.token(Token.Kind.comma, start);
                },
                '.' => {
                    self.skip();
                    return self.token(Token.Kind.dot, start);
                },
                0 => {
                    return self.token(Token.Kind.eof, start);
                },
                else => {
                    std.debug.print("Unexpected character {c} {}\n", .{ c, c });
                    std.debug.print("Parsing {s}\n", .{self.source});
                    return error.UnexpectedCharacter;
                },
            }
        }
    }

    fn skip(self: *Self) void {
        self.offset += 1;
    }

    fn peek(self: *Self) u8 {
        if (self.offset < self.source.len) {
            return self.source[self.offset];
        } else {
            return 0;
        }
    }

    fn token(self: *Self, kind: Token.Kind, start: usize) Token {
        return Token{ .kind = kind, .text = self.source[start..self.offset] };
    }
};

pub const Parser = struct {
    const Self = @This();
    const PointerProps = struct { is_const: bool, is_optional: bool };

    allocator: std.mem.Allocator,
    lookahead: Token,
    lexer: *Lexer,
    reject_unsupported: bool,

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer, reject_unsupported: bool) !Parser {
        return Parser{
            .allocator = allocator,
            .lookahead = try lexer.next(),
            .lexer = lexer,
            .reject_unsupported = reject_unsupported,
        };
    }

    /// Returns true if `text` is a known Apple SDK attribute-macro identifier (e.g.
    /// `API_AVAILABLE`, `NS_SWIFT_NAME`, `NS_EXTENSION_UNAVAILABLE_IOS`) whose parenthesized
    /// arguments should be skipped during type parsing.
    fn isAttributeMacro(text: []const u8) bool {
        const list = [_][]const u8{
            // API_*
            "API_AVAILABLE",
            "API_UNAVAILABLE",
            "API_DEPRECATED",
            "API_DEPRECATED_WITH_REPLACEMENT",
            // NS_*
            "NS_AVAILABLE",
            "NS_AVAILABLE_MAC",
            "NS_AVAILABLE_IOS",
            "NS_DEPRECATED",
            "NS_DEPRECATED_MAC",
            "NS_DEPRECATED_IOS",
            "NS_EXTENSION_UNAVAILABLE",
            "NS_EXTENSION_UNAVAILABLE_IOS",
            "NS_EXTENSION_UNAVAILABLE_MAC",
            "NS_SWIFT_NAME",
            "NS_SWIFT_UNAVAILABLE",
            "NS_SWIFT_UNAVAILABLE_FROM_ASYNC",
            "NS_REFINED_FOR_SWIFT_ASYNC",
            // UIKIT_*
            "UIKIT_AVAILABLE_TVOS_ONLY",
            "UIKIT_AVAILABLE_IOS_ONLY",
            "UIKIT_EXTERN",
            "UI_APPEARANCE_SELECTOR",
            // Misc
            "CF_SWIFT_NAME",
            "CG_AVAILABLE_STARTING",
            "CG_AVAILABLE_BUT_DEPRECATED",
            // GCC-style attribute spelled out in some qualType strings, e.g. the NEON vector
            // typedefs pulled in transitively via <simd/simd.h>:
            //   __attribute__((neon_vector_type(8))) signed char
            // Skip the whole `((...))` group; skipParenContent handles the nested parens.
            "__attribute__",
        };
        for (list) |m| if (std.mem.eql(u8, text, m)) return true;
        return false;
    }

    pub fn parseType(self: *Self) !Type {
        // Skip Apple SDK availability/macro annotations like API_AVAILABLE(...),
        // NS_AVAILABLE(...), NS_EXTENSION_UNAVAILABLE_IOS(...), NS_SWIFT_NAME(...), etc.
        while (self.lookahead.kind == .id and isAttributeMacro(self.lookahead.text)) {
            try self.match(.id);
            if (self.lookahead.kind == .lparen) try self.skipParenContent();
        }
        const is_const = self.lookahead.kind == .kw_const;
        if (is_const)
            try self.match(.kw_const);

        // TODO - what does this mean?
        if (self.lookahead.kind == .kw_kindof)
            try self.match(.kw_kindof);

        switch (self.lookahead.kind) {
            .kw_void => {
                try self.match(.kw_void);
                return self.parseTypeSuffix(.{ .void = {} }, is_const, false);
            },
            .kw_bool => {
                try self.match(.kw_bool);
                return self.parseTypeSuffix(.{ .bool = {} }, is_const, false);
            },
            .kw_char => {
                try self.match(.kw_char);
                return self.parseTypeSuffix(.{ .uint = 8 }, is_const, false);
            },
            .kw_short => {
                try self.match(.kw_short);
                return self.parseTypeSuffix(.{ .c_short = {} }, is_const, false);
            },
            .kw_int => {
                try self.match(.kw_int);
                return self.parseTypeSuffix(.{ .c_int = {} }, is_const, false);
            },
            .kw_long => {
                try self.match(.kw_long);
                if (self.lookahead.kind == .kw_long) {
                    try self.match(.kw_long);
                    return self.parseTypeSuffix(.{ .c_longlong = {} }, is_const, false);
                } else {
                    return self.parseTypeSuffix(.{ .c_long = {} }, is_const, false);
                }
            },
            .kw_unsigned => {
                try self.match(.kw_unsigned);
                switch (self.lookahead.kind) {
                    .kw_char => {
                        try self.match(.kw_char);
                        return self.parseTypeSuffix(.{ .uint = 8 }, is_const, false);
                    },
                    .kw_short => {
                        try self.match(.kw_short);
                        return self.parseTypeSuffix(.{ .c_ushort = {} }, is_const, false);
                    },
                    .kw_int => {
                        try self.match(.kw_int);
                        return self.parseTypeSuffix(.{ .c_uint = {} }, is_const, false);
                    },
                    .kw_long => {
                        try self.match(.kw_long);
                        if (self.lookahead.kind == .kw_long) {
                            try self.match(.kw_long);
                            return self.parseTypeSuffix(.{ .c_ulonglong = {} }, is_const, false);
                        } else {
                            return self.parseTypeSuffix(.{ .c_ulong = {} }, is_const, false);
                        }
                    },
                    else => {
                        return self.parseTypeSuffix(.{ .c_uint = {} }, is_const, false);
                    },
                }
            },
            .kw_int8_t => {
                try self.match(.kw_int8_t);
                return self.parseTypeSuffix(.{ .int = 8 }, is_const, false);
            },
            .kw_int16_t => {
                try self.match(.kw_int16_t);
                return self.parseTypeSuffix(.{ .int = 16 }, is_const, false);
            },
            .kw_int32_t => {
                try self.match(.kw_int32_t);
                return self.parseTypeSuffix(.{ .int = 32 }, is_const, false);
            },
            .kw_int64_t => {
                try self.match(.kw_int64_t);
                return self.parseTypeSuffix(.{ .int = 64 }, is_const, false);
            },
            .kw_uint => {
                try self.match(.kw_uint);
                return self.parseTypeSuffix(.{ .uint = 32 }, is_const, false);
            },
            .kw_uint8_t => {
                try self.match(.kw_uint8_t);
                return self.parseTypeSuffix(.{ .uint = 8 }, is_const, false);
            },
            .kw_uint16_t => {
                try self.match(.kw_uint16_t);
                return self.parseTypeSuffix(.{ .uint = 16 }, is_const, false);
            },
            .kw_uint32_t => {
                try self.match(.kw_uint32_t);
                return self.parseTypeSuffix(.{ .uint = 32 }, is_const, false);
            },
            .kw_uint64_t => {
                try self.match(.kw_uint64_t);
                return self.parseTypeSuffix(.{ .uint = 64 }, is_const, false);
            },
            .kw_float => {
                try self.match(.kw_float);
                return self.parseTypeSuffix(.{ .float = 32 }, is_const, false);
            },
            .kw_double => {
                try self.match(.kw_double);
                return self.parseTypeSuffix(.{ .float = 64 }, is_const, false);
            },
            .kw_class => {
                try self.match(.kw_class);
                // Accept an optional Objective-C protocol qualifier, e.g. `Class<UIFooBar>` —
                // we discard it (objc.Class doesn't carry protocol-conformance information).
                if (self.lookahead.kind == .less) {
                    try self.match(.less);
                    _ = try self.parseTypeList();
                    try self.match(.greater);
                }
                return self.parsePointerSuffix(.{ .name = "objc.Class" }, is_const, true);
            },
            .kw_sel => {
                try self.match(.kw_sel);
                return self.parsePointerSuffix(.{ .name = "objc.Selector" }, is_const, true);
            },
            .kw_id => {
                try self.match(.kw_id);

                if (self.lookahead.kind == .less) {
                    try self.match(.less);
                    const types = try self.parseTypeList();
                    try self.match(.greater);

                    if (self.reject_unsupported and types.items.len != 1) {
                        return error.UnsupportedGenericObjectType;
                    }
                    return self.parsePointerSuffix(types.items[0], is_const, true);
                } else {
                    const t = Type{ .name = "objc.Id" };
                    return self.parsePointerSuffix(t, is_const, true);
                }
            },
            .kw_imp => {
                try self.match(.kw_imp);

                //void (*)(void)
                const return_type = try self.allocator.create(Type);
                return_type.* = .{ .void = {} };

                return self.parseTypeSuffix(.{
                    .function = .{
                        .return_type = return_type,
                        .params = std.array_list.Managed(Type).init(self.allocator),
                    },
                }, is_const, true);
            },
            .kw_instancetype => {
                try self.match(.kw_instancetype);
                return self.parsePointerSuffix(.{ .instance_type = {} }, is_const, true);
            },
            .kw_struct => {
                try self.match(.kw_struct);
                const name = self.lookahead.text;
                try self.match(.id);
                return self.parseTypeSuffix(.{ .name = name }, is_const, false);
            },
            else => {
                const text = self.lookahead.text;
                try self.match(.id);
                return self.parseTypeSuffix(.{ .name = text }, is_const, false);
            },
        }
    }

    fn parseTypeList(self: *Self) (ParseError || error{OutOfMemory})!std.array_list.Managed(Type) {
        var types = std.array_list.Managed(Type).init(self.allocator);

        try types.append(try self.parseType());
        while (self.lookahead.kind == .comma) {
            try self.match(.comma);
            try types.append(try self.parseType());
        }

        return types;
    }

    fn parseTypeSuffix(self: *Self, base_type: Type, is_const: bool, is_single: bool) !Type {
        if (self.lookahead.kind == .star) {
            try self.match(.star);

            return self.parsePointerSuffix(base_type, is_const, is_single);
        } else if (self.lookahead.kind == .lbracket) {
            // Dimensions are collected iteratively rather than by recursing into
            // parseTypeSuffix: a self-recursive call would make this function's
            // inferred error set depend on itself.
            var lengths: [8]u64 = undefined;
            var count: usize = 0;
            while (self.lookahead.kind == .lbracket) {
                try self.match(.lbracket);

                // `T[]` is a decayed parameter in one context and a flexible
                // array member in another, and the spelling alone cannot say
                // which. Only the lenient path keeps the old pointer reading.
                if (self.lookahead.kind != .int) {
                    if (self.reject_unsupported) return error.UnsupportedArrayType;
                    try self.match(.rbracket);
                    return self.parsePointerSuffix(base_type, is_const, is_single);
                }
                if (count == lengths.len) return error.UnsupportedArrayType;

                lengths[count] = std.fmt.parseInt(u64, self.lookahead.text, 10) catch
                    return error.UnsupportedArrayType;
                count += 1;
                try self.match(.int);
                try self.match(.rbracket);
            }

            // `float[4][3]` is four `float[3]`, so build outwards from the
            // innermost dimension.
            var result = base_type;
            var index = count;
            while (index > 0) {
                index -= 1;
                const child = try self.allocator.create(Type);
                child.* = result;
                result = .{ .array = .{ .len = lengths[index], .child = child } };
            }
            return result;
        } else if (self.lookahead.kind == .lparen) {
            try self.match(.lparen);

            if (self.lookahead.kind == .star) {
                if (self.reject_unsupported) return error.UnsupportedFunctionPointer;
                try self.match(.star);

                const props = try self.parsePointerProps(is_const);
                _ = props;

                try self.match(.rparen);
                try self.match(.lparen);
                _ = try self.parseTypeList();
                try self.match(.rparen);
            } else if (self.lookahead.kind == .caret) {
                try self.match(.caret);

                const props = try self.parsePointerProps(is_const);
                _ = props;

                try self.match(.rparen);
                try self.match(.lparen);
                const params = try self.parseTypeList();
                try self.match(.rparen);

                const return_type = try self.allocator.create(Type);
                return_type.* = base_type;

                return .{
                    .function = .{
                        .return_type = return_type,
                        .params = params,
                    },
                };
            } else {
                if (self.reject_unsupported) return error.UnsupportedParenthesizedType;
                _ = try self.parseTypeList();
                try self.match(.rparen);
            }

            return base_type;
        } else if (self.lookahead.kind == .less) {
            try self.match(.less);
            const types = try self.parseTypeList();
            try self.match(.greater);

            const child = try self.allocator.create(Type);
            child.* = base_type;

            return self.parseTypeSuffix(.{ .generic = .{ .base_type = child, .args = types } }, is_const, true);
        } else {
            const props = try self.parsePointerProps(false);
            _ = props;

            return base_type;
        }
    }

    fn parsePointerProps(self: *Self, elem_is_const: bool) !PointerProps {
        var is_const = elem_is_const;
        var is_optional = false;
        while (true) {
            if (self.lookahead.kind == .kw_const) {
                try self.match(.kw_const);
                is_const = true;
            } else if (self.lookahead.kind == .kw_nullable) {
                try self.match(.kw_nullable);
                is_optional = true;
            } else if (self.lookahead.kind == .kw_nonnull) {
                try self.match(.kw_nonnull);
            } else if (self.lookahead.kind == .kw_null_unspecified) {
                try self.match(.kw_null_unspecified);
            } else if (self.lookahead.kind == .kw_nullable_result) {
                try self.match(.kw_nullable_result);
            } else break;
        }

        return .{ .is_const = is_const, .is_optional = is_optional };
    }

    fn parsePointerSuffix(
        self: *Self,
        base_type: Type,
        is_const: bool,
        is_single: bool,
    ) (ParseError || error{OutOfMemory})!Type {
        const props = try self.parsePointerProps(is_const);
        const child = try self.allocator.create(Type);
        child.* = base_type;

        const t = Type{ .pointer = .{
            .is_single = is_single,
            .is_const = props.is_const,
            .is_optional = props.is_optional,
            .child = child,
        } };
        return self.parseTypeSuffix(t, false, is_single);
    }

    fn skipParenContent(self: *Self) !void {
        var nestLevel: u32 = 0;
        while (true) {
            if (self.lookahead.kind == .lparen) {
                try self.match(.lparen);
                nestLevel = nestLevel + 1;
            } else if (self.lookahead.kind == .rparen) {
                try self.match(.rparen);
                nestLevel = nestLevel - 1;
            } else {
                self.lookahead = try self.lexer.next();
            }
            if (nestLevel == 0)
                break;
        }
    }

    fn match(self: *Self, k: Token.Kind) !void {
        if (self.lookahead.kind == k) {
            self.lookahead = try self.lexer.next();
        } else {
            // Show ~80 bytes of source context to make it possible to identify the offending decl.
            const ctx_start = if (self.lexer.offset > 80) self.lexer.offset - 80 else 0;
            const ctx_end = @min(self.lexer.offset + 40, self.lexer.source.len);
            std.debug.print(
                "Expected {any} but found {any} (text='{s}') near:\n  ...{s}<<HERE>>{s}...\n",
                .{
                    k,
                    self.lookahead.kind,
                    self.lookahead.text,
                    self.lexer.source[ctx_start..self.lexer.offset],
                    self.lexer.source[self.lexer.offset..ctx_end],
                },
            );
            return error.UnexpectedToken;
        }
    }
};

// ------------------------------------------------------------------------------------------------

pub fn getObject(x: std.json.Value, key: []const u8) ?std.json.Value {
    switch (x) {
        .object => |o| {
            if (o.get(key)) |v| {
                switch (v) {
                    .object => return v,
                    else => return null,
                }
            } else {
                return null;
            }
        },
        else => return null,
    }
}

pub fn getArray(x: std.json.Value, key: []const u8) []std.json.Value {
    switch (x) {
        .object => |o| {
            if (o.get(key)) |v| {
                switch (v) {
                    .array => |a| {
                        return a.items;
                    },
                    else => return &[_]std.json.Value{},
                }
            } else {
                return &[_]std.json.Value{};
            }
        },
        else => return &[_]std.json.Value{},
    }
}

pub fn getString(x: std.json.Value, key: []const u8) []const u8 {
    switch (x) {
        .object => |o| {
            if (o.get(key)) |v| {
                switch (v) {
                    .string => |s| {
                        return s;
                    },
                    else => return "",
                }
            } else {
                return "";
            }
        },
        else => return "",
    }
}

pub fn getBool(x: std.json.Value, key: []const u8) bool {
    switch (x) {
        .object => |o| {
            if (o.get(key)) |v| {
                switch (v) {
                    .bool => |b| {
                        return b;
                    },
                    else => return false,
                }
            } else {
                return false;
            }
        },
        else => return false,
    }
}

pub fn getInteger(x: std.json.Value, key: []const u8) ?i64 {
    switch (x) {
        .object => |o| {
            const value = o.get(key) orelse return null;
            return switch (value) {
                .integer => |integer| integer,
                else => null,
            };
        },
        else => return null,
    }
}

pub const Converter = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    manifest: *coverage.Manifest,
    surface: Framework,
    dependencies: std.StringHashMap(void),
    strict_types: bool = false,
    emit_diagnostics: bool = true,
    current_header: []const u8 = "<unknown>",

    pub fn init(
        allocator: std.mem.Allocator,
        manifest: *coverage.Manifest,
        surface: Framework,
    ) Converter {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .manifest = manifest,
            .surface = surface,
            .dependencies = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.dependencies.deinit();
        self.arena.deinit();
    }

    pub fn convert(self: *Self, n: std.json.Value) !void {
        const kind = getString(n, "kind");
        if (std.mem.eql(u8, kind, "TranslationUnitDecl")) {
            try self.convertTranslationUnitDecl(n);
            try self.expandDependencies(n);
            try self.collectCoverage(n);
        } else {
            return error.ExpectedTranslationUnitDecl;
        }
    }

    fn isDirectName(self: *Self, name: []const u8) bool {
        return switch (self.surface) {
            .metal => std.mem.startsWith(u8, name, "MTL"),
            .metal_fx => std.mem.startsWith(u8, name, "MTLFX") or
                std.mem.startsWith(u8, name, "MTL4FX"),
            .quartz_core => std.mem.startsWith(u8, name, "CA"),
            .app_kit => false,
        };
    }

    fn isDirectHeader(self: *Self, header: []const u8) bool {
        const framework_component = switch (self.surface) {
            .metal => "/Metal.framework/",
            .metal_fx => "/MetalFX.framework/",
            .quartz_core => "/QuartzCore.framework/",
            .app_kit => "/AppKit.framework/",
        };
        return std.mem.indexOf(u8, header, framework_component) != null;
    }

    fn noteTypeDependencies(self: *Self, qual_type: []const u8) !void {
        var index: usize = 0;
        while (index < qual_type.len) {
            while (index < qual_type.len and
                !(std.ascii.isAlphabetic(qual_type[index]) or qual_type[index] == '_'))
            {
                index += 1;
            }
            const start = index;
            while (index < qual_type.len and
                (std.ascii.isAlphanumeric(qual_type[index]) or qual_type[index] == '_'))
            {
                index += 1;
            }
            if (start == index) continue;
            const identifier = qual_type[start..index];
            if (self.isDirectName(identifier) or
                std.mem.startsWith(u8, identifier, "NS") or
                std.mem.startsWith(u8, identifier, "CF") or
                std.mem.startsWith(u8, identifier, "CG"))
            {
                try self.dependencies.put(identifier, {});
            }
        }
    }

    fn expandDependencies(self: *Self, n: std.json.Value) !void {
        var changed = true;
        while (changed) {
            const previous_count = self.dependencies.count();
            for (getArray(n, "inner")) |child| {
                if (!std.mem.eql(u8, getString(child, "kind"), "TypedefDecl")) continue;
                const name = getString(child, "name");
                if (!self.dependencies.contains(name)) continue;
                if (getObject(child, "type")) |ty| {
                    try self.noteTypeDependencies(getString(ty, "qualType"));
                }
            }
            changed = self.dependencies.count() != previous_count;
        }
    }

    fn collectCoverage(self: *Self, n: std.json.Value) !void {
        self.current_header = "<unknown>";
        for (getArray(n, "inner")) |child| {
            const kind = getString(child, "kind");
            const header = self.declarationHeader(child);
            var name = getString(child, "name");
            if (std.mem.eql(u8, kind, "ObjCCategoryDecl")) {
                if (getObject(child, "interface")) |interface| {
                    name = getString(interface, "name");
                }
            }

            const required = self.isDirectHeader(header) or
                self.isDirectName(name) or
                (name.len > 0 and self.dependencies.contains(name));
            if (!required) continue;

            if (declarationKind(kind)) |manifest_kind| {
                const manifest_name = if (name.len > 0)
                    name
                else
                    try std.fmt.allocPrint(
                        self.arena.allocator(),
                        "(anonymous:{d})",
                        .{declarationLine(child)},
                    );
                _ = try self.manifest.add(manifest_kind, manifest_name, std.fs.path.basename(header));
            }

            if (std.mem.eql(u8, kind, "ObjCInterfaceDecl") or
                std.mem.eql(u8, kind, "ObjCProtocolDecl") or
                std.mem.eql(u8, kind, "ObjCCategoryDecl"))
            {
                if (self.isDirectName(name) or self.isDirectHeader(header)) {
                    try self.collectContainerCoverage(name, child, header);
                }
            }
        }
    }

    fn collectContainerCoverage(
        self: *Self,
        container_name: []const u8,
        n: std.json.Value,
        fallback_header: []const u8,
    ) !void {
        for (getArray(n, "inner")) |child| {
            const kind = getString(child, "kind");
            const manifest_kind: coverage.DeclarationKind = if (std.mem.eql(u8, kind, "ObjCMethodDecl"))
                .method
            else if (std.mem.eql(u8, kind, "ObjCPropertyDecl"))
                .property
            else
                continue;
            const child_name = getString(child, "name");
            const full_name = try std.fmt.allocPrint(
                self.arena.allocator(),
                "{s}.{s}",
                .{ container_name, child_name },
            );
            const explicit_header = explicitLocationFile(child);
            const header = if (explicit_header.len > 0) explicit_header else fallback_header;
            _ = try self.manifest.add(manifest_kind, full_name, std.fs.path.basename(header));
        }
    }

    fn declarationHeader(self: *Self, n: std.json.Value) []const u8 {
        const explicit = explicitLocationFile(n);
        if (explicit.len > 0) self.current_header = explicit;
        return self.current_header;
    }

    fn declarationKind(kind: []const u8) ?coverage.DeclarationKind {
        if (std.mem.eql(u8, kind, "EnumDecl")) return .enum_decl;
        if (std.mem.eql(u8, kind, "FunctionDecl")) return .function;
        if (std.mem.eql(u8, kind, "RecordDecl")) return .record;
        if (std.mem.eql(u8, kind, "VarDecl")) return .variable;
        if (std.mem.eql(u8, kind, "TypedefDecl")) return .typedef;
        if (std.mem.eql(u8, kind, "ObjCInterfaceDecl")) return .interface;
        if (std.mem.eql(u8, kind, "ObjCProtocolDecl")) return .protocol;
        return null;
    }

    fn explicitLocationFile(n: std.json.Value) []const u8 {
        const loc = getObject(n, "loc") orelse return "";
        const direct = getString(loc, "file");
        if (direct.len > 0) return direct;
        if (getObject(loc, "expansionLoc")) |expansion| {
            const file = getString(expansion, "file");
            if (file.len > 0) return file;
        }
        if (getObject(loc, "spellingLoc")) |spelling| {
            const file = getString(spelling, "file");
            if (file.len > 0) return file;
        }
        return "";
    }

    fn declarationLine(n: std.json.Value) i64 {
        const loc = getObject(n, "loc") orelse return 0;
        if (getInteger(loc, "line")) |line| return line;
        if (getObject(loc, "expansionLoc")) |expansion| {
            if (getInteger(expansion, "line")) |line| return line;
        }
        if (getObject(loc, "spellingLoc")) |spelling| {
            if (getInteger(spelling, "line")) |line| return line;
        }
        return 0;
    }

    fn convertTranslationUnitDecl(self: *Self, n: std.json.Value) !void {
        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "EnumDecl")) {
                try self.convertEnumDecl(child);
            } else if (std.mem.eql(u8, childKind, "FunctionDecl")) {
                self.convertFunctionDecl(child);
            } else if (std.mem.eql(u8, childKind, "ObjCCategoryDecl")) {
                try self.convertObjCCategoryDecl(child);
            } else if (std.mem.eql(u8, childKind, "ObjCInterfaceDecl")) {
                try self.convertObjCInterfaceDecl(child);
            } else if (std.mem.eql(u8, childKind, "ObjCProtocolDecl")) {
                try self.convertObjcProtocolDecl(child);
            } else if (std.mem.eql(u8, childKind, "RecordDecl")) {
                self.convertRecordDecl(child);
            } else if (std.mem.eql(u8, childKind, "TypedefDecl")) {
                try self.convertTypedefDecl(child);
            } else if (std.mem.eql(u8, childKind, "VarDecl")) {
                self.convertVarDecl(child);
            }
        }
    }

    fn convertEnumDecl(self: *Self, n: std.json.Value) !void {
        const name = getString(n, "name");
        if (name.len == 0) {
            return;
        }

        const previous_strict = self.strict_types;
        self.strict_types = self.isDirectName(name);
        defer self.strict_types = previous_strict;

        var e = try registry.getEnum(name);
        if (getObject(n, "fixedUnderlyingType")) |ty| {
            e.ty = try self.convertType(ty);
        } else {
            e.ty = .{ .int = 32 };
        }

        var next_implicit_value: i128 = 0;
        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "EnumConstantDecl")) {
                const v = try self.convertEnumConstantDecl(child, next_implicit_value);
                try e.values.append(v);
                next_implicit_value = v.value + 1;
            }
        }
    }

    fn convertEnumConstantDecl(
        self: *Self,
        n: std.json.Value,
        implicit_value: i128,
    ) !EnumValue {
        var evaluated: ?EnumValue = null;
        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "ConstantExpr")) {
                evaluated = try self.convertConstantExpr(child);
            } else if (std.mem.eql(u8, childKind, "ImplicitCastExpr")) {
                evaluated = try self.convertImplicitCastExpr(child);
            }
        }

        const children = getArray(n, "inner");
        var has_expression = false;
        for (children) |child| {
            const kind = getString(child, "kind");
            if (!std.mem.endsWith(u8, kind, "Attr")) has_expression = true;
        }
        if (evaluated == null and has_expression) {
            if (self.emit_diagnostics) {
                std.debug.print(
                    "unsupported enum expression for {s}\n",
                    .{getString(n, "name")},
                );
            }
            return error.UnsupportedEnumExpression;
        }
        const result = evaluated orelse EnumValue{ .name = "", .value = implicit_value };
        return .{
            .name = getString(n, "name"),
            .value = result.value,
            .is_max_uint = result.is_max_uint,
        };
    }

    fn convertConstantExpr(self: *Self, n: std.json.Value) !EnumValue {
        const value = getString(n, "value");
        const parsed = std.fmt.parseInt(i128, value, 10) catch {
            if (self.emit_diagnostics) {
                std.debug.print("Clang did not provide an integer enum value: '{s}'\n", .{value});
            }
            return error.InvalidClangEnumValue;
        };
        if (parsed == std.math.maxInt(u64)) {
            return .{ .name = "", .value = parsed, .is_max_uint = true };
        }
        return .{ .name = "", .value = parsed };
    }

    fn convertImplicitCastExpr(self: *Self, n: std.json.Value) !EnumValue {
        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "ConstantExpr")) {
                return try self.convertConstantExpr(child);
            }
        }

        return error.MissingClangEnumValue;
    }

    fn convertFunctionDecl(self: *Self, n: std.json.Value) void {
        _ = self;
        _ = n;
    }

    fn convertObjCCategoryDecl(self: *Self, n: std.json.Value) !void {
        const interfaceDecl = getObject(n, "interface").?;
        const name = getString(interfaceDecl, "name");
        const previous_strict = self.strict_types;
        self.strict_types = self.isDirectName(name);
        defer self.strict_types = previous_strict;
        const container = try registry.getInterface(name);
        try self.convertContainer(container, n);
    }

    fn convertObjCInterfaceDecl(self: *Self, n: std.json.Value) !void {
        const name = getString(n, "name");
        const previous_strict = self.strict_types;
        self.strict_types = self.isDirectName(name);
        defer self.strict_types = previous_strict;
        var container = try registry.getInterface(name);
        if (getObject(n, "super")) |super| {
            const superName = getString(super, "name");
            if (superName.len > 0) {
                container.super = try registry.getInterface(superName);
            }
        }

        try self.convertContainer(container, n);
    }

    fn convertObjcProtocolDecl(self: *Self, n: std.json.Value) !void {
        const name = getString(n, "name");
        const previous_strict = self.strict_types;
        self.strict_types = self.isDirectName(name);
        defer self.strict_types = previous_strict;
        var container = try registry.getProtocol(name);
        if (getObject(n, "super")) |super| {
            const superName = getString(super, "name");
            if (superName.len > 0) {
                container.super = try registry.getProtocol(superName);
            }
        }

        try self.convertContainer(container, n);
    }

    fn convertRecordDecl(self: *Self, n: std.json.Value) void {
        _ = self;
        _ = n;
    }

    fn convertTypedefDecl(self: *Self, n: std.json.Value) !void {
        const name = getString(n, "name");
        const ty = try self.convertType(getObject(n, "type").?);
        try registry.typedefs.put(name, ty);
    }

    fn convertVarDecl(self: *Self, n: std.json.Value) void {
        _ = self;
        _ = n;
    }

    fn convertContainer(self: *Self, container: *Container, n: std.json.Value) !void {
        // TODO - better solution for this?
        container.type_params.clearAndFree();
        container.protocols.clearAndFree();

        for (getArray(n, "protocols")) |protocolJson| {
            const protocolName = getString(protocolJson, "name");
            const protocol = try registry.getProtocol(protocolName);
            try container.protocols.append(protocol);
        }

        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "ObjCTypeParamDecl")) {
                const type_param = try self.convertTypeParam(child);
                try container.type_params.append(type_param);
            } else if (std.mem.eql(u8, childKind, "ObjCPropertyDecl")) {
                const property = try self.convertProperty(child);
                try container.properties.append(property);
            } else if (std.mem.eql(u8, childKind, "ObjCMethodDecl")) {
                const method = try self.convertMethod(child);
                try container.methods.append(method);
            }
        }
    }

    fn convertTypeParam(self: *Self, n: std.json.Value) !TypeParam {
        _ = self;
        return TypeParam.init(getString(n, "name"));
    }

    fn convertProperty(self: *Self, n: std.json.Value) !Property {
        const ty = try self.convertType(getObject(n, "type").?);
        var property = Property.init(getString(n, "name"), ty);
        // Clang emits `getter`/`setter` declaration references only when the
        // property overrides the default selector; default selectors stay
        // implicit and are reconstructed in findPropertyAccessors.
        if (getObject(n, "getter")) |getter| {
            property.explicit_getter = getString(getter, "name");
        }
        if (getObject(n, "setter")) |setter| {
            property.explicit_setter = getString(setter, "name");
        }
        return property;
    }

    fn convertMethod(self: *Self, n: std.json.Value) !Method {
        const return_type = try self.convertType(getObject(n, "returnType").?);
        var params = std.array_list.Managed(Param).init(registry.allocator);

        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "ParmVarDecl")) {
                const param = try self.convertParam(child);
                try params.append(param);
            }
        }

        return Method.init(getString(n, "name"), getBool(n, "instance"), return_type, params);
    }

    fn convertParam(self: *Self, n: std.json.Value) !Param {
        const ty = try self.convertType(getObject(n, "type").?);
        return Param.init(getString(n, "name"), ty);
    }

    fn convertType(self: *Self, t: std.json.Value) !Type {
        const qual_type = getString(t, "qualType");
        if (self.strict_types) {
            try self.noteTypeDependencies(qual_type);
            if (std.mem.indexOf(u8, qual_type, "vector_type") != null or
                std.mem.indexOf(u8, qual_type, "vector_size") != null)
            {
                if (self.emit_diagnostics) {
                    std.debug.print("unsupported vector type in selected surface: {s}\n", .{qual_type});
                }
                return error.UnsupportedVectorType;
            }
        }

        var lexer = Lexer{ .source = qual_type };
        var parser = try Parser.init(self.arena.allocator(), &lexer, self.strict_types);
        const result = parser.parseType() catch |err| {
            if (self.emit_diagnostics) {
                std.debug.print("failed to convert selected type '{s}': {s}\n", .{ qual_type, @errorName(err) });
            }
            return err;
        };
        if (self.strict_types and parser.lookahead.kind != .eof) {
            if (self.emit_diagnostics) {
                std.debug.print(
                    "unconsumed type syntax in selected type '{s}' at '{s}'\n",
                    .{ qual_type, parser.lookahead.text },
                );
            }
            return error.UnconsumedTypeSyntax;
        }
        return result;
    }
};

// ------------------------------------------------------------------------------------------------

const prefixes = [_][]const u8{ "CA", "CF", "CG", "MTK", "MTLFX", "MTL", "NS", "CV" };

fn stringLessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

pub fn getNamespace(id: []const u8) []const u8 {
    if (std.mem.startsWith(u8, id, "MTL4FX")) return "MTLFX";
    if (std.mem.startsWith(u8, id, "MTL4")) return "MTL";
    for (prefixes) |prefix| {
        if (std.mem.startsWith(u8, id, prefix)) {
            return prefix;
        }
    }

    return &[_]u8{};
}

pub fn trimNamespace(id: []const u8) []const u8 {
    // Metal 4 and Metal 4 FX share files with their original API families. Preserve their
    // complete names so they remain valid and unambiguous Zig declarations.
    if (std.mem.startsWith(u8, id, "MTL4FX")) return id;
    if (std.mem.startsWith(u8, id, "MTL4")) return id;
    for (prefixes) |prefix| {
        if (std.mem.startsWith(u8, id, prefix)) {
            return id[prefix.len..];
        }
    }

    return id;
}

pub fn trimTrailingColon(id: []const u8) []const u8 {
    if (id.len == 0) {
        return id;
    } else if (id[id.len - 1] == ':') {
        return id[0 .. id.len - 1];
    } else {
        return id;
    }
}

fn isKeyword(id: []const u8) bool {
    if (std.mem.eql(u8, id, "error")) {
        return true;
    } else if (std.mem.eql(u8, id, "opaque")) {
        return true;
    } else if (std.mem.eql(u8, id, "type")) {
        return true;
    } else if (std.mem.eql(u8, id, "resume")) {
        return true;
    } else {
        return false;
    }
}

fn Generator(comptime WriterType: type) type {
    return struct {
        const Self = @This();
        const WriteError = WriterType.Error;
        const EnumList = std.array_list.Managed(*reg.Enum);
        const ContainerList = std.array_list.Managed(*reg.Container);
        const SelectorHashSet = std.StringHashMap(void);

        allocator: std.mem.Allocator,
        writer: *WriterType,
        manifest: *coverage.Manifest,
        enums: EnumList,
        containers: ContainerList,
        selectors: SelectorHashSet,
        /// Block typedefs referenced by an emitted method, collected during
        /// generation so that only aliases whose types were bound get emitted.
        block_typedefs: SelectorHashSet,
        /// Clang's layout for each hand-written record, used to assert that the
        /// hand-written Zig declaration still matches the SDK.
        record_layouts: []const RecordLayout,
        namespace: []const u8,
        allow_methods: []const [2][]const u8,

        fn init(
            allocator: std.mem.Allocator,
            writer: *WriterType,
            manifest: *coverage.Manifest,
        ) Self {
            return Self{
                .allocator = allocator,
                .writer = writer,
                .manifest = manifest,
                .enums = EnumList.init(allocator),
                .containers = ContainerList.init(allocator),
                .selectors = SelectorHashSet.init(allocator),
                .block_typedefs = SelectorHashSet.init(allocator),
                .record_layouts = &.{},
                .namespace = undefined,
                .allow_methods = undefined,
            };
        }

        fn deinit(self: *Self) void {
            self.enums.deinit();
            self.containers.deinit();
            self.selectors.deinit();
            self.block_typedefs.deinit();
        }

        pub fn addProtocol(self: *Self, name: []const u8) !void {
            const container = registry.protocols.get(name) orelse {
                std.debug.print("required protocol {s} not found\n", .{name});
                return error.MissingRequiredProtocol;
            };

            try self.addContainer(container);
            try self.manifest.markIfPresent(
                .protocol,
                name,
                .generated,
                "generated Objective-C protocol wrapper",
            );
        }

        pub fn addInterface(self: *Self, name: []const u8) !void {
            const container = registry.interfaces.get(name) orelse {
                std.debug.print("required interface {s} not found\n", .{name});
                return error.MissingRequiredInterface;
            };

            try self.addContainer(container);
            try self.manifest.markIfPresent(
                .interface,
                name,
                .generated,
                "generated Objective-C class wrapper",
            );
        }

        pub fn addEnum(self: *Self, name: []const u8) !void {
            const e = registry.enums.get(name) orelse {
                std.debug.print("required enum {s} not found\n", .{name});
                return error.MissingRequiredEnum;
            };

            try self.enums.append(e);
            try self.manifest.markIfPresent(.enum_decl, name, .generated, "generated enum values");
            try self.manifest.markIfPresent(.typedef, name, .generated, "generated as the enum underlying type alias");
        }

        pub fn addEnumsWithPrefix(self: *Self, prefix: []const u8) !void {
            var names: std.ArrayList([]const u8) = .empty;
            defer names.deinit(self.allocator);
            var iterator = registry.enums.keyIterator();
            while (iterator.next()) |name| {
                if (std.mem.startsWith(u8, name.*, prefix)) {
                    try names.append(self.allocator, name.*);
                }
            }
            std.sort.insertion([]const u8, names.items, {}, stringLessThan);
            for (names.items) |name| try self.addEnum(name);
        }

        pub fn addInterfacesWithPrefix(self: *Self, prefix: []const u8) !void {
            var names: std.ArrayList([]const u8) = .empty;
            defer names.deinit(self.allocator);
            var iterator = registry.interfaces.keyIterator();
            while (iterator.next()) |name| {
                const container = registry.interfaces.get(name.*).?;
                const is_forward_declaration = container.super == null and
                    container.methods.items.len == 0 and
                    container.properties.items.len == 0;
                if (std.mem.startsWith(u8, name.*, prefix) and !is_forward_declaration) {
                    try names.append(self.allocator, name.*);
                }
            }
            std.sort.insertion([]const u8, names.items, {}, stringLessThan);
            for (names.items) |name| try self.addInterface(name);
        }

        pub fn addProtocolsWithPrefix(self: *Self, prefix: []const u8) !void {
            var names: std.ArrayList([]const u8) = .empty;
            defer names.deinit(self.allocator);
            var iterator = registry.protocols.keyIterator();
            while (iterator.next()) |name| {
                if (std.mem.startsWith(u8, name.*, prefix)) {
                    try names.append(self.allocator, name.*);
                }
            }
            std.sort.insertion([]const u8, names.items, {}, stringLessThan);
            for (names.items) |name| try self.addProtocol(name);
        }

        fn addContainer(self: *Self, container: *Container) !void {
            try self.containers.append(container);

            for (container.methods.items) |method| {
                try self.selectors.put(method.name, {});
            }
        }

        const PendingContainer = struct {
            container: *Container,
            provenance: coverage.Provenance,
        };

        /// Error set of the closure walk.
        ///
        /// Written out rather than inferred because `markTypeClosure` and
        /// `markNamedType` are mutually recursive — a typedef resolves to a type
        /// which may name another typedef — and Zig cannot infer an error set
        /// through a dependency loop. It is the union of what the walk's callees
        /// produce: allocation for the queues and visited sets, and the manifest
        /// lookup.
        const ClosureError = std.mem.Allocator.Error || error{ManifestDeclarationNotFound};

        /// Mark every declaration reachable from the explicit selection list.
        ///
        /// Selecting a class selects what its public signatures mention:
        /// superclasses, adopted protocols, parameter and return types, property
        /// types, and whatever those resolve to through typedefs.
        /// `Manifest.finalize` turns anything reachable but unbound into a
        /// rejection, so this is the standing guard against adding an API and
        /// forgetting one of the types it depends on.
        ///
        /// Reachability here is a property of the type graph only. A record that
        /// callers fill in and copy into a buffer — an indirect draw argument
        /// struct, an acceleration structure instance descriptor — appears in no
        /// signature and cannot be discovered this way. Those must be named in
        /// the selection list.
        fn markSelectedClosure(self: *Self) !void {
            // Interfaces and protocols share a namespace of names in Metal, so
            // they need separate visited sets or one would mask the other.
            var visited_interfaces = std.StringHashMap(void).init(self.allocator);
            defer visited_interfaces.deinit();
            var visited_protocols = std.StringHashMap(void).init(self.allocator);
            defer visited_protocols.deinit();
            var visited_types = std.StringHashMap(void).init(self.allocator);
            defer visited_types.deinit();
            var queue = std.array_list.Managed(PendingContainer).init(self.allocator);
            defer queue.deinit();

            for (self.enums.items) |e| {
                _ = try self.manifest.selectIfPresent(.enum_decl, e.name, .explicit);
                _ = try self.manifest.selectIfPresent(.typedef, e.name, .explicit);
            }
            // Explicit containers are enqueued first so that breadth-first order
            // reaches them before anything can claim them as transitive.
            for (self.containers.items) |container| {
                try queue.append(.{ .container = container, .provenance = .explicit });
            }

            var index: usize = 0;
            while (index < queue.items.len) : (index += 1) {
                const pending = queue.items[index];
                const container = pending.container;
                const visited = if (container.is_interface)
                    &visited_interfaces
                else
                    &visited_protocols;
                if ((try visited.getOrPut(container.name)).found_existing) continue;

                // Containers reached from another framework are bound in that
                // framework's output. Every generated class has NSObject as its
                // superclass, and NSObject is hand-written in src/foundation.zig
                // as ObjectInterface/ObjectProtocol, so it is neither this
                // manifest's to generate nor detectable as manual by name.
                if (pending.provenance == .transitive_dependency and
                    !std.mem.eql(u8, getNamespace(container.name), self.namespace)) continue;

                const kind: coverage.DeclarationKind =
                    if (container.is_interface) .interface else .protocol;
                _ = try self.manifest.selectIfPresent(kind, container.name, pending.provenance);

                // The superclass is emitted as part of the wrapper, so it is a
                // genuine dependency. Adopted protocols are not: every generated
                // ExternClass and ExternProtocol carries an empty protocol list,
                // so following them would claim reachability the bindings do not
                // have. CALayer adopts CAMediaTiming without binding any of it.
                if (container.super) |super| {
                    try queue.append(.{ .container = super, .provenance = .transitive_dependency });
                }

                for (container.methods.items) |method| {
                    if (!try self.memberIsGenerated(.method, container.name, method.name)) continue;
                    try self.markTypeClosure(method.return_type, &queue, &visited_types);
                    for (method.params.items) |param| {
                        try self.markTypeClosure(param.ty, &queue, &visited_types);
                    }
                }
                for (container.properties.items) |property| {
                    if (!try self.memberIsGenerated(.property, container.name, property.name)) continue;
                    try self.markTypeClosure(property.ty, &queue, &visited_types);
                }
            }
        }

        /// Was this member actually emitted?
        ///
        /// Reachability has to follow the bindings, not the SDK. A container can
        /// declare far more than the generator emits — QuartzCore binds a handful
        /// of CALayer methods from an allowlist and excludes the rest — and
        /// walking an excluded declaration would drag its parameter types in as
        /// dependencies of a binding that does not exist. This runs after
        /// `generate`, so the manifest already knows what was emitted.
        fn memberIsGenerated(
            self: *Self,
            kind: coverage.DeclarationKind,
            container_name: []const u8,
            member_name: []const u8,
        ) !bool {
            const manifest_name = try std.fmt.allocPrint(
                self.allocator,
                "{s}.{s}",
                .{ container_name, member_name },
            );
            defer self.allocator.free(manifest_name);
            const status = self.manifest.statusOf(kind, manifest_name) orelse return false;
            return status == .generated;
        }

        fn markTypeClosure(
            self: *Self,
            ty: Type,
            queue: *std.array_list.Managed(PendingContainer),
            visited_types: *std.StringHashMap(void),
        ) ClosureError!void {
            switch (ty) {
                .name => |name| try self.markNamedType(name, queue, visited_types),
                .pointer => |pointer| try self.markTypeClosure(pointer.child.*, queue, visited_types),
                .array => |array| try self.markTypeClosure(array.child.*, queue, visited_types),
                .function => |function| {
                    try self.markTypeClosure(function.return_type.*, queue, visited_types);
                    for (function.params.items) |param| {
                        try self.markTypeClosure(param, queue, visited_types);
                    }
                },
                .generic => |generic| {
                    try self.markTypeClosure(generic.base_type.*, queue, visited_types);
                    for (generic.args.items) |arg| {
                        try self.markTypeClosure(arg, queue, visited_types);
                    }
                },
                else => {},
            }
        }

        fn markNamedType(
            self: *Self,
            name: []const u8,
            queue: *std.array_list.Managed(PendingContainer),
            visited_types: *std.StringHashMap(void),
        ) ClosureError!void {
            if ((try visited_types.getOrPut(name)).found_existing) return;

            // Names belonging to another framework are bound elsewhere and are
            // not this manifest's responsibility: Metal types referenced by
            // CAMetalLayer are emitted into metal.zig, and Foundation and
            // CoreGraphics types are hand-written in src/foundation.zig and
            // src/core_graphics.zig. This matters because QuartzCore's own
            // headers forward-declare `@protocol MTLDevice`, which puts it in the
            // QuartzCore inventory where it would otherwise look like an unbound
            // dependency. The same rule covers NSObject, whose Zig binding is
            // named ObjectInterface and so is invisible to manual-source
            // detection.
            if (!std.mem.eql(u8, getNamespace(name), self.namespace)) return;

            // One identifier can appear under several declaration kinds — an enum
            // and its typedef, an interface and a like-named protocol — so record
            // every kind this inventory knows it by.
            var known = false;
            const kinds = [_]coverage.DeclarationKind{
                .enum_decl,
                .typedef,
                .record,
                .interface,
                .protocol,
            };
            for (kinds) |kind| {
                if (try self.manifest.selectIfPresent(kind, name, .transitive_dependency)) {
                    known = true;
                }
            }

            // Stop at names this framework's inventory does not own. Their own
            // dependencies are somebody else's surface — Foundation types are
            // bound by hand in src/foundation.zig — and walking through them
            // would manufacture reachability that says nothing about this
            // framework.
            if (!known) return;

            if (registry.interfaces.get(name)) |container| {
                try queue.append(.{ .container = container, .provenance = .transitive_dependency });
            }
            if (registry.protocols.get(name)) |container| {
                try queue.append(.{ .container = container, .provenance = .transitive_dependency });
            }
            if (registry.typedefs.get(name)) |underlying| {
                try self.markTypeClosure(underlying, queue, visited_types);
            }
        }

        pub fn generate(self: *Self) !void {
            try self.generateEnumerations();
            try self.generateContainers();
            try self.generateBlockTypedefs();
            try self.generateRecordLayoutAssertions();
        }

        /// Assert every hand-written record's layout against Clang's.
        ///
        /// These structs are still declared by hand, so nothing but a check keeps
        /// them honest, and the failure mode is quiet: swapping two same-sized
        /// fields changes neither size nor alignment, and every call that passes
        /// one then reads the wrong member. Size alone would not catch it, which
        /// is why each field offset is asserted individually.
        ///
        /// The numbers come from Clang's own record layout dump rather than from
        /// a person reading a header, which is the whole point — a hand-written
        /// assertion of a hand-written layout proves nothing.
        fn generateRecordLayoutAssertions(self: *Self) !void {
            var verified: usize = 0;
            for (self.record_layouts) |layout| {
                // Only this framework's own records: another framework's are
                // declared in its output or in the shared hand-written modules,
                // and are not in scope here.
                if (!std.mem.eql(u8, getNamespace(layout.name), self.namespace)) continue;

                try self.writer.print("\n// {s}\ncomptime {{\n", .{layout.name});
                try self.writer.writeAll("    std.debug.assert(@sizeOf(");
                try self.generateTypeName(layout.name);
                try self.writer.print(") == {d});\n", .{layout.size});
                try self.writer.writeAll("    std.debug.assert(@alignOf(");
                try self.generateTypeName(layout.name);
                try self.writer.print(") == {d});\n", .{layout.alignment});
                for (layout.fields) |field| {
                    try self.writer.writeAll("    std.debug.assert(@offsetOf(");
                    try self.generateTypeName(layout.name);
                    try self.writer.print(", \"{s}\") == {d});\n", .{ field.name, field.offset });
                }
                try self.writer.writeAll("}\n");

                const reason = "manually maintained record; size, alignment and field offsets verified against Clang";
                try self.manifest.markIfPresent(.typedef, layout.name, .manual, reason);
                try self.manifest.markIfPresent(.record, layout.name, .manual, reason);
                verified += 1;
            }

            if (verified != 0) {
                std.log.info(
                    "{s}: verified {d} hand-written record layouts against Clang",
                    .{ self.manifest.framework, verified },
                );
            }
        }

        /// Emit a named alias for every block typedef an emitted method uses.
        ///
        /// Objective-C names its completion handlers — `MTLNewLibraryCompletionHandler`
        /// and the rest — but the generator expands them inline at each use, which
        /// leaves the typedef itself with no Zig declaration: usable API, but
        /// nothing a caller can spell, and an unbound declaration in the manifest.
        ///
        /// Only typedefs collected during generation are aliased, so an alias can
        /// never reference a type that was not bound. The alias includes the
        /// pointer because the Objective-C typedef names the block pointer type,
        /// and it is the same Zig type as the expanded form, so callers can use
        /// either spelling interchangeably.
        fn generateBlockTypedefs(self: *Self) !void {
            var names: std.ArrayList([]const u8) = .empty;
            defer names.deinit(self.allocator);
            var iterator = self.block_typedefs.keyIterator();
            while (iterator.next()) |name| try names.append(self.allocator, name.*);
            std.sort.insertion([]const u8, names.items, {}, stringLessThan);

            for (names.items) |name| {
                const function = switch (registry.typedefs.get(name) orelse continue) {
                    .function => |f| f,
                    else => continue,
                };
                try self.writer.writeAll("\npub const ");
                try self.generateTypeName(name);
                try self.writer.writeAll(" = *ns.Block(fn (");
                for (function.params.items, 0..) |param_ty, i| {
                    if (i > 0) try self.writer.writeAll(", ");
                    try self.generateType(param_ty);
                }
                try self.writer.writeAll(") ");
                try self.generateType(function.return_type.*);
                try self.writer.writeAll(");\n");
                try self.manifest.markIfPresent(
                    .typedef,
                    name,
                    .generated,
                    "generated Objective-C block type alias",
                );
            }
        }

        fn generateEnumerations(self: *Self) !void {
            for (self.enums.items) |e| {
                try self.writer.writeAll("\n");
                try self.writer.print("pub const ", .{});
                try self.generateTypeName(e.name);
                try self.writer.print(" = ", .{});
                try self.generateType(e.ty);
                try self.writer.print(";\n", .{});

                for (e.values.items) |v| {
                    try self.writer.print("pub const ", .{});
                    try self.generateTypeName(v.name);
                    try self.writer.print(": ", .{});
                    try self.generateTypeName(e.name);
                    if (v.is_max_uint) {
                        try self.writer.print(" = std.math.maxInt(", .{});
                        try self.generateType(e.ty);
                        try self.writer.print(");\n", .{});
                    } else {
                        try self.writer.print(" = {d};\n", .{v.value});
                    }
                }
            }
        }

        fn generateContainers(self: *Self) !void {
            for (self.containers.items) |container| {
                try self.generateContainer(container);
            }
        }

        fn generateContainer(self: *Self, container: *Container) !void {
            try self.writer.writeAll("\n");
            if (container.type_params.items.len > 0) {
                try self.writer.print("pub fn ", .{});
                try self.generateContainerName(container);
                try self.writer.print("(", .{});
                var first = true;
                for (container.type_params.items) |type_param| {
                    if (!first)
                        try self.writer.writeAll(", ");
                    first = false;
                    try self.writer.print("comptime {s}: type", .{type_param.name});
                }
                try self.writer.print(") type {{ return opaque {{\n", .{});
            } else {
                try self.writer.print("pub const ", .{});
                try self.generateContainerName(container);
                try self.writer.print(" = opaque {{\n", .{});
            }
            if (container.is_interface) {
                try self.writer.print("    pub const InternalInfo = objc.ExternClass(\"{s}\", @This(), ", .{
                    container.name,
                });
                if (container.super) |super| {
                    try self.generateContainerName(super);
                } else {
                    try self.writer.writeAll("objc.Id");
                }
                try self.writer.writeAll(", &.{");
            } else {
                try self.writer.print("    pub const InternalInfo = objc.ExternProtocol(\"{s}\", @This(), &.{{", .{
                    container.name,
                });
            }
            var first = true;
            for (container.protocols.items) |protocol| {
                // TODO: optimize this O(n) lookup. We don't want to create references to protocols
                // we don't generate, but this isn't a great way to do it. I plan on reworking the
                // container generation code to take other frameworks into account so things like
                // app_kit.zig doesn't duplicate NSObject (for example). Once that is done it will
                // be easier to do an O(1) global symbol lookup across all frameworks.
                for (self.containers.items) |c| {
                    if (std.mem.eql(u8, c.name, protocol.name)) {
                        if (!first) try self.writer.writeAll(", ");
                        first = false;
                        try self.generateContainerName(protocol);
                    }
                }
            }
            try self.writer.writeAll("});\n");
            try self.writer.writeAll("    pub const as = InternalInfo.as;\n");
            try self.writer.writeAll("    pub const retain = InternalInfo.retain;\n");
            try self.writer.writeAll("    pub const release = InternalInfo.release;\n");
            try self.writer.writeAll("    pub const autorelease = InternalInfo.autorelease;\n");

            if (container.is_interface and self.doesParentHaveMethod(container, "init")) {
                // TODO: check if the type (or one of its parents) marks new/alloc/init as NS_UNAVAILABLE.
                try self.writer.writeAll("    pub const new = InternalInfo.new;\n");
                try self.writer.writeAll("    pub const alloc = InternalInfo.alloc;\n");
                try self.writer.writeAll("    pub const allocInit = InternalInfo.allocInit;\n");
            }
            try self.writer.writeByte('\n');

            // Track method names we've already emitted for this container so that duplicate
            // ObjCMethodDecls (e.g. a property getter declared both as @property and as a
            // separate method) don't produce duplicate Zig declarations. We dedupe by selector
            // + instance/class flag, since a class method and instance method with the same
            // selector can coexist (handled via the T_ prefix in `generateMethod`).
            var seen = std.array_list.Managed([]const u8).init(self.allocator);
            defer seen.deinit();
            method_loop: for (container.methods.items) |method| {
                const key = try std.fmt.allocPrint(self.allocator, "{s}|{}", .{ method.name, method.instance });
                defer self.allocator.free(key);
                for (seen.items) |s| if (std.mem.eql(u8, s, key)) continue :method_loop;
                try seen.append(try self.allocator.dupe(u8, key));
                try self.generateMethod(container, method);
            }
            for (seen.items) |s| self.allocator.free(s);

            for (container.properties.items) |property| {
                const property_name = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}.{s}",
                    .{ container.name, property.name },
                );
                defer self.allocator.free(property_name);
                const accessor_status = try self.propertyAccessorStatus(container, property);
                if (accessor_status) |status| {
                    switch (status) {
                        .generated => try self.manifest.markIfPresent(
                            .property,
                            property_name,
                            .generated,
                            "represented by generated Objective-C accessor methods",
                        ),
                        .excluded => try self.manifest.markIfPresent(
                            .property,
                            property_name,
                            .excluded,
                            "Objective-C property accessors are outside the selected binding surface",
                        ),
                        .rejected => try self.manifest.markIfPresent(
                            .property,
                            property_name,
                            .rejected,
                            "selected Objective-C property accessors are not represented safely",
                        ),
                        .unclassified, .manual => {},
                    }
                }
            }

            try self.writer.print("}};\n", .{});
            if (container.type_params.items.len > 0) {
                try self.writer.print("}}\n", .{});
            }
        }

        fn isAllowedMethod(self: *Self, container: *Container, method: Method) bool {
            const generate_allowed_methods_only = blk: {
                for (self.allow_methods) |pair| {
                    if (std.mem.eql(u8, container.name, pair[0])) {
                        break :blk true;
                    }
                }
                break :blk false;
            };
            if (!generate_allowed_methods_only) return true;

            for (self.allow_methods) |pair| {
                if (std.mem.eql(u8, container.name, pair[0]) and std.mem.eql(u8, trimTrailingColon(method.name), pair[1])) {
                    return true;
                }
            }
            return false;
        }

        /// Classify a property by the accessors that actually represent it.
        ///
        /// A property is never emitted directly; it is bound through its getter
        /// and setter. Resolving it against its real accessors is what keeps a
        /// property whose getter was generated correctly from being reported as
        /// unrepresented.
        fn propertyAccessorStatus(
            self: *Self,
            container: *Container,
            property: Property,
        ) !?coverage.Status {
            const accessors = try findPropertyAccessors(self.allocator, container, property);
            defer self.allocator.free(accessors);

            var result: ?coverage.Status = null;
            for (accessors) |selector| {
                const manifest_name = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}.{s}",
                    .{ container.name, selector },
                );
                defer self.allocator.free(manifest_name);
                const status = self.manifest.statusOf(.method, manifest_name) orelse continue;
                // One represented accessor is enough to represent the property.
                if (status == .generated) return .generated;
                if (result == null or status == .rejected) result = status;
            }
            return result;
        }

        fn generateMethod(self: *Self, container: *Container, method: Method) !void {
            const manifest_name = try std.fmt.allocPrint(
                self.allocator,
                "{s}.{s}",
                .{ container.name, method.name },
            );
            defer self.allocator.free(manifest_name);

            if (!self.isAllowedMethod(container, method)) {
                try self.manifest.markIfPresent(
                    .method,
                    manifest_name,
                    .excluded,
                    "method excluded by the audited framework method allowlist",
                );
                return;
            }
            if (container.super) |super| {
                if (self.doesParentHaveMethod(super, method.name)) {
                    try self.manifest.markIfPresent(
                        .method,
                        manifest_name,
                        .excluded,
                        "duplicate inherited method omitted from this wrapper",
                    );
                    return;
                }
            }

            // Class 'type methods' and 'self methods' can have naming conflicts, e.g. NSCursor pop()
            // which takes a self parameter and NSCursor pop() which is a type method. We prefix the
            // type method one with 'T_' only if there would be a conflict.
            const nameConflict = blk: {
                var count: usize = 0;
                for (container.methods.items) |m| {
                    if (std.mem.eql(u8, m.name, method.name)) count += 1;
                    if (count >= 2) break :blk true;
                }
                break :blk false;
            };
            var name = method.name;
            if (nameConflict and !method.instance) {
                const new_name = try self.allocator.alloc(u8, method.name.len + 2);
                @memcpy(new_name[2..], method.name);
                new_name[0] = 'T';
                new_name[1] = '_';
                name = new_name;
            }

            try self.writer.writeAll("    pub fn ");
            try self.generateMethodName(name);
            try self.writer.print("(", .{});
            try self.generateMethodParams(method);
            try self.writer.print(") ", .{});
            try self.generateType(method.return_type);
            try self.writer.print(" {{\n", .{});
            try self.writer.writeAll("                return objc.msgSend(");
            try self.generateMethodArgs(method);
            try self.writer.print(");\n", .{});
            try self.writer.print("    }}\n", .{});
            try self.manifest.markIfPresent(
                .method,
                manifest_name,
                .generated,
                "generated typed Objective-C message wrapper",
            );
        }

        fn doesParentHaveMethod(self: *Self, container: *Container, name: []const u8) bool {
            if (container.super) |super| {
                if (self.doesParentHaveMethod(super, name))
                    return true;
            }

            for (container.methods.items) |method| {
                if (std.mem.eql(u8, method.name, name))
                    return true;
            }

            return false;
        }

        fn generateMethodName(self: *Self, name: []const u8) !void {
            if (isKeyword(name)) {
                try self.writer.print("@\"{s}\"", .{name});
            } else {
                try self.generateSelectorName(trimTrailingColon(name));
            }
        }

        fn generateMethodParams(self: *Self, method: Method) !void {
            var first = true;
            if (method.instance) {
                try self.writer.print("self_: *@This()", .{});
                first = false;
            }
            for (method.params.items) |param| {
                if (!first)
                    try self.writer.writeAll(", ");
                first = false;
                try self.generateMethodParam(param);
            }
        }

        fn generateMethodParam(self: *Self, param: Param) !void {
            if (getBlockType(param)) |f| {
                // Remember the named typedef so an alias can be emitted for it.
                // A block written inline in the signature has no name to alias.
                switch (param.ty) {
                    .name => |name| try self.block_typedefs.put(name, {}),
                    else => {},
                }
                try self.writer.print("{s}_: *ns.Block(fn (", .{param.name});
                var first = true;
                for (f.params.items) |param_ty| {
                    if (!first) try self.writer.writeAll(", ");
                    first = false;
                    try self.generateType(param_ty);
                }
                try self.writer.writeAll(") ");
                try self.generateType(f.return_type.*);
                try self.writer.writeByte(')');
            } else {
                try self.writer.print("{s}_: ", .{param.name});
                try self.generateType(param.ty);
            }
        }

        fn generateMethodArgs(self: *Self, method: Method) !void {
            if (method.instance) {
                try self.writer.print("self_", .{});
            } else {
                try self.writer.print("@This().InternalInfo.class()", .{});
            }
            try self.writer.print(", \"{s}\", ", .{method.name});
            try self.generateType(method.return_type);
            try self.writer.writeAll(", .{");
            for (method.params.items, 0..) |param, i| {
                if (i != 0) try self.writer.writeAll(", ");
                try self.writer.print("{s}_", .{param.name});
            }
            try self.writer.writeAll("}");
        }

        fn getBlockType(param: Param) ?Type.Function {
            switch (param.ty) {
                .name => |s| {
                    if (registry.typedefs.get(s)) |t| {
                        return switch (t) {
                            .function => |f| f,
                            else => null,
                        };
                    }
                },
                .function => |f| return f,
                else => return null,
            }
            return null;
        }

        fn generateSelectorName(self: *Self, name: []const u8) !void {
            for (name) |ch| {
                if (ch == ':') {
                    try self.writer.writeByte('_');
                } else {
                    try self.writer.writeByte(ch);
                }
            }
        }

        fn generateType(self: *Self, ty: Type) WriteError!void {
            switch (ty) {
                .void => {
                    try self.writer.writeAll("void");
                },
                .bool => {
                    try self.writer.writeAll("bool");
                },
                .int => |bits| {
                    try self.writer.print("i{d}", .{bits});
                },
                .uint => |bits| {
                    try self.writer.print("u{d}", .{bits});
                },
                .float => |bits| {
                    try self.writer.print("f{d}", .{bits});
                },
                .c_short => {
                    try self.writer.writeAll("c_short");
                },
                .c_ushort => {
                    try self.writer.writeAll("c_ushort");
                },
                .c_int => {
                    try self.writer.writeAll("c_int");
                },
                .c_uint => {
                    try self.writer.writeAll("c_uint");
                },
                .c_long => {
                    try self.writer.writeAll("c_long");
                },
                .c_ulong => {
                    try self.writer.writeAll("c_ulong");
                },
                .c_longlong => {
                    try self.writer.writeAll("c_longlong");
                },
                .c_ulonglong => {
                    try self.writer.writeAll("c_ulonglong");
                },
                .name => |n| {
                    try self.generateTypeName(n);
                },
                .array => |a| {
                    try self.writer.print("[{d}]", .{a.len});
                    try self.generateType(a.child.*);
                },
                .instance_type => {
                    try self.writer.writeAll("@This()");
                },
                .pointer => |p| {
                    if (p.is_optional)
                        try self.writer.writeAll("?");
                    if (p.is_single or p.is_optional) {
                        try self.writer.writeAll("*");
                    } else {
                        //try self.writer.writeAll("[*c]");
                        try self.writer.writeAll("*");
                    }
                    if (p.is_const)
                        try self.writer.writeAll("const ");
                    if (p.child.* == .void) {
                        try self.writer.writeAll("anyopaque");
                    } else {
                        try self.generateType(p.child.*);
                    }
                },
                .function => |f| {
                    try self.writer.writeAll("fn (");
                    for (f.params.items, 0..) |param_ty, i| {
                        if (i > 0)
                            try self.writer.writeAll(", ");
                        try self.generateType(param_ty);
                    }
                    try self.writer.writeAll(") callconv(.c) ");
                    try self.generateType(f.return_type.*);
                },
                .generic => |g| {
                    // Generic types (like Dictionary(K,V), Array(T)) are defined as
                    // functions in foundation.zig, so always qualify with namespace
                    // prefix to avoid resolving to a local non-generic opaque type.
                    switch (g.base_type.*) {
                        .name => |n| {
                            const namespace = getNamespace(n);
                            if (namespace.len > 0) {
                                try self.generateLower(namespace);
                                try self.writer.writeAll(".");
                            }
                            try self.writer.writeAll(trimNamespace(n));
                        },
                        else => try self.generateType(g.base_type.*),
                    }
                    try self.writer.writeAll("(");
                    for (g.args.items, 0..) |arg, i| {
                        if (i > 0)
                            try self.writer.writeAll(", ");
                        try self.generateType(arg);
                    }
                    try self.writer.writeAll(")");
                },
            }
        }

        fn generateTypePrefix(self: *Self, name: []const u8) !void {
            // If this type is locally added to the current file (e.g. NSObject when generating
            // UIKit), reference it without a foreign-namespace prefix even though its canonical
            // namespace differs from this file's. Otherwise we'd emit `ns.ObjectInterface = ...`
            // as a declaration, which is a syntax error.
            if (self.isLocallyDefined(name)) return;

            const namespace = getNamespace(name);
            if (namespace.len > 0 and !std.mem.eql(u8, namespace, self.namespace)) {
                try self.generateLower(namespace);
                try self.writer.writeAll(".");
            }
        }

        fn isLocallyDefined(self: *Self, name: []const u8) bool {
            for (self.containers.items) |c| if (std.mem.eql(u8, c.name, name)) return true;
            for (self.enums.items) |e| if (std.mem.eql(u8, e.name, name)) return true;
            return false;
        }

        fn generateContainerSuffix(self: *Self, container: *Container) !void {
            if (container.ambiguous) {
                if (container.is_interface) {
                    try self.writer.writeAll("Interface");
                } else {
                    try self.writer.writeAll("Protocol");
                }
            }
        }

        fn generateTypeName(self: *Self, name: []const u8) !void {
            try self.generateTypePrefix(name);
            try self.writer.writeAll(trimNamespace(name));
            if (registry.protocols.get(name)) |container| {
                try self.generateContainerSuffix(container);
            } else if (registry.interfaces.get(name)) |container| {
                try self.generateContainerSuffix(container);
            }
        }

        fn generateContainerName(self: *Self, container: *Container) !void {
            try self.generateTypePrefix(container.name);
            try self.writer.writeAll(trimNamespace(container.name));
            try self.generateContainerSuffix(container);
        }

        fn isExternalContainerName(self: *Self, container: *Container) bool {
            const namespace = getNamespace(container.name);
            if (namespace.len > 0 and !std.mem.eql(u8, namespace, self.namespace)) {
                return true;
            }
            return false;
        }

        fn generateLower(self: *Self, str: []const u8) !void {
            for (str) |ch| {
                try self.writer.writeByte(std.ascii.toLower(ch));
            }
        }
    };
}

// ------------------------------------------------------------------------------------------------

fn generateMetal(generator: anytype) !void {
    generator.namespace = "MTL";
    generator.allow_methods = &.{};

    try generator.addEnumsWithPrefix("MTL");
    try generator.addInterfacesWithPrefix("MTL");
    try generator.addProtocolsWithPrefix("MTL");
}

fn generateMetalLegacy(generator: anytype) !void {
    generator.namespace = "MTL";
    generator.allow_methods = &.{};

    // MTLAccelerationStructure
    try generator.addEnum("MTLAccelerationStructureUsage");
    try generator.addEnum("MTLAccelerationStructureInstanceOptions");
    try generator.addInterface("MTLAccelerationStructureDescriptor");
    try generator.addInterface("MTLAccelerationStructureGeometryDescriptor");
    try generator.addEnum("MTLMotionBorderMode");
    try generator.addInterface("MTLPrimitiveAccelerationStructureDescriptor");
    try generator.addInterface("MTLAccelerationStructureTriangleGeometryDescriptor");
    try generator.addInterface("MTLAccelerationStructureBoundingBoxGeometryDescriptor");
    try generator.addInterface("MTLMotionKeyframeData");
    try generator.addInterface("MTLAccelerationStructureMotionTriangleGeometryDescriptor");
    try generator.addInterface("MTLAccelerationStructureMotionBoundingBoxGeometryDescriptor");
    //try generator.addStruct("MTLAccelerationStructureInstanceDescriptor");
    //try generator.addStruct("MTLAccelerationStructureUserIDInstanceDescriptor");
    try generator.addEnum("MTLAccelerationStructureInstanceDescriptorType");
    //try generator.addStruct("MTLAccelerationStructureMotionInstanceDescriptor");
    try generator.addInterface("MTLInstanceAccelerationStructureDescriptor");
    try generator.addProtocol("MTLAccelerationStructure");

    // MTLAccelerationStructureCommandEncoder
    try generator.addEnum("MTLAccelerationStructureRefitOptions");
    try generator.addProtocol("MTLAccelerationStructureCommandEncoder");
    try generator.addInterface("MTLAccelerationStructurePassSampleBufferAttachmentDescriptor");
    try generator.addInterface("MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray");
    try generator.addInterface("MTLAccelerationStructurePassDescriptor");

    // MTLAccelerationStructureTypes
    //try generator.addStruct("MTLPackedFloat3");
    //try generator.addStruct("MTLPackedFloat4x3");
    //try generator.addStruct("MTLAxisAlignedBoundingBox");

    // MTLArgument
    try generator.addEnum("MTLDataType");
    try generator.addEnum("MTLBindingType");
    try generator.addEnum("MTLArgumentType");
    try generator.addEnum("MTLBindingAccess");
    try generator.addInterface("MTLType");
    try generator.addInterface("MTLStructMember");
    try generator.addInterface("MTLStructType");
    try generator.addInterface("MTLArrayType");
    try generator.addInterface("MTLPointerType");
    try generator.addInterface("MTLTextureReferenceType");
    try generator.addInterface("MTLArgument");
    try generator.addProtocol("MTLBinding");
    try generator.addProtocol("MTLBufferBinding");
    try generator.addProtocol("MTLThreadgroupBinding");
    try generator.addProtocol("MTLTextureBinding");
    try generator.addProtocol("MTLObjectPayloadBinding");

    // MTLArgumentEncoder
    try generator.addProtocol("MTLArgumentEncoder");

    // MTLBinaryArchive
    try generator.addEnum("MTLBinaryArchiveError");
    try generator.addInterface("MTLBinaryArchiveDescriptor");
    try generator.addProtocol("MTLBinaryArchive");

    // MTLBlitCommandEncoder
    try generator.addEnum("MTLBlitOption");
    try generator.addProtocol("MTLBlitCommandEncoder");

    // MTLBlitPass
    try generator.addInterface("MTLBlitPassSampleBufferAttachmentDescriptor");
    try generator.addInterface("MTLBlitPassSampleBufferAttachmentDescriptorArray");
    try generator.addInterface("MTLBlitPassDescriptor");

    // MTLBuffer
    try generator.addProtocol("MTLBuffer");

    // MTLCaptureManager
    try generator.addEnum("MTLCaptureError");
    try generator.addEnum("MTLCaptureDestination");
    try generator.addInterface("MTLCaptureDescriptor");
    try generator.addInterface("MTLCaptureManager");

    // MTLCaptureScope
    try generator.addProtocol("MTLCaptureScope");

    // MTLCommandBuffer
    try generator.addEnum("MTLCommandBufferStatus");
    try generator.addEnum("MTLCommandBufferError");
    try generator.addEnum("MTLCommandBufferErrorOption");
    try generator.addEnum("MTLCommandEncoderErrorState");
    try generator.addInterface("MTLCommandBufferDescriptor");
    try generator.addProtocol("MTLCommandBufferEncoderInfo");
    try generator.addEnum("MTLDispatchType");
    //try generator.addType("MTLCommandBufferHandler");
    try generator.addProtocol("MTLCommandBuffer");

    // MTLCommandEncoder
    try generator.addEnum("MTLResourceUsage");
    try generator.addEnum("MTLBarrierScope");
    try generator.addProtocol("MTLCommandEncoder");

    // MTLCommandQueue
    try generator.addProtocol("MTLCommandQueue");

    // MTLComputeCommandEncoder
    //try generator.addStruct("MTLDispatchThreadgroupsIndirectArguments");
    //try generator.addStruct("MTLStageInRegionIndirectArguments");
    try generator.addProtocol("MTLComputeCommandEncoder");

    // MTLComputePass
    try generator.addInterface("MTLComputePassSampleBufferAttachmentDescriptor");
    try generator.addInterface("MTLComputePassSampleBufferAttachmentDescriptorArray");
    try generator.addInterface("MTLComputePassDescriptor");

    // MTLComputePipeline
    try generator.addInterface("MTLComputePipelineReflection");
    try generator.addInterface("MTLComputePipelineDescriptor");
    try generator.addProtocol("MTLComputePipelineState");

    // MTLCounters
    //try generator.addConst("MTLCounterErrorDomain");
    //try generator.addType("MTLCommonCounter");
    //try generator.addConst("MTLCommonCounterTimestamp");
    //try generator.addConst("MTLCommonCounterTessellationInputPatches");
    //try generator.addConst("MTLCommonCounterVertexInvocations");
    //try generator.addConst("MTLCommonCounterPostTessellationVertexInvocations");
    //try generator.addConst("MTLCommonCounterClipperInvocations");
    //try generator.addConst("MTLCommonCounterClipperPrimitivesOut");
    //try generator.addConst("MTLCommonCounterFragmentInvocations");
    //try generator.addConst("MTLCommonCounterFragmentsPassed");
    //try generator.addConst("MTLCommonCounterComputeKernelInvocations");
    //try generator.addConst("MTLCommonCounterTotalCycles");
    //try generator.addConst("MTLCommonCounterVertexCycles");
    //try generator.addConst("MTLCommonCounterTessellationCycles");
    //try generator.addConst("MTLCommonCounterPostTessellationVertexCycles");
    //try generator.addConst("MTLCommonCounterFragmentCycles");
    //try generator.addConst("MTLCommonCounterRenderTargetWriteCycles");
    //try generator.addType("MTLCommonCounterSet");
    //try generator.addConst("MTLCommonCounterSetTimestamp");
    //try generator.addConst("MTLCommonCounterSetStageUtilization");
    //try generator.addConst("MTLCommonCounterSetStatistic");
    //try generator.addStruct("MTLCounterResultTimestamp");
    //try generator.addStruct("MTLCounterResultStageUtilization");
    //try generator.addStruct("MTLCounterResultStatistic");
    try generator.addProtocol("MTLCounter");
    try generator.addProtocol("MTLCounterSet");
    try generator.addInterface("MTLCounterSampleBufferDescriptor");
    try generator.addProtocol("MTLCounterSampleBuffer");
    try generator.addEnum("MTLCounterSampleBufferError");

    // MTLDepthStencil
    try generator.addEnum("MTLCompareFunction");
    try generator.addEnum("MTLStencilOperation");
    try generator.addInterface("MTLStencilDescriptor");
    try generator.addInterface("MTLDepthStencilDescriptor");
    try generator.addProtocol("MTLDepthStencilState");

    // MTLDevice
    try generator.addInterface("MTLArchitecture");
    try generator.addEnum("MTLIOCompressionMethod");
    try generator.addEnum("MTLFeatureSet");
    try generator.addEnum("MTLGPUFamily");
    try generator.addEnum("MTLDeviceLocation");
    try generator.addEnum("MTLPipelineOption");
    try generator.addEnum("MTLReadWriteTextureTier");
    try generator.addEnum("MTLArgumentBuffersTier");
    try generator.addEnum("MTLSparseTextureRegionAlignmentMode");
    try generator.addEnum("MTLSparsePageSize");
    // try generator.addStruct("MTLAccelerationStructureSizes");
    try generator.addEnum("MTLCounterSamplingPoint");
    // try generator.addStruct("MTLSizeAndAlign");
    try generator.addInterface("MTLArgumentDescriptor");
    //try generator.addType("MTLDeviceNotificationName");
    //try generator.addConst("MTLDeviceWasAddedNotification");
    //try generator.addConst("MTLDeviceRemovalRequestedNotification));
    //try generator.addConst("MTLDeviceWasRemovedNotification));
    //try generator.addType("MTLDeviceNotificationHandlerBlock");
    //try generator.addType("MTLAutoreleasedComputePipelineReflection");
    //try generator.addType("MTLAutoreleasedRenderPipelineReflection");
    //try generator.addType("MTLNewLibraryCompletionHandler");
    //try generator.addType("MTLNewRenderPipelineStateCompletionHandler");
    //try generator.addType("MTLNewRenderPipelineStateWithReflectionCompletionHandler");
    //try generator.addType("MTLNewComputePipelineStateCompletionHandler");
    //try generator.addType("MTLNewComputePipelineStateWithReflectionCompletionHandler");
    //try generator.addType("MTLTimestamp");
    //try generator.addFunction("MTLCreateSystemDefaultDevice");
    //try generator.addFunction("MTLCopyAllDevices");
    //try generator.addFunction("MTLCopyAllDevicesWithObserver");
    //try generator.addFunction("MTLRemoveDeviceObserver");
    try generator.addProtocol("MTLDevice");

    // MTLDrawable
    //try generator.addType("MTLDrawablePresentedHandler");
    try generator.addProtocol("MTLDrawable");

    // MTLDynamicLibrary
    try generator.addEnum("MTLDynamicLibraryError");
    try generator.addProtocol("MTLDynamicLibrary");

    // MTLEvent
    try generator.addProtocol("MTLEvent");
    try generator.addInterface("MTLSharedEventListener");
    // try generator.addType("MTLSharedEventNotificationBlock");
    try generator.addProtocol("MTLSharedEvent");
    try generator.addInterface("MTLSharedEventHandle");
    // try generator.addStruct("MTLSharedEventHandlePrivate");

    // MTLFence
    try generator.addProtocol("MTLFence");

    // MTLFunctionConstantValues
    try generator.addInterface("MTLFunctionConstantValues");

    // MTLFunctionDescriptor
    try generator.addEnum("MTLFunctionOptions");
    try generator.addInterface("MTLFunctionDescriptor");
    try generator.addInterface("MTLIntersectionFunctionDescriptor");

    // MTLFunctionHandle
    try generator.addProtocol("MTLFunctionHandle");

    // MTLFunctionLog
    try generator.addEnum("MTLFunctionLogType");
    try generator.addProtocol("MTLLogContainer");
    try generator.addProtocol("MTLFunctionLogDebugLocation");
    try generator.addProtocol("MTLFunctionLog");

    // MTLFunctionStitching
    try generator.addProtocol("MTLFunctionStitchingAttribute");
    try generator.addInterface("MTLFunctionStitchingAttributeAlwaysInline");
    try generator.addProtocol("MTLFunctionStitchingNode");
    try generator.addInterface("MTLFunctionStitchingInputNode");
    try generator.addInterface("MTLFunctionStitchingFunctionNode");
    try generator.addInterface("MTLFunctionStitchingGraph");
    try generator.addInterface("MTLStitchedLibraryDescriptor");

    // MTLHeap
    try generator.addEnum("MTLHeapType");
    try generator.addInterface("MTLHeapDescriptor");
    try generator.addProtocol("MTLHeap");

    // MTLIndirectCommandBuffer
    try generator.addEnum("MTLIndirectCommandType");
    // try generator.addStruct("MTLIndirectCommandBufferExecutionRange");
    try generator.addInterface("MTLIndirectCommandBufferDescriptor");
    try generator.addProtocol("MTLIndirectCommandBuffer");

    // MTLIndirectCommandEncoder
    try generator.addProtocol("MTLIndirectRenderCommand");
    try generator.addProtocol("MTLIndirectComputeCommand");

    // MTLIntersectionFunctionTable
    try generator.addEnum("MTLIntersectionFunctionSignature");
    try generator.addInterface("MTLIntersectionFunctionTableDescriptor");
    try generator.addProtocol("MTLIntersectionFunctionTable");

    // MTLIOCommandBuffer
    try generator.addEnum("MTLIOStatus");
    //try generator.addType("MTLIOCommandBufferHandler");
    try generator.addProtocol("MTLIOCommandBuffer");

    // MTLIOCommandQueue
    try generator.addEnum("MTLIOPriority");
    try generator.addEnum("MTLIOCommandQueueType");
    //try generator.addConst("MTLIOErrorDomain");
    try generator.addEnum("MTLIOError");
    try generator.addProtocol("MTLIOCommandQueue");
    try generator.addProtocol("MTLIOScratchBuffer");
    try generator.addProtocol("MTLIOScratchBufferAllocator");
    try generator.addInterface("MTLIOCommandQueueDescriptor");
    try generator.addProtocol("MTLIOFileHandle");

    // MTLLibrary
    try generator.addEnum("MTLPatchType");
    try generator.addInterface("MTLVertexAttribute");
    try generator.addInterface("MTLAttribute");
    try generator.addEnum("MTLFunctionType");
    try generator.addInterface("MTLFunctionConstant");
    // try generator.addType("MTLAutoreleasedArgument");
    try generator.addProtocol("MTLFunction");
    try generator.addEnum("MTLLanguageVersion");
    try generator.addEnum("MTLLibraryType");
    try generator.addEnum("MTLLibraryOptimizationLevel");
    try generator.addEnum("MTLCompileSymbolVisibility");

    try generator.addInterface("MTLCompileOptions");
    try generator.addEnum("MTLLibraryError");
    try generator.addProtocol("MTLLibrary");

    // MTLLinkedFunctions
    try generator.addInterface("MTLLinkedFunctions");

    // MTLParallelRenderCommandEncoder
    try generator.addProtocol("MTLParallelRenderCommandEncoder");

    // MTLPipeline
    try generator.addEnum("MTLMutability");
    try generator.addInterface("MTLPipelineBufferDescriptor");
    try generator.addInterface("MTLPipelineBufferDescriptorArray");

    // MTLPixelFormat
    try generator.addEnum("MTLPixelFormat");

    // MTLRasterizationRate
    try generator.addInterface("MTLRasterizationRateSampleArray");
    try generator.addInterface("MTLRasterizationRateLayerDescriptor");
    try generator.addInterface("MTLRasterizationRateLayerArray");
    try generator.addInterface("MTLRasterizationRateMapDescriptor");
    try generator.addProtocol("MTLRasterizationRateMap");

    // MTLRenderCommandEncoder
    try generator.addEnum("MTLPrimitiveType");
    try generator.addEnum("MTLVisibilityResultMode");
    // try generator.addStruct("MTLScissorRect");
    // try generator.addStruct("MTLViewport");
    try generator.addEnum("MTLCullMode");
    try generator.addEnum("MTLWinding");
    try generator.addEnum("MTLDepthClipMode");
    try generator.addEnum("MTLTriangleFillMode");
    // try generator.addStruct("MTLDrawPrimitivesIndirectArguments");
    // try generator.addStruct("MTLDrawIndexedPrimitivesIndirectArguments");
    // try generator.addStruct("MTLVertexAmplificationViewMapping");
    // try generator.addStruct("MTLDrawPatchIndirectArguments");
    // try generator.addStruct("MTLQuadTessellationFactorsHalf");
    // try generator.addStruct("MTLTriangleTessellationFactorsHalf");
    try generator.addEnum("MTLRenderStages");
    try generator.addProtocol("MTLRenderCommandEncoder");

    // MTLRenderPass
    try generator.addEnum("MTLLoadAction");
    try generator.addEnum("MTLStoreAction");
    try generator.addEnum("MTLStoreActionOptions");
    // try generator.addStruct("MTLClearColor");
    try generator.addInterface("MTLRenderPassAttachmentDescriptor");
    try generator.addInterface("MTLRenderPassColorAttachmentDescriptor");
    try generator.addEnum("MTLMultisampleDepthResolveFilter");
    try generator.addInterface("MTLRenderPassDepthAttachmentDescriptor");
    try generator.addEnum("MTLMultisampleStencilResolveFilter");
    try generator.addInterface("MTLRenderPassStencilAttachmentDescriptor");
    try generator.addInterface("MTLRenderPassColorAttachmentDescriptorArray");
    try generator.addInterface("MTLRenderPassSampleBufferAttachmentDescriptor");
    try generator.addInterface("MTLRenderPassSampleBufferAttachmentDescriptorArray");
    try generator.addInterface("MTLRenderPassDescriptor");

    // MTLRenderPipeline
    try generator.addEnum("MTLBlendFactor");
    try generator.addEnum("MTLBlendOperation");
    try generator.addEnum("MTLColorWriteMask");
    try generator.addEnum("MTLPrimitiveTopologyClass");
    try generator.addEnum("MTLTessellationPartitionMode");
    try generator.addEnum("MTLTessellationFactorStepFunction");
    try generator.addEnum("MTLTessellationFactorFormat");
    try generator.addEnum("MTLTessellationControlPointIndexType");
    try generator.addInterface("MTLRenderPipelineColorAttachmentDescriptor");
    try generator.addInterface("MTLRenderPipelineReflection");
    try generator.addInterface("MTLRenderPipelineDescriptor");
    try generator.addInterface("MTLRenderPipelineFunctionsDescriptor");
    try generator.addProtocol("MTLRenderPipelineState");
    try generator.addInterface("MTLRenderPipelineColorAttachmentDescriptorArray");
    try generator.addInterface("MTLTileRenderPipelineColorAttachmentDescriptor");
    try generator.addInterface("MTLTileRenderPipelineColorAttachmentDescriptorArray");
    try generator.addInterface("MTLTileRenderPipelineDescriptor");
    try generator.addInterface("MTLMeshRenderPipelineDescriptor");

    // MTLResource
    try generator.addEnum("MTLPurgeableState");
    try generator.addEnum("MTLCPUCacheMode");
    try generator.addEnum("MTLStorageMode");
    try generator.addEnum("MTLHazardTrackingMode");
    try generator.addEnum("MTLResourceOptions");
    try generator.addProtocol("MTLResource");

    // MTLResourceStateCommandEncoder
    try generator.addEnum("MTLSparseTextureMappingMode");
    // try generator.addStruct("MTLMapIndirectArguments");
    try generator.addProtocol("MTLResourceStateCommandEncoder");

    // MTLResourceStatePass
    try generator.addInterface("MTLResourceStatePassSampleBufferAttachmentDescriptor");
    try generator.addInterface("MTLResourceStatePassSampleBufferAttachmentDescriptorArray");
    try generator.addInterface("MTLResourceStatePassDescriptor");

    // MTLSampler
    try generator.addEnum("MTLSamplerMinMagFilter");
    try generator.addEnum("MTLSamplerMipFilter");
    try generator.addEnum("MTLSamplerAddressMode");
    try generator.addEnum("MTLSamplerBorderColor");
    try generator.addInterface("MTLSamplerDescriptor");
    try generator.addProtocol("MTLSamplerState");

    // MTLStageInputOutputDescriptor
    try generator.addEnum("MTLAttributeFormat");
    try generator.addEnum("MTLIndexType");
    try generator.addEnum("MTLStepFunction");
    try generator.addInterface("MTLBufferLayoutDescriptor");
    try generator.addInterface("MTLBufferLayoutDescriptorArray");
    try generator.addInterface("MTLAttributeDescriptor");
    try generator.addInterface("MTLAttributeDescriptorArray");
    try generator.addInterface("MTLStageInputOutputDescriptor");

    // MTLTexture
    try generator.addEnum("MTLTextureType");
    try generator.addEnum("MTLTextureSwizzle");
    // try generator.addStruct("MTLTextureSwizzleChannels");
    try generator.addInterface("MTLSharedTextureHandle");
    // try generator.addStruct("MTLSharedTextureHandlePrivate");
    try generator.addEnum("MTLTextureUsage");
    try generator.addEnum("MTLTextureCompressionType");
    try generator.addInterface("MTLTextureDescriptor");
    try generator.addProtocol("MTLTexture");

    // MTLTypes
    // try generator.addStruct("MTLOrigin");
    // try generator.addStruct("MTLSize");
    // try generator.addStruct("MTLRegion");
    // try generator.addType("MTLCoordinate2D");
    // try generator.addStruct("MTLSamplePosition");

    // MTLVertexDescriptor
    try generator.addEnum("MTLVertexFormat");
    try generator.addEnum("MTLVertexStepFunction");
    try generator.addInterface("MTLVertexBufferLayoutDescriptor");
    try generator.addInterface("MTLVertexBufferLayoutDescriptorArray");
    try generator.addInterface("MTLVertexAttributeDescriptor");
    try generator.addInterface("MTLVertexAttributeDescriptorArray");
    try generator.addInterface("MTLVertexDescriptor");

    // MTLVisibleFunctionTable
    try generator.addInterface("MTLVisibleFunctionTableDescriptor");
    try generator.addProtocol("MTLVisibleFunctionTable");

    // Metal 4 is part of Metal.framework but uses a separate MTL4 prefix. Generate the complete
    // family from the selected SDK so the bindings track the Metal 4 surface shipped by Xcode.
    try generator.addEnumsWithPrefix("MTL4");
    try generator.addInterfacesWithPrefix("MTL4");
    try generator.addProtocolsWithPrefix("MTL4");
}

fn generateMetalFX(generator: anytype) !void {
    generator.namespace = "MTLFX";
    generator.allow_methods = &.{};

    try generator.addEnumsWithPrefix("MTLFX");
    try generator.addInterfacesWithPrefix("MTLFX");
    try generator.addProtocolsWithPrefix("MTLFX");
    try generator.addEnumsWithPrefix("MTL4FX");
    try generator.addInterfacesWithPrefix("MTL4FX");
    try generator.addProtocolsWithPrefix("MTL4FX");
}

fn generateAVFAudio(generator: anytype) !void {
    generator.namespace = "AV";
    generator.allow_methods = &.{};

    try generator.addEnum("AVAudioSessionCategoryOptions");
    try generator.addEnum("AVAudioSessionRouteSharingPolicy");
    try generator.addEnum("AVAudioSessionPortOverride");
    try generator.addEnum("AVAudioSessionRecordPermission");
    try generator.addEnum("AVAudioSessionSetActiveOptions");
    try generator.addEnum("AVAudioSessionActivationOptions");
    try generator.addEnum("AVAudioStereoOrientation");
    try generator.addEnum("AVAudioSessionPromptStyle");
    try generator.addEnum("AVAudioSessionIOType");

    try generator.addInterface("AVAudioSession");
    try generator.addInterface("AVAudioSessionPortDescription");
    try generator.addInterface("AVAudioSessionDataSourceDescription");
    try generator.addInterface("AVAudioSessionRouteDescription");
    try generator.addInterface("AVAudioSessionChannelDescription");

    try generator.addProtocol("AVAudioSessionDelegate");
}

fn generateCoreMIDI(generator: anytype) !void {
    generator.namespace = "MTL"; // TODO
    generator.allow_methods = &.{};

    // TODO: generate everything needed to replace https://github.com/hexops/mach/pull/1196/files#diff-0bf7b1323cd692a01ead7d43a082b7dec001f9b2fc0ded1b1c0bd6d750578456
}

fn generateCoreVideo(generator: anytype) !void {
    generator.namespace = "CV";
    generator.allow_methods = &.{
        //[2][]const u8{ "NS", "copy" },
    };
}

fn generateQuartzCore(generator: anytype) !void {
    generator.namespace = "CA";
    generator.allow_methods = &.{
        // CALayer
        [2][]const u8{ "CALayer", "setFrame" },
        [2][]const u8{ "CALayer", "contentsScale" },
        [2][]const u8{ "CALayer", "setContentsScale" },
        [2][]const u8{ "CALayer", "addSublayer" },
        [2][]const u8{ "CALayer", "setOpaque" },
        [2][]const u8{ "CALayer", "setOpacity" },

        // CAMetalLayer
        [2][]const u8{ "CAMetalLayer", "nextDrawable" },
        [2][]const u8{ "CAMetalLayer", "device" },
        [2][]const u8{ "CAMetalLayer", "setDevice" },
        [2][]const u8{ "CAMetalLayer", "preferredDevice" },
        [2][]const u8{ "CAMetalLayer", "pixelFormat" },
        [2][]const u8{ "CAMetalLayer", "setPixelFormat" },
        [2][]const u8{ "CAMetalLayer", "framebufferOnly" },
        [2][]const u8{ "CAMetalLayer", "setFramebufferOnly" },
        [2][]const u8{ "CAMetalLayer", "drawableSize" },
        [2][]const u8{ "CAMetalLayer", "setDrawableSize" },
        [2][]const u8{ "CAMetalLayer", "maximumDrawableCount" },
        [2][]const u8{ "CAMetalLayer", "setMaximumDrawableCount" },
        [2][]const u8{ "CAMetalLayer", "presentsWithTransaction" },
        [2][]const u8{ "CAMetalLayer", "setPresentsWithTransaction" },
        [2][]const u8{ "CAMetalLayer", "colorspace" },
        [2][]const u8{ "CAMetalLayer", "setColorspace" },
        [2][]const u8{ "CAMetalLayer", "wantsExtendedDynamicRangeContent" },
        [2][]const u8{ "CAMetalLayer", "setWantsExtendedDynamicRangeContent" },
        [2][]const u8{ "CAMetalLayer", "displaySyncEnabled" },
        [2][]const u8{ "CAMetalLayer", "setDisplaySyncEnabled" },
        [2][]const u8{ "CAMetalLayer", "allowsNextDrawableTimeout" },
        [2][]const u8{ "CAMetalLayer", "setAllowsNextDrawableTimeout" },

        // CAMetalDrawable
        [2][]const u8{ "CAMetalDrawable", "texture" },
        [2][]const u8{ "CAMetalDrawable", "layer" },
    };

    try generator.addInterface("CALayer");
    try generator.addInterface("CAMetalLayer");
    try generator.addProtocol("CAMetalDrawable");
}

fn generateAppKit(generator: anytype) !void {
    generator.namespace = "NS";
    generator.allow_methods = &.{
        // TODO: move to generateFoundation
        [2][]const u8{ "NSObject", "copy" },
        [2][]const u8{ "NSObject", "retainCount" },

        [2][]const u8{ "NSApplication", "sharedApplication" },
        [2][]const u8{ "NSApplication", "delegate" },
        [2][]const u8{ "NSApplication", "setDelegate" },
        [2][]const u8{ "NSApplication", "finishLaunching" },
        [2][]const u8{ "NSApplication", "run" },
        [2][]const u8{ "NSApplication", "setActivationPolicy" },
        [2][]const u8{ "NSApplication", "activateIgnoringOtherApps" },
        [2][]const u8{ "NSApplication", "nextEventMatchingMask:untilDate:inMode:dequeue" },
        [2][]const u8{ "NSApplication", "sendEvent" },
        [2][]const u8{ "NSApplication", "currentEvent" },
        [2][]const u8{ "NSApplication", "setMainMenu" },

        [2][]const u8{ "NSWindow", "initWithContentRect:styleMask:backing:defer:screen" },
        [2][]const u8{ "NSWindow", "isReleasedWhenClosed" },
        [2][]const u8{ "NSWindow", "setReleasedWhenClosed" },
        [2][]const u8{ "NSWindow", "contentView" },
        [2][]const u8{ "NSWindow", "isKeyWindow" },
        [2][]const u8{ "NSWindow", "isVisible" },
        [2][]const u8{ "NSWindow", "setIsVisible" },
        [2][]const u8{ "NSWindow", "makeKeyAndOrderFront" },
        [2][]const u8{ "NSWindow", "setDelegate" },
        [2][]const u8{ "NSWindow", "title" },
        [2][]const u8{ "NSWindow", "setTitle" },
        [2][]const u8{ "NSWindow", "contentRectForFrameRect" },
        [2][]const u8{ "NSWindow", "frameRectForContentRect" },
        [2][]const u8{ "NSWindow", "frame" },
        [2][]const u8{ "NSWindow", "setFrame:display:animate" },
        [2][]const u8{ "NSWindow", "setContentView" },
        [2][]const u8{ "NSWindow", "update" },
        [2][]const u8{ "NSWindow", "setMinSize" },
        [2][]const u8{ "NSWindow", "center" },
        [2][]const u8{ "NSWindow", "titlebarAppearsTransparent" },
        [2][]const u8{ "NSWindow", "setTitlebarAppearsTransparent" },
        [2][]const u8{ "NSWindow", "backgroundColor" },
        [2][]const u8{ "NSWindow", "setBackgroundColor" },
        [2][]const u8{ "NSWindow", "backingScaleFactor" },
        [2][]const u8{ "NSWindow", "setAppearance" },
        [2][]const u8{ "NSWindow", "sendEvent" },
        [2][]const u8{ "NSWindow", "screen" },

        [2][]const u8{ "NSCursor", "hide" },
        [2][]const u8{ "NSCursor", "unhide" },
        [2][]const u8{ "NSCursor", "pop" },

        [2][]const u8{ "NSCursor", "push" },
        [2][]const u8{ "NSCursor", "arrowCursor" },
        [2][]const u8{ "NSCursor", "IBeamCursor" },
        [2][]const u8{ "NSCursor", "pointingHandCursor" },
        [2][]const u8{ "NSCursor", "closedHandCursor" },
        [2][]const u8{ "NSCursor", "openHandCursor" },
        [2][]const u8{ "NSCursor", "resizeLeftCursor" },
        [2][]const u8{ "NSCursor", "resizeRightCursor" },
        [2][]const u8{ "NSCursor", "resizeLeftRightCursor" },
        [2][]const u8{ "NSCursor", "resizeUpCursor" },
        [2][]const u8{ "NSCursor", "resizeDownCursor" },
        [2][]const u8{ "NSCursor", "resizeUpDownCursor" },
        [2][]const u8{ "NSCursor", "crosshairCursor" },
        [2][]const u8{ "NSCursor", "operationNotAllowedCursor" },

        [2][]const u8{ "NSAppearance", "appearanceNamed" },

        [2][]const u8{ "NSMenu", "addItem" },
        [2][]const u8{ "NSMenu", "addItemWithTitle:action:keyEquivalent" },

        [2][]const u8{ "NSMenuItem", "setSubmenu" },
        [2][]const u8{ "NSMenuItem", "separatorItem" },

        [2][]const u8{ "NSWindowDelegate", "windowWillResize:toSize" },

        [2][]const u8{ "NSView", "layer" },
        [2][]const u8{ "NSView", "setLayer" },
        [2][]const u8{ "NSView", "setWantsLayer" },
        [2][]const u8{ "NSView", "initWithFrame" },
        [2][]const u8{ "NSView", "sendEvent" },
        [2][]const u8{ "NSView", "addSubview" },
        [2][]const u8{ "NSView", "setFrameOrigin" },
        [2][]const u8{ "NSView", "setFrameSize" },
        [2][]const u8{ "NSView", "setBoundsOrigin" },
        [2][]const u8{ "NSView", "setBoundsSize" },
        [2][]const u8{ "NSView", "window" },
        [2][]const u8{ "NSView", "bounds" },
        [2][]const u8{ "NSView", "visibleRect" },
        [2][]const u8{ "NSView", "addTrackingArea" },

        [2][]const u8{ "NSResponder", "interpretKeyEvents" },

        [2][]const u8{ "NSTrackingArea", "initWithRect:options:owner:userInfo" },
        [2][]const u8{ "NSTrackingArea", "rect" },
        [2][]const u8{ "NSTrackingArea", "options" },
        [2][]const u8{ "NSTrackingArea", "owner" },
        [2][]const u8{ "NSTrackingArea", "userInfo" },

        [2][]const u8{ "NSDate", "distantPast" },

        [2][]const u8{ "NSColor", "colorWithRed:green:blue:alpha" },

        [2][]const u8{ "NSResponder", "" },

        [2][]const u8{ "NSEvent", "keyCode" },
        [2][]const u8{ "NSEvent", "modifierFlags" },
        [2][]const u8{ "NSEvent", "isARepeat" },
        [2][]const u8{ "NSEvent", "locationInWindow" },
        [2][]const u8{ "NSEvent", "mouseLocation" },
        [2][]const u8{ "NSEvent", "pressedMouseButtons" },
        [2][]const u8{ "NSEvent", "buttonNumber" },
        [2][]const u8{ "NSEvent", "deltaX" },
        [2][]const u8{ "NSEvent", "deltaY" },
        [2][]const u8{ "NSEvent", "scrollingDeltaX" },
        [2][]const u8{ "NSEvent", "scrollingDeltaY" },
        [2][]const u8{ "NSEvent", "hasPreciseScrollingDeltas" },
        [2][]const u8{ "NSEvent", "magnification" },
        [2][]const u8{ "NSEvent", "phase" },
        [2][]const u8{ "NSEvent", "type" },
        [2][]const u8{ "NSEvent", "addLocalMonitorForEventsMatchingMask:handler" },
        [2][]const u8{ "NSEvent", "removeMonitor" },

        [2][]const u8{ "NSDate", "dateWithTimeIntervalSinceNow" },

        [2][]const u8{ "NSDictionary", "" },

        [2][]const u8{ "NSScreen", "screens" },
        [2][]const u8{ "NSScreen", "mainScreen" },
        [2][]const u8{ "NSScreen", "frame" },
        [2][]const u8{ "NSScreen", "maximumFramesPerSecond" },

        [2][]const u8{ "NSApplicationDelegate", "applicationDidFinishLaunching" },

        [2][]const u8{ "NSNotification", "object" },
        [2][]const u8{ "NSNotification", "name" },
    };

    // TODO: many things below can be removed and/or moved to generateFoundation
    // try generator.addInterface("INIntent");
    // try generator.addInterface("CKShareMetadata");

    try generator.addInterface("NSApplication");
    try generator.addInterface("NSResponder");
    // try generator.addInterface("NSRunningApplication");
    // try generator.addInterface("NSString");
    try generator.addInterface("NSWindow");
    try generator.addInterface("NSNotification");
    // try generator.addInterface("NSUserActivity");
    // try generator.addInterface("NSCoder");
    try generator.addInterface("NSDictionary");
    try generator.addInterface("NSMenu");
    try generator.addInterface("NSMenuItem");
    // try generator.addInterface("NSArray");
    // try generator.addInterface("NSURL");
    // try generator.addInterface("NSError");

    try generator.addInterface("NSObject");
    // try generator.addInterface("NSException");
    // try generator.addInterface("NSImage");
    // try generator.addInterface("NSDockTile");
    try generator.addInterface("NSAppearance");
    try generator.addInterface("NSEvent");
    try generator.addInterface("NSDate");
    // try generator.addInterface("NSGraphicsContext");
    // try generator.addInterface("NSDocument");
    // try generator.addInterface("NSData");
    // try generator.addInterface("NSFileWrapper");
    // try generator.addInterface("NSSavePanel");
    // try generator.addInterface("NSPageLayout");
    // try generator.addInterface("NSPrintInfo");
    // try generator.addInterface("NSMethodSignature");
    // try generator.addInterface("NSInvocation");
    // try generator.addInterface("NSPrinter");
    // try generator.addInterface("NSPDFInfo");
    // try generator.addInterface("NSMutableDictionary");
    // try generator.addInterface("NSTouchBar");
    // try generator.addInterface("NSOperationQueue");
    // try generator.addInterface("NSOperation");
    // try generator.addInterface("NSTouchBarItem");
    // try generator.addInterface("NSViewController");
    try generator.addInterface("NSView");
    // try generator.addInterface("NSArchiver");
    // try generator.addInterface("NSAttributedString");
    // try generator.addInterface("NSBitmapImageRep");
    // try generator.addInterface("NSBundle");
    // try generator.addInterface("NSButtonCell");
    // try generator.addInterface("NSCandidateListTouchBarItem");
    // try generator.addInterface("NSCharacterSet");
    // try generator.addInterface("NSClassDescription");
    // try generator.addInterface("NSClipView");
    // try generator.addInterface("NSCloseCommand");
    try generator.addInterface("NSColor");
    // try generator.addInterface("NSColorSpace");
    try generator.addInterface("NSCursor");
    // try generator.addInterface("NSDraggingItem");
    // try generator.addInterface("NSDrawer");
    // try generator.addInterface("NSEnumerator");
    // try generator.addInterface("NSFileManager");
    // try generator.addInterface("NSFileVersion");
    // try generator.addInterface("NSFont");
    // try generator.addInterface("NSFontPanel");
    // try generator.addInterface("NSGestureRecognizer");
    // try generator.addInterface("NSImageRep");
    // try generator.addInterface("NSImageSymbolConfiguration");
    // try generator.addInterface("NSIndexSet");
    // try generator.addInterface("NSInputStream");
    // try generator.addInterface("NSKeyedArchiver");
    // try generator.addInterface("NSLayoutConstraint");
    // try generator.addInterface("NSLayoutDimension");
    // try generator.addInterface("NSLayoutGuide");
    // try generator.addInterface("NSLayoutXAxisAnchor");
    // try generator.addInterface("NSLayoutYAxisAnchor");
    // try generator.addInterface("NSLocale");
    // try generator.addInterface("NSMutableArray");
    // try generator.addInterface("NSMutableOrderedSet");
    // try generator.addInterface("NSMutableSet");
    // try generator.addInterface("NSNumber");
    // try generator.addInterface("NSOrderedCollectionDifference");
    // try generator.addInterface("NSPanel");
    // try generator.addInterface("NSPasteboard");
    // try generator.addInterface("NSPortCoder");
    // try generator.addInterface("NSPredicate");
    // try generator.addInterface("NSPressureConfiguration");
    // try generator.addInterface("NSPrintOperation");
    // try generator.addInterface("NSProgress");
    // try generator.addInterface("NSRulerView");
    try generator.addInterface("NSScreen");
    // try generator.addInterface("NSScriptCommand");
    // try generator.addInterface("NSScriptObjectSpecifier");
    // try generator.addInterface("NSScrollView");
    // try generator.addInterface("NSSet");
    // try generator.addInterface("NSShadow");
    // try generator.addInterface("NSSharingService");
    // try generator.addInterface("NSSharingServicePicker");
    // try generator.addInterface("NSSortDescriptor");
    // try generator.addInterface("NSStoryboard");
    // try generator.addInterface("NSTableView");
    // try generator.addInterface("NSText");
    // try generator.addInterface("NSTextInputContext");
    // try generator.addInterface("NSThread");
    // try generator.addInterface("NSTimeZone");
    // try generator.addInterface("NSTitlebarAccessoryViewController");
    // try generator.addInterface("NSToolbar");
    // try generator.addInterface("NSToolbarItem");
    // try generator.addInterface("NSTouch");
    try generator.addInterface("NSTrackingArea");
    try generator.addEnum("NSTrackingAreaOptions");
    // try generator.addInterface("NSURLHandle");
    // try generator.addInterface("NSUndoManager");
    // try generator.addInterface("NSWindowController");
    // try generator.addInterface("NSWindowTab");
    // try generator.addInterface("NSWindowTabGroup");

    // try generator.addEnum("NSRequestUserAttentionType");
    // try generator.addEnum("NSWindowListOptions");
    // try generator.addEnum("NSApplicationDelegateReply");
    // try generator.addEnum("NSApplicationPresentationOptions");
    // try generator.addEnum("NSApplicationOcclusionState");
    try generator.addEnum("NSEventMask");
    // try generator.addEnum("NSRemoteNotificationType");
    // try generator.addEnum("NSUserInterfaceLayoutDirection");
    // try generator.addEnum("NSSaveOperationType");
    // try generator.addEnum("NSApplicationPrintReply");
    // try generator.addEnum("NSApplicationTerminateReply");
    // try generator.addEnum("NSPrintingPaginationMode");
    // try generator.addEnum("NSPaperOrientation");
    // try generator.addEnum("NSApplicationActivationOptions");
    // try generator.addEnum("NSStringCompareOptions");
    // try generator.addEnum("NSComparisonResult");
    // try generator.addEnum("NSQualityOfService");
    // try generator.addEnum("NSOperationQueuePriority");
    // try generator.addEnum("NSPrinterTableStatus");
    // try generator.addEnum("NSPageLayoutResult");
    // try generator.addEnum("NSAlignmentOptions");
    // try generator.addEnum("NSAutoresizingMaskOptions");
    try generator.addEnum("NSBackingStoreType");
    // try generator.addEnum("NSColorRenderingIntent");
    // try generator.addEnum("NSCompositingOperation");
    // try generator.addEnum("NSDataBase64DecodingOptions");
    // try generator.addEnum("NSDataBase64EncodingOptions");
    // try generator.addEnum("NSDataCompressionAlgorithm");
    // try generator.addEnum("NSDataReadingOptions");
    // try generator.addEnum("NSDataSearchOptions");
    // try generator.addEnum("NSDataWritingOptions");
    // try generator.addEnum("NSDecodingFailurePolicy");
    // try generator.addEnum("NSDisplayGamut");
    // try generator.addEnum("NSDocumentChangeType");
    // try generator.addEnum("NSDragOperation");
    // try generator.addEnum("NSEnumerationOptions");
    // try generator.addEnum("NSEventButtonMask");
    // try generator.addEnum("NSEventGestureAxis");
    try generator.addEnum("NSEventModifierFlags");
    try generator.addEnum("NSEventPhase");
    // try generator.addEnum("NSEventSubtype");
    // try generator.addEnum("NSEventSwipeTrackingOptions");
    try generator.addEnum("NSEventType");
    // try generator.addEnum("NSFileWrapperReadingOptions");
    // try generator.addEnum("NSFileWrapperWritingOptions");
    // try generator.addEnum("NSFocusRingType");
    // try generator.addEnum("NSImageCacheMode");
    // try generator.addEnum("NSImageInterpolation");
    // try generator.addEnum("NSImageResizingMode");
    // try generator.addEnum("NSKeyValueChange");
    // try generator.addEnum("NSKeyValueObservingOptions");
    // try generator.addEnum("NSKeyValueSetMutationKind");
    // try generator.addEnum("NSLayoutAttribute");
    // try generator.addEnum("NSLayoutConstraintOrientation");
    // try generator.addEnum("NSMenuPresentationStyle");
    // try generator.addEnum("NSMenuProperties");
    // try generator.addEnum("NSMenuSelectionMode");
    // try generator.addEnum("NSPointingDeviceType");
    // try generator.addEnum("NSPressureBehavior");
    // try generator.addEnum("NSRectEdge");
    // try generator.addEnum("NSSelectionDirection");
    // try generator.addEnum("NSSortOptions");
    // try generator.addEnum("NSStringDrawingOptions");
    // try generator.addEnum("NSStringEnumerationOptions");
    // try generator.addEnum("NSTIFFCompression");
    // try generator.addEnum("NSTouchPhase");
    // try generator.addEnum("NSTouchTypeMask");
    // try generator.addEnum("NSURLBookmarkCreationOptions");
    // try generator.addEnum("NSURLBookmarkResolutionOptions");
    // try generator.addEnum("NSViewControllerTransitionOptions");
    // try generator.addEnum("NSViewLayerContentsPlacement");
    // try generator.addEnum("NSViewLayerContentsRedrawPolicy");
    // try generator.addEnum("NSWindowAnimationBehavior");
    // try generator.addEnum("NSWindowBackingLocation");
    // try generator.addEnum("NSWindowButton");
    // try generator.addEnum("NSWindowCollectionBehavior");
    // try generator.addEnum("NSWindowDepth");
    // try generator.addEnum("NSWindowNumberListOptions");
    // try generator.addEnum("NSWindowOcclusionState");
    // try generator.addEnum("NSWindowOrderingMode");
    // try generator.addEnum("NSWindowSharingType");
    try generator.addEnum("NSWindowStyleMask");
    // try generator.addEnum("NSWindowTabbingMode");
    // try generator.addEnum("NSWindowTitleVisibility");
    // try generator.addEnum("NSWindowToolbarStyle");
    // try generator.addEnum("NSWindowUserTabbingPreference");

    // // alias
    // // try generator.addEnum("NSRangePointer");
    // // try generator.addEnum("NSTrackingRectTag");

    // // structs
    // // try generator.addEnum("NSFastEnumerationState");
    // // try generator.addEnum("NSAccessibility");
    // // try generator.addEnum("NSEdgeInsets");

    // // float
    // // try generator.addEnum("NSLayoutPriority");

    // // *String
    // // try generator.addEnum("NSAppearanceName");
    // // try generator.addEnum("NSBindingName");
    // // try generator.addEnum("NSAttributedStringKey");
    // // try generator.addEnum("NSGraphicsContextAttributeKey");
    // // try generator.addEnum("NSImageHintKey");
    // // try generator.addEnum("NSKeyValueChangeKey");
    // // try generator.addEnum("NSLinguisticTagScheme");

    try generator.addProtocol("NSApplicationDelegate");
    try generator.addProtocol("NSWindowDelegate");
    // try generator.addProtocol("NSUserActivityRestoring");
    // try generator.addProtocol("NSSecureCoding");
    // try generator.addProtocol("NSCopying");
    // try generator.addProtocol("NSUserInterfaceItemSearching");
    try generator.addProtocol("NSObject");
    // NSMenuItem is declared as both an @interface and an @protocol in AppKit, so it is
    // "ambiguous": type references resolve to MenuItemProtocol while methods live on
    // MenuItemInterface. Emit the protocol too so the MenuItemProtocol type exists.
    try generator.addProtocol("NSMenuItem");
    // try generator.addProtocol("NSCoding");
    // try generator.addProtocol("NSMutableCopying");
    // try generator.addProtocol("NSProgressReporting");
    // try generator.addProtocol("NSTouchBarDelegate");
    // try generator.addProtocol("NSAnimatablePropertyContainer");
    // try generator.addProtocol("NSMenuDelegate");
    // try generator.addProtocol("NSAppearanceCustomization");
    // try generator.addProtocol("NSDraggingDestination");
    // try generator.addProtocol("NSEditor");
    // try generator.addProtocol("NSImageDelegate");
    // try generator.addProtocol("NSPreviewRepresentableActivityItem");
}

fn generateUIKit(generator: anytype) !void {
    generator.namespace = "UI";
    generator.allow_methods = &.{
        // NSObject (TODO: move to generateFoundation)
        [2][]const u8{ "NSObject", "copy" },
        [2][]const u8{ "NSObject", "retainCount" },

        // UIApplication
        [2][]const u8{ "UIApplication", "sharedApplication" },
        [2][]const u8{ "UIApplication", "delegate" },
        [2][]const u8{ "UIApplication", "setDelegate" },

        // UIScreen
        [2][]const u8{ "UIScreen", "mainScreen" },
        [2][]const u8{ "UIScreen", "screens" },
        [2][]const u8{ "UIScreen", "bounds" },
        [2][]const u8{ "UIScreen", "nativeBounds" },
        [2][]const u8{ "UIScreen", "scale" },
        [2][]const u8{ "UIScreen", "nativeScale" },

        // UIWindow
        [2][]const u8{ "UIWindow", "initWithFrame" },
        [2][]const u8{ "UIWindow", "initWithWindowScene" },
        [2][]const u8{ "UIWindow", "windowScene" },
        [2][]const u8{ "UIWindow", "setWindowScene" },
        [2][]const u8{ "UIWindow", "rootViewController" },
        [2][]const u8{ "UIWindow", "setRootViewController" },
        [2][]const u8{ "UIWindow", "makeKeyAndVisible" },
        [2][]const u8{ "UIWindow", "isKeyWindow" },

        // UIView
        [2][]const u8{ "UIView", "initWithFrame" },
        [2][]const u8{ "UIView", "layer" },
        [2][]const u8{ "UIView", "bounds" },
        [2][]const u8{ "UIView", "setBounds" },
        [2][]const u8{ "UIView", "frame" },
        [2][]const u8{ "UIView", "setFrame" },
        [2][]const u8{ "UIView", "contentScaleFactor" },
        [2][]const u8{ "UIView", "setContentScaleFactor" },
        [2][]const u8{ "UIView", "backgroundColor" },
        [2][]const u8{ "UIView", "setBackgroundColor" },
        [2][]const u8{ "UIView", "isHidden" },
        [2][]const u8{ "UIView", "setHidden" },
        [2][]const u8{ "UIView", "setOpaque" },
        [2][]const u8{ "UIView", "isOpaque" },
        [2][]const u8{ "UIView", "addSubview" },
        [2][]const u8{ "UIView", "addGestureRecognizer" },
        [2][]const u8{ "UIView", "window" },
        [2][]const u8{ "UIView", "setNeedsDisplay" },
        [2][]const u8{ "UIView", "setNeedsLayout" },
        [2][]const u8{ "UIView", "layoutIfNeeded" },

        // UIViewController
        [2][]const u8{ "UIViewController", "view" },
        [2][]const u8{ "UIViewController", "setView" },

        // UIResponder
        [2][]const u8{ "UIResponder", "becomeFirstResponder" },
        [2][]const u8{ "UIResponder", "resignFirstResponder" },
        [2][]const u8{ "UIResponder", "canBecomeFirstResponder" },
        [2][]const u8{ "UIResponder", "nextResponder" },

        // UISceneConfiguration
        [2][]const u8{ "UISceneConfiguration", "initWithName:sessionRole" },
        [2][]const u8{ "UISceneConfiguration", "delegateClass" },
        [2][]const u8{ "UISceneConfiguration", "setDelegateClass" },

        // UIScene
        [2][]const u8{ "UIScene", "session" },
        [2][]const u8{ "UIScene", "activationState" },

        // UISceneSession
        [2][]const u8{ "UISceneSession", "role" },
        [2][]const u8{ "UISceneSession", "configuration" },

        // UIWindowScene
        [2][]const u8{ "UIWindowScene", "screen" },
        [2][]const u8{ "UIWindowScene", "windows" },

        // UITouch
        [2][]const u8{ "UITouch", "locationInView" },
        [2][]const u8{ "UITouch", "previousLocationInView" },
        [2][]const u8{ "UITouch", "phase" },
        [2][]const u8{ "UITouch", "timestamp" },
        [2][]const u8{ "UITouch", "tapCount" },
        [2][]const u8{ "UITouch", "force" },
        [2][]const u8{ "UITouch", "maximumPossibleForce" },
        [2][]const u8{ "UITouch", "type" },
        [2][]const u8{ "UITouch", "view" },
        [2][]const u8{ "UITouch", "window" },

        // UIEvent
        [2][]const u8{ "UIEvent", "timestamp" },
        [2][]const u8{ "UIEvent", "allTouches" },
        [2][]const u8{ "UIEvent", "type" },
        [2][]const u8{ "UIEvent", "subtype" },

        // UIPress / UIPressesEvent / UIKey
        [2][]const u8{ "UIPress", "phase" },
        [2][]const u8{ "UIPress", "type" },
        [2][]const u8{ "UIPress", "force" },
        [2][]const u8{ "UIPress", "key" },
        [2][]const u8{ "UIPressesEvent", "allPresses" },
        [2][]const u8{ "UIKey", "keyCode" },
        [2][]const u8{ "UIKey", "modifierFlags" },
        [2][]const u8{ "UIKey", "characters" },
        [2][]const u8{ "UIKey", "charactersIgnoringModifiers" },

        // UIGestureRecognizer
        [2][]const u8{ "UIGestureRecognizer", "initWithTarget:action" },
        [2][]const u8{ "UIGestureRecognizer", "state" },
        [2][]const u8{ "UIGestureRecognizer", "locationInView" },
        [2][]const u8{ "UIGestureRecognizer", "numberOfTouches" },

        // UIPinchGestureRecognizer
        [2][]const u8{ "UIPinchGestureRecognizer", "scale" },
        [2][]const u8{ "UIPinchGestureRecognizer", "setScale" },
        [2][]const u8{ "UIPinchGestureRecognizer", "velocity" },

        // UIColor
        [2][]const u8{ "UIColor", "blackColor" },
        [2][]const u8{ "UIColor", "whiteColor" },
        [2][]const u8{ "UIColor", "clearColor" },
        [2][]const u8{ "UIColor", "colorWithRed:green:blue:alpha" },

        // UIApplicationDelegate (selectors we plug into)
        [2][]const u8{ "UIApplicationDelegate", "application:didFinishLaunchingWithOptions" },
        [2][]const u8{ "UIApplicationDelegate", "application:configurationForConnectingSceneSession:options" },

        // UISceneDelegate / UIWindowSceneDelegate
        [2][]const u8{ "UISceneDelegate", "sceneDidBecomeActive" },
        [2][]const u8{ "UISceneDelegate", "sceneWillResignActive" },
        [2][]const u8{ "UISceneDelegate", "sceneWillEnterForeground" },
        [2][]const u8{ "UISceneDelegate", "sceneDidEnterBackground" },
        [2][]const u8{ "UIWindowSceneDelegate", "scene:willConnectToSession:options" },
    };

    try generator.addInterface("NSObject");

    // Application / scene
    try generator.addInterface("UIApplication");
    try generator.addInterface("UIResponder");
    try generator.addInterface("UIScene");
    try generator.addInterface("UISceneConfiguration");
    try generator.addInterface("UISceneSession");
    try generator.addInterface("UIWindowScene");

    // Window / view / controller
    try generator.addInterface("UIScreen");
    try generator.addInterface("UIWindow");
    try generator.addInterface("UIView");
    try generator.addInterface("UIViewController");

    // Input
    try generator.addInterface("UITouch");
    try generator.addInterface("UIEvent");
    try generator.addInterface("UIPress");
    try generator.addInterface("UIPressesEvent");
    try generator.addInterface("UIKey");

    // Gesture recognizers
    try generator.addInterface("UIGestureRecognizer");
    try generator.addInterface("UIPinchGestureRecognizer");

    // Color
    try generator.addInterface("UIColor");

    // Enums
    try generator.addEnum("UITouchPhase");
    try generator.addEnum("UITouchType");
    try generator.addEnum("UIPressPhase");
    try generator.addEnum("UIPressType");
    try generator.addEnum("UIEventType");
    try generator.addEnum("UIEventSubtype");
    try generator.addEnum("UISceneActivationState");
    try generator.addEnum("UIInterfaceOrientation");
    try generator.addEnum("UIInterfaceOrientationMask");
    try generator.addEnum("UIKeyboardHIDUsage");
    try generator.addEnum("UIKeyModifierFlags");
    try generator.addEnum("UIGestureRecognizerState");

    // Protocols
    try generator.addProtocol("UIApplicationDelegate");
    try generator.addProtocol("UISceneDelegate");
    try generator.addProtocol("UIWindowSceneDelegate");
    try generator.addProtocol("NSObject");
}

const FieldLayout = struct {
    name: []const u8,
    /// Byte offset from the start of the record.
    offset: u64,
};

const RecordLayout = struct {
    name: []const u8,
    size: u64,
    alignment: u64,
    fields: []const FieldLayout,
};

fn parseLabelledInteger(text: []const u8, label: []const u8) !u64 {
    const start = std.mem.indexOf(u8, text, label) orelse return error.MalformedRecordLayout;
    var index = start + label.len;
    const begin = index;
    while (index < text.len and std.ascii.isDigit(text[index])) index += 1;
    if (index == begin) return error.MalformedRecordLayout;
    return std.fmt.parseInt(u64, text[begin..index], 10);
}

fn lastToken(text: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, text, " ");
    if (trimmed.len == 0) return null;
    const space = std.mem.lastIndexOfScalar(u8, trimmed, ' ') orelse return trimmed;
    return trimmed[space + 1 ..];
}

/// Strip the tag keyword Clang prints before a named record.
///
/// A record the SDK declares with a tag dumps as `struct MTLResourceID`, while
/// one reachable only through a typedef dumps under the typedef name. Both refer
/// to the same declaration as far as the manifest is concerned.
fn stripRecordTagKeyword(name: []const u8) []const u8 {
    const keywords = [_][]const u8{ "struct ", "union ", "class " };
    for (keywords) |keyword| {
        if (std.mem.startsWith(u8, name, keyword)) return name[keyword.len..];
    }
    return name;
}

/// Parse the output of `clang -Xclang -fdump-record-layouts`.
///
/// Each record arrives as a block:
///
///     *** Dumping AST Record Layout
///              0 | MTLOrigin
///              0 |   NSUInteger x
///              8 |   NSUInteger y
///                | [sizeof=24, align=8]
///
/// Indentation after the `|` gives nesting depth. The record sits at depth 0 and
/// its own fields at depth 1; deeper lines expand the interior of a nested
/// record and are skipped, since a nested field's position is already accounted
/// for by the field that contains it.
///
/// The lazy dump is used rather than `-fdump-record-layouts-complete` because it
/// names each record by the typedef the probe referenced it through. The
/// complete dump prints `struct (unnamed at file:line:col)` for the anonymous
/// structs that most Metal types are declared as, which would then have to be
/// joined back to their typedefs by source location.
///
/// Only records named in `wanted` are kept. Including a framework header lays
/// out a great deal besides what the probe asked for — system headers reached
/// through `Metal.h` contain bitfields and other shapes with no bearing on the
/// selected surface — and passing judgement on those would be noise at best and
/// a spurious generation failure at worst.
fn parseRecordLayouts(
    arena: std.mem.Allocator,
    text: []const u8,
    wanted: *const std.StringHashMap(void),
    /// Receives the offending record's name when the parse fails on a bitfield.
    /// The parser reports through this rather than logging, so that exercising
    /// the failure path in a test does not look like a real error.
    bitfield_record: ?*[]const u8,
) ![]const RecordLayout {
    var layouts = std.array_list.Managed(RecordLayout).init(arena);
    var fields = std.array_list.Managed(FieldLayout).init(arena);
    var name: ?[]const u8 = null;
    var keep = false;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (std.mem.indexOf(u8, line, "*** Dumping AST Record Layout") != null) {
            name = null;
            keep = false;
            fields.clearRetainingCapacity();
            continue;
        }

        const bar = std.mem.indexOfScalar(u8, line, '|') orelse continue;
        const rest = line[bar + 1 ..];
        var indent: usize = 0;
        while (indent < rest.len and rest[indent] == ' ') indent += 1;
        const body = rest[indent..];
        if (body.len == 0) continue;

        if (std.mem.startsWith(u8, body, "[sizeof=")) {
            if (keep) {
                if (name) |record_name| try layouts.append(.{
                    .name = record_name,
                    .size = try parseLabelledInteger(body, "sizeof="),
                    .alignment = try parseLabelledInteger(body, ", align="),
                    .fields = try arena.dupe(FieldLayout, fields.items),
                });
            }
            name = null;
            keep = false;
            fields.clearRetainingCapacity();
            continue;
        }

        const offset_text = std.mem.trim(u8, line[0..bar], " ");
        const depth = if (indent == 0) 0 else (indent - 1) / 2;

        // Bitfields are dumped as `0:0-2` instead of a plain byte offset. One
        // sitting directly in a record being verified has no honest `@offsetOf`
        // to assert, so it fails loudly. Deeper down it belongs to a nested
        // record, which is verified separately if it is bound at all.
        if (std.mem.indexOfScalar(u8, offset_text, ':') != null) {
            if (keep and depth == 1) {
                if (bitfield_record) |out| out.* = name orelse "<unknown>";
                return error.UnsupportedBitfieldLayout;
            }
            continue;
        }

        const offset = std.fmt.parseInt(u64, offset_text, 10) catch continue;

        if (depth == 0) {
            const record_name = stripRecordTagKeyword(body);
            name = record_name;
            keep = wanted.contains(record_name);
            for (layouts.items) |existing| {
                if (std.mem.eql(u8, existing.name, record_name)) keep = false;
            }
        } else if (depth == 1 and keep) {
            try fields.append(.{
                .name = lastToken(body) orelse continue,
                .offset = offset,
            });
        }
    }

    return try layouts.toOwnedSlice();
}

/// Does a manual source declare `objc_name` as a hand-written `extern struct`?
fn manualDeclaresExternStruct(
    sources: []const coverage.ManualSource,
    objc_name: []const u8,
) bool {
    const zig_name = trimNamespace(objc_name);
    for (sources) |source| {
        var lines = std.mem.splitScalar(u8, source.content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trimStart(u8, line, " \t");
            if (!std.mem.startsWith(u8, trimmed, "pub const ")) continue;
            const rest = trimmed["pub const ".len..];
            if (!std.mem.startsWith(u8, rest, zig_name)) continue;
            const declaration = std.mem.trimStart(u8, rest[zig_name.len..], " ");
            if (std.mem.startsWith(u8, declaration, "= extern struct")) return true;
        }
    }
    return false;
}

/// Records this framework binds by hand, in declaration-name order.
fn handWrittenRecordNames(
    arena: std.mem.Allocator,
    manifest: *const coverage.Manifest,
    sources: []const coverage.ManualSource,
    namespace: []const u8,
) ![]const []const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    var seen = std.StringHashMap(void).init(arena);
    for (manifest.entries.items) |entry| {
        if (entry.kind != .typedef and entry.kind != .record) continue;
        if (!std.mem.eql(u8, getNamespace(entry.name), namespace)) continue;
        if (!manualDeclaresExternStruct(sources, entry.name)) continue;
        if ((try seen.getOrPut(entry.name)).found_existing) continue;
        try names.append(arena, entry.name);
    }
    std.sort.insertion([]const u8, names.items, {}, stringLessThan);
    return try names.toOwnedSlice(arena);
}

/// Ask Clang for the layout of each named record.
///
/// The probe references every record through its typedef so that the layout dump
/// prints it under that name.
fn probeRecordLayouts(
    arena: std.mem.Allocator,
    io: std.Io,
    spec: FrameworkSpec,
    dirs: SdkDirs,
    header_content: []const u8,
    names: []const []const u8,
) ![]const RecordLayout {
    if (names.len == 0) return &.{};

    var probe: std.ArrayList(u8) = .empty;
    try probe.appendSlice(arena, header_content);
    for (names) |name| {
        try probe.appendSlice(arena, "_Static_assert(sizeof(");
        try probe.appendSlice(arena, name);
        try probe.appendSlice(arena, ") > 0, \"\");\n");
    }

    const probe_path = ".zig-cache/tmp_record_layouts.m";
    try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = probe_path, .data = probe.items });
    defer std.Io.Dir.deleteFile(.cwd(), io, probe_path) catch {};

    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(arena, &.{
        "clang",
        probe_path,
        "-Xclang",
        "-fdump-record-layouts",
        "-fsyntax-only",
        "-Wno-deprecated-declarations",
        "-isysroot",
        dirs.macos_sdk_root,
        "-F",
        dirs.macos_frameworks_dir,
    });
    for (spec.extra_clang_args) |arg| try argv.append(arena, arg);

    var wanted = std.StringHashMap(void).init(arena);
    for (names) |name| try wanted.put(name, {});

    const dump = try runCommand(arena, io, argv.items);
    var bitfield_record: []const u8 = "<unknown>";
    return parseRecordLayouts(arena, dump, &wanted, &bitfield_record) catch |err| {
        if (err == error.UnsupportedBitfieldLayout) std.log.err(
            "record {s} has a bitfield member, which cannot be layout-verified",
            .{bitfield_record},
        );
        return err;
    };
}

const FrameworkSpec = struct {
    name: []const u8,
    tag: Framework,
    manual_path: []const u8,
    output_path: []const u8,
    manifest_path: ?[]const u8,
    parity_surface: bool,
    header_content: union(enum) {
        inline_text: []const u8,
        file_path: []const u8,
    },
    extra_clang_args: []const []const u8,
};

const framework_specs = [_]FrameworkSpec{
    .{
        .name = "Metal",
        .tag = .metal,
        .manual_path = "src/metal.zig",
        .output_path = "src/generated/metal.zig",
        .manifest_path = "src/generated/metal.manifest.json",
        .parity_surface = true,
        .header_content = .{ .inline_text = "\n#include <Metal/Metal.h>\n" },
        .extra_clang_args = &.{},
    },
    .{
        .name = "MetalFX",
        .tag = .metal_fx,
        .manual_path = "src/metal_fx.zig",
        .output_path = "src/generated/metal_fx.zig",
        .manifest_path = "src/generated/metal_fx.manifest.json",
        .parity_surface = true,
        .header_content = .{ .inline_text = "\n#include <MetalFX/MetalFX.h>\n" },
        .extra_clang_args = &.{},
    },
    .{
        .name = "QuartzCore",
        .tag = .quartz_core,
        .manual_path = "src/quartz_core.zig",
        .output_path = "src/generated/quartz_core.zig",
        .manifest_path = "src/generated/quartz_core.manifest.json",
        .parity_surface = true,
        .header_content = .{ .inline_text = "\n#include <QuartzCore/QuartzCore.h>\n" },
        .extra_clang_args = &.{"-Wno-availability"},
    },
    .{
        .name = "AppKit",
        .tag = .app_kit,
        .manual_path = "src/app_kit.zig",
        .output_path = "src/generated/app_kit.zig",
        .manifest_path = null,
        .parity_surface = false,
        .header_content = .{ .inline_text = "\n#include <AppKit/AppKit.h>\n" },
        .extra_clang_args = &.{"-Wno-availability"},
    },
};

fn runCommand(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) ![]u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
    });
    defer allocator.free(result.stderr);
    errdefer allocator.free(result.stdout);
    switch (result.term) {
        .exited => |code| {
            if (code != 0) {
                std.log.warn("command failed with exit code {d}: {s}", .{ code, result.stderr });
                return error.CommandFailed;
            }
        },
        else => {
            std.log.warn("command terminated abnormally: {s}", .{result.stderr});
            return error.CommandFailed;
        },
    }
    return result.stdout;
}

fn readFileContents(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.openFile(.cwd(), io, path, .{});
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var rdr = file.reader(io, &buf);
    var contents: std.ArrayList(u8) = .empty;
    defer contents.deinit(allocator);
    try rdr.interface.appendRemainingUnlimited(allocator, &contents);
    return contents.toOwnedSlice(allocator);
}

const SdkDirs = struct {
    macos_sdk_root: []const u8,
    macos_frameworks_dir: []const u8,
};

fn generateForFramework(allocator: std.mem.Allocator, io: std.Io, spec: FrameworkSpec, dirs: SdkDirs) !void {
    std.debug.print("Generating {s}\n", .{spec.name});

    // Write headers.m
    const header_content = switch (spec.header_content) {
        .inline_text => |text| text,
        .file_path => |path| try readFileContents(allocator, io, path),
    };
    defer if (spec.header_content == .file_path) allocator.free(header_content);

    const tmp_header_path = ".zig-cache/tmp_headers.m";
    try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = tmp_header_path, .data = header_content });
    defer std.Io.Dir.deleteFile(.cwd(), io, tmp_header_path) catch {};

    // Build clang argv
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{
        "clang",
        tmp_header_path,
        "-Xclang",
        "-ast-dump=json",
        "-fsyntax-only",
        "-Wno-deprecated-declarations",
    });
    try argv.appendSlice(allocator, &.{
        "-isysroot",
        dirs.macos_sdk_root,
        "-F",
        dirs.macos_frameworks_dir,
    });
    for (spec.extra_clang_args) |arg| {
        try argv.append(allocator, arg);
    }

    // Run clang and capture JSON stdout
    const json_data = try runCommand(allocator, io, argv.items);
    defer allocator.free(json_data);

    // Read manual zig file
    const manual_content = try readFileContents(allocator, io, spec.manual_path);
    defer allocator.free(manual_content);
    const foundation_content = try readFileContents(allocator, io, "src/foundation.zig");
    defer allocator.free(foundation_content);
    const core_foundation_content = try readFileContents(allocator, io, "src/core_foundation.zig");
    defer allocator.free(core_foundation_content);
    const core_graphics_content = try readFileContents(allocator, io, "src/core_graphics.zig");
    defer allocator.free(core_graphics_content);
    const system_content = try readFileContents(allocator, io, "src/system.zig");
    defer allocator.free(system_content);

    // Parse JSON
    var scanner = std.json.Scanner.initCompleteInput(allocator, json_data);
    defer scanner.deinit();
    var diagnostics = std.json.Diagnostics{};
    scanner.enableDiagnostics(&diagnostics);
    var valueTree = std.json.parseFromTokenSource(std.json.Value, allocator, &scanner, .{
        .duplicate_field_behavior = .@"error",
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.log.debug("parsing JSON failed at line {d} column {d}\n", .{ diagnostics.getLine(), diagnostics.getColumn() });
        return err;
    };
    defer valueTree.deinit();

    // Re-initialize global registry
    registry.deinit();
    registry = Registry.init(allocator);

    var manifest = coverage.Manifest.init(allocator, spec.name);
    defer manifest.deinit();

    var converter = Converter.init(allocator, &manifest, spec.tag);
    defer converter.deinit();
    try converter.convert(valueTree.value);

    // Create output file, write manual content, then generate
    try std.Io.Dir.createDirPath(.cwd(), io, "src/generated");
    var atomic_output = try std.Io.Dir.cwd().createFileAtomic(io, spec.output_path, .{ .replace = true });
    defer atomic_output.deinit(io);
    try atomic_output.file.writeStreamingAll(io, manual_content);

    const manual_sources = [_]coverage.ManualSource{
        .{ .path = spec.manual_path, .content = manual_content },
        .{ .path = "src/foundation.zig", .content = foundation_content },
        .{ .path = "src/core_foundation.zig", .content = core_foundation_content },
        .{ .path = "src/core_graphics.zig", .content = core_graphics_content },
        .{ .path = "src/system.zig", .content = system_content },
    };

    var file_buf: [4096]u8 = undefined;
    var file_writer = atomic_output.file.writerStreaming(io, &file_buf);
    var generator = Generator(std.Io.Writer).init(allocator, &file_writer.interface, &manifest);
    defer generator.deinit();

    switch (spec.tag) {
        .metal => try generateMetal(&generator),
        .metal_fx => try generateMetalFX(&generator),
        .quartz_core => try generateQuartzCore(&generator),
        .app_kit => try generateAppKit(&generator),
    }
    // Ask Clang for the layout of every record this framework binds by hand.
    // Runs after the selection list is set, so that `generator.namespace` is
    // known, and before generation, which emits the assertions.
    var layout_arena = std.heap.ArenaAllocator.init(allocator);
    defer layout_arena.deinit();
    generator.record_layouts = try probeRecordLayouts(
        layout_arena.allocator(),
        io,
        spec,
        dirs,
        header_content,
        try handWrittenRecordNames(
            layout_arena.allocator(),
            &manifest,
            &manual_sources,
            generator.namespace,
        ),
    );

    try generator.generate();
    try generator.markSelectedClosure();
    try file_writer.flush();

    if (spec.manifest_path) |manifest_path| {
        try manifest.finalize(&manual_sources);
        try manifest.write(io, manifest_path);
    }
    try atomic_output.replace(io);
}

fn generateAllFrameworks(allocator: std.mem.Allocator, io: std.Io, dirs: SdkDirs) !void {
    registry = Registry.init(allocator);
    defer registry.deinit();

    for (framework_specs) |spec| {
        if (!spec.parity_surface) continue;
        try generateForFramework(allocator, io, spec, dirs);
    }

    // Run zig fmt on generated files
    const fmt_stdout = try runCommand(allocator, io, &.{
        "zig",
        "fmt",
        "src/generated/metal.zig",
        "src/generated/metal_fx.zig",
        "src/generated/quartz_core.zig",
    });
    allocator.free(fmt_stdout);
}

fn generateSingleFramework(allocator: std.mem.Allocator, io: std.Io, framework: Framework) !void {
    const file = try std.Io.Dir.openFile(.cwd(), io, "headers.json", .{});
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var rdr = file.reader(io, &buf);
    var file_list: std.ArrayList(u8) = .empty;
    defer file_list.deinit(allocator);
    try rdr.interface.appendRemainingUnlimited(allocator, &file_list);
    const file_data = file_list.items;

    var scanner = std.json.Scanner.initCompleteInput(allocator, file_data);
    defer scanner.deinit();
    var diagnostics = std.json.Diagnostics{};
    scanner.enableDiagnostics(&diagnostics);
    var valueTree = std.json.parseFromTokenSource(std.json.Value, allocator, &scanner, .{
        .duplicate_field_behavior = .@"error",
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.log.debug("parsing JSON failed at line {d} column {d}\n", .{ diagnostics.getLine(), diagnostics.getColumn() });
        return err;
    };
    defer valueTree.deinit();

    registry = Registry.init(allocator);
    defer registry.deinit();

    var manifest = coverage.Manifest.init(allocator, @tagName(framework));
    defer manifest.deinit();

    var converter = Converter.init(allocator, &manifest, framework);
    defer converter.deinit();

    try converter.convert(valueTree.value);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buf);
    var generator = Generator(std.Io.Writer).init(allocator, &stdout_writer.interface, &manifest);
    defer generator.deinit();

    switch (framework) {
        .metal => try generateMetal(&generator),
        .metal_fx => try generateMetalFX(&generator),
        .quartz_core => try generateQuartzCore(&generator),
        .app_kit => try generateAppKit(&generator),
    }
    try generator.generate();
    try stdout_writer.flush();
}

fn usage() void {
    std.log.warn(
        \\mach-objc-generator [options]
        \\
        \\Options:
        \\  --framework Metal,MetalFX,QuartzCore,AppKit  generate a single framework to stdout
        \\  --generate-all                         generate all frameworks
        \\  --sdk-root <path>                      path to the macOS SDK
        \\  --frameworks-dir <path>                path to the SDK Frameworks directory
        \\  --help
        \\
    , .{});
}

const Framework = enum {
    metal,
    metal_fx,
    quartz_core,
    app_kit,
};

pub fn main(init: std.process.Init) anyerror!void {
    const allocator = init.gpa;
    const io = init.io;

    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_iter.deinit();
    _ = args_iter.skip(); // skip argv[0]

    var framework: ?Framework = null;
    var generate_all = false;
    var sdk_root: []const u8 = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
    var frameworks_dir: []const u8 = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks";

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--framework")) {
            const fw_arg = args_iter.next() orelse {
                usage();
                std.process.exit(1);
            };
            framework = blk: {
                if (std.mem.eql(u8, fw_arg, "Metal")) break :blk .metal;
                if (std.mem.eql(u8, fw_arg, "MetalFX")) break :blk .metal_fx;
                if (std.mem.eql(u8, fw_arg, "QuartzCore")) break :blk .quartz_core;
                if (std.mem.eql(u8, fw_arg, "AppKit")) break :blk .app_kit;
                usage();
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--generate-all")) {
            generate_all = true;
        } else if (std.mem.eql(u8, arg, "--sdk-root")) {
            sdk_root = args_iter.next() orelse {
                usage();
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--frameworks-dir")) {
            frameworks_dir = args_iter.next() orelse {
                usage();
                std.process.exit(1);
            };
        }
    }

    const dirs: SdkDirs = .{
        .macos_sdk_root = sdk_root,
        .macos_frameworks_dir = frameworks_dir,
    };

    if (generate_all) {
        try generateAllFrameworks(allocator, io, dirs);
    } else if (framework) |fw| {
        try generateSingleFramework(allocator, io, fw);
    } else {
        usage();
        std.process.exit(1);
    }
}

test {
    std.testing.refAllDecls(@This());
}

/// Prefixes Apple uses for boolean accessors. `are` covers plural properties
/// such as `areBarycentricCoordsSupported`.
const boolean_accessor_prefixes = [_][]const u8{
    "is",
    "are",
    "has",
    "does",
    "can",
    "should",
    "was",
    "will",
};

/// Does `selector` name a boolean-style accessor for `property_name`?
///
/// The comparison strips a known prefix and then requires the remainder to match
/// the property name exactly apart from case, because Apple preserves acronym
/// casing: `uiTextureComposited` is read through `isUITextureComposited`. The
/// exact-length requirement is what stops `isNotSupported` from being claimed as
/// an accessor for `supported`.
fn isBooleanAccessor(selector: []const u8, property_name: []const u8) bool {
    if (property_name.len == 0) return false;
    for (boolean_accessor_prefixes) |prefix| {
        if (selector.len != prefix.len + property_name.len) continue;
        if (!std.mem.startsWith(u8, selector, prefix)) continue;
        if (std.ascii.eqlIgnoreCase(selector[prefix.len..], property_name)) return true;
    }
    return false;
}

/// Selectors that `container` declares which implement `property`.
///
/// Clang records `getter=` and `setter=` overrides explicitly but leaves default
/// selectors implicit, so the defaults are reconstructed and then confirmed
/// against the selectors the container actually declares. Nothing is claimed
/// that does not exist.
///
/// Returned selectors borrow from `container`; the caller owns only the slice.
fn findPropertyAccessors(
    allocator: std.mem.Allocator,
    container: *Container,
    property: Property,
) ![]const []const u8 {
    var found = std.array_list.Managed([]const u8).init(allocator);
    errdefer found.deinit();
    if (property.name.len == 0) return try found.toOwnedSlice();

    const default_setter = try std.fmt.allocPrint(allocator, "set{c}{s}:", .{
        std.ascii.toUpper(property.name[0]),
        property.name[1..],
    });
    defer allocator.free(default_setter);

    for (container.methods.items) |method| {
        const matches =
            (property.explicit_getter.len > 0 and
                std.mem.eql(u8, method.name, property.explicit_getter)) or
            (property.explicit_setter.len > 0 and
                std.mem.eql(u8, method.name, property.explicit_setter)) or
            std.mem.eql(u8, method.name, property.name) or
            std.mem.eql(u8, method.name, default_setter) or
            isBooleanAccessor(method.name, property.name);
        if (!matches) continue;

        for (found.items) |existing| {
            if (std.mem.eql(u8, existing, method.name)) break;
        } else {
            try found.append(method.name);
        }
    }

    return try found.toOwnedSlice();
}

test "clang record layouts parse into sizes, alignments and field offsets" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const dump =
        \\
        \\*** Dumping AST Record Layout
        \\         0 | MTLOrigin
        \\         0 |   NSUInteger x
        \\         8 |   NSUInteger y
        \\        16 |   NSUInteger z
        \\           | [sizeof=24, align=8]
        \\
        \\*** Dumping AST Record Layout
        \\         0 | MTLRegion
        \\         0 |   MTLOrigin origin
        \\         0 |     NSUInteger x
        \\         8 |     NSUInteger y
        \\        24 |   MTLSize size
        \\        24 |     NSUInteger width
        \\           | [sizeof=48, align=8]
        \\
        \\*** Dumping AST Record Layout
        \\         0 | struct MTLResourceID
        \\         0 |   unsigned long long _impl
        \\           | [sizeof=8, align=8]
        \\
        \\*** Dumping AST Record Layout
        \\         0 | __not_requested
        \\     0:0-2 |   int bits
        \\           | [sizeof=4, align=4]
    ;

    var wanted = std.StringHashMap(void).init(std.testing.allocator);
    defer wanted.deinit();
    try wanted.put("MTLOrigin", {});
    try wanted.put("MTLRegion", {});
    try wanted.put("MTLResourceID", {});

    // Including a framework header lays out far more than the probe asked for.
    // A record nobody requested is skipped, bitfields and all.
    const layouts = try parseRecordLayouts(arena.allocator(), dump, &wanted, null);
    try std.testing.expectEqual(@as(usize, 3), layouts.len);

    try std.testing.expectEqualStrings("MTLOrigin", layouts[0].name);
    try std.testing.expectEqual(@as(u64, 24), layouts[0].size);
    try std.testing.expectEqual(@as(u64, 8), layouts[0].alignment);
    try std.testing.expectEqual(@as(usize, 3), layouts[0].fields.len);
    try std.testing.expectEqualStrings("z", layouts[0].fields[2].name);
    try std.testing.expectEqual(@as(u64, 16), layouts[0].fields[2].offset);

    // A nested record contributes one field, not its expanded interior.
    try std.testing.expectEqualStrings("MTLRegion", layouts[1].name);
    try std.testing.expectEqual(@as(usize, 2), layouts[1].fields.len);
    try std.testing.expectEqualStrings("origin", layouts[1].fields[0].name);
    try std.testing.expectEqualStrings("size", layouts[1].fields[1].name);
    try std.testing.expectEqual(@as(u64, 24), layouts[1].fields[1].offset);

    // A record the SDK declares with a tag dumps as `struct MTLResourceID`, but
    // it is the same declaration the manifest knows as MTLResourceID.
    try std.testing.expectEqualStrings("MTLResourceID", layouts[2].name);
    try std.testing.expectEqual(@as(u64, 8), layouts[2].size);
    try std.testing.expectEqualStrings("_impl", layouts[2].fields[0].name);
}

test "bitfield record layouts are rejected rather than guessed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const dump =
        \\*** Dumping AST Record Layout
        \\         0 | struct B
        \\     0:0-2 |   int a
        \\           | [sizeof=4, align=4]
    ;

    var wanted = std.StringHashMap(void).init(std.testing.allocator);
    defer wanted.deinit();
    try wanted.put("B", {});

    var offending: []const u8 = "";
    try std.testing.expectError(
        error.UnsupportedBitfieldLayout,
        parseRecordLayouts(arena.allocator(), dump, &wanted, &offending),
    );
    try std.testing.expectEqualStrings("B", offending);

    // The same record goes unmentioned when it was never requested.
    var empty = std.StringHashMap(void).init(std.testing.allocator);
    defer empty.deinit();
    const skipped = try parseRecordLayouts(arena.allocator(), dump, &empty, null);
    try std.testing.expectEqual(@as(usize, 0), skipped.len);
}

test "hand-written records are detected by their extern struct declaration" {
    const source =
        \\pub const OriginExtra = extern struct {};
        \\pub const Origin = extern struct {
        \\    x: ns.UInteger,
        \\};
        \\pub const Coordinate2D = SamplePosition;
    ;
    const sources = [_]coverage.ManualSource{.{ .path = "src/metal.zig", .content = source }};

    try std.testing.expect(manualDeclaresExternStruct(&sources, "MTLOrigin"));
    try std.testing.expect(manualDeclaresExternStruct(&sources, "MTLOriginExtra"));
    // An alias to another record is not itself a record declaration.
    try std.testing.expect(!manualDeclaresExternStruct(&sources, "MTLCoordinate2D"));
    // Nor is a name that merely appears on the right-hand side.
    try std.testing.expect(!manualDeclaresExternStruct(&sources, "MTLSamplePosition"));
}

test "boolean accessor matching tolerates plurals and acronym casing" {
    try std.testing.expect(isBooleanAccessor("isHeadless", "headless"));
    try std.testing.expect(isBooleanAccessor("isRasterizationEnabled", "rasterizationEnabled"));
    try std.testing.expect(isBooleanAccessor("areBarycentricCoordsSupported", "barycentricCoordsSupported"));
    try std.testing.expect(isBooleanAccessor("isUITextureComposited", "uiTextureComposited"));

    // A longer selector that merely ends with the property name is not an accessor.
    try std.testing.expect(!isBooleanAccessor("isNotSupported", "supported"));
    try std.testing.expect(!isBooleanAccessor("headless", "headless"));
    try std.testing.expect(!isBooleanAccessor("isHeadless", ""));
}

test "property accessors resolve against declared selectors only" {
    const allocator = std.testing.allocator;
    var container = Container.init(allocator, "MTLDevice", false);
    defer container.deinit();

    const selectors = [_][]const u8{
        "isHeadless",
        "label",
        "setLabel:",
        "numberOfThings",
        "isNotSupported",
    };
    for (selectors) |selector| {
        try container.methods.append(Method.init(
            selector,
            true,
            .void,
            std.array_list.Managed(Param).init(allocator),
        ));
    }

    // Boolean getter found even though no method matches the property name.
    const headless = try findPropertyAccessors(allocator, &container, Property.init("headless", .void));
    defer allocator.free(headless);
    try std.testing.expectEqual(@as(usize, 1), headless.len);
    try std.testing.expectEqualStrings("isHeadless", headless[0]);

    // Getter and default setter both resolve.
    const label = try findPropertyAccessors(allocator, &container, Property.init("label", .void));
    defer allocator.free(label);
    try std.testing.expectEqual(@as(usize, 2), label.len);
    try std.testing.expectEqualStrings("label", label[0]);
    try std.testing.expectEqualStrings("setLabel:", label[1]);

    // An explicit getter= override that shares nothing with the property name.
    var aliased = Property.init("count", .void);
    aliased.explicit_getter = "numberOfThings";
    const count = try findPropertyAccessors(allocator, &container, aliased);
    defer allocator.free(count);
    try std.testing.expectEqual(@as(usize, 1), count.len);
    try std.testing.expectEqualStrings("numberOfThings", count[0]);

    // Nothing is invented for a property with no declared accessor.
    const supported = try findPropertyAccessors(allocator, &container, Property.init("supported", .void));
    defer allocator.free(supported);
    try std.testing.expectEqual(@as(usize, 0), supported.len);
}

test "clang getter and setter overrides are captured" {
    var manifest = coverage.Manifest.init(std.testing.allocator, "Metal");
    defer manifest.deinit();
    var converter = Converter.init(std.testing.allocator, &manifest, .metal);
    defer converter.deinit();

    var json = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "{\"name\":\"rasterizationEnabled\",\"type\":{\"qualType\":\"BOOL\"}," ++
            "\"getter\":{\"kind\":\"ObjCMethodDecl\",\"name\":\"isRasterizationEnabled\"}," ++
            "\"setter\":{\"kind\":\"ObjCMethodDecl\",\"name\":\"setRasterizationEnabled:\"}}",
        .{},
    );
    defer json.deinit();

    const property = try converter.convertProperty(json.value);
    try std.testing.expectEqualStrings("rasterizationEnabled", property.name);
    try std.testing.expectEqualStrings("isRasterizationEnabled", property.explicit_getter);
    try std.testing.expectEqualStrings("setRasterizationEnabled:", property.explicit_setter);
}

test "fixed size arrays are preserved rather than decayed to pointers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var lexer = Lexer{ .source = "float[3]" };
    var parser = try Parser.init(arena.allocator(), &lexer, true);
    const ty = try parser.parseType();
    try std.testing.expectEqual(@as(u64, 3), ty.array.len);
    try std.testing.expectEqual(@as(u8, 32), ty.array.child.*.float);

    // `float[4][3]` is four `float[3]`, not three `float[4]`.
    var nested_lexer = Lexer{ .source = "float[4][3]" };
    var nested_parser = try Parser.init(arena.allocator(), &nested_lexer, true);
    const nested = try nested_parser.parseType();
    try std.testing.expectEqual(@as(u64, 4), nested.array.len);
    try std.testing.expectEqual(@as(u64, 3), nested.array.child.*.array.len);
    try std.testing.expectEqual(@as(u8, 32), nested.array.child.*.array.child.*.float);
}

test "strict type parsing rejects representations it cannot preserve" {
    // An unsized array is a decayed parameter in one context and a flexible
    // array member in another; the spelling cannot distinguish them.
    try expectStrictTypeError("int []", error.UnsupportedArrayType);
    try expectStrictTypeError("void (*)(void)", error.UnsupportedFunctionPointer);
    try expectStrictTypeError("id<NSCopying, NSObject>", error.UnsupportedGenericObjectType);
}

test "selected vector types and invalid enum values fail closed" {
    var manifest = coverage.Manifest.init(std.testing.allocator, "Metal");
    defer manifest.deinit();
    var converter = Converter.init(std.testing.allocator, &manifest, .metal);
    defer converter.deinit();
    converter.strict_types = true;
    converter.emit_diagnostics = false;

    var type_json = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "{\"qualType\":\"float __attribute__((ext_vector_type(4)))\"}",
        .{},
    );
    defer type_json.deinit();
    try std.testing.expectError(
        error.UnsupportedVectorType,
        converter.convertType(type_json.value),
    );

    var constant_json = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "{\"value\":\"not-an-integer\"}",
        .{},
    );
    defer constant_json.deinit();
    try std.testing.expectError(
        error.InvalidClangEnumValue,
        converter.convertConstantExpr(constant_json.value),
    );

    var expression_json = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "{\"name\":\"Unsupported\",\"inner\":[{\"kind\":\"UnaryOperator\"}]}",
        .{},
    );
    defer expression_json.deinit();
    try std.testing.expectError(
        error.UnsupportedEnumExpression,
        converter.convertEnumConstantDecl(expression_json.value, 0),
    );
}

fn expectStrictTypeError(source: []const u8, expected_error: anyerror) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var lexer = Lexer{ .source = source };
    var parser = try Parser.init(arena.allocator(), &lexer, true);
    try std.testing.expectError(expected_error, parser.parseType());
}
