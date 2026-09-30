// c128d_case.scad
//
// Printable external keyboard enclosure for the-c128-keyboard-project plate + PCB,
// intended as a replacement housing for the detached C128D / C128DCR keyboard.
// The plate, PCB and keycap measurements live in keyboard.scad.
//
// License: CC BY-SA 4.0 (LICENSE.md); credits in README.md.
//
// Everything is modeled in *plate coordinates*: the same X/Y as plate/plate.step,
// Z = 0 is the top surface of the steel plate, +Y points toward the rear of the
// keyboard (away from the typist).  The floor of the case is tilted by `tilt`
// degrees relative to the plate so the finished keyboard has a typing angle while
// still printing flat.
//
// The case is four printed parts so that each one fits a 256 x 256 mm bed
// (Bambu P2S in my setup):
//
//   tray_left / tray_right    bottom tray, joined by a lap joint at `tray_split_x`
//   bezel_left / bezel_right  top frame, butt-joined at `bezel_split_x`
//
// The two split lines are staggered so each bezel half straddles the tray joint.
//
// Fixings (all M3):
//   4x  M3x6 wafer / ultra-low-profile head (<= 0.9 mm tall)
//                               plate -> rear tray bosses (heat-set inserts).  The heads sit in shallow
//                               pockets in the bezel underside, so the bezel top stays one flat plane
//                               and prints face-down with no supports.
//   5x  M3x8                    floor -> rear bezel columns (heat-set inserts), through the plate's rear slots
//   2x  M3x8                    floor -> front bezel columns (self-tapping), through the plate's 6.5 mm holes
//
// Render a single part with e.g.:  openscad -o tray_left.stl -D 'part="tray_left"' c128d_case.scad
//
// How the file is organized:
//   parameters          everything you might tune, with units and why
//   keyboard            keyboard.scad: plate/PCB features from plate.step and the KiCad board
//   derived             positions and heights computed from the above (no tuning here)
//   helpers             2D outlines, the tilted floor frame, posts
//   key opening         the bezel's keycap windows
//   tray                bottom shell: shell, features (bosses, ledges), cuts, hooks' pockets, split
//   bezel               top frame: slab, cuts, columns, skirt, hook tabs, split
//   reference geometry  a plate and PCB stand-in for the assembly view
//   output              print orientation and the part selector
//
// Conventions: modules named *2d() return 2D outlines meant for linear_extrude();
// *_cuts() modules are always subtracted; anything with "floorf" in it works in the
// tilted floor frame (see helpers).

part = "assembly"; // ["assembly","tray","bezel","tray_left","tray_right","bezel_left","bezel_right"]
crop = [];         // optional [x0, y0, x1, y1] (plate coords) to show only a region of the assembly
show = ["tray", "bezel", "plate"];  // what to include in the assembly view

/* ---------------------------------------------------------------- parameters */

tilt          = 5;      // typing angle, degrees.  0 = flat.
wall          = 2.4;    // side wall thickness (6 perimeters at 0.4 mm)
floor_t       = 3.0;    // floor thickness
plate_gap     = 2.0;    // plate edge -> inside of wall.  Also houses the bezel skirt.
corner_r      = 6;      // outer vertical corner radius

under_pcb     = 6.0;    // clearance under the PCB at the front wall (rear is deeper because of the tilt)

bezel_gap     = 0.3;    // bezel underside sits this far above the plate top (= tray wall top)
bezel_t       = 2.6;    // bezel top plate thickness.  Top sits 2.9 mm above the plate; measured pressed keycap skirts sit >= 3.8 mm
bezel_cham    = 1.2;    // 45 deg chamfer on the outer top edge
open_cham     = 0.8;    // 45 deg chamfer on the key opening edge
key_clear     = 1.2;    // gap between keycap envelope and bezel opening
skirt_t       = 1.2;    // bezel skirt that drops into plate_gap for alignment
skirt_h       = 1.6;
group_openings = true;  // one opening per key group (like the original C128 top case) instead of one big hole

plate_screw_head_h = 0.9;  // head height of the plate screws.  Wafer/ultra-low-profile M3 = 0.5-0.8; 0.9 gives a deeper pocket
plate_screw_head_d = 6.0;  // head diameter.  Taller heads than the bezel can pocket force a raised rear
                           // deck, which then needs supports when printing the bezel face-down.

insert_d      = 4.0;    // hole for M3 heat-set inserts
insert_depth  = 6.0;
tap_d         = 2.6;    // self-tapping M3 hole (front bezel columns are only 6 mm dia, so we can't use the heat-set inserts here)
screw_clear_d = 3.4;
cbore_d       = 6.5;
cbore_depth   = 1.5;

tray_split_x  = -5;     // tray lap joint position (plate X)
bezel_split_x = 30;     // bezel joint position (plate X), measured at the bezel underside
lap           = 8;      // floor lap length
lap_w         = 6;      // wall lap length
joint_clear   = 0.15;
// Bezel joint: a 45 deg scarf through the slab (the left half's top surface rides over the
// right half by bezel_t, a ~3.7 mm wide sloped glue face) plus a stagger in the skirt so the
// halves key together.  45 deg prints without supports on both halves; do not go shallower.
bezel_scarf   = 45;     // scarf angle from horizontal
skirt_lap     = 8;      // the left half's skirt runs this far past the joint

rear_port     = "db25"; // ["db25","cable","none"]
port_x        = 43;     // center of the rear port (plate X).  Keep clear of the columns/bosses.
cable_d       = 9;      // for rear_port = "cable"

foot_d        = 12.5;   // rubber bumper recesses in the underside
foot_depth    = 1.0;

front_ledge   = true;   // rest strip under the plate's front edge
side_ledge    = true;   // rest strips under the plate's side edges
clamp_bump    = 0.35;   // bump on the bezel underside around the front columns that presses the plate down

// Front snap hooks. These sort of work, but not really.
front_hooks   = true;
hook_x        = [-110, -14, 14, 120];  // tab centers along the front wall (plate X)
hook_w        = 10;     // tab width
hook_t        = 1.2;    // tab thickness (= skirt_t; the tab is a taller piece of skirt)
hook_len      = 11;     // tab length below the bezel underside (floor is ~12.6 below the plate at the front)
hook_bump     = 0.8;    // catch protrusion beyond the tab face; it sits 0.2 from the wall, so 0.6 engages
hook_catch_h  = 2.0;    // catch height, 45 deg lead-in below and 45 deg release above
hook_clear    = 0.25;   // pocket clearance around the catch
hook_pocket_d = 1.0;    // pocket depth into the wall inner face (leaves wall - 1.0 outside)
hook_release  = 55;     // angle of the catch's top (release) face, degrees from horizontal.
                        // 45 = symmetric, lifts off easily; 60-70 holds harder; 90 = permanent
hook_guide    = false;  // rib behind each tab that only allows the deflection the catch needs,
                        // so the tab bends and snaps instead of leaning away.  Harder to open.
hook_guide_t  = 1.2;    // rib thickness (ends 0.4 mm short of the PCB edge)

$fn = 48;

/* ---------------------------------------------------------------- keyboard */

include <keyboard.scad>

groups = group_openings ? key_groups : [[KX0, KY0, KX1, KY1]];
pin_d  = pin_hole_d - 0.4;   // locating pins, 0.2 mm clearance a side

/* ---------------------------------------------------------------- derived */

cav_x0 = PX0 - plate_gap; cav_x1 = PX1 + plate_gap;
cav_y0 = PY0 - plate_gap; cav_y1 = PY1 + plate_gap;
cav_r  = 2;
out_x0 = cav_x0 - wall; out_x1 = cav_x1 + wall;
out_y0 = cav_y0 - wall; out_y1 = cav_y1 + wall;

// Bezel underside and top.  The plate screws' heads stand above the plate; if they are
// taller than bezel_gap they are pocketed into the bezel underside (head_pocket), and only
// if even that is not enough does the rear of the bezel rise (deck_raise) - which costs
// support-free printing, hence the warning below.  With wafer heads deck_raise is 0.
z_top       = bezel_gap;                       // tray wall top / bezel underside
main_top    = z_top + bezel_t;                 // bezel top surface
head_need   = plate_screw_head_h + 0.3 - bezel_gap;         // extra clearance needed above the plate for the screw heads
head_pocket = max(0, min(head_need, bezel_t - 1.2));         // how much of that we pocket into the bezel underside
deck_raise  = max(0, head_need - head_pocket);               // remainder becomes a raised rear deck (0 with wafer heads)
deck_under  = z_top + deck_raise;                            // rear bezel underside / column top
deck_top    = main_top + deck_raise;
depth_front = plate_t + plate_to_pcb + pcb_t + under_pcb;  // floor (inside) below plate top at the front wall

open_y1  = KY1 + key_clear;                    // rear edge of key opening
y_deck0  = open_y1;                            // deck slope starts here
y_pocket0 = y_deck0 + 1.4;

// The floor is tilted by `tilt` about the front wall, so its height depends on y.
// zfl(y): z (plate frame) of the floor's inside surface at plate-y.  Front wall: -depth_front.
// yf(y):  distance along the tilted floor from the front wall to plate-y; use it to place
//         things in the floor frame (floorf) that were measured in plate y.
function zfl(y) = -depth_front - (y - cav_y0) * tan(tilt);
function yf(y)  = (y - cav_y0) / cos(tilt);    // plate y -> floor-frame y'

port_z = (zfl(cav_y1) - plate_t) / 2;

feet = [[out_x0 + 16, cav_y0 + 13], [(out_x0 + out_x1) / 2, cav_y0 + 13], [out_x1 - 16, cav_y0 + 13],
        [out_x0 + 16, cav_y1 - 13], [(out_x0 + out_x1) / 2, cav_y1 - 13], [out_x1 - 16, cav_y1 - 13]];

echo(str("case footprint: ", out_x1 - out_x0, " x ", out_y1 - out_y0, " mm"));
echo(str("height front ", main_top + depth_front + floor_t, " mm, rear ~",
         main_top + depth_front + floor_t + (out_y1 - out_y0) * tan(tilt), " mm"));
if (deck_raise > 0) echo(str("WARNING: plate screw heads too tall to pocket; rear deck raised ", deck_raise,
                             " mm.  The bezel will need supports.  Use wafer-head screws or raise bezel_t."));
if (front_hooks) echo(str("hook tab bending strain ~", round(1000 * 1.5 * hook_t * (hook_bump - 0.2) / (hook_len * hook_len)) / 10,
                          " %  (keep under ~1 % for PETG/ASA)"));
echo(str("tray halves: ", tray_split_x - out_x0, " / ", out_x1 - tray_split_x,
         "   bezel halves: ", bezel_split_x + skirt_lap - out_x0, " / ", out_x1 - bezel_split_x));

/* ---------------------------------------------------------------- helpers */

// rrect: 2D rectangle from (x0,y0) to (x1,y1) with corner radius r.
module rrect(x0, y0, x1, y1, r) {
    translate([x0 + r, y0 + r]) offset(r = r) square([x1 - x0 - 2 * r, y1 - y0 - 2 * r]);
}
// outer2d: the case's outside outline; cav2d: the cavity inside the walls (plate + plate_gap).
// `inset` shrinks the outline by that much on every side (negative grows it); used for
// chamfers (outer2d(bezel_cham)) and for the skirt (cav2d(0.2) minus cav2d(0.2 + skirt_t)).
module outer2d(inset = 0) { rrect(out_x0 + inset, out_y0 + inset, out_x1 - inset, out_y1 - inset, corner_r - inset); }
module cav2d(inset = 0)   { rrect(cav_x0 + inset, cav_y0 + inset, cav_x1 - inset, cav_y1 - inset, max(cav_r - inset, 0.01)); }
// halfplane_y: everything with y >= y0, for intersecting "the rear part of" an outline.
module halfplane_y(y0)    { translate([-1000, y0]) square([2000, 2000]); }

// floorf: the tilted floor frame.  Children are drawn with the floor horizontal, then
// tilted and placed: the frame's origin is the front wall's inner face at the floor's inside
// surface, its y' axis runs up the floor toward the rear, and z' = 0 is the floor's inside
// surface (floor material occupies z' in [-floor_t, 0]).  Use yf() to convert plate y to y'.
module floorf() { translate([0, cav_y0, -depth_front]) rotate([-tilt, 0, 0]) children(); }
// Half-spaces bounded by the tilted floor, for trimming: above_floor_inside keeps what is
// above the floor's inside surface (the cavity); above_floor_outside keeps what is above the
// floor's underside (the whole case including the floor).  Intersect with these to give a
// vertical extrusion a tilted bottom.
module above_floor_inside()  { floorf() translate([-1000, -1000, 0])        cube([2000, 2000, 300]); }
module above_floor_outside() { floorf() translate([-1000, -1000, -floor_t]) cube([2000, 2000, 300]); }

// post: a cylinder of diameter d standing on the floor at (x, y), top at z1 (plate frame).
// It starts 0.6 mm below the floor's inside surface so it fuses with the floor regardless of
// the tilt.  Used for the plate bosses and corner rests.
module post(x, y, d, z1) {
    z0 = zfl(y) - floor_t + 0.6;
    translate([x, y, z0]) cylinder(d = d, h = z1 - z0);
}

/* ---------------------------------------------------------------- key opening */

// opening_piece2d: one keycap window, grown by key_clear (+ grow) on every side.  Pieces
// 0..len(groups)-1 are the key groups (or the single big envelope when group_openings is
// off); piece len(groups) is the spacebar, which hangs below the main block.  Each piece
// is convex so bezel_cuts() can hull it on its own for the chamfer; hulling the union
// would fill the inside corners between groups.
module opening_piece2d(i, grow = 0) {
    c = key_clear + grow;
    if (i < len(groups)) {
        g = groups[i];
        translate([g[0] - c, g[1] - c]) square([g[2] - g[0] + 2 * c, g[3] - g[1] + 2 * c]);
    } else {
        translate([space_cx - space_cap_w / 2 - c, space_cy - space_cap_d / 2 - c])
            square([space_cap_w + 2 * c, main_y0 - (space_cy - space_cap_d / 2) + c + 1]);
    }
}
// opening2d: all the windows together.
module opening2d(grow = 0) { for (i = [0 : len(groups)]) opening_piece2d(i, grow); }

/* ---------------------------------------------------------------- tray */

// tray_shell: walls and floor.  Outer outline extruded up to the wall top and trimmed to the
// floor's underside, minus the cavity trimmed to the floor's inside surface.  The tilt comes
// entirely from the two above_floor_* trims, so the walls stay vertical and print cleanly.
module tray_shell() {
    difference() {
        intersection() {
            translate([0, 0, -120]) linear_extrude(120 + z_top) outer2d();
            above_floor_outside();
        }
        intersection() {
            translate([0, 0, -120]) linear_extrude(240) cav2d();
            above_floor_inside();
        }
    }
}

// tray_features: everything added to the shell inside the cavity.
//   * four rear bosses the plate screws into, each with a rib back to the rear wall;
//   * two rear-corner bosses carrying 4.6 mm pins into the plate's 5 mm locating holes;
//   * two front-corner rests carrying 3.1 mm pins into the plate's front M3 holes (no screws
//     there; the bezel's front columns clamp that corner down);
//   * thin ledges under the plate's front and side edges so it cannot sag between bosses.
// Everything the plate rests on tops out at -plate_t, i.e. the plate's underside.
module tray_features() {
    // rear plate bosses, ribbed to the rear wall
    for (x = rear_holes_x) hull() {
        post(x, rear_hole_y, 7, -plate_t);
        translate([x - 3.5, cav_y1 - 0.5, zfl(cav_y1) - floor_t + 0.6]) cube([7, 1, -plate_t - (zfl(cav_y1) - floor_t + 0.6)]);
    }
    // locating pin bosses at the rear corners
    for (p = pin_holes) {
        post(p[0], p[1], 7, -plate_t);
        translate([p[0], p[1], -plate_t - 0.1]) cylinder(d = pin_d, h = plate_t - 0.2);
    }
    // front corner rests with a pin through the plate's M3 holes
    for (p = front_holes) {
        post(p[0], p[1], 7, -plate_t);
        translate([p[0], p[1], -plate_t - 0.1]) cylinder(d = 3.1, h = plate_t - 0.2);
    }
    // ledges under the plate edges
    if (front_ledge) intersection() {
        translate([cav_x0, cav_y0 - 1, zfl(cav_y0) - floor_t]) cube([cav_x1 - cav_x0, (PY0 + 1.24) - (cav_y0 - 1), -plate_t - (zfl(cav_y0) - floor_t)]);
        above_floor_outside();
    }
    if (side_ledge) intersection() {
        union() {
            translate([cav_x0 - 1, cav_y0, zfl(cav_y1) - floor_t]) cube([(PX0 + 2.0) - (cav_x0 - 1), cav_y1 - cav_y0, -plate_t - (zfl(cav_y1) - floor_t)]);
            translate([PX1 - 2.0, cav_y0, zfl(cav_y1) - floor_t]) cube([(cav_x1 + 1) - (PX1 - 2.0), cav_y1 - cav_y0, -plate_t - (zfl(cav_y1) - floor_t)]);
        }
        above_floor_outside();
    }
}

// tray_cuts: everything subtracted from the tray.  Heat-set insert holes in the rear bosses,
// the seven counterbored screw holes through the floor for the bezel columns, the rubber-foot
// recesses, the rear connector opening (DB25 panel cutout or a plain cable hole), and the
// snap-hook pockets.
module tray_cuts() {
    // insert holes in the rear bosses
    for (x = rear_holes_x) translate([x, rear_hole_y, -plate_t - insert_depth]) cylinder(d = insert_d, h = insert_depth + 1);
    // bezel column screws through the floor, counterbored from below
    for (c = rear_cols) column_floor_hole(c[0], rear_col_y);
    for (c = front_cols) column_floor_hole(c[0], c[1]);
    // rubber feet
    for (f = feet) floorf() translate([f[0], yf(f[1]), -floor_t - 1]) cylinder(d = foot_d, h = 1 + foot_depth);
    // rear port
    if (rear_port == "db25") translate([port_x, out_y1 - wall / 2, port_z]) rotate([90, 0, 0]) {
        linear_extrude(wall + 4, center = true) hull() for (sx = [-1, 1]) translate([sx * (41.6 / 2 - 1.5), 0]) circle(r = 1.5, $fn = 24) ;
        linear_extrude(wall + 4, center = true) square([41.6, 12.8], center = true);
        for (sx = [-1, 1]) translate([sx * 23.52, 0, 0]) cylinder(d = 3.2, h = wall + 4, center = true, $fn = 24);
    }
    if (rear_port == "cable") translate([port_x, out_y1 - wall / 2, port_z]) rotate([90, 0, 0])
        cylinder(d = cable_d, h = wall + 4, center = true);
    // snap-hook pockets in the front wall and ledge relief behind the tabs
    if (front_hooks) for (x = hook_x) hook_pocket(x);
}

// hook_pocket: what the tray gives up for one snap tab at plate-x.  A blind pocket in the
// front wall's inner face where the catch lands, and a relief in the front ledge behind the
// tab so the tab can hang down and flex inward.
module hook_pocket(x) {
    zc = z_top - hook_len;                       // bottom of the catch
    // blind pocket in the wall's inner face
    translate([x - hook_w / 2 - hook_clear, cav_y0 - hook_pocket_d, zc - hook_clear])
        cube([hook_w + 2 * hook_clear, hook_pocket_d + 0.01, hook_catch_h + 2 * hook_clear]);
    // relieve the front ledge from the wall face to its inner edge so the tab can hang and flex
    translate([x - hook_w / 2 - 1, cav_y0 - 0.01, zc - 1])
        cube([hook_w + 2, (PY0 + 1.24) - cav_y0 + 0.02, -plate_t - (zc - 1)]);
}

// hook_guide_rib: optional (hook_guide) rib standing on the floor behind a tab.  It leaves the
// tab exactly the room the catch needs to clear the wall top (bump - 0.2 standoff +
// clearance), so the tab has to bend and then snaps back instead of leaning away into the
// cavity.  Firmer click, harder to open.
module hook_guide_rib(x) {
    zc = z_top - hook_len;
    y0 = cav_y0 + 0.2 + hook_t + (hook_bump - 0.2) + hook_clear;   // rib face
    intersection() {
        translate([x - hook_w / 2 - 1, y0, zc - 1]) cube([hook_w + 2, hook_guide_t, -plate_t - 0.3 - (zc - 1)]);
        above_floor_inside();
    }
}

// column_floor_hole: a screw hole through the floor under a bezel column, counterbored from
// below so the screw head sits inside the floor.
module column_floor_hole(x, y) {
    translate([x, y, -120]) cylinder(d = screw_clear_d, h = 120);
    translate([x, y, -120]) cylinder(d = cbore_d, h = 120 + zfl(y) - (floor_t - cbore_depth));
}

// tray: the complete bottom shell in one piece (shell + features - cuts, plus guide ribs).
module tray() {
    difference() {
        union() { tray_shell(); tray_features(); }
        tray_cuts();
    }
    if (front_hooks && hook_guide) for (x = hook_x) hook_guide_rib(x);
}

// tray_joint: the lap-joint region at the tray split, used both ways.  It covers the upper
// half of the floor for `lap` mm past the split and the outer half of the front and rear
// walls for `lap_w` mm.  tray_left keeps this region shrunk by joint_clear (the tongue);
// tray_right has it grown by joint_clear removed (the pocket), so the halves slide together
// with 0.15 mm of clearance.
module tray_joint(c) {
    xs = tray_split_x;
    // upper half of the floor between the wall inner faces
    floorf() translate([xs - 1, -c, -floor_t / 2 + c])
        cube([lap + 1 - c, yf(cav_y1) + 2 * c, floor_t / 2 - c + 0.01]);
    // outer half of the front and rear walls, full height, including the floor beneath them
    translate([xs - 1, out_y0 - 1, -150]) cube([lap_w + 1 - c, wall / 2 + 1 + c, 300]);
    translate([xs - 1, out_y1 - wall / 2 - c, -150]) cube([lap_w + 1 - c, wall / 2 + 1 + c, 300]);
}

// tray_left / tray_right: the two printable halves.  Left is everything west of the split
// plus the tongue; right is everything east of the split minus the pocket.
module tray_left() {
    union() {
        intersection() { tray(); translate([-1000, -500, -200]) cube([1000 + tray_split_x, 1000, 400]); }
        intersection() { tray(); tray_joint(-joint_clear); }
    }
}
module tray_right() {
    difference() {
        intersection() { tray(); translate([tray_split_x, -500, -200]) cube([1000, 1000, 400]); }
        tray_joint(joint_clear);
    }
}

/* ---------------------------------------------------------------- bezel */

// bezel_slab: the top plate of the bezel, a hull of two extrusions so the outer top edge gets
// a 45 deg chamfer.  If the plate screw heads cannot be fully pocketed (deck_raise > 0) a
// raised rear deck is hulled on with a 45 deg slope at its front; with wafer heads it is not.
module bezel_slab() {
    // main slab with chamfered outer top edge
    hull() {
        translate([0, 0, z_top]) linear_extrude(bezel_t - bezel_cham) outer2d();
        translate([0, 0, z_top]) linear_extrude(bezel_t) outer2d(bezel_cham);
    }
    // raised rear deck with a 45 deg slope at its front (only if the screw heads can't be pocketed)
    if (deck_raise > 0) hull() {
        translate([0, 0, z_top]) linear_extrude(bezel_t - bezel_cham) intersection() { outer2d();           halfplane_y(y_deck0); }
        translate([0, 0, z_top]) linear_extrude(bezel_t)              intersection() { outer2d(bezel_cham); halfplane_y(y_deck0 + bezel_cham); }
        translate([0, 0, z_top]) linear_extrude(deck_top - z_top - bezel_cham) intersection() { outer2d();           halfplane_y(y_deck0 + deck_raise); }
        translate([0, 0, z_top]) linear_extrude(deck_top - z_top)              intersection() { outer2d(bezel_cham); halfplane_y(y_deck0 + deck_raise + bezel_cham); }
    }
}

// bezel_cuts: the keycap windows (straight through, plus a hull per piece for the small top
// chamfer), the hollow under a raised rear deck if there is one, and the shallow pockets in
// the underside over the four plate screw heads.
module bezel_cuts() {
    // key openings with a small chamfer on the top edge
    translate([0, 0, z_top - 1]) linear_extrude(10) opening2d();
    for (i = [0 : len(groups)]) hull() {
        translate([0, 0, main_top - open_cham]) linear_extrude(0.01) opening_piece2d(i);
        translate([0, 0, main_top]) linear_extrude(1) opening_piece2d(i, open_cham);
    }
    // hollow under the rear deck (only if raised)
    if (deck_raise > 0) translate([0, 0, z_top - 1]) linear_extrude(deck_under - z_top + 1)
        intersection() { cav2d(skirt_t + 0.2); halfplane_y(y_pocket0); }
    // shallow pockets over the plate screw heads
    if (head_pocket > 0) for (x = rear_holes_x)
        translate([x, rear_hole_y, deck_under - 1]) cylinder(d = plate_screw_head_d + 1.5, h = 1 + head_pocket);
}

// bezel_columns: the seven columns that hang from the bezel to the floor and take the screws
// from below.  Five rear columns pass through the plate's rear slots and notches (heat-set
// inserts); two front columns pass through the plate's 6.5 mm corner holes (self-tapping,
// they are only 6 mm across) and carry a small bump that presses the plate onto its rest.
module bezel_columns() {
    // rear columns through the plate's slots, heat-set inserts
    for (c = rear_cols) bezel_column(c[0], rear_col_y, c[1], deck_under, insert_d, insert_depth);
    // front columns through the 6.5 mm holes, self tapping
    for (c = front_cols) {
        bezel_column(c[0], c[1], 6.0, z_top, tap_d, 8);
        translate([c[0], c[1], z_top - clamp_bump]) cylinder(d = 11, h = clamp_bump + 0.01);
    }
}

// bezel_column: one column of diameter d from 0.2 mm above the floor up to ztop, with a
// screw hole of diameter hole_d and depth hole_h up from the floor.
module bezel_column(x, y, d, ztop, hole_d, hole_h) {
    difference() {
        intersection() {
            translate([x, y, -120]) cylinder(d = d, h = 120 + ztop);
            floorf() translate([-1000, -1000, 0.2]) cube([2000, 2000, 300]);
        }
        translate([x, y, -120]) cylinder(d = hole_d, h = 120 + zfl(y) + hole_h + 1);
    }
}

// bezel_skirt: a thin lip hanging from the bezel underside into the gap between the plate
// edge and the wall (plate_gap), 0.2 mm off the wall.  It registers the bezel to the tray.
module bezel_skirt() {
    translate([0, 0, z_top - skirt_h]) linear_extrude(skirt_h + 0.01)
        difference() { cav2d(0.2); cav2d(0.2 + skirt_t); }
}

// bezel_hook: one snap tab at plate-x.  A taller piece of skirt (hook_len long) with a catch
// on its wall-facing side: a (y, z) profile extruded along x, 45 deg lead-in on the bottom so
// it rides over the wall top, hook_release deg on the top so it can be lifted off again.
module bezel_hook(x) {
    y0 = cav_y0 + 0.2;                           // tab outer face, 0.2 off the wall like the skirt
    z0 = z_top - hook_len;
    translate([x - hook_w / 2, y0, z0]) cube([hook_w, hook_t, hook_len + 0.01]);
    // catch: (y, z) profile extruded along x; 45 deg lead-in below, `hook_release` above
    rel = hook_bump / tan(hook_release);        // vertical run of the release face
    translate([x - hook_w / 2 + 1, 0, 0]) rotate([90, 0, 90]) linear_extrude(hook_w - 2)
        polygon([[y0 + 0.01, z0], [y0 - hook_bump, z0 + hook_bump],
                 [y0 - hook_bump, z0 + hook_catch_h - rel], [y0 + 0.01, z0 + hook_catch_h]]);
}

// bezel: the complete top frame in one piece.
module bezel() {
    union() {
        difference() { bezel_slab(); bezel_cuts(); }
        bezel_columns();
        bezel_skirt();
        if (front_hooks) for (x = hook_x) bezel_hook(x);
    }
}

// bezel_left_region: the volume that belongs to the left bezel half, with the joint shifted
// +c in x.  Above the underside it is bounded by a plane rising at bezel_scarf deg from
// (split, z_top), so the left half's top surface rides over the right half on a sloped glue
// face; below the underside (skirt and hook tabs) the cut is straight at split + skirt_lap,
// so the two halves key together.  bezel_left keeps it; bezel_right removes it grown by
// joint_clear.
module bezel_left_region(c = 0) {
    xs = bezel_split_x + c;
    run = 40 / tan(bezel_scarf);                     // x run of the scarf over 40 mm of height
    translate([0, 500, 0]) rotate([90, 0, 0]) linear_extrude(1000)
        polygon([[-1000, z_top - 0.01], [xs, z_top - 0.01], [xs + run, z_top + 40], [-1000, z_top + 40]]);
    translate([-1000, -500, -200]) cube([1000 + xs + skirt_lap, 1000, 200 + z_top]);
}
module bezel_left()  { intersection() { bezel(); bezel_left_region(0); } }
module bezel_right() { difference()   { bezel(); bezel_left_region(joint_clear); } }

/* ---------------------------------------------------------------- reference geometry */

// plate_ref: stand-ins for the steel plate (with its holes, slots and key openings) and the
// PCB, for the assembly view only.  Not printed.
module plate_ref() {
    color("silver") translate([0, 0, -plate_t]) linear_extrude(plate_t) difference() {
        translate([PX0, PY0]) square([PX1 - PX0, PY1 - PY0]);
        for (x = rear_holes_x) translate([x, rear_hole_y]) circle(d = plate_hole_d);
        for (p = front_holes) translate(p) circle(d = plate_hole_d);
        for (p = front_cols) translate(p) circle(d = front_col_hole_d);
        for (p = pin_holes) translate(p) circle(d = pin_hole_d);
        for (c = rear_cols) hull() { translate([c[0], rear_hole_y]) circle(d = 9); translate([c[0] - 4.5, rear_hole_y]) square([9, 20]); }
        opening2d(-key_clear - 2);
    }
    color("darkgreen") translate([0, 0, -plate_t - plate_to_pcb - pcb_t]) linear_extrude(pcb_t) difference() {
        translate([PCBX0, PCBY0]) square([PCBX1 - PCBX0, PCBY1 - PCBY0]);
        for (n = pcb_notches) translate([n[0], n[1]]) square([n[2] - n[0], n[3] - n[1]]);
    }
}

/* ---------------------------------------------------------------- output */

// print_tray: tray print orientation.  The floor is tilted in the model, so rotate the part
// by `tilt` to lay the floor flat and drop it onto z = 0.
module print_tray() {
    zoff = cav_y0 * sin(tilt) - depth_front * cos(tilt) - floor_t;
    translate([0, 0, -zoff]) rotate([tilt, 0, 0]) children();
}
// print_bezel: bezel print orientation, top face down on the bed.
module print_bezel() { translate([0, 0, deck_top]) rotate([180, 0, 0]) children(); }

// cropped: if `crop` is set, keep only that [x0, y0, x1, y1] region (plate coords) of the
// children, for looking closely at one area of the model.
module cropped() {
    if (len(crop) == 4) intersection() { children(); translate([crop[0], crop[1], -100]) cube([crop[2] - crop[0], crop[3] - crop[1], 200]); }
    else children();
}

// Part selector.  The assembly view shows the halves in place with the plate/PCB stand-in;
// the printable parts are moved to the print orientation and centerd on the bed.
if (part == "assembly") cropped() {
    if (search(["tray"], show)  != [[]]) { tray_left(); tray_right(); }
    if (search(["bezel"], show) != [[]]) color("lightsteelblue") { bezel_left(); bezel_right(); }
    if (search(["plate"], show) != [[]]) plate_ref();
}
else if (part == "tray")        print_tray()  cropped() tray();
else if (part == "bezel")       print_bezel() cropped() bezel();
else if (part == "tray_left")   translate([-(out_x0 + tray_split_x) / 2, -(out_y0 + out_y1) / 2, 0]) print_tray()  cropped() tray_left();
else if (part == "tray_right")  translate([-(out_x1 + tray_split_x) / 2, -(out_y0 + out_y1) / 2, 0]) print_tray()  cropped() tray_right();
else if (part == "bezel_left")  translate([-(out_x0 + bezel_split_x) / 2, (out_y0 + out_y1) / 2, 0]) print_bezel() cropped() bezel_left();
else if (part == "bezel_right") translate([-(out_x1 + bezel_split_x) / 2, (out_y0 + out_y1) / 2, 0]) print_bezel() cropped() bezel_right();
