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
const frame_delay_ns: u64 = 30_000_000;
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
    half_width: f32,
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
    id: u32, // used for easily removing self/duplicate collisions
};

const Manifold = struct {
    this: *Body,
    other: *Body,
    normal: ga.Line, // not normalized
    contacts: [2]ga.Point,
    n_contacts: u32, // could be smaller...
};

var bodies: std.ArrayList(Body) = undefined;
var manifolds: std.ArrayList(Manifold) = undefined;

fn setup() void {
    bodies.append(.{
        .transform = .{ 0, 0, 0, 1 },
        .motion = .{ -7, -2, -5, 0 },
        .shape = Shape{ .circle = .{ .radius = 1.0 } },
        .imass = 1.0,
        .restitution = 0.5,
        .friction = 0.5,
        .id = 0,
    }) catch unreachable;

    bodies.append(.{
        .transform = ga.initM.trans(2, 3),
        .motion = .{ 0, 0, 1, 0 },
        .shape = Shape{ .square = .{ .half_width = 1.2 } },
        .imass = 1.0,
        .restitution = 0.5,
        .friction = 0.5,
        .id = 1,
    }) catch unreachable;

    bodies.append(.{
        .transform = ga.initM.trans(-1, 4),
        .motion = .{ 0, 0, 2, 0 },
        .shape = Shape{ .circle = .{ .radius = 0.5 } },
        .imass = 0.3,
        .restitution = 0.5,
        .friction = 0.5,
        .id = 2,
    }) catch unreachable;

    // floor from infinite-mass cubes
    bodies.append(.{
        .transform = ga.mulMM(
            ga.initM.trans(-6, -10),
            ga.initM.rotCW(0.2),
        ),
        .motion = .{ 0, 0, 0, 0 },
        .shape = Shape{ .square = .{ .half_width = 6 } },
        .imass = 0.0,
        .restitution = 0.5,
        .friction = 0.5,
        .id = 3,
    }) catch unreachable;
    bodies.append(.{
        .transform = ga.mulMM(
            ga.initM.trans(6, -10),
            ga.initM.rotCCW(0.2),
        ),
        .motion = .{ 0, 0, 0, 0 },
        .shape = Shape{ .square = .{ .half_width = 6 } },
        .imass = 0.0,
        .restitution = 0.5,
        .friction = 0.5,
        .id = 4,
    }) catch unreachable;
}

// 0.5 * (dual(a) x a) = 0.5 * (dual(a)*a - a*dual(a))
// solved by for the case when a is an (e20, e01, e12) vector (i.e. point)
fn dcomm(a: ga.F32x4) ga.F32x4 {
    return .{
        -a[1] * a[2],
        a[0] * a[2],
        0,
        0,
    };
}

fn gravity(transform: ga.Motor) ga.F32x4 {
    // why is the motion representation rotated 90 degrees?
    return ga.applyMP(ga.revM(transform), ga.f32x4(9.82, 0, 0, 0));
}

fn step() void {
    for (bodies.items) |*body| {
        if (body.imass > 0) {
            // TODO is this correct use of mass?
            // seems odd that mass is applied to the commutator product, but not gravity
            body.motion += ga.f32x4s(tick * body.imass) * (gravity(body.transform) - dcomm(body.motion) * ga.f32x4s(1.0 / body.imass));
        } else {
            // infinite mass bodies ignore forces entirely
            body.motion -= ga.f32x4s(tick) * dcomm(body.motion);
        }
        body.transform -= ga.f32x4s(0.5 * tick) * ga.mulBB(body.transform, body.motion);
    }

    manifolds.clearRetainingCapacity();
    for (bodies.items) |*body_a| {
        for (bodies.items) |*body_b| {
            if (body_a.id >= body_b.id) {
                continue; // ignore duplicate/self collisions
            }

            // to simplify some logic
            // ensure that we always test sphere against cube,
            // or like against like, but never cube against sphere
            var this = body_a;
            var other = body_b;
            if (this.shape == .square and other.shape == .circle) {
                const tmp = this;
                this = other;
                other = tmp;
            }

            // ignore any kind of broad phase
            // it's not really relevant to this demo
            if (this.shape == .circle and other.shape == .circle) {
                // find worldspace coords of circle centers by transforming the origin
                const w_this = ga.normP(ga.applyMP(this.transform, ga.f32x4(0.0, 0.0, 1.0, 0.0)));
                const w_other = ga.normP(ga.applyMP(other.transform, ga.f32x4(0.0, 0.0, 1.0, 0.0)));
                const r_this = this.shape.circle.radius; // NOTE: this would panic if this.shape was a square (at least in debug mode)
                const r_other = other.shape.circle.radius; // would be cool if it did a compile time check instead
                const normal = ga.joinPP(w_this, w_other);
                const distance = @sqrt(normal[0] * normal[0] + normal[1] * normal[1]);
                if (distance > r_this + r_other) {
                    continue;
                }
                manifolds.append(Manifold{
                    .this = this,
                    .other = other,
                    .normal = normal,
                    // the sum of two points is the weighted average of their position
                    .contacts = .{ ga.normP(ga.f32x4s(r_other) * w_this + ga.f32x4s(r_this) * w_other), undefined },
                    .n_contacts = 1, // a convex shape can only touch a circle in one spot
                }) catch unreachable;
            } else if (this.shape == .square and other.shape == .square) {
                //
            } else if (this.shape == .circle and other.shape == .square) {
                //
            } else {
                @panic("Impossible shape pair");
            }
        }
    }

    for (manifolds.items) |manifold| {
        // how do we find relative velocity at the collision point when rotation is involved?
        for (0..manifold.n_contacts) |i| {
            // transform the contact to the local body frames
            const contact_this = ga.applyMP(ga.revM(manifold.this.transform), manifold.contacts[i]);
            const contact_other = ga.applyMP(ga.revM(manifold.other.transform), manifold.contacts[i]);

            // commutator product of contact and velocity rate
            const local_rate_this = ga.joinPP(
                contact_this,
                ga.Point{
                    contact_this[2] * manifold.this.motion[1] - contact_this[1] * manifold.this.motion[2],
                    contact_this[0] * manifold.this.motion[2] - contact_this[2] * manifold.this.motion[0],
                    0,
                    0,
                },
            );
            const local_rate_other = ga.joinPP(
                contact_other,
                ga.Point{
                    contact_other[2] * manifold.other.motion[1] - contact_other[1] * manifold.other.motion[2],
                    contact_other[0] * manifold.other.motion[2] - contact_other[2] * manifold.other.motion[0],
                    0,
                    0,
                },
            );

            _ = local_rate_this;
            _ = local_rate_other;
        }
    }

    for (bodies.items) |*body| {
        body.transform = ga.normM(body.transform);
    }
}

fn draw() void {
    renderbuffer = [_]u8{' '} ** (grid_height * grid_width);

    // drawLine(.{ -6, -6, 1, 0 }, .{ 6, 6, 1, 0 });
    // drawLine(.{ -4, 4, 1, 0 }, .{ 4, -4, 1, 0 });
    // drawCircle(.{ 0, 0, 0, 1 }, 3); // identity motor

    for (bodies.items) |body| {
        switch (body.shape) {
            .circle => |circle| drawCircle(body.transform, circle.radius),
            .square => |square| drawSquare(body.transform, square.half_width),
        }
    }

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

    manifolds = std.ArrayList(Manifold).init(alloc);
    defer manifolds.deinit();

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

/// draw a circle at the point indicated by transforming the origin, with given radius
fn drawCircle(transform: ga.Motor, radius: f32) void {
    const segments = 11;
    const center = ga.Point{ 0, 0, 1, 0 };
    const rim = ga.Point{ radius, 0, 1, 0 };
    drawLine(
        ga.applyMP(transform, center),
        ga.applyMP(transform, rim),
    );
    for (0..segments + 1) |_i| {
        const i = 2 * std.math.pi * @intToFloat(f32, _i % segments) / segments;
        const j = 2 * std.math.pi * @intToFloat(f32, (_i + 1) % segments) / segments;
        drawLine(
            ga.applyMP(ga.mulMM(transform, ga.initM.rotCCW(i)), rim),
            ga.applyMP(ga.mulMM(transform, ga.initM.rotCCW(j)), rim),
        );
    }
}

/// draw a square at the point indicated by transforming the origin, with given radius
fn drawSquare(transform: ga.Motor, half_width: f32) void {
    const ne = ga.applyMP(transform, ga.Point{ half_width, half_width, 1, 0 });
    const nw = ga.applyMP(transform, ga.Point{ -half_width, half_width, 1, 0 });
    const se = ga.applyMP(transform, ga.Point{ half_width, -half_width, 1, 0 });
    const sw = ga.applyMP(transform, ga.Point{ -half_width, -half_width, 1, 0 });
    drawLine(ne, nw);
    drawLine(nw, sw);
    drawLine(sw, se);
    drawLine(se, ne);
}
