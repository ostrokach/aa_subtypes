"""
Library for visualising data in PyMOL, paticularly projecting arbitary values onto proteins.
"""
from itertools import cycle
from colour_spectrum import ColourSpectrum

def project_landscape(cmd, chain, position, value, colourer=None, na_colour=None):
    """
    Colour specific residues according to a colourmap. colourer must return a Hexcode
    when called with a value as well as have an 'na_colour' attribute if no na_colour
    is specifically supplied. Chain can either be a single identifier (str) or an
    iterable of identifiers
    """
    if colourer is None:
        colourer = ColourSpectrum(min(value), max(value), colourmap='viridis')

    if isinstance(chain, str):
        chain = cycle([chain])

    colour_residues(cmd, *zip(chain, position, [colourer(val) for val in value]),
                    base_colour=na_colour or colourer.na_colour)

def colour_residues(cmd, *args, base_colour=None):
    """
    Colour multiple residues programatically. Each argument should be a
    (chain, position index, hex code) tuple
    """
    if base_colour is not None:
        cmd.color(base_colour, 'prot')

    for chn, pos, col in args:
        cmd.color(col, f'prot and chain {chn} and resi {int(pos)}')
