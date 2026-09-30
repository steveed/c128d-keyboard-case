// keyboard.scad
//
// The keyboard this case is built around: the steel plate, the PCB under it and the keycap
// footprint on top, from the-c128-keyboard-project
// (https://codeberg.org/jflitton/the-c128-keyboard-project).  Data only, no geometry;
// c128d_case.scad includes it.  Nothing in here is a case design choice: every number is a
// measurement of the plate or the board, so if the keyboard changes, this is the only file
// that should need editing.
//
// License: CC BY-SA 4.0 (LICENSE.md); credits in README.md.
//
// Frame: plate coordinates, the same X/Y as plate/plate.step in that repo.  Z = 0 is the
// top of the plate, +X to the right as you type, +Y toward the rear.  KiCad measurements
// (pcb/rev3/plate/plate_features.json, the rev 2.3 / rev 3 boards) convert with
//
//     plate_x = kicad_x - 295.52
//     plate_y = 150.02 - kicad_y
//
// the offset gen_plate.py finds when it fits the STEP's switch openings to the board
// (0.06 mm RMS).

/* ---------------------------------------------------------------- stack */

plate_t       = 1.5;    // steel plate thickness
plate_to_pcb  = 3.5;    // plate underside -> PCB top (MX plate mount: 5.0 - plate_t)
pcb_t         = 1.6;

/* ---------------------------------------------------------------- plate */

// plate outline (square corners)
PX0 = -189.905; PX1 = 211.581; PY0 = -57.839; PY1 = 80.0;

// M3 plate holes
plate_hole_d = 3.5;
rear_hole_y  = 75.46;
rear_holes_x = [-161.0, -54.24, 75.87, 182.63];
front_holes  = [[-178.9, -49.32], [200.53, -49.32]];

// 6.5 mm holes in the front corners (bezel columns pass through these)
front_col_hole_d = 6.5;
front_cols   = [[-161.65, -49.82], [183.28, -49.82]];

// slots / notches in the rear edge (bezel columns pass through these)
// [x, largest column diameter the slot takes]
rear_cols    = [[-170.0, 8], [10.87, 8], [128.43, 7.4], [167.63, 8], [191.63, 8]];
rear_col_y   = rear_hole_y + 0.5;   // clear of the screw bosses' ribs

// locating holes at the rear corners
pin_hole_d   = 5;
pin_holes    = [[-182.0, 74.96], [203.63, 74.96]];

/* ---------------------------------------------------------------- PCB */

// PCB outline
PCBX0 = -186.62; PCBX1 = 208.53; PCBY0 = -55.98; PCBY1 = 69.95;

// the stepped front corners, as [x0, y0, x1, y1] rectangles cut from the outline
// (only the assembly view draws these)
pcb_notches = [
    [PCBX0 - 1, PCBY0 - 1, -167.62,   -40.98],
    [PCBX0 - 1, PCBY0 - 1, -156.62,   -44.53],
    [189.48,    PCBY0 - 1, PCBX1 + 1, -40.98],
    [178.48,    PCBY0 - 1, PCBX1 + 1, -44.53],
];

/* ---------------------------------------------------------------- keycaps */

// keycap envelope (switch centers +/- 19.05/2 per unit)
KX0 = -186.79; KX1 = 208.47; KY0 = -36.385; KY1 = 69.375;

// Spacebar.  The C128 bar is 9u; the plate also comes in a 6.25u variant (same switch
// position, stabilizers at 100 mm) for keycap sets without a 9u bar.  Erring large only
// exposes a little plate next to it, erring small will make the bar rub on the bezel.
space_cx = -34.23; space_cy = -45.91;
space_cap_w   = 9 * 19.05;
space_cap_d   = 19.05;

// key groups as keycap envelopes [x0, y0, x1, y1], from the switch positions in the PCB
hu = 19.05 / 2;
top_y0 = 59.85 - hu;  top_y1 = 59.85 + hu;
main_y0 = -26.86 - hu; main_y1 = 30.29 + hu;
key_groups = [
    [-177.26 - hu, top_y0,  -120.11 + hu, top_y1],   // ESC TAB ALT CAPS LOCK
    [ -62.96 - hu, top_y0,    -5.81 + hu, top_y1],   // HELP LINE FEED 40/80 NO SCROLL
    [  51.34 - hu, top_y0,   108.49 + hu, top_y1],   // cursor keys
    [ 141.79 - hu, top_y0,   198.94 + hu, top_y1],   // F1 F3 F5 F7
    [-177.26 - hu, main_y0,  108.49 + hu, main_y1],  // main block (Inst/Del, Restore, Return and Crsr all end at 118.0)
    [ 141.79 - hu, main_y0,  198.94 + hu, main_y1],  // numeric keypad
];
