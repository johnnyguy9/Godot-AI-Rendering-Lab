GODOT ?= godot
FFMPEG ?= ffmpeg

.PHONY: capture-media clean-capture

capture-media:
	mkdir -p media/_frames
	$(GODOT) --path . --audio-driver Dummy --write-movie media/_frames/capture.png --fixed-fps 30 --quit-after 240
	cp media/_frames/capture00000060.png media/hero.png
	$(FFMPEG) -y -framerate 30 -i media/_frames/capture%08d.png -vf "fps=12,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" media/patrol-seek.gif
	rm -rf media/_frames media/_frames.wav

clean-capture:
	rm -rf media/_frames media/_frames.wav
