// roughly based on https://enki.ws/ganja.js/examples/pga_dyn.html

const std = @import("std");
const garlic = @import("garlic");

const ga = garlic.CL201;

const gridsize = 80;
const bottom = 0;
const top = 10;
const left = 0;
const right = 5;

const dt = 0.001;
const dframe = 50_000_000;

var renderbuffer: [gridsize * gridsize]u8 = [_]u8{' '} ** (gridsize * gridsize);

var circles = [_]ga.Motor{
    ga.Motor.fromCart(1.5, 2),
    ga.Motor.fromCart(3.5, 5),
    ga.Motor.fromCart(2.5, 7),
};
var radii = [_]f32{ 1.0, 0.5, 0.75 };
// these are not world space!
var velocities = [_]ga.Point{ga.Point{ .e20 = 0.0, .e01 = 0.0, .e12 = 0 }} ** 3;

const corners = [_]ga.Point{
    ga.Point.fromCart(left, bottom),
    ga.Point.fromCart(right, bottom),
    ga.Point.fromCart(right, top),
    ga.Point.fromCart(left, top),
};
const walls = [_]ga.Line{
    ga.normalized(ga.join(corners[3], corners[2])),
    ga.normalized(ga.join(corners[2], corners[1])),
    ga.normalized(ga.join(corners[1], corners[0])),
    ga.normalized(ga.join(corners[0], corners[3])),
};

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
    for (&circles, &velocities, radii) |*c, *v, r| {
        std.debug.print("{}\n", .{v.*});
        // basic state update (gravity + movement)
        const f = ga.dual(ga.apply(
            ga.rev(c.*),
            ga.Point{ .e20 = 0.0, .e01 = 9.82, .e12 = 0.0 },
        ));
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
        // collision resolution
        for (walls) |w| {
            std.debug.print("{}\t{}\n", .{
                w,
                ga.normalized(ga.apply(c.*, ga.Point.fromCart(0, 0))),
            });
            const d = ga.join(
                w,
                ga.normalized(ga.apply(c.*, ga.Point.fromCart(0, 0))),
            ); // oriented distance to wall
            if (d > r) {
                continue;
            }
            // we are colliding with this wall
            std.debug.print("collision {} {} {}\n", .{ d, c.*, w });

            // transform the wall into the body space
            // and figure out the normal in body space
            // note that the center of a circle,
            // in the body space,
            // is always at the origin
            const n = ga.inner(
                ga.apply(ga.rev(c.*), w),
                ga.Point.fromCart(0, 0),
            );
            std.debug.print("{}\n", .{n});
            std.debug.print("{}\n", .{v.*});
            // somehow calculate impulse
            // const j = -(1 + 0.5) * velocity_along_normal * r * r;
            const v_along_n = ga.project(
                ga.apply(ga.rev(c.*), v.*),
                n,
            );
            std.debug.print("{}\n", .{v_along_n});
            const speed_along_n = @sqrt(v_along_n.e20 * v_along_n.e20 + v_along_n.e01 * v_along_n.e01);
            const j = -(1 + 0.5) * speed_along_n * r * r;
            v.* = ga.add(
                v.*,
                ga.mul(ga.dual(n), @as(f32, j)),
            );
        }
    }
}

pub fn main() void {
    std.debug.assert(circles.len == radii.len);

    while (true) {
        draw();
        update();
        std.time.sleep(dframe);
    }
}
