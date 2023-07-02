// roughly based on https://enki.ws/ganja.js/examples/pga_dyn.html
// and https://gamedevelopment.tutsplus.com/series/how-to-create-a-custom-physics-engine--gamedev-12715

const std = @import("std");
const ga = @import("garlic");

// physics update rates
const ticks_per_second = 240;
const tick: f32 = 1.0 / @intToFloat(f32, ticks_per_second);
const tick_ns = @floatToInt(u64, tick * 1e9);
const max_tick_ns = @floatToInt(u64, 0.1 * 1e9);

// for rendering to the terminal
const frame_delay_ns: u64 = 300_000_000;
const grid_height = 50;
const grid_width = 100;
const grid_aspect = 0.5; // height of terminal character / width of terminal character
const resolution = 10.0; // horizontal terminal characters per worldspace unit
const right = 0.5 * grid_width / resolution;
const left = -right;
const top = 0.5 * grid_height / grid_aspect / resolution;
const bottom = -top;
var renderbuffer = [_]u8{' '} ** (grid_height * grid_width);

const Circle = struct {
    radius: f32,
};
const Square = struct {
    half_length: f32,
};
const ShapeTag = enum {
    circle,
    square,
};
const Shape = union(ShapeTag) {
    circle: Circle,
    square: Square,
};

const Body = struct {
    transform: ga.Motor,
    motion: ga.Point,
    shape: Shape,
    imass: f32,
    restitution: f32,
    friction: f32,
};

var bodies: std.ArrayList(Body) = undefined;

fn setup() void {
    bodies.append(.{
        .transform = .{ 0, 0, 0, 1 },
        .motion = .{ 0, 0, 0, 0 },
        .shape = Shape{ .circle = .{ .radius = 1.0 } },
        .imass = 1.0,
        .restitution = 0.5,
        .friction = 0.5,
    }) catch unreachable;
}

fn step() void {}

/// draw a line from point a to point b
fn drawLine(a: ga.Point, b: ga.Point) void {
    // bresenhams line algorithm
    // https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
    // this formulation is so handy with how it handles any kind of line
    var x0 = @floatToInt(i32, grid_width * (a[0] - left) / (right - left) + 0.5);
    var y0 = @floatToInt(i32, grid_height * (a[1] - bottom) / (top - bottom) + 0.5);
    const x1 = @floatToInt(i32, grid_width * (b[0] - left) / (right - left) + 0.5);
    const y1 = @floatToInt(i32, grid_height * (b[1] - bottom) / (top - bottom) + 0.5);
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx = if (x0 < x1) @as(i32, 1) else @as(i32, -1);
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy = if (y0 < y1) @as(i32, 1) else @as(i32, -1);
    var err = dx + dy;

    while (true) {
        if (x0 >= 0 and x0 < grid_width and y0 >= 0 and y0 < grid_height) {
            renderbuffer[@intCast(usize, y0) * grid_width + @intCast(usize, x0)] = '#';
        }
        if (x0 == x1 and y0 == y1) {
            break;
        }
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x0 += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y0 += sy;
        }
    }
}

fn drawCircle(transform: ga.Motor, radius: f32) void {
    const segments = 9;
    const center = ga.Point{ 0, 0, 1, 0 };
    const rim = ga.Point{ radius, 0, 1, 0 };
    drawLine(
        ga.applyMP(transform, center),
        ga.applyMP(transform, rim),
    );
    for (0..segments + 1) |_i| {
        std.debug.print("{}\n", .{_i});
        const i = 2 * std.math.pi * @intToFloat(f32, _i % segments) / segments;
        const j = 2 * std.math.pi * @intToFloat(f32, (_i + 1) % segments) / segments;
        drawLine(
            ga.applyMP(ga.mulMM(transform, ga.initM.rotCCW(i)), rim),
            ga.applyMP(ga.mulMM(transform, ga.initM.rotCCW(j)), rim),
        );
    }
}

fn draw() void {
    renderbuffer = [_]u8{' '} ** (grid_height * grid_width);

    // drawLine(.{ -6, -6, 1, 0 }, .{ 6, 6, 1, 0 });
    // drawLine(.{ -4, 4, 1, 0 }, .{ 4, -4, 1, 0 });
    drawCircle(.{ 0, 0, 0, 1 }, 3); // identity motor

    std.debug.print("\x1B[2J\x1B[H", .{});
    {
        var y = @intCast(i32, grid_height) - 1;
        while (y >= 0) : (y -= 1) {
            std.debug.print("{s}\n", .{renderbuffer[(@intCast(usize, y) * grid_width)..((@intCast(usize, y) + 1) * grid_width)]});
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    bodies = std.ArrayList(Body).init(alloc);
    defer bodies.deinit();

    setup();

    var lag: u64 = 0;
    var tick_timer = try std.time.Timer.start();

    while (true) {
        lag += @min(tick_timer.lap(), max_tick_ns);

        while (lag >= tick_ns) {
            step();
            lag -= tick_ns;
        }

        draw();
        std.time.sleep(frame_delay_ns);
    }
}
