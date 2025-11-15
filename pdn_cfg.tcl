# Custom PDN configuration for Clownfish - Skip channel repair
# This is a workaround for PDN-0179 errors with SRAM macros

pdngen::specify_grid stdcell {
    name grid
    rails {
	    met1 {width 0.48 pitch 2.720 offset 0}
    }
    straps {
	    met4 {width 1.6 pitch 180.0 offset 13.5}
	    met5 {width 1.6 pitch 180.0 offset 13.5}
    }
    connect {{met1 met4} {met4 met5}}
}

# Core ring on met4/met5
pdngen::specify_grid stdcell {
    name core_ring
    core_ring {
        met4 {width 4.5 spacing 2.0 core_offset 10}
        met5 {width 4.5 spacing 2.0 core_offset 10}
    }
    connect {{met4_PIN_ver met4}}
}

set ::halo 0

# CRITICAL: Set repair_channels to 0 to skip channel repair
set ::pdngen::repair_channels 0
