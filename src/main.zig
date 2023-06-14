const std = @import("std");
const testing = std.testing;

pub const CL201 = struct {
    pub const Point = struct {
        e20: f32, // x
        e01: f32, // y
        e12: f32, // homogenous coords, 1 = points, 0 = direction

        pub fn fromCartesian(x: f32, y: f32) Point {
            return Point{ .e20 = x, .e01 = y, .e12 = 1.0 };
        }

        /// performs perspective division (?)
        /// such that we can read out cartesian x/y
        pub fn toCartesian(p: *Point) void {
            if (p.e12 != 0) {
                p.e20 /= p.e12;
                p.e01 /= p.e12;
                p.e12 = 1.0;
            }
        }
    };

    pub const Line = struct {
        e1: f32, // a
        e2: f32, // b
        e0: f32, // c

        pub fn equation(a: f32, b: f32, c: f32) Line {
            return Line{ .e1 = a, .e2 = b, .e0 = c };
        }
    }; // ax + by + c = 0

    pub const Motor = struct {
        s: f32,
        e01: f32,
        e20: f32,
        e12: f32,
    };

    pub fn normalize(a: anytype) @TypeOf(a) {
        const T = @TypeOf(a);
        if (T == Point) {
            const inorm = 1.0 / a.e12;
            return Point{
                .e20 = a.e20 * inorm,
                .e01 = a.e01 * inorm,
                .e12 = a.e12 * inorm,
            };
        } else if (T == Line) {
            const inorm = 1.0 / @sqrt(a.e1 * a.e1 + a.e2 * a.e2);
            return Line{
                .e1 = a.e1 * inorm,
                .e2 = a.e2 * inorm,
                .e0 = a.e0 * inorm,
            };
        } else if (T == Motor) {
            const inorm = 1.0 / @sqrt(2 * a.s * a.s + a.e12 * a.e12);
            return Motor{
                .s = a.e01 * inorm,
                .e01 = a.e01 * inorm,
                .e20 = a.e20 * inorm,
                .e12 = a.e12 * inorm,
            };
        }
        @compileError("normalize not supported for type " ++ @typeName(T));
    }

    // neat construction i learned from zmath
    fn dualReturnType(comptime T: type) type {
        if (T == Point) {
            return Line;
        } else if (T == Line) {
            return Point;
        }
        @compileError("dual not supported for type " ++ @typeName(T));
    }
    pub fn dual(a: anytype) dualReturnType(@TypeOf(a)) {
        const T = @TypeOf(a);
        if (T == Point) {
            return Line{
                .e1 = a.e20,
                .e2 = a.e01,
                .e0 = a.e12,
            };
        } else if (T == Line) {
            return Point{
                .e20 = a.e1,
                .e01 = a.e2,
                .e12 = a.e0,
            };
        }
        @compileError("dual not supported for type " ++ @typeName(T));
    }

    pub fn meet(a: Line, b: Line) Point {
        var p = Point{
            .e20 = a.e2 * b.e0 - a.e0 * b.e2,
            .e01 = a.e0 * b.e1 - a.e1 * b.e0,
            .e12 = a.e1 * b.e2 - a.e2 * b.e1,
        };
        return p;
    }

    pub fn join(a: Point, b: Point) Line {
        return dual(meet(dual(a), dual(b)));
    }

    // fn mulReturnType(comptime Ta: type, comptime Tb: type) type {
    //     if (Ta == Line and Tb == Line) {
    //         return Line;
    //     }
    //     @compileError("mul not supported for types " ++ @typeName(Ta) ++ " and " ++ @typeName(Tb));
    // }
    // pub fn mul(a: anytype, b: anytype) mulReturnType(@TypeOf(a), @TypeOf(b)) {
    //     const Ta = @TypeOf(a);
    //     const Tb = @TypeOf(b);
    //     if (Ta == Line and Tb == Line) {}
    //     @compileError("mul not supported for types " ++ @typeName(Ta) ++ " and " ++ @typeName(Tb));
    // }

    // TODO think about how to unify interface
    // reflect point b across line a using sandwich product
    // pub fn swch_lp(a: Line, b: Point) Point {}
};

pub const CL201MV = struct {
    pub const MV = struct {
        s: f32 = 0,
        e0: f32 = 0,
        e1: f32 = 0,
        e2: f32 = 0,
        e01: f32 = 0,
        e20: f32 = 0,
        e12: f32 = 0,
        e012: f32 = 0,

        pub fn fromCart(x: f32, y: f32) MV {
            return MV{ .e20 = x, .e01 = y, .e12 = 1 };
        } // cartesian x/y coordinates

        pub fn fromEq(a: f32, b: f32, c: f32) MV {
            return MV{ .e1 = a, .e2 = b, .e0 = c };
        } // line equation ax + by + c = 0
    };

    pub fn dual(mv: MV) MV {
        return MV{
            .s = mv.e012,
            .e0 = mv.e12,
            .e1 = mv.e20,
            .e2 = mv.e01,
            .e01 = mv.e2,
            .e20 = mv.e1,
            .e12 = mv.e0,
            .e012 = mv.s,
        };
    }

    pub fn rev(mv: MV) MV {
        var mv2 = mv;
        mv2.e01 = -mv2.e01;
        mv2.e20 = -mv2.e20;
        mv2.e12 = -mv2.e12;
        mv2.e012 = -mv2.e012;
        return mv2;
    }

    pub fn conj(mv: MV) MV {
        var mv2 = mv;
        mv2.e0 = -mv.e0;
        mv2.e1 = -mv.e1;
        mv2.e2 = -mv.e2;
        mv2.e01 = -mv2.e01;
        mv2.e20 = -mv2.e20;
        mv2.e12 = -mv2.e12;
        return mv2;
    }

    pub fn normalize(mv: MV) MV {
        const n = 1.0 / @sqrt(@fabs(mul(mv, conj(mv)).s));
        return smul(n, mv);
    }

    /// geometric product
    pub fn mul(a: MV, b: MV) MV {
        return MV{
            .s = a.s * b.s + a.e1 * b.e1 + a.e2 * b.e2 - a.e12 * b.e12,
            .e0 = b.e0 * a.s + b.s * a.e0 - b.e01 * a.e1 + b.e20 * a.e2 +
                b.e1 * a.e01 - b.e2 * a.e20 - b.e012 * a.e12 - b.e12 * a.e012,
            .e1 = b.e1 * a.s + b.s * a.e1 - b.e12 * a.e2 + b.e2 * a.e12,
            .e2 = b.e2 * a.s + b.e12 * a.e1 + b.s * a.e2 - b.e1 * a.e12,
            .e01 = b.e01 * a.s + b.e1 * a.e0 - b.e0 * a.e1 + b.e012 * a.e2 +
                b.s * a.e01 + b.e12 * a.e20 - b.e20 * a.e12 + b.e2 * a.e012,
            .e20 = b.e20 * a.s - b.e2 * a.e0 + b.e012 * a.e1 + b.e0 * a.e2 -
                b.e12 * a.e01 + b.s * a.e20 + b.e01 * a.e12 + b.e1 * a.e012,
            .e12 = b.e12 * a.s + b.e2 * a.e1 - b.e1 * a.e2 + b.s * a.e12,
            .e012 = b.e012 * a.s + b.e12 * a.e0 + b.e20 * a.e1 + b.e01 * a.e2 +
                b.e2 * a.e01 + b.e1 * a.e20 + b.e0 * a.e12 + b.s * a.e012,
        };
    }

    /// outer product
    pub fn meet(a: MV, b: MV) MV {
        return MV{
            .s = b.s * a.s,
            .e0 = b.e0 * a.s + b.s * a.e0,
            .e1 = b.e1 * a.s + b.s * a.e1,
            .e2 = b.e2 * a.s + b.s * a.e2,
            .e01 = b.e01 * a.s + b.e1 * a.e0 - b.e0 * a.e1 + b.s * a.e01,
            .e20 = b.e20 * a.s - b.e2 * a.e0 + b.e0 * a.e2 + b.s * a.e20,
            .e12 = b.e12 * a.s + b.e2 * a.e1 - b.e1 * a.e2 + b.s * a.e12,
            .e012 = b.e012 * a.s + b.e12 * a.e0 + b.e20 * a.e1 + b.e01 * a.e2 +
                b.e2 * a.e01 + b.e1 * a.e20 + b.e0 * a.e12 + b.s * a.e012,
        };
    }

    /// regressive product
    pub fn join(a: MV, b: MV) MV {
        // the reverse order of a/b results in a changed minus sign for the result
        // i don't know if it matters though...
        // return dual(meet(dual(b), dual(a)));

        // this straight up implementation is probably faster anyway
        return MV{
            .s = a.s * b.e012 + a.e0 * b.e12 + a.e1 * b.e20 + a.e2 * b.e01 +
                a.e01 * b.e2 + a.e20 * b.e1 + a.e12 * b.e0 + a.e012 * b.s,
            .e0 = a.e0 * b.e012 + a.e01 * b.e20 - a.e20 * b.e01 + a.e012 * b.e0,
            .e1 = a.e1 * b.e012 - a.e01 * b.e12 + a.e12 * b.e01 + a.e012 * b.e1,
            .e2 = a.e2 * b.e012 + a.e20 * b.e12 - a.e12 * b.e20 + a.e012 * b.e2,
            .e01 = a.e01 * b.e012 + a.e012 * b.e01,
            .e20 = a.e20 * b.e012 + a.e012 * b.e20,
            .e12 = a.e12 * b.e012 + a.e012 * b.e12,
            .e012 = a.e012 * b.e012,
        };
    }

    /// inner product
    pub fn dot(a: MV, b: MV) MV {
        return MV{
            .s = b.s * a.s + b.e1 * a.e1 + b.e2 * a.e2 - b.e12 * a.e12,
            .e0 = b.e0 * a.s + b.s * a.e0 - b.e01 * a.e1 + b.e20 * a.e2 +
                b.e1 * a.e01 - b.e2 * a.e20 - b.e012 * a.e12 - b.e12 * a.e012,
            .e1 = b.e1 * a.s + b.s * a.e1 - b.e12 * a.e2 + b.e2 * a.e12,
            .e2 = b.e2 * a.s + b.e12 * a.e1 + b.s * a.e2 - b.e1 * a.e12,
            .e01 = b.e01 * a.s + b.e012 * a.e2 + b.s * a.e01 + b.e2 * a.e012,
            .e20 = b.e20 * a.s + b.e012 * a.e1 + b.s * a.e20 + b.e1 * a.e012,
            .e12 = b.e12 * a.s + b.s * a.e12,
            .e012 = b.e012 * a.s + b.s * a.e012,
        };
    }

    pub fn smul(s: f32, mv: MV) MV {
        return MV{
            .s = s * mv.s,
            .e0 = s * mv.e0,
            .e1 = s * mv.e1,
            .e2 = s * mv.e2,
            .e01 = s * mv.e01,
            .e20 = s * mv.e20,
            .e12 = s * mv.e12,
            .e012 = s * mv.e012,
        };
    }
};

test "basic functionality" {
    std.debug.print("\n", .{});
    const ga = CL201MV;

    // const p = ga.MV.fromCart(2, 3);
    // std.debug.print("{}\n", .{p});
    // std.debug.print("{}\n", .{ga.dual(p)});
    // std.debug.print("{}\n", .{ga.dual(ga.dual(p))});

    // std.debug.print("{}\n", .{ga.meet(
    //     ga.MV.fromEq(1, 1, 0),
    //     ga.MV.fromEq(-1, 1, 0),
    // )});
    // std.debug.print("{}\n", .{ga.meet(
    //     ga.MV.fromEq(-1, 1, 0),
    //     ga.MV.fromEq(1, 1, 0),
    // )});
    // std.debug.print("{}\n", .{ga.meet(
    //     ga.MV.fromEq(-1, -1, 2),
    //     ga.MV.fromEq(1, -1, 0),
    // )});
    // std.debug.print("{}\n", .{ga.meet(
    //     ga.MV.fromEq(-1, -1, 2),
    //     ga.MV.fromEq(1, -1, 0),
    // )});
    std.debug.print("{}\n", .{ga.MV.fromCart(-1, -1)});
    std.debug.print("{}\n", .{ga.MV.fromCart(1, 1)});
    std.debug.print("{}\n", .{ga.mul(
        ga.MV.fromCart(-1, -1),
        ga.MV.fromCart(1, 1),
    )});
    std.debug.print("{}\n", .{ga.join(
        ga.MV.fromCart(-1, -1),
        ga.MV.fromCart(1, 1),
    )});
    std.debug.print("{}\n", .{ga.meet(
        ga.MV.fromEq(-1, -1, 2),
        ga.MV.fromEq(1, -1, 0),
    )});
    std.debug.print("{}\n", .{ga.normalize(ga.mul(
        ga.dot(
            ga.MV.fromEq(1, -1, 0),
            ga.MV.fromCart(2, 0),
        ),
        ga.MV.fromEq(1, -1, 0),
    ))}); // projection of point onto line
    std.debug.print("{}\n", .{ga.normalize(ga.mul(
        ga.mul(
            ga.MV.fromEq(1, -1, 0),
            ga.MV.fromCart(2, 0),
        ),
        ga.MV.fromEq(1, -1, 0),
    ))}); // reflection of point across line

    try std.testing.expect(true);
}
