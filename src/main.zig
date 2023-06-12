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
};

test "basic functionality" {
    std.debug.print("\n", .{});
    const ga = CL201;

    const p = ga.Point.fromCartesian(2, 3);
    std.debug.print("{}\n", .{p});
    std.debug.print("{}\n", .{ga.dual(p)});
    std.debug.print("{}\n", .{ga.dual(ga.dual(p))});

    std.debug.print("{}\n", .{ga.meet(
        ga.Line.equation(1, 1, 0),
        ga.Line.equation(-1, 1, 0),
    )});
    std.debug.print("{}\n", .{ga.meet(
        ga.Line.equation(-1, 1, 0),
        ga.Line.equation(1, 1, 0),
    )});
    std.debug.print("{}\n", .{ga.meet(
        ga.Line.equation(-1, -1, 2),
        ga.Line.equation(1, -1, 0),
    )});
    std.debug.print("{}\n", .{ga.meet(
        ga.Line.equation(-1, -1, 2),
        ga.Line.equation(1, -1, 0),
    )});
    std.debug.print("{}\n", .{ga.join(
        ga.Point.fromCartesian(-1, -1),
        ga.Point.fromCartesian(1, 1),
    )});

    try std.testing.expect(true);
}
