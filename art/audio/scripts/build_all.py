"""Rebuilds every sound in assets/audio, then runs verify_audio.py (docs/audio-direction.md).

Run: python3 -I art/audio/scripts/build_all.py     (about 5 s; the room tone step needs ffmpeg)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bubbles  # noqa: E402
import chimes  # noqa: E402
import feed  # noqa: E402
import jar  # noqa: E402
import mold  # noqa: E402
import room_tone  # noqa: E402
import smell  # noqa: E402
import ui  # noqa: E402
import verify_audio  # noqa: E402

if __name__ == "__main__":
    for module in (bubbles, jar, feed, smell, ui, chimes, mold, room_tone):
        module.main()
    sys.exit(verify_audio.main())
