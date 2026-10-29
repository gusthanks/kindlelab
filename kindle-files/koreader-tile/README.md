# KOReader home-screen tile (icon gallery)

The stock Kindle home screen shows KOReader as a "book" whose cover comes from the `# Icon:` line of the
launcher `documents/KOReader.sh`. This folder holds ready-made covers. All are original artwork, made for a
6-inch grayscale e-ink screen (600x900 PNG, 8-bit gray). The Kindle's own catalog picks a new icon up the
next time KOReader is closed: the stock scanner is paused while KOReader runs.

| File | Style |
|---|---|
| `icons/woodcut-reader.png` | **Default.** Woodcut: a reader under a tree at night |
| `icons/pixel-vampire.png` | Pixel art: a little vampire reading by candlelight (goes well with SimpleUI's vampire mascot) |
| `icons/open-book-sun.png` | Minimal emblem: an open book with a rising sun |

## Install / switch the icon
1. Copy the PNG files to `/mnt/us/koreader/kindlelab/icons/` on the Kindle.
2. Edit the `# Icon:` line of `/mnt/us/documents/KOReader.sh`, for example
   `# Icon: /mnt/us/koreader/kindlelab/icons/pixel-vampire.png`.
3. Close KOReader. The tile changes once the stock scanner has looked at the file again.

## Make your own with an AI image generator
Any image AI works (ChatGPT, Gemini, Codex CLI with image generation, ...). Paste this and change the scene:

```text
Create an ORIGINAL image for the home-screen tile of the "KOReader" e-book app on a Kindle
(6-inch GRAYSCALE e-ink screen).
- Portrait 2:3 (1024x1536).
- Grayscale e-ink: black, white and a few grays only; high contrast; clean bold shapes; flat plain
  background; no fine textures, gradients or tiny details.
- The word "KOReader" clearly legible, spelled exactly like that. No other text.
- Original artwork only: no existing characters, no real logos.
Scene: <describe your idea, e.g. "a capybara reading in a hammock, linocut style">
```

Then convert it for the Kindle (ImageMagick):

```bash
magick my-icon.png -colorspace Gray -resize 600x900 -depth 8 -strip my-icon-kindle.png
```

The icons here were generated with Codex CLI's built-in image generation and converted as above.
