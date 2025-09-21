import argparse
import os
import sys
import glob
from moviepy.editor import *
import pyttsx3
from PIL import Image, ImageDraw, ImageFont
import numpy as np

def find_images(image_dir):
    """Find all jpg/png images in directory."""
    return sorted(glob.glob(os.path.join(image_dir, "*.jpg")) + glob.glob(os.path.join(image_dir, "*.png")))

def create_narration(text, filename, voice_hint="female"):
    engine = pyttsx3.init()
    voices = engine.getProperty('voices')
    selected = None
    for v in voices:
        if voice_hint in v.name.lower() or "zira" in v.name.lower():
            engine.setProperty('voice', v.id)
            selected = v
            break
    if not selected:
        print("⚠️ Female voice not found, using default voice.")
    engine.save_to_file(text, filename)
    engine.runAndWait()
    return filename

def create_subtitle_image(text, width=1280, height=250, font_path=None, font_size=40, color="white", fill="black"):
    img = Image.new("RGB", (width, height), color=color)
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype(font_path or "DejaVuSans.ttf", font_size)
    except Exception as e:
        print(f"⚠️ Font not found ({font_path}), using default. Error: {e}")
        font = ImageFont.load_default()

    # Wrap text
    words = text.split(" ")
    lines = []
    line = ""
    for word in words:
        test_line = line + word + " "
        if draw.textlength(test_line, font=font) < (width - 40):
            line = test_line
        else:
            lines.append(line)
            line = word + " "
    lines.append(line)

    y_text = 20
    for l in lines:
        draw.text((20, y_text), l, font=font, fill=fill)
        y_text += font_size + 10

    return np.array(img)

def main(args):
    # -------- STORY TEXT --------
    story_text = (
        "It was a sunny afternoon at Sunrise Solutions, a bustling marketing firm. "
        "In the glass-walled meeting room, the team had gathered for more than just another status update. "
        "Maya, the energetic project manager, grinned mischievously as she adjusted the colorful cake on the table. "
        "Mr. Kapoor, the respected yet approachable boss in his classic navy jacket, clapped his hands to get everyone's attention. "
        "Next to him stood Priya, who had just completed her first big campaign - today was her work anniversary. "
        "Riya, the team's creative wizard, whispered something funny to Priya, causing her to burst out laughing. "
        "Arun, always the life of the party, waved a party popper in anticipation. "
        "Sneha, who had quietly organized the celebration, watched the scene unfold, feeling proud that the team was closer than ever. "
        "As the candles were lit, everyone started singing, and Priya's eyes sparkled with gratitude. "
        "The cake was sliced, jokes were shared, and for a moment, deadlines and emails faded away - replaced by friendship and happiness. "
        "In that short office celebration, Sunrise Solutions felt more like a family than ever."
    )

    # -------- NARRATION --------
    narration_file = args.narration or "narration_offline.mp3"
    print("🔊 Generating narration...")
    create_narration(story_text, narration_file)
    if not os.path.exists(narration_file):
        print(f"❌ Narration file missing: {narration_file}")
        sys.exit(1)
    narration_audio = AudioFileClip(narration_file)

    # -------- SUBTITLES IMAGE --------
    print("📝 Creating subtitles...")
    subtitle_img = create_subtitle_image(
        story_text, font_path=args.font
    )
    subtitle_clip = ImageClip(subtitle_img).set_duration(narration_audio.duration).set_position(("center", "bottom"))

    # -------- BACKGROUND IMAGES --------
    image_files = args.images or find_images(args.image_dir)
    if not image_files:
        print(f"❌ No images found in {args.image_dir}")
        sys.exit(1)
    print(f"🖼️ Using {len(image_files)} images.")
    dur_per_img = narration_audio.duration / len(image_files)
    clips = [
        ImageClip(img_file).set_duration(dur_per_img).resize((1280,720))
        for img_file in image_files
    ]
    background = concatenate_videoclips(clips, method="compose")

    # -------- BACKGROUND MUSIC --------
    final_audio_clips = [narration_audio.volumex(1.0)]
    if args.music and os.path.exists(args.music):
        print("🎵 Adding background music.")
        music = AudioFileClip(args.music).volumex(args.music_vol)
        final_audio_clips.append(music.set_duration(narration_audio.duration))
    else:
        if args.music:
            print(f"⚠️ Music file not found: {args.music}")

    final_audio = CompositeAudioClip(final_audio_clips)

    # -------- FINAL VIDEO --------
    print("🎬 Composing video...")
    video = CompositeVideoClip([background, subtitle_clip]).set_duration(narration_audio.duration)
    video = video.set_audio(final_audio)

    print(f"💾 Exporting video to {args.output}")
    video.write_videofile(args.output, fps=24)

    # Optionally remove temp narration
    if args.cleanup and os.path.exists(narration_file):
        os.remove(narration_file)
        print(f"🧹 Removed temp narration file: {narration_file}")

    print("✅ Video created:", args.output)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create an office celebration story video.")
    parser.add_argument("--image-dir", type=str, default=".", help="Directory containing office images (jpg/png)")
    parser.add_argument("--images", nargs='+', help="List of image files to use instead of auto-discovery")
    parser.add_argument("--music", type=str, help="Optional background music mp3 file")
    parser.add_argument("--music-vol", type=float, default=0.2, help="Background music volume (0.0-1.0)")
    parser.add_argument("--font", type=str, help="Path to TTF font for subtitles")
    parser.add_argument("--narration", type=str, help="Output file for narration audio")
    parser.add_argument("--output", type=str, default="sunrise_solutions_offline.mp4", help="Output video file")
    parser.add_argument("--cleanup", action="store_true", help="Remove narration file after creating video")
    args = parser.parse_args()
    main(args)
