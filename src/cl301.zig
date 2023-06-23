// I wonder if we could compile-time generate some of this

// NOTE layouts of the vectors is selected to make dual
// - free for the plane/point cases
// - simple for the line/motor cases
// but we may want to reconsider details

pub const Plane = struct {
    data: @Vector(4, f32),

    pub inline fn e0(plane: Plane) f32 {
        return plane.data[0];
    }
    pub inline fn e1(plane: Plane) f32 {
        return plane.data[1];
    }
    pub inline fn e2(plane: Plane) f32 {
        return plane.data[2];
    }
    pub inline fn e3(plane: Plane) f32 {
        return plane.data[3];
    }

    pub fn dual(plane: Plane) Point {
        return Point{ .data = plane.data };
    }
};

pub const Line = struct {
    data: @Vector(8, f32),

    pub inline fn s(line: Line) f32 {
        return line.data[0];
    }
    pub inline fn e12(line: Line) f32 {
        return line.data[1];
    }
    pub inline fn e31(line: Line) f32 {
        return line.data[2];
    }
    pub inline fn e23(line: Line) f32 {
        return line.data[3];
    }
    pub inline fn ps(line: Line) f32 {
        return line.data[4];
    }
    pub inline fn e03(line: Line) f32 {
        return line.data[5];
    }
    pub inline fn e02(line: Line) f32 {
        return line.data[6];
    }
    pub inline fn e01(line: Line) f32 {
        return line.data[7];
    }

    pub fn dual(line: Line) Line {
        return Line{ .data = @shuffle(
            f32,
            line.data,
            undefined,
            @Vector(8, i32){ 4, 5, 6, 7, 0, 1, 2, 3 },
        ) };
    }
};

pub const Point = struct {
    data: @Vector(4, f32),

    pub inline fn e123(point: Point) f32 {
        return point.data[0];
    }
    pub inline fn e032(point: Point) f32 {
        return point.data[1];
    }
    pub inline fn e013(point: Point) f32 {
        return point.data[2];
    }
    pub inline fn e021(point: Point) f32 {
        return point.data[3];
    }

    pub fn dual(point: Point) Plane {
        return Plane{ .data = point.data };
    }
};

pub const Motor = struct {
    data: @Vector(8, f32),

    pub inline fn s(line: Line) f32 {
        return line.data[0];
    }
    pub inline fn e12(line: Line) f32 {
        return line.data[1];
    }
    pub inline fn e31(line: Line) f32 {
        return line.data[2];
    }
    pub inline fn e23(line: Line) f32 {
        return line.data[3];
    }
    pub inline fn ps(line: Line) f32 {
        return line.data[4];
    }
    pub inline fn e03(line: Line) f32 {
        return line.data[5];
    }
    pub inline fn e02(line: Line) f32 {
        return line.data[6];
    }
    pub inline fn e01(line: Line) f32 {
        return line.data[7];
    }

    pub fn dual(motor: Motor) Motor {
        return Motor{ .data = @shuffle(
            f32,
            motor.data,
            undefined,
            @Vector(8, i32){ 4, 5, 6, 7, 0, 1, 2, 3 },
        ) };
    }
};
