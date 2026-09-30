# Walkthrough of `c128d_case.scad`

A guided reading of the case model for someone who wants to understand it well enough to
change it with confidence.  It goes through the file in order, explains the OpenSCAD idioms
as they come up, and for every constant says where the number came from.  Line references
are given as the file's own section banners (the `/* ---- name */` comment lines), which
are stable even as the file grows.

Companion reading: `README.md` (how the case goes together, printing, hardware),
`keyboard.scad` (the plate and board measurements, section 4) and, for where those numbers
come from, [`pcb/rev3/README.md`](https://codeberg.org/jflitton/the-c128-keyboard-project/src/branch/main/pcb/rev3/README.md) in the keyboard
project.

---

## 1. The one idea that makes everything else simple: plate coordinates

Every dimension in the file is expressed in **plate coordinates**: the same X and Y as
[`plate/plate.step`](https://codeberg.org/jflitton/the-c128-keyboard-project/src/branch/main/plate/plate.step) in the keyboard project, with Z = 0 at the *top surface of the steel plate*.  +X is to the
right as you type, +Y is toward the rear (away from you), +Z is up.  The origin is
wherever the STEP file put it, near the middle of the plate, which is why the plate spans
X from -190 to +212 rather than 0 to 400.

Why do this rather than model the case from its own front-left corner?  Because every
feature the case has to line up with lives on the plate or the PCB: the four screw holes,
the corner locating holes, the slots the columns pass through, the keycap positions.  With
plate coordinates those numbers go into the file exactly as measured, no conversion, and if
the plate changes, the numbers change in one place.

The PCB uses KiCad's frame, X to the right and **Y down**, with its own origin.  The
conversion is written at the top of `keyboard.scad`:

    plate_x = kicad_x - 295.52
    plate_y = 150.02 - kicad_y

The two offsets are simply where the STEP origin lands in the KiCad frame; they came out of
the plate-to-PCB fit in [`pcb/rev3/tools/gen_plate.py`](https://codeberg.org/jflitton/the-c128-keyboard-project/src/branch/main/pcb/rev3/tools/gen_plate.py), which lays the 88 plain switch
openings of the STEP onto the 88 switch footprints of the board and reports the offset (it
matches to 0.06 mm RMS).  Every number in `keyboard.scad` (section 4) was produced by
pushing a plate or KiCad measurement through these two lines.

One more frame matters, the **tilted floor frame**, and it gets its own section (5) because
it is the only genuinely tricky part of the file.

---

## 2. How to read OpenSCAD, in five idioms

If you have not written OpenSCAD before, these cover nearly everything in the file.

**Everything is a solid or a 2D shape, and operations combine them.**  `union()` adds,
`difference()` subtracts every child after the first from the first, `intersection()` keeps
what all children share.  There are no variables you can mutate; a name is bound once.

**2D first, then extrude.**  Most shapes are drawn flat (`square`, `circle`, `polygon`,
`offset`) and then given height with `linear_extrude(h)`.  The file names 2D modules with a
`2d` suffix so you know a shape still needs extruding.

**`offset(r = x)` grows or shrinks a 2D shape** by `x`, rounding the corners when `r` is
used (as opposed to `delta`).  It is how rounded rectangles and chamfers are made here.

**`hull()` wraps its children in the tightest convex skin.**  Hull a fat short extrusion
and a thin tall one with the same footprint and you get a chamfered edge for free; hull a
post and a sliver of wall and you get a rib.  The file leans on this constantly.  The
catch is that hull fills concave corners, which is why the key openings are hulled one
convex piece at a time.

**`children()` lets a module wrap whatever you put inside its braces.**  `floorf() cube(...)`
runs the cube through the `floorf` transform.  Modules that do this (`floorf`, `print_tray`,
`print_bezel`, `cropped`) are the file's coordinate-frame changers.

Also: `$fn = 48` at the end of the parameters section sets how many segments a circle gets; 48 is smooth enough for
7 mm bosses and cheap to render.  Local `$fn = 24` on the tiny screw holes saves time.

---

## 3. Parameters: what each one is and why it has that value

These are the knobs.  Nothing below this block should need editing for a normal change.

### Selecting what to render

| name | value | meaning |
|---|---|---|
| `part` | `"assembly"` | which body the file emits.  The Makefile overrides it per STL with `-D 'part="tray_left"'`. |
| `crop` | `[]` | optional `[x0, y0, x1, y1]` window; when set, only that region is kept.  For inspecting one corner without rendering everything. |
| `show` | tray, bezel, plate | which layers the assembly view includes. |

### The shell

| name | value | where the number comes from |
|---|---|---|
| `tilt` | 5° | typing angle.  A design choice: the original 128D keyboard is steeper, but its body is also thicker.  5° gives a 13 mm rise over the 147 mm depth, enough to feel like a keyboard, while keeping the rear wall at 31 mm. |
| `wall` | 2.4 mm | six perimeters of a 0.4 mm nozzle.  Walls that are a whole number of perimeters print solid with no infill gap. |
| `floor_t` | 3.0 mm | thick enough to take the counterbored M3 heads (1.5 mm deep) with 1.5 mm of material left, and to resist the 400 mm span warping. |
| `plate_gap` | 2.0 mm | clearance between the plate edge and the inside of the wall.  It doubles as the pocket the bezel's skirt drops into, so it must exceed `skirt_t` plus a working gap: 1.2 + 0.2 on the wall side + 0.6 on the plate side. |
| `corner_r` | 6 mm | outer vertical corner radius.  Cosmetic; also what the roadmap item "big soft edges" would raise. |

### The stack under the plate

These four add up to `depth_front`, how far the floor sits below the plate at the front
wall, and they are the reason the front is 18.5 mm tall.  The first three describe the
keyboard, so they live in `keyboard.scad`; `under_pcb` is the case's own choice:

| name | value | source |
|---|---|---|
| `plate_t` | 1.5 mm | the steel plate: 0.060" cold-rolled, per the keyboard project's README. |
| `plate_to_pcb` | 3.5 mm | MX plate-mount geometry puts the plate top 5.0 mm above the PCB; subtract the plate's own thickness. |
| `pcb_t` | 1.6 mm | standard FR4. |
| `under_pcb` | 6.0 mm | room below the PCB for solder joints, switch pins, the FFC connector's cable and a possible adapter board.  Chosen, not measured; the README calls it out as the one to raise if you need more room. |

Sum: 12.6 mm.  Add the bezel's 2.9 mm above the plate and the 3 mm floor: 18.5 mm, which the
`echo` at the bottom of the file prints.

### The bezel

| name | value | source |
|---|---|---|
| `bezel_gap` | 0.3 mm | the bezel underside floats this far above the plate so it rests on the tray walls, not the plate.  This is also the wall top height, `z_top`. |
| `bezel_t` | 2.6 mm | bezel top plate thickness.  Its top ends up 2.9 mm above the plate.  The constraint is the keycaps: measured on the built keyboard, original C128 caps on mid-height switches have their skirts 3.8 to 4.6 mm above the plate when fully pressed, so 2.9 leaves about 1 mm of margin at the worst key.  Also the value that decides whether the screw heads can be pocketed (see `head_pocket`). |
| `bezel_cham` | 1.2 mm | 45° chamfer on the outer top edge.  Cosmetic. |
| `open_cham` | 0.8 mm | 45° chamfer on the key openings.  Takes the sharp printed edge off where fingers land. |
| `key_clear` | 1.2 mm | gap between the keycap envelope and the opening.  Caps rock slightly on their stems; 1.2 keeps them off the bezel without a visible moat. |
| `group_openings` | true | one window per key group, like the original C128 top shell, rather than one big hole. |
| `skirt_t`, `skirt_h` | 1.2, 1.6 mm | the alignment lip hanging from the bezel underside: three perimeters thick, deep enough to register but shallow enough to clear the plate's edge features. |

### Screws and inserts

| name | value | source |
|---|---|---|
| `plate_screw_head_h` | 0.9 mm | the plate screws sit *under* the bezel, so their heads must fit in the 0.3 mm gap plus whatever pocket the bezel can spare.  Wafer / ultra-low-profile M3 heads are 0.5 to 0.8 mm; you raised this to 0.9 for a slightly deeper pocket. |
| `plate_screw_head_d` | 6.0 mm | wafer head diameter, plus the 1.5 mm the pocket adds. |
| `insert_d`, `insert_depth` | 4.0, 6.0 mm | the standard pilot hole for an M3 heat-set insert (4.0 to 4.2 depending on brand) and the length of the common M3x5 insert plus a little. |
| `tap_d` | 2.6 mm | pilot for an M3 screw cutting its own thread in PETG or ABS: the core diameter of M3 is 2.46, so 2.6 gives a firm bite without splitting a 6 mm column. |
| `screw_clear_d` | 3.4 mm | clearance hole for M3 through the floor (a "medium" fit). |
| `cbore_d`, `cbore_depth` | 6.5, 1.5 mm | counterbore for an M3 button or pan head (5.7 mm) so it sits inside the floor. |

### The splits

The case is 410 mm long and the printer bed is 256, so both tray and bezel are two halves.

| name | value | why |
|---|---|---|
| `tray_split_x` | -5 | puts the tray halves at 198 and 221 mm, both under the bed, and off any boss or foot. |
| `bezel_split_x` | 30 | 35 mm from the tray split, so each bezel half straddles the tray joint and stiffens it.  The left bezel half is 8 mm longer than this suggests because of `skirt_lap`. |
| `lap`, `lap_w` | 8, 6 mm | how far the tray floor tongue and wall tongues overlap.  Enough glue area, not so long the halves fight over a 256 bed. |
| `joint_clear` | 0.15 mm | per-side clearance on printed mating parts.  Snug hand fit for a well-tuned printer; raise to 0.25 if the halves need persuading. |
| `bezel_scarf` | 45° | the bezel halves meet on a slope instead of a butt so the top surface has a glue face.  45° is the steepest overhang that prints face-down without supports on *both* halves; shallower gives more glue area but one half overhangs. |
| `skirt_lap` | 8 mm | the left half's skirt runs past the joint so the halves key together under the scarf. |

### Connector, feet, plate rests

`rear_port = "db25"` with `port_x = 43`: the DB25 shell cutout is 41.6 × 12.8 mm with 3.2 mm
jack-screw holes 47.04 mm apart, the standard D-sub 25 panel dimensions with 0.3 mm of
clearance.  `port_x = 43` places it directly behind the FFC connector on the board and away
from the rear columns.  `cable_d = 9` is the alternative grommet hole.

`foot_d = 12.5`, `foot_depth = 1.0`: recesses for the common 12 mm hemispherical rubber
bumpers, half a millimeter of clearance, one millimeter deep so they cannot skate.

`front_ledge`, `side_ledge`: strips under the plate edges.  `clamp_bump = 0.35`: a small boss
on the bezel underside around each front column that presses the plate onto its rest, since
those corners have no screw.

### Front snap hooks

The bezel is screwed to the tray through the seven columns, five at the rear and two at the
front corners, and nothing else holds the front edge down along its 400 mm.  The front wall
is only 18 mm tall, too thin for more columns.  Snap hooks solve it: the skirt grows into
cantilever tabs that hang down inside the front wall, each with a catch that clicks into a
pocket in the wall.

| name | value | why |
|---|---|---|
| `hook_x` | -110, -14, 14, 120 | four tabs: two near the ends, two either side of the tray joint at -5 so the bezel also pins the tray halves together.  All kept off the bezel split at 30 and the front columns at ±160. |
| `hook_w` | 10 mm | wide enough for a firm click, narrow enough to flex. |
| `hook_t` | 1.2 mm | equals `skirt_t`: the tab *is* a taller piece of skirt. |
| `hook_len` | 11 mm | the floor is 12.6 mm below the plate at the front; 11 leaves 1.6 mm so the tab never bottoms out. |
| `hook_bump` | 0.8 mm | catch protrusion.  The tab already stands 0.2 mm off the wall, so 0.6 engages. |
| `hook_catch_h` | 2.0 mm | catch height. |
| `hook_clear` | 0.25 mm | pocket clearance around the catch. |
| `hook_pocket_d` | 1.0 mm | pocket depth into the wall, leaving 1.4 mm of the 2.4 mm wall outside it. |
| `hook_release` | 55° | angle of the catch's top face.  45° is symmetric and lifts off easily; 90° would be permanent; you settled on 55 after the first print felt loose. |
| `hook_guide` | false | optional rib behind each tab that forces it to bend rather than lean.  Firmer, harder to open. |

The strain estimate printed by the `echo` in the derived section is the textbook cantilever formula:
maximum surface strain of a beam of thickness *t* and length *L* deflected *δ* at its tip
is 3tδ / 2L².  With t = 1.2, δ = 0.6 (the bump minus the 0.2 standoff) and L = 11 it comes to
0.9 %, comfortably under the roughly 1 % that PETG and ASA tolerate repeatedly; PLA is more
brittle, hence the README's advice to drop the bump for PLA.

---

## 4. The keyboard: `keyboard.scad`

`c128d_case.scad` pulls this file in with `include <keyboard.scad>` in its `keyboard`
section.  Nothing in it is a design choice.  Each number is a measurement pushed through
the conversion in section 1, and each can be checked against
[`pcb/rev3/plate/plate_features.json`](https://codeberg.org/jflitton/the-c128-keyboard-project/src/branch/main/pcb/rev3/plate/plate_features.json)
in the keyboard project, which lists the same features in KiCad coordinates.  The hole
diameters (`plate_hole_d`, `front_col_hole_d`, `pin_hole_d`) are here too; the assembly
view's plate stand-in draws them, and the case derives its pin size from `pin_hole_d`.

One OpenSCAD detail: a variable is only defined *after* the `include` line that brings it
in, so anything computed from a `keyboard.scad` value (`groups`, `pin_d`) sits just below
the `include`, not up in the parameters.

**Plate outline** `PX0..PY1`: the STEP's bounding box, -189.9 to 211.6 by -57.8 to 80.0.

**PCB outline** `PCBX0..PCBY1`: the board's Edge.Cuts rectangle, 108.9 to 504.05 by 80.075
to 191 in KiCad, converted.  (The board's front edge steps down to 206 in the middle; the
corner notches are `pcb_notches`, which only the assembly's PCB stand-in in `plate_ref()`
draws; the case does not need them.)

**M3 plate holes**: four along the rear at y = 75.46, x = -161.0, -54.24, 75.87, 182.63, and
two at the front corners.  These are the plate's Ø3.5 holes; in the features file they are
the `hole` entries with `d = 3.5`.

**Front columns** `front_cols`: the plate's two Ø6.5 holes at the front corners.  Bezel
columns pass through them.

**Rear columns** `rear_cols`: five positions along the rear edge where the plate has slots
or notches, each with the column diameter that fits its slot (8 mm, or 7.4 for the narrower
one at 128.43).  `rear_col_y` sits 0.5 mm behind the screw line so the columns clear the
boss ribs.

**Locating pins** `pin_holes`: the two Ø5 holes (`pin_hole_d`) at the rear corners; the
case's `pin_d = pin_hole_d - 0.4` = 4.6 gives 0.2 mm clearance a side so the plate drops on
by hand.

**Keycap envelope** `KX0..KY1`: the extreme switch centers (from the board, converted) plus
half a key pitch.  For example the leftmost switch is at KiCad x = 118.26, which is plate
x = -177.26, minus 9.525 gives -186.79.  `space_cx, space_cy` is the spacebar switch.

**Spacebar** `space_cap_w = 9 * 19.05`, `space_cap_d = 19.05`.  The C128 spacebar is nine
units of the standard 19.05 mm (0.75") key pitch; every other cap width comes from the switch
positions directly.  Erring large exposes a sliver of plate; erring small makes the bar rub.
The keyboard project's plate also comes in a 6.25u variant with the switch in the same place;
for that, set `space_cap_w = 6.25 * 19.05`.

**Key groups** `key_groups`: six rectangles, each the envelope of one group of switches: the
four top-row clusters, the main block and the numeric keypad.  `top_y0/1` and `main_y0/1`
are the row centers ±9.525.  The comment on each line names the keys so you can check it
against the keyboard.  The case's `groups` is `key_groups`, or, when `group_openings` is false, the single
envelope rectangle `KX0..KY1`.

---

## 5. Derived values and the tilted floor

### Cavity and outer outline

    cav = plate outline grown by plate_gap        (2 mm all round)
    out = cavity grown by wall                    (2.4 mm all round)

`cav_r = 2`: a small inside corner radius so the plate's square corners never bind.

### Heights above the plate

`z_top = bezel_gap` is both the wall top and the bezel underside.  `main_top = z_top +
bezel_t` is the bezel's top surface, 2.9 mm above the plate.

### The screw-head decision

The four plate screws sit under the bezel with their heads above the plate.  Three lines
work out what to do about that:

    head_need   = plate_screw_head_h + 0.3 - bezel_gap    how much the head sticks up past the bezel underside, plus 0.3 clearance
    head_pocket = min(head_need, bezel_t - 1.2)            how much of that can be pocketed into the bezel, keeping 1.2 mm of slab
    deck_raise  = head_need - head_pocket                  whatever is left has to raise the rear of the bezel

With a 0.9 mm head: `head_need` = 0.9, the bezel can pocket up to 1.4, so `head_pocket` = 0.9
and `deck_raise` = 0.  A raised deck would need supports when the bezel prints face down,
which is why the `echo` warns if it ever becomes non-zero.  Everything downstream that
mentions `deck_under` or `deck_top` is dormant until then.

### The floor

The floor is not horizontal in plate coordinates: it is hinged at the front wall and drops
away toward the rear by `tilt`.  Two functions describe it:

    zfl(y) = -depth_front - (y - cav_y0) * tan(tilt)    height of the floor's inside surface at plate-y
    yf(y)  = (y - cav_y0) / cos(tilt)                  distance up the slope from the front wall to plate-y

At the front wall (`y = cav_y0`) the floor is 12.6 mm below the plate; at the rear wall it
is 12.6 + 146.6 × tan 5° = 25.4 mm below.  `port_z` puts the DB25 cutout halfway between
the plate underside and the floor at the rear wall.

`feet`: six positions, 16 mm in from each end and 13 mm from the front and rear walls, plus
the center pair, so a 400 mm floor has no unsupported span over 200 mm.

### The `echo` lines

They print the footprint, the front and rear heights, the hook strain, and the width of
each half.  Read them after every parameter change; the halves must stay under 256.

---

## 6. Helpers

`rrect(x0, y0, x1, y1, r)`: a rounded rectangle from a plain `square` shrunk by `r` and
grown back with `offset(r = r)`, which rounds the corners.  `outer2d(inset)` and
`cav2d(inset)` are the two outlines the whole file is built from; the `inset` argument
shrinks them uniformly and is how the chamfer hulls and the skirt ring are made.

`halfplane_y(y0)`: everything with y ≥ y0, for "the rear part of" an outline via
intersection.

**`floorf()`** is the tilted floor frame.  It translates to the front wall's inner face at the
floor's inside surface and rotates by `-tilt` about X.  Anything drawn inside it with the
floor horizontal comes out tilted correctly.  Its y' axis runs up the slope, which is why
`yf()` exists: a foot at plate-y must be placed at y' = yf(y).

`above_floor_inside()` and `above_floor_outside()` are enormous boxes in the floor frame
whose bottoms are the floor's inside surface and underside.  Intersect any vertical
extrusion with one of them and it acquires a tilted bottom.  This is the trick that makes
the tilt cost nothing: walls stay vertical, only their bottom edge follows the floor.

`post(x, y, d, z1)`: a boss on the floor.  It starts 0.6 mm below the floor's inside surface
so it fuses with the floor whatever the tilt, and rises to `z1` in plate coordinates,
usually `-plate_t`, the plate's underside.

---

## 7. Key openings

`opening_piece2d(i, grow)`: piece *i* of the bezel window, grown by `key_clear` plus
`grow`.  Pieces 0 to 5 are the groups; piece 6 is the spacebar, drawn as a rectangle that
hangs below the main block and overlaps into it by 1 mm so the two merge cleanly.

Each piece is convex on purpose.  `bezel_cuts()` needs to hull each opening with a slightly
larger copy to make the top chamfer, and hulling the *union* of all openings would fill in
the corners between groups.  So the chamfer is done per piece and the pieces are unioned
afterward.

---

## 8. The tray

Read `tray()` first: shell plus features, minus cuts, plus the optional guide
ribs.  Then each part.

**`tray_shell()`**: outer outline extruded from far below up to the wall top, trimmed to the
floor's underside; minus the cavity extruded through everything, trimmed to the floor's
inside surface.  Two extrusions, two trims, and you have tilted floor, vertical walls and
the right floor thickness everywhere.

**`tray_features()`** adds, inside the cavity:

- the four rear bosses, each `hull()`ed with a 1 mm sliver of the rear wall so it is ribbed
  to the wall rather than a free-standing 7 mm post;
- the two rear-corner bosses with 4.6 mm pins standing 1.3 mm proud (`plate_t - 0.2`) into
  the plate's Ø5 holes;
- the two front-corner rests with 3.1 mm pins into the plate's front M3 holes.  No screws
  here: the bezel's front columns clamp these corners;
- the front and side ledges, thin strips at plate-underside height so the plate cannot sag
  between bosses.  The front ledge extends 1.24 mm under the plate (`PY0 + 1.24`), the side
  ledges 2 mm.  Both are intersected with `above_floor_outside()` so they meet the tilted
  floor.

Everything the plate rests on tops out at exactly `-plate_t`.

**`tray_cuts()`** subtracts: insert holes in the rear bosses; the seven column screw holes
through the floor (`column_floor_hole`: a 3.4 mm clearance hole plus a 6.5 mm counterbore
1.5 mm deep from below); the six foot recesses, placed in the floor frame with `yf()`;
the rear connector (DB25: a `hull` of two circles for the rounded shell opening, a square
to widen it, and the two jack-screw holes; or a plain cylinder for `"cable"`); and the
snap-hook pockets.

**`hook_pocket(x)`**: a blind rectangular pocket in the front wall's inner face at catch
height, sized `hook_w + 2 × clear` by `catch_h + 2 × clear` by `pocket_d` deep; and a relief
cut through the front ledge behind the tab, from the wall face to the ledge's inner edge,
so the tab can hang down and flex inward.

**`hook_guide_rib(x)`**: only when `hook_guide` is true.  A rib on the floor behind the tab
whose face is at exactly `tab thickness + (bump - 0.2) + clearance` from the wall: the tab
can move inward just enough for the catch to clear the wall top, no more, so it must bend
and then springs back.

**The lap joint** (`tray_joint`, `tray_left`, `tray_right`): `tray_joint(c)` describes one
region, the upper half of the floor for `lap` mm past the split plus the outer half of the
front and rear walls for `lap_w` mm.  The same module serves both halves: the left half
keeps `tray()` west of the split *plus* the region shrunk by `joint_clear` (the tongue); the
right half keeps `tray()` east of the split *minus* the region grown by `joint_clear` (the
pocket).  Growing and shrinking the same shape by the same amount is what gives a uniform
0.15 mm clearance all round.

---

## 9. The bezel

**`bezel_slab()`**: hull of the outer outline extruded to `bezel_t - bezel_cham` and the
outline inset by `bezel_cham` extruded to the full `bezel_t`.  The hull's sloping skin
between them is the 45° chamfer.  The second `hull` builds the raised rear deck and is
skipped while `deck_raise` is 0.

**`bezel_cuts()`**: the openings straight through, then per piece a hull between the opening
at `main_top - open_cham` and the opening grown by `open_cham` at `main_top`, which is the
top-edge chamfer.  Then the pockets over the four screw heads: cylinders of
`plate_screw_head_d + 1.5` diameter, `head_pocket` deep into the underside.

**`bezel_columns()`** and **`bezel_column()`**: seven columns from 0.2 mm above the floor (so
they never quite touch it and the screw pulls them down) to the bezel underside.  Rear
ones are the slot's diameter with an insert hole; front ones are 6 mm with a 2.6 mm
self-tap hole 8 mm deep, plus the 11 mm clamp bump.

**`bezel_skirt()`**: the ring `cav2d(0.2)` minus `cav2d(0.2 + skirt_t)`, extruded `skirt_h`
downward from the underside.  It sits 0.2 mm off the wall and 0.6 mm off the plate edge.

**`bezel_hook(x)`**: a `hook_w × hook_t × hook_len` block hanging from the underside at the
skirt's position, and the catch: a four-point (y, z) polygon extruded along x, 1 mm short of
the tab's edges so the catch never reaches the tab's stress concentration at its sides.
The polygon's lower face rises at 45° (the lead-in that rides over the wall top on the way
in); its upper face rises at `hook_release` (what you feel when lifting the bezel off).
`rel = hook_bump / tan(hook_release)` is that face's vertical run.

**The scarf joint** (`bezel_left_region`, `bezel_left`, `bezel_right`): the left half's
region is a wedge whose face rises from the split at the underside at `bezel_scarf`
degrees, so above the underside the left half's top rides over the right half on a slope;
below the underside (skirt and tabs) it is a straight cut at `split + skirt_lap`.  As with
the tray, the left keeps the region and the right removes it grown by `joint_clear`.  The
slope is also the glue face: about 3.7 mm wide for a 2.6 mm slab at 45°.

---

## 10. Reference geometry and output

**`plate_ref()`** draws a silver plate with its holes, slots and key openings, and a dark
green PCB with its corner notches, for the assembly view only.  It is the quickest visual
check that the case constants still match the plate.

**`print_tray()`**: the tray is modeled with a tilted floor, so to print it floor-down the
part is rotated by `+tilt` about X and then raised by `-zoff`, where `zoff` is where the
floor's underside at the front wall lands after the rotation:

    zoff = cav_y0 * sin(tilt) - depth_front * cos(tilt) - floor_t = -20.77

Translating by +20.77 puts the floor underside on z = 0.

**`print_bezel()`**: flip the bezel top-down and drop it so its top face is on z = 0.

**`cropped()`**: if `crop` has four numbers, intersect the children with that column of
space; otherwise pass them through.

**The part selector**: the assembly places the halves where they live; each printable part
is passed through its print orientation and centered on the bed by translating half its
width and depth to the origin, which is why the four `translate` lines mention the split
positions.

---

## 11. How to change things safely

- Change a parameter, run `make`, read the `echo` lines.  The half widths must stay under
  256 and `deck_raise` must stay 0.
- If the plate changes, regenerate `plate_features.json` with `gen_plate.py` in the
  keyboard project, convert the new hole positions with the two lines in section 1, and
  update `keyboard.scad`.  The
  assembly view with `show = ["plate"]` will show at once whether the bosses still line up.
- New features that touch the plate go in `tray_features()`; anything removed goes in the
  matching `_cuts()` module.  Keep additions inside the cavity outline and above
  `above_floor_inside()`, and they will pick up the tilt automatically.
- Hook tuning knobs and their symptoms are in the README.
