# Odin-Zig GameDev Docker Image

Humble environment for cross-platform building simple games written in Odin.

Uses Zig as cross-platform linker and C cross-compiler for dependencies. (So, I
guess one could use the image for building Zig games too, but that's not what I
am doing.)

Includes:

* SDL
* SDL_image
* SDL_ttf
* miniaudio
* Box2D

And also:

* A hack to define the `_fltused` symbol, which (as far as I understand) should
  be provided by the Windows C runtime, but for some reason the tools I use
  don't do it. Not entirely sure this is a safe workaround.
