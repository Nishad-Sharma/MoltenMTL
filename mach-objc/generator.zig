const std = @import("std");
const reg = @import("registry.zig");

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
pub const ParseError = error{ UnexpectedCharacter, UnexpectedToken };

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

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) !Parser {
        return Parser{ .allocator = allocator, .lookahead = try lexer.next(), .lexer = lexer };
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

                    // TODO - how should handle multiple types?

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

                const child = try self.allocator.create(Type);
                child.* = .{ .instance_type = {} };

                return Type{ .pointer = .{ .is_single = true, .is_const = is_const, .is_optional = false, .child = child } };
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
            // TODO - handle arrays
            try self.match(.lbracket);
            if (self.lookahead.kind == .int)
                try self.match(.int);
            try self.match(.rbracket);

            return self.parsePointerSuffix(base_type, is_const, is_single);
        } else if (self.lookahead.kind == .lparen) {
            try self.match(.lparen);

            if (self.lookahead.kind == .star) {
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

    fn parsePointerSuffix(self: *Self, base_type: Type, is_const: bool, is_single: bool) error{
        OutOfMemory,
        UnexpectedToken,
        UnexpectedCharacter,
    }!Type {
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

pub const Converter = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) Converter {
        return Converter{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn convert(self: *Self, n: std.json.Value) !void {
        const kind = getString(n, "kind");
        if (std.mem.eql(u8, kind, "TranslationUnitDecl")) {
            try self.convertTranslationUnitDecl(n);
        }
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

        var e = try registry.getEnum(name);
        if (getObject(n, "fixedUnderlyingType")) |ty| {
            e.ty = try self.convertType(ty);
        } else {
            e.ty = .{ .int = 32 };
        }

        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "EnumConstantDecl")) {
                const v = try self.convertEnumConstantDecl(child);
                try e.values.append(v);
            }
        }
    }

    fn convertEnumConstantDecl(self: *Self, n: std.json.Value) !EnumValue {
        var value: i64 = 0;
        var is_max_uint = false;
        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "ConstantExpr")) {
                const result = self.convertConstantExpr(child);
                value = result.value;
                is_max_uint = result.is_max_uint;
            } else if (std.mem.eql(u8, childKind, "ImplicitCastExpr")) {
                const result = self.convertImplicitCastExpr(child);
                value = result.value;
                is_max_uint = result.is_max_uint;
            }
        }

        return .{ .name = getString(n, "name"), .value = value, .is_max_uint = is_max_uint };
    }

    fn convertConstantExpr(_: *Self, n: std.json.Value) EnumValue {
        const value = getString(n, "value");
        if (std.fmt.parseInt(i64, value, 10)) |v| {
            return .{ .name = "", .value = v };
        } else |_| {
            if (std.fmt.parseUnsigned(u64, value, 10)) |v| {
                if (v == std.math.maxInt(u64)) {
                    return .{ .name = "", .value = 0, .is_max_uint = true };
                }
            } else |_| {}
            return .{ .name = "", .value = 0 };
        }
    }

    fn convertImplicitCastExpr(self: *Self, n: std.json.Value) EnumValue {
        for (getArray(n, "inner")) |child| {
            const childKind = getString(child, "kind");
            if (std.mem.eql(u8, childKind, "ConstantExpr")) {
                return self.convertConstantExpr(child);
            }
        }

        return .{ .name = "", .value = 0 };
    }

    fn convertFunctionDecl(self: *Self, n: std.json.Value) void {
        _ = self;
        _ = n;
    }

    fn convertObjCCategoryDecl(self: *Self, n: std.json.Value) !void {
        const interfaceDecl = getObject(n, "interface").?;
        const container = try registry.getInterface(getString(interfaceDecl, "name"));
        try self.convertContainer(container, n);
    }

    fn convertObjCInterfaceDecl(self: *Self, n: std.json.Value) !void {
        var container = try registry.getInterface(getString(n, "name"));
        if (getObject(n, "super")) |super| {
            const superName = getString(super, "name");
            if (superName.len > 0) {
                container.super = try registry.getInterface(superName);
            }
        }

        try self.convertContainer(container, n);
    }

    fn convertObjcProtocolDecl(self: *Self, n: std.json.Value) !void {
        var container = try registry.getProtocol(getString(n, "name"));
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
        return Property.init(getString(n, "name"), ty);
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
        //std.debug.print("convertType: {s}\n", .{t.qualType});
        var lexer = Lexer{ .source = getString(t, "qualType") };
        var parser = try Parser.init(self.arena.allocator(), &lexer);
        return parser.parseType();
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
        enums: EnumList,
        containers: ContainerList,
        selectors: SelectorHashSet,
        namespace: []const u8,
        allow_methods: []const [2][]const u8,

        fn init(allocator: std.mem.Allocator, writer: *WriterType) Self {
            return Self{
                .allocator = allocator,
                .writer = writer,
                .enums = EnumList.init(allocator),
                .containers = ContainerList.init(allocator),
                .selectors = SelectorHashSet.init(allocator),
                .namespace = undefined,
                .allow_methods = undefined,
            };
        }

        fn deinit(self: *Self) void {
            self.enums.deinit();
            self.containers.deinit();
            self.selectors.deinit();
        }

        pub fn addProtocol(self: *Self, name: []const u8) !void {
            const container = registry.protocols.get(name) orelse {
                std.debug.print("Protocol {s} not found\n", .{name});
                return;
            };

            try self.addContainer(container);
        }

        pub fn addInterface(self: *Self, name: []const u8) !void {
            const container = registry.interfaces.get(name) orelse {
                std.debug.print("Interface {s} not found\n", .{name});
                return;
            };

            try self.addContainer(container);
        }

        pub fn addEnum(self: *Self, name: []const u8) !void {
            const e = registry.enums.get(name) orelse {
                std.debug.print("Enum {s} not found\n", .{name});
                return;
            };

            try self.enums.append(e);
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

        pub fn generate(self: *Self) !void {
            try self.generateEnumerations();
            try self.generateContainers();
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

        fn generateMethod(self: *Self, container: *Container, method: Method) !void {
            if (!self.isAllowedMethod(container, method)) return;
            if (container.super) |super| {
                if (self.doesParentHaveMethod(super, method.name))
                    return;
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

const FrameworkSpec = struct {
    name: []const u8,
    tag: Framework,
    manual_path: []const u8,
    output_path: []const u8,
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
        .header_content = .{ .inline_text = "\n#include <Metal/Metal.h>\n" },
        .extra_clang_args = &.{},
    },
    .{
        .name = "MetalFX",
        .tag = .metal_fx,
        .manual_path = "src/metal_fx.zig",
        .output_path = "src/generated/metal_fx.zig",
        .header_content = .{ .inline_text = "\n#include <MetalFX/MetalFX.h>\n" },
        .extra_clang_args = &.{},
    },
    .{
        .name = "QuartzCore",
        .tag = .quartz_core,
        .manual_path = "src/quartz_core.zig",
        .output_path = "src/generated/quartz_core.zig",
        .header_content = .{ .inline_text = "\n#include <QuartzCore/QuartzCore.h>\n" },
        .extra_clang_args = &.{"-Wno-availability"},
    },
    .{
        .name = "AppKit",
        .tag = .app_kit,
        .manual_path = "src/app_kit.zig",
        .output_path = "src/generated/app_kit.zig",
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

    var converter = Converter.init(allocator);
    defer converter.deinit();
    try converter.convert(valueTree.value);

    // Create output file, write manual content, then generate
    try std.Io.Dir.createDirPath(.cwd(), io, "src/generated");
    var out_file = try std.Io.Dir.createFile(.cwd(), io, spec.output_path, .{});
    defer out_file.close(io);
    try out_file.writeStreamingAll(io, manual_content);

    var file_buf: [4096]u8 = undefined;
    var file_writer = out_file.writerStreaming(io, &file_buf);
    var generator = Generator(std.Io.Writer).init(allocator, &file_writer.interface);
    defer generator.deinit();

    switch (spec.tag) {
        .metal => try generateMetal(&generator),
        .metal_fx => try generateMetalFX(&generator),
        .quartz_core => try generateQuartzCore(&generator),
        .app_kit => try generateAppKit(&generator),
    }
    try generator.generate();
    try file_writer.flush();
}

fn generateAllFrameworks(allocator: std.mem.Allocator, io: std.Io, dirs: SdkDirs) !void {
    for (framework_specs) |spec| {
        try generateForFramework(allocator, io, spec, dirs);
    }

    // Run zig fmt on generated files
    const fmt_stdout = try runCommand(allocator, io, &.{
        "zig",
        "fmt",
        "src/generated/metal.zig",
        "src/generated/metal_fx.zig",
        "src/generated/quartz_core.zig",
        "src/generated/app_kit.zig",
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

    var converter = Converter.init(allocator);
    defer converter.deinit();

    try converter.convert(valueTree.value);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buf);
    var generator = Generator(std.Io.Writer).init(allocator, &stdout_writer.interface);
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
