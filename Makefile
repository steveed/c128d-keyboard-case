# Regenerate the printable STLs from the OpenSCAD source.
# Renders run in the openscad container (docker-compose.yml); OPENSCAD=openscad uses a host
# install instead (2025+ for the manifold backend).

PARTS   := tray_left tray_right bezel_left bezel_right
STLS    := $(addprefix stl/,$(addsuffix .stl,$(PARTS)))
SRC     := c128d_case.scad keyboard.scad
OPENSCAD ?= docker compose run --rm -T openscad openscad
# PNG export needs OpenGL, which the container lacks, so the preview uses a host install.
PREVIEW_OPENSCAD ?= openscad

all: $(STLS)

stl/%.stl: $(SRC)
	@mkdir -p stl
	$(OPENSCAD) --backend=manifold --export-format=binstl -o $@ -D 'part="$*"' $<

preview.png: $(SRC)
	$(PREVIEW_OPENSCAD) --render --backend=manifold --autocenter --viewall --projection=p \
	  --imgsize=2000,900 --camera=0,0,0,60,0,15,0 -o $@ $<

clean:
	rm -f $(STLS) preview.png

.PHONY: all clean
