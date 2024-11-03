# Heliotropic Patterns

# Setup
Using tmux/vim:
Start audio:
* Open sound.sc
* In vim, run `:SClangStart`
Start video:
* Open new tmux pane 
* cd heliotropic_patterns/animation/
* Open in read mode
* vim -R animation.pde
* In vim, run `:RunProcessing`
Video will now start in a separate application called "animation". Position on projection screen and set to full screen mode.
Note that currently no images will show when audio is not running. This is because the animation events are triggered by OSC messages from sound.sc.
Run image downloader  (assumes virtualenv is created)
* cd img_downloader
* source venv/activate
* python img_downloader.py 
Image uplaoder script is to be run from a cloud hosting provider 

