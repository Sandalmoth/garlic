const std = @import("std");
const garlic = @import("garlic");

const ga = garlic.CL201;

const gridsize = 80;
const bottom = 0;
const top = 10;
const left = 0;
const right = 5;
const dt = 0.001;

var renderbuffer: [gridsize * gridsize]u8 = [_]u8{' '} ** (gridsize * gridsize);

var circles = [_]ga.Motor{
    ga.Motor.fromCart(1.5, 2),
    ga.Motor.fromCart(3.5, 5),
    ga.Motor.fromCart(2.5, 7),
};
var radii = [_]f32{ 1.0, 0.5, 0.75 };
// these are not world space!
var velocities = [_]ga.Point{ga.Point{ .e20 = 0.0, .e01 = 0.0, .e12 = 0 }} ** 3;

fn draw() void {
    // probably very bad drawing function
    renderbuffer = [_]u8{' '} ** (gridsize * gridsize);
    std.debug.print("\x1B[2J\x1B[H", .{});

    // for each pixel, check if it's in the radius of any circle
    for (0..gridsize) |y| {
        for (0..gridsize) |x| {
            // surely there's a nicer way
            const p = ga.Point.fromCart(
                (@intToFloat(f32, x) + 0.5) / gridsize * (right - left),
                (@intToFloat(f32, gridsize - y - 1) + 0.5) / gridsize * (top - bottom),
            );
            for (circles, radii) |c, r| {
                if (ga.norm(ga.join(ga.apply(c, ga.Point.fromCart(0, 0)), p)) < r) {
                    renderbuffer[y * gridsize + x] = 'X';
                }
            }
        }
    }

    for (0..gridsize) |y| {
        std.debug.print("{s}\n", .{renderbuffer[(y * gridsize)..((y + 1) * gridsize)]});
    }
}

fn update() void {
    for (&circles, &velocities) |*c, *v| {
        std.debug.print("{}\t{}\n", .{ c.*, v.* });
        std.debug.print("{}\n", .{ga.mul(c.*, v.*)});
        const f = ga.dual(ga.apply(
            ga.rev(c.*),
            ga.Point{ .e20 = 0.0, .e01 = 9.82, .e12 = 0.0 },
        ));
        std.debug.print("{} {s}\n", .{ f, @typeName(@TypeOf(f)) });
        c.* = ga.add(
            c.*,
            ga.mul(ga.mul(c.*, v.*), @as(f32, -0.5 * dt)),
        );
        const dcomm = ga.Line{
            .e1 = v.e01 * v.e12,
            .e2 = -v.e20 * v.e12,
            .e0 = 0,
        };
        v.* = ga.add(
            v.*,
            ga.dual(ga.add(f, dcomm)),
        );
        std.debug.print("{}\t{}\n", .{ c.*, v.* });
    }
}

pub fn main() void {
    std.debug.assert(circles.len == radii.len);

    while (true) {
        draw();
        update();
        std.time.sleep(100_000_000);
    }
}
