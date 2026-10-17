"""Build the project's original 8x8 bitmap glyphs as a font-free SVG atlas.

Run with Python 3, from any directory. No external packages are required.
Glyphs are ordered by measured ink coverage, rather than alphabetical order.
"""

import json
from pathlib import Path


GLYPHS = {
    " ": ["........"] * 8,
    ".": ["........", "........", "........", "........", "........", "........", "...#....", "........"],
    ":": ["........", "........", "...#....", "........", "........", "...#....", "........", "........"],
    ",": ["........", "........", "........", "........", "........", "...##...", "...#....", "........"],
    "-": ["........", "........", "........", "..####..", "........", "........", "........", "........"],
    ";": ["........", "........", "...##...", "........", "........", "...##...", "...#....", "........"],
    "~": ["........", "........", "........", "..##.#..", ".#..##..", "........", "........", "........"],
    "+": ["........", "...#....", "...#....", ".#####..", "...#....", "...#....", "........", "........"],
    "=": ["........", "........", ".#####..", "........", ".#####..", "........", "........", "........"],
    "c": ["........", "........", "..###...", ".#...#..", ".#......", ".#...#..", "..###...", "........"],
    "*": ["........", ".#.#.#..", "..###...", ".#####..", "..###...", ".#.#.#..", "........", "........"],
    "o": ["........", "........", "..####..", ".#....#.", ".#....#.", ".#....#.", "..####..", "........"],
    "%": ["........", ".##...#.", ".##..#..", "....#...", "..##....", "..#..##.", ".#...##.", "........"],
    "#": ["........", "..#..#..", ".######.", "..#..#..", "..#..#..", ".######.", "..#..#..", "........"],
    "M": ["........", ".##..##.", ".######.", ".#.##.#.", ".#....#.", ".#....#.", ".##..##.", "........"],
    "@": ["........", "..####..", ".##..##.", ".#.####.", ".#.####.", ".##.....", "..#####.", "........"],
}

def write_svg(target: Path, ordered: list) -> None:
    pixels = []
    for index, (_, rows) in enumerate(ordered):
        for y, row in enumerate(rows):
            for x, pixel in enumerate(row):
                if pixel == "#":
                    pixels.append(f"M{index * 8 + x},{y}h1v1h-1z")
    width = len(ordered) * 8
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="8" '
           f'viewBox="0 0 {width} 8" shape-rendering="crispEdges">\n'
           f'<rect width="{width}" height="8" fill="#000"/>\n'
           f'<path fill="#fff" d="{"".join(pixels)}"/>\n</svg>\n')
    target.write_text(svg, encoding="utf-8", newline="\n")


def main() -> None:
    assert len(GLYPHS) == 16
    for rows in GLYPHS.values():
        assert len(rows) == 8 and all(len(row) == 8 for row in rows)
        assert all(set(row) <= {".", "#"} for row in rows)
    ordered = sorted(GLYPHS.items(), key=lambda item: sum(row.count("#") for row in item[1]))
    counts = [sum(row.count("#") for row in rows) for _, rows in ordered]
    assert len(set(counts)) == 16, "Each glyph must provide a distinct density level"
    target = Path(__file__).resolve().parents[1] / "addons/ascii_renderer/textures"
    target.mkdir(parents=True, exist_ok=True)
    write_svg(target / "ascii_16.svg", ordered)
    manifest = {
        "cell_size": 8,
        "glyphs": [{"character": character, "filled_pixels": count}
                   for (character, _), count in zip(ordered, counts)],
    }
    (target / "ascii_16.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("16 glyphs, ordered by ink coverage:", repr("".join(character for character, _ in ordered)))
    print("Filled pixels per 8x8 cell:", counts)


if __name__ == "__main__":
    main()
