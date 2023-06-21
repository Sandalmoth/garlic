const std = @import("std");
const garlic = @import("garlic");

const ga = garlic.CL201;

const gridsize = 80;
const bottom = 0;
const top = 10;
const left = 0;
const right = 5;

var renderbuffer: [gridsize * gridsize]u8 = [_]u8{' '} ** (gridsize * gridsize);

var circles = [_]ga.Point{
    ga.Point.fromCart(1.5, 2),
    ga.Point.fromCart(3.5, 5),
    ga.Point.fromCart(2.5, 7),
};
var radii = [_]f32{ 1.0, 0.5, 0.75 };

pub fn draw() void {
    // probably very bad drawing function
    renderbuffer = [_]u8{' '} ** (gridsize * gridsize);
    std.debug.print("\x1B[2J\x1B[H", .{});

    for (&circles, radii) |*c, r| {
        _ = r;
        c.toCart();
    }

    for (0..gridsize) |y| {
        for (0..gridsize) |x| {
            // surely there's a nicer way
            const p = ga.Point.fromCart(
                (@intToFloat(f32, x) + 0.5) / gridsize * (right - left),
                (@intToFloat(f32, gridsize - y - 1) + 0.5) / gridsize * (top - bottom),
            );
            for (circles, radii) |c, r| {
                if (ga.norm(ga.join(c, p)) < r) {
                    renderbuffer[y * gridsize + x] = 'O';
                }
            }
        }
    }

    for (0..gridsize) |y| {
        std.debug.print("{s}\n", .{renderbuffer[(y * gridsize)..((y + 1) * gridsize)]});
    }
}

pub fn main() void {
    std.debug.assert(circles.len == radii.len);

    draw();
}
