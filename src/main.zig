const std = @import("std");
const testing = std.testing;

// notes
// motor * point * rev(motor)
// (a + be01 + ce20 + de12)(xe20 + ye01 + ze12)
// = (ax + dy - bz)e20 + (ay + cz - dx)e01 - dz + aze12
// [(ax + dy - bz)e20 + (ay + cz - dx)e01 - dz + aze12](a - be01 - ce20 - de12)
// = (a2x + 2ady - abz + 2cdz - d2x - acz)e20 + (a2y + acz - 2adx + 2bdz - d2y + abz)e01 + (az + d2z)e12

pub const CL201 = struct {
    pub const Point = struct {
        e20: f32, // x
        e01: f32, // y
        e12: f32, // homogenous coords, 1 = points, 0 = direction

        pub fn fromCart(x: f32, y: f32) Point {
            return Point{ .e20 = x, .e01 = y, .e12 = 1.0 };
        }

        /// performs perspective division (?)
        /// such that we can read out cartesian x/y
        pub fn toCart(p: *Point) void {
            if (p.e12 != 0) {
                p.e20 /= p.e12;
                p.e01 /= p.e12;
                p.e12 = 1.0;
            }
        }
    };

    pub const Direction = struct {
        e20: f32, // x
        e01: f32, // y
        // e12: f32 = 0, homogenous coords, 1 = points, 0 = direction

        pub fn fromRad(d: f32) Direction {
            return Direction{ .e20 = @cos(d), .e01 = @sin(d) };
        }
    };

    pub const Line = struct {
        e1: f32, // a
        e2: f32, // b
        e0: f32, // c

        /// line defined as ax + by + c = 0
        pub fn fromEq(a: f32, b: f32, c: f32) Line {
            return Line{ .e1 = a, .e2 = b, .e0 = c };
        }
    };

    pub const Translator = struct {
        s: f32,
        e01: f32,
        e20: f32,

        pub fn fromCart(dx: f32, dy: f32) Translator {
            return Translator{ .s = 1.0, .e20 = 0.5 * dx, .e01 = -0.5 * dy };
        }
    };

    pub const Rotor = struct {
        s: f32,
        e12: f32,

        pub fn fromRad(d: f32) Rotor {
            return Rotor{ .s = @cos(0.5 * d), .e12 = @sin(0.5 * d) };
        }
    };

    pub const Motor = struct {
        s: f32,
        e01: f32,
        e20: f32,
        e12: f32,
    };

    // pub const Flector = struct {} ???

    /// return a normalized copy
    pub fn normalized(a: anytype) @TypeOf(a) {
        const T = @TypeOf(a);
        if (T == Point) {
            const inorm = 1.0 / a.e12; // we could take the absolute, but why waste the time?
            return Point{
                .e20 = a.e20 * inorm,
                .e01 = a.e01 * inorm,
                .e12 = a.e12 * inorm,
            };
        } else if (T == Direction) {
            const inorm = 1.0 / @sqrt(a.e20 * a.e20 + a.e12 * a.e12);
            return Direction{
                .e20 = a.e20 * inorm,
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
            // Is this correct
            const inorm = 1.0 / @sqrt(2 * a.s * a.s + a.e12 * a.e12);
            return Motor{
                .s = a.e01 * inorm,
                .e01 = a.e01 * inorm,
                .e20 = a.e20 * inorm,
                .e12 = a.e12 * inorm,
            };
        }
        // TODO add normalization for Translator and Rotor
        @compileError("normalized not supported for type " ++ @typeName(T));
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

    /// outer product
    // TODO does it make sense to apply this to anything else?
    pub fn meet(a: Line, b: Line) Point {
        var p = Point{
            .e20 = a.e2 * b.e0 - a.e0 * b.e2,
            .e01 = a.e0 * b.e1 - a.e1 * b.e0,
            .e12 = a.e1 * b.e2 - a.e2 * b.e1,
        };
        return p;
    }

    /// regressive product
    // TODO does it make sense to apply this to anything else?
    pub fn join(a: Point, b: Point) Line {
        // return dual(meet(dual(b), dual(a)));
        var p = Line{
            .e1 = a.e12 * b.e01 - a.e01 * b.e12,
            .e2 = a.e20 * b.e12 - a.e12 * b.e20,
            .e0 = a.e01 * b.e20 - a.e20 * b.e01,
        };
        return p;
    }

    /// projection of a onto b
    // TODO somewhat worried that one of these is negated
    pub fn project(a: anytype, b: anytype) @TypeOf(a) {
        const Ta = @TypeOf(a);
        const Tb = @TypeOf(b);
        // this appears to be wrong
        if (Ta == Line and Tb == Point) {
            const z2 = b.e12 * b.e12;
            return Line{
                .e1 = a.e1 * z2,
                .e2 = a.e2 * z2,
                .e0 = -b.e12 * (a.e1 * b.e20 + a.e2 * b.e01),
            };
        } else if (Ta == Point and Tb == Line) {
            const A = b.e2 * a.e20 - b.e1 * a.e01;
            const wz = b.e0 * a.e12;
            return Point{
                .e20 = b.e1 * wz - A * b.e2,
                .e01 = b.e2 * wz + A * b.e1,
                .e12 = a.e12 * (b.e1 * b.e1 - b.e2 * b.e2),
            };
        }
        @compileError("project not supported for types " ++ @typeName(Ta) ++ " and " ++ @typeName(Tb));
    }

    /// sandwidth multiplication of a*b*reverse(a)
    pub fn apply(a: anytype, b: anytype) @TypeOf(b) {
        const Ta = @TypeOf(a);
        const Tb = @TypeOf(b);
        if (Ta == Motor and Tb == Point) {
            // motor * point * rev(motor)
            // (xe20 + ye01 + ze12)
            // = (sx - uz + wy)e20 + (sy + vz - wx)e01 + sze12 - wz
            // [(sx - uz + wy)e20 + (sy + vz - wx)e01 + sze12 - wz](s - ue01 - ve20 - we12)
            // A = (sx - uz + wy)
            // B = (sy + vz - wx)
            // = (sA - suz + vwz + wB)e20 + (sB + uwz + svz - wA)e01 + z(s2 + w2)e12
            const s = a.s;
            const u = a.e01;
            const v = a.e20;
            const w = a.e12;
            const x = b.e01;
            const y = b.e20;
            const z = b.e12;
            const A = s * x - u * z + w * y;
            const B = s * y + v * z - w * x;
            return Point{
                .e20 = s * A - s * u * z + v * w * z + w * B,
                .e01 = s * B + u * w * z + s * v * z - w * A,
                .e12 = z * (s * s + w * w),
            };
        } else if (Ta == Translator and Tb == Point) {
            const s = a.s;
            const u = a.e01;
            const v = a.e20;
            const x = b.e01;
            const y = b.e20;
            const z = b.e12;
            const A = s * x - u * z;
            const B = s * y + v * z;
            return Point{
                .e20 = s * A - s * u * z,
                .e01 = s * B + s * v * z,
                .e12 = z * s * s,
            };
        } else if (Ta == Rotor and Tb == Point) {
            // rotor * point * rev(rotor)
            // (s + we12)(xe20 + ye01 + ze12)
            // = (sx + wy)e20 + (sy - wx)e01 + sze12 = wz
            // [(sx + wy)e20 + (sy - wx)e01 + sze12 = wz](s - we12)
            // = (s(sx + wy) + w(sy - wx))e20 + (s(sy - wx) - w(sx + wy))e01 + z(s2 - w2)e12
            const s = a.s;
            const w = a.e12;
            const x = b.e01;
            const y = b.e20;
            const z = b.e12;
            const A = s * x + w * y;
            const B = s * y - w * x;
            return Point{
                .e20 = s * A + w * B,
                .e01 = s * B - w * A,
                .e12 = z * (s * s + w * w),
            };
        }

        @compileError("apply (sandwich) not supported for types " ++ @typeName(Ta) ++ " and " ++ @typeName(Tb));
    }

    fn mulReturnType(comptime Ta: type, comptime Tb: type) type {
        if ((Ta == Rotor and Tb == Translator) or (Ta == Translator and Tb == Rotor)) {
            return Motor;
        } else if (Ta == Motor and Tb == Motor) {
            return Motor;
        }
        @compileError("mul not supported for types " ++ @typeName(Ta) ++ " and " ++ @typeName(Tb));
    }
    /// mul(rotor, translator) -> motor that first translates, then rotates
    /// mul(translator, rotor) -> motor that first rotates, then translates
    /// mul(motor a, motor b) -> motor that first applies motor b, then motor a
    pub fn mul(a: anytype, b: anytype) mulReturnType(@TypeOf(a), @TypeOf(b)) {
        const Ta = @TypeOf(a);
        const Tb = @TypeOf(b);
        if (Ta == Rotor and Tb == Translator) {
            return Motor{
                .s = a.s * b.s,
                .e01 = a.s * b.e01 - a.e12 * b.e20,
                .e20 = a.s * b.e20 + a.e12 * b.e01,
                .e12 = a.e12 * b.s,
            };
        } else if (Ta == Translator and Tb == Rotor) {
            return Motor{
                .s = a.s * b.s,
                .e01 = b.s * a.e01 + b.e12 * a.e20,
                .e20 = b.s * a.e20 - b.e12 * a.e01,
                .e12 = b.e12 * a.s,
            };
        } else if (Ta == Motor and Tb == Motor) {
            return Motor{
                .s = a.s * b.s - a.e12 * b.e12,
                .e01 = a.s * b.e20 - a.e01 * b.e12 + a.e20 * b.s + a.e12 * b.e01,
                .e20 = a.s * b.e01 + a.e01 * b.s + a.e20 * b.e12 - a.e12 * b.e20,
                .e12 = a.s * b.e12 + a.e12 * b.s,
            };
        }
        @compileError("mul not supported for types " ++ @typeName(Ta) ++ " and " ++ @typeName(Tb));
    }
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
    const ga = CL201;
    const ga_mv = CL201MV;

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
    std.debug.print("{}\n", .{ga_mv.MV.fromCart(-1, -1)});
    std.debug.print("{}\n", .{ga.Point.fromCart(-1, -1)});
    std.debug.print("{}\n", .{ga_mv.MV.fromCart(1, 1)});
    std.debug.print("{}\n", .{ga.Point.fromCart(-1, -1)});
    std.debug.print("join {}\n", .{ga_mv.join(
        ga_mv.MV.fromCart(-1, -1),
        ga_mv.MV.fromCart(1, 1),
    )});
    std.debug.print("join {}\n", .{ga.join(
        ga.Point.fromCart(-1, -1),
        ga.Point.fromCart(1, 1),
    )});
    std.debug.print("{}\n", .{ga_mv.MV.fromCart(-1, -1)});
    std.debug.print("{}\n", .{ga.normalized(ga.Point.fromCart(-1, -1))});
    std.debug.print("meet {}\n", .{ga_mv.meet(
        ga_mv.MV.fromEq(-1, -1, 2),
        ga_mv.MV.fromEq(1, -1, 0),
    )});
    std.debug.print("meet {}\n", .{ga.meet(
        ga.Line.fromEq(-1, -1, 2),
        ga.Line.fromEq(1, -1, 0),
    )});

    std.debug.print("{}\n", .{ga.apply(
        ga.Motor{ .s = 1, .e01 = 1, .e20 = 1, .e12 = 1 },
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{
        ga.Rotor.fromRad(0.25 * std.math.pi),
    });
    std.debug.print("{}\n", .{ga.apply(
        ga.Rotor.fromRad(0.25 * std.math.pi),
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{
        ga.Rotor.fromRad(0.5 * std.math.pi),
    });
    std.debug.print("{}\n", .{ga.apply(
        ga.Rotor.fromRad(0.5 * std.math.pi),
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{
        ga.Rotor.fromRad(std.math.pi),
    });
    std.debug.print("{}\n", .{ga.apply(
        ga.Rotor.fromRad(std.math.pi),
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{
        ga.Rotor.fromRad(2 * std.math.pi),
    });
    std.debug.print("{}\n", .{ga.apply(
        ga.Rotor.fromRad(2 * std.math.pi),
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{ga.apply(
        ga.Translator.fromCart(1, 1),
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{ga.mul(
        ga.Translator.fromCart(1, 1),
        ga.Rotor.fromRad(0.5 * std.math.pi),
    )});
    std.debug.print("{}\n", .{ga.mul(
        ga.Rotor.fromRad(0.5 * std.math.pi),
        ga.Translator.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{ga.apply(
        ga.mul(
            ga.Translator.fromCart(1, 1),
            ga.Rotor.fromRad(0.5 * std.math.pi),
        ),
        ga.Point.fromCart(1, 1),
    )});
    std.debug.print("{}\n", .{ga.apply(
        ga.mul(
            ga.Rotor.fromRad(0.5 * std.math.pi),
            ga.Translator.fromCart(1, 1),
        ),
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{ga.apply(
        ga.mul(
            ga.mul(
                ga.Rotor.fromRad(0.5 * std.math.pi),
                ga.Translator.fromCart(1, 1),
            ),
            ga.mul(
                ga.Translator.fromCart(1, 1),
                ga.Rotor.fromRad(0.5 * std.math.pi),
            ),
        ),
        ga.Point.fromCart(1, 1),
    )});
    std.debug.print("{}\n", .{ga.apply(
        ga.mul(
            ga.mul(
                ga.Translator.fromCart(1, 1),
                ga.Rotor.fromRad(0.5 * std.math.pi),
            ),
            ga.mul(
                ga.Rotor.fromRad(0.5 * std.math.pi),
                ga.Translator.fromCart(1, 1),
            ),
        ),
        ga.Point.fromCart(1, 1),
    )});

    std.debug.print("{}\n", .{ga.project(
        ga.Line.fromEq(1, 1, 0),
        ga.Point.fromCart(1, 1),
    )});
    std.debug.print("{}\n", .{ga.project(
        ga.Point.fromCart(1, 1),
        ga.Line.fromEq(1, 1, 0),
    )});

    // var mv = ga_mv.MV{ .e01 = 1, .e20 = 1 }; // a direction
    // std.debug.print("{}\n", .{mv});
    // mv = ga_mv.normalize(mv);
    // std.debug.print("{}\n", .{mv});

    // std.debug.print("{}\n", .{ga_mv.normalize(ga_mv.mul(
    //     ga_mv.dot(
    //         ga_mv.MV.fromEq(1, -1, 0),
    //         ga_mv.MV.fromCart(2, 0),
    //     ),
    //     ga_mv.MV.fromEq(1, -1, 0),
    // ))}); // projection of point onto line
    // std.debug.print("{}\n", .{ga_mv.normalize(ga_mv.mul(
    //     ga_mv.mul(
    //         ga_mv.MV.fromEq(1, -1, 0),
    //         ga_mv.MV.fromCart(2, 0),
    //     ),
    //     ga_mv.MV.fromEq(1, -1, 0),
    // ))}); // reflection of point across line

    try std.testing.expect(true);
}
