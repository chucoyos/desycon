require "prawn"

# Built-in PDF fonts remain limited to Windows-1252; full Unicode requires embedded fonts.
Prawn::Fonts::AFM.hide_m17n_warning = true
