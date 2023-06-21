const std = @import("std");
const garlic = @import("garlic");

const ga = garlic.CL201;

const gridsize = 80;
const bottom = 0;
const top = 10;
const left = 0;
const right = 5;

var renderbuffer: [gridsize * gridsize]u8 = [_]u8{' '} ** (gridsize * gridsize);

var circles = [_]ga.Translator{
    ga.Translator.fromCart(1.5, 2),
    ga.Translator.fromCart(3.5, 5),
    ga.Translator.fromCart(2.5, 7),
};
var radii = [_]f32{ 1.0, 0.5, 0.75 };
var velocities = [_]ga.Direction{
    ga.Direction{ .e20 = 0.1, .e01 = 0.0 },
    ga.Direction{ .e20 = 0.0, .e01 = 0.1 },
    ga.Direction{ .e20 = -0.1, .e01 = -0.1 },
};

fn draw() void {
    // probably very bad drawing function
    renderbuffer = [_]u8{' '} ** (gridsize * gridsize);
    std.debug.print("\x1B[2J\x1B[H", .{});

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
        c.* = ga.add(c.*, ga.neg(ga.mul(c.*, v.*)));
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
