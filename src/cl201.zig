const std = @import("std");

// for the sake of interoperability, same definition as in zmath
pub const F32x4 = @Vector(4, f32);

pub inline fn f32x4(e0: f32, e1: f32, e2: f32, e3: f32) F32x4 {
    return .{ e0, e1, e2, e3 };
}
pub inline fn f32x4s(e0: f32) F32x4 {
    return @splat(4, e0);
}

// there's gonna be two types of vector
// A - np.array([ e1,  e2,  e0, e012]) - lines (and flectors)
// B - np.array([e20, e01, e12,    1]) - points and motors
// under this definition
// - dual is free (noop)
// - the first two items of a (normalized) B vector are cartesian coordinates

// these make no difference (until zig gets distinct types)
// but are useful for the sake of annotating function inputs and outputs
pub const Point = F32x4;
pub const Line = F32x4;
pub const Motor = F32x4;
// also, functions that operate these objects
// are postfixed with P/L/M respectively
// functions that work on type A or type B vectors are annotated similarly

// namespace the initialization functions
pub const init = struct {
    /// create a motor for the translation dx, dy
    pub inline fn trans(dx: f32, dy: f32) Motor {
        return .{ 0.5 * dy, -0.5 * dx, 0.0, 1.0 };
    }

    /// create a motor for a clockwise rotation around the origin
    pub inline fn rotCW(radians: f32) Motor {
        return .{ 0, 0, @sin(0.5 * radians), @cos(0.5 * radians) };
    }

    /// create a motor for a counter-clockwise rotation around the origin
    pub inline fn rotCCW(radians: f32) Motor {
        return .{ 0, 0, @sin(-0.5 * radians), @cos(-0.5 * radians) };
    }

    // TODO
    // pub fn RotCWAround() Motor {}
    // pub fn RotCCWAround() Motor {}
};

pub fn normP(p: Point) Point {
    std.debug.assert(p[3] == 0);
    return p / @splat(4, p[2]);
}

pub fn normL(l: Line) Line {
    std.debug.assert(l[3] == 0);
    const l2 = l * l;
    const inorm = 1 / @sqrt(l2[0] + l2[1]);
    return @splat(4, inorm) * l;
}

/// outer product
/// find the intersection of two lines
pub fn meetLL(l0: Line, l1: Line) Point {
    // TODO try to optimize simd
    std.debug.assert(l0[3] == 0);
    std.debug.assert(l1[3] == 0);
    return .{
        l0[1] * l1[2] - l0[2] * l1[1],
        l0[2] * l1[0] - l0[0] * l1[2],
        l0[0] * l1[1] - l0[1] * l1[0],
        0,
    };
}

/// regressive product
/// find the line between two points
pub inline fn joinPP(p0: Point, p1: Point) Point {
    // dual is noop, so dual(meet(dual(p0), dual(p1))) == meet(p0, p1)
    return meetLL(p0, p1);
}

/// sandwitch product
/// moves point p by the translation described by motor m
pub fn applyMP(m: Motor, p: Point) Point {
    std.debug.assert(p[3] == 0);
    // TODO make sure this gets optimized away
    // TODO try to optimize simd
    const u = m[0];
    const v = m[1];
    const w = m[2];
    const s = m[3];
    const x = p[0];
    const y = p[1];
    const z = p[2];
    const A = s * x - v * z + w * y;
    const B = s * y + u * z - w * x;
    return .{
        s * A + w * B + z * (u * w - v * s),
        s * B - w * A + z * (v * w + u * s),
        z * (s * s + w * w),
        0,
    };
}

/// sandwitch product
/// moves line l by the translation described by motor m
/// FIXME - doesn't appear to work for translations, only rotations
pub fn applyML(m: Motor, l: Line) Line {
    // TODO make sure this gets optimized away
    // TODO try to optimize simd
    const u = m[0];
    const v = m[1];
    const w = m[2];
    const s = m[3];
    const a = l[0];
    const b = l[1];
    const c = l[2];
    const A = s * a + w * b;
    const B = s * b - w * a;
    const C = s * c - u * b + v * a;
    const D = w * c + v * b + u * a;
    return .{
        s * A + w * B,
        s * B - w * A,
        s * C + w * D + v * A - u * B,
        0,
    };
}

/// commutator product of line l and point p
/// returns a new line through p perpendicular to l
/// TODO rename?
pub fn commLP(l: Line, p: Point) Line {
    const ab = l[0] * p[2];
    return .{
        ab,
        -ab,
        l[1] * p[0] - l[0] * p[1],
        0,
    };
}

/// geometric product of two type B vectors
pub fn mulBB(b0: F32x4, b1: F32x4) F32x4 {
    // TODO test optimization, is it actually faster?
    const A = @shuffle(f32, b0, undefined, @Vector(4, i32){ 2, 3, 2, 3 });
    const B = @shuffle(f32, b1, undefined, @Vector(4, i32){ 3, 2, 2, 3 });
    const AB = A * B;
    const C = @shuffle(f32, b0, undefined, @Vector(4, i32){ 2, 3, 0, 1 });
    const D = @shuffle(f32, b0, undefined, @Vector(4, i32){ 3, 2, 1, 0 });
    const n0 = @Vector(4, f32){ 1, 1, -1, 1 };
    const n1 = @Vector(4, f32){ -1, 1, 1, 1 };
    return .{
        @reduce(.Add, D * b1 * n0),
        @reduce(.Add, C * b1 * n1),
        AB[0] + AB[1],
        AB[3] - AB[2],
    };
}
/// compose two motors m0, m1 to a new one performing first m1 then m0
pub inline fn mulMM(m0: Motor, m1: Motor) Motor {
    return mulBB(m0, m1);
}

test "motors" {
    const p: Point = .{ 1, 1, 1, 0 };
    const mr = init.rotCCW(0.5 * std.math.pi);
    const mt = init.trans(2, 2);

    // std.debug.print("\n", .{});
    // std.debug.print("{}\n", .{normP(applyMP(mr, p))});
    // std.debug.print("{}\n", .{normP(applyMP(mt, p))});
    // std.debug.print("{}\n", .{normP(applyMP(mulMM(mr, mt), p))});
    // std.debug.print("{}\n", .{normP(applyMP(mulMM(mt, mr), p))});
    // std.debug.print("{}\n", .{normP(applyMP(mr, applyMP(mt, p)))});
    // std.debug.print("{}\n", .{normP(applyMP(mt, applyMP(mr, p)))});

    const mr_p = normP(applyMP(mr, p));
    const mt_p = normP(applyMP(mt, p));
    const mtr_p = normP(applyMP(mulMM(mr, mt), p));
    const mrt_p = normP(applyMP(mulMM(mt, mr), p));
    const mt_mr_p = normP(applyMP(mr, applyMP(mt, p)));
    const mr_mt_p = normP(applyMP(mt, applyMP(mr, p)));

    try std.testing.expect(approxEqAbs(mr_p, f32x4(-1, 1, 1, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mt_p, f32x4(3, 3, 1, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mtr_p, f32x4(-3, 3, 1, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mrt_p, f32x4(1, 3, 1, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mrt_p, mr_mt_p, 1e-3));
    try std.testing.expect(approxEqAbs(mtr_p, mt_mr_p, 1e-3));

    const l: Line = .{ 1, -1, -1, 0 };

    // std.debug.print("\n", .{});
    // std.debug.print("{}\n", .{applyML(mr, l)});
    // std.debug.print("{}\n", .{applyML(mt, l)});
    // std.debug.print("{}\n", .{applyML(mulMM(mr, mt), l)});
    // std.debug.print("{}\n", .{applyML(mulMM(mt, mr), l)});
    // std.debug.print("{}\n", .{applyML(mr, applyML(mt, l))});
    // std.debug.print("{}\n", .{applyML(mt, applyML(mr, l))});

    const mr_l = applyML(mr, l);
    const mt_l = applyML(mt, l);
    const mtr_l = applyML(mulMM(mr, mt), l);
    const mrt_l = applyML(mulMM(mt, mr), l);
    const mt_mr_l = applyML(mr, applyML(mt, l));
    const mr_mt_l = applyML(mt, applyML(mr, l));

    try std.testing.expect(approxEqAbs(mr_l, f32x4(1, 1, -1, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mt_l, f32x4(1, -1, -1, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mtr_l, f32x4(1, 1, -1, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mrt_l, f32x4(1, 1, -5, 0), 1e-3));
    try std.testing.expect(approxEqAbs(mrt_l, mr_mt_l, 1e-3));
    try std.testing.expect(approxEqAbs(mtr_l, mt_mr_l, 1e-3));
}

// adapted from zmath, used in tests
fn approxEqAbs(v0: F32x4, v1: F32x4, eps: f32) bool {
    comptime var i: comptime_int = 0;
    inline while (i < 4) : (i += 1) {
        if (!std.math.approxEqAbs(f32, v0[i], v1[i], eps)) {
            return false;
        }
    }
    return true;
}
