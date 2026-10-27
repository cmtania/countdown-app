"""Create distinct native font names without changing the supplied glyphs.
Run with fontTools installed. Original files in the supplied folder are read only.
"""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / '.tools' / 'fonttools'))
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parent.parent
source = Path(sys.argv[1])
for filename, weight in [('regular.ttf', 'Regular'), ('bold.ttf', 'Bold'), ('heavy.ttf', 'Heavy')]:
    font = TTFont(source / filename)
    family = 'Calendar Nunito ' + weight
    postscript = 'CalendarNunito-' + weight
    names = {1: family, 2: 'Regular', 3: postscript + '-1.0', 4: family,
             6: postscript, 16: family, 17: 'Regular'}
    for record in font['name'].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    for name_id, value in names.items():
        font['name'].setName(value, name_id, 3, 1, 0x409)
    output = root / 'CountdownApp' / 'Resources' / 'Fonts' / filename
    font.save(output)
    print(filename, '->', postscript, 'weight', font['OS/2'].usWeightClass)
