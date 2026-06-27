# aseprite-colorize
Colorize is an Aseprite script that helps you quickly recolor your sprites.

![](img/modes.gif)

## How does it work?
Colorize matches each of the colors in your sprite with a color in your palette.
The method used for matching the colors depends on the mode and settings.
It then recolors your sprite, substituting each color form the sprite with its corresponding palette color.

By default, all colors in the palette are used, but by selecting one more more colors in the palette, you can limit the operation to just those colors.

## Colorize Mode

![](img/colorize_example.png)
_Left: Original. Right: Colorized._

Recolor the sprite by replacing the sprite colors with a gradient of palette colors, ordered from darkest to lightest.

This works best when selecting multiple shades of the same hue from the palette.

**Options**
- Gamma: Shift the gamma of the gradient so that the midpoint colors skew lighter or darker.

## Conform Mode

![](img/conform_example.png)
_Left to right: Original, Weighted Euclidean, Euclidean, Redmean, Delta E._

Recolor the sprite by replacing the sprite colors with the closest matching colors in the palette.

There are several options to configure how the closest match is calculated.
Results can vary greatly depending on the colors in the sprite and the palette.

**Options**
- Method: The algorithm used to determine the closest matching color.
  - Weighted Euclidean: Colors are matched with more weight given to green, and less weight given to blue.
  - Euclidean: Colors are matched using the red, green, and blue components equally.
  - Redmean: Colors are matched with weight given to the red and blue components depending on the average amount of red in both colors.
  - Delta E: Colors are matched using the closest human-perceptible color.
- Bit Depth: The bit depth used when calculating the color.
  - 8-bit: Color distance is calculated with full 8-bit color.
  - 5-bit: Color distance is calculated with reduce 5-bit colors. This is the bit depth used natively when Aseprite converts from RGB to Indexed color mode.

## Grayscale Mode

![](img/grayscale_example.png)
_Left: Original. Right: Grayscale._

Recolor the sprite by replacing the sprite colors with grayscale values.
