const std = @import("std");

// for the sake of interoperability, same definition as in zmath
pub const F32x4 = @Vector(4, f32);

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
    return p / p[2];
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
    const C = s * c - u * a + v * b;
    const D = w * c + u * b + v * a;
    return .{
        s * A + w * B,
        s * B - w * A,
        s * C + w * D + u * A - v * B,
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
    // TODO test optimization
    const A = @shuffle(f32, b0, undefined, @Vector(4, i32){ 2, 3, 2, 3 });
    const B = @shuffle(f32, b1, undefined, @Vector(4, i32){ 3, 2, 2, 3 });
    const AB = A * B;
    const C = @shuffle(f32, b0, undefined, @Vector(4, i32){ 2, 3, 0, 1 });
    const D = @shuffle(f32, b0, undefined, @Vector(4, i32){ 3, 2, 1, 0 });
    return .{
        AB[3] - AB[2],
        D * b1 * @Vector(4, f32){ 1, 1, -1, 1 },
        C * b1 * @Vector(4, f32){ -1, 1, 1, 1 },
        AB[0] + AB[1],
    };
}
/// compose two motors m0, m1 to a new one performing first m1 then m0
pub inline fn mulMM(m0: Motor, m1: Motor) Motor {
    return mulBB(m0, m1);
}
