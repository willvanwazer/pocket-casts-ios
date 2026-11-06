# Personal fork customizations

- The default iPhone, in-app preview, and Watch icon is emerald green with the white Pocket Casts mark.
- Bookmarks have been removed from the app UI, including creation, lists, episode badges, headphone controls, transcript selection menus, sharing, and promotions. Shared database and server records remain compatible with the regular Pocket Casts app.
- Transcript is always the first swipe page after Now Playing for podcast episodes, followed by Details and Chapters. Loading, unavailable, and retry states appear inside the page instead of hiding it. There is no transcript action on the player shelf or its overflow menu. Saved shelf arrangements discard both retired actions.
- Transcript search, highlighting, playback, and existing subscription requirements remain available. Transcript pages work in the compact player and the large-screen split arrangement.

## Icon source

The default icon was edited with the built-in image generation tool, using the original red icon as its reference. Prompt: recolor the red background and interior regions emerald green (#14965C), preserve the white concentric open-ring mark, keep the canvas opaque and square, and add no text, border, shadow, or framing. The generated master was resized with `sips` into the existing icon asset sizes.
