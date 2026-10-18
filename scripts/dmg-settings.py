# dmgbuild settings for Ticker. Used by scripts/make-dmg.sh; paths come in via -D defines.
# Icon positions must match the layout drawn by scripts/make-dmg-background.swift.
import os

app = defines["app"]            # path to Ticker.app
root = defines["root"]          # repo root

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")
background = os.path.join(root, "Resources", "dmg-background.tiff")

window_rect = ((200, 160), (660, 428))  # 400 pt background + title bar
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 112
text_size = 12
icon_locations = {
    "Ticker.app": (180, 190),
    "Applications": (480, 190),
}
