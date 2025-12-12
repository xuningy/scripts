#!/usr/bin/env python3
"""
Create a GIF from the Nth frame of multiple videos matching pattern <video_name>_<number>.mp4
Each frame is displayed for a configurable duration (default 0.2s).
"""

import argparse
import glob
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


class FrameGifMaker:
    """Create a GIF from frames extracted from multiple videos."""

    def __init__(self):
        # Frame selection
        self.frame_number = 0  # Which frame to extract (0-indexed)
        self.frame_duration = 0.2  # Duration per frame in seconds

        # Output settings
        self.output_file = ""
        self.max_width = 640

        # Label settings
        self.show_labels = True
        self.label_size = 24
        self.label_color = "white"
        self.label_position = "bottom"
        self.label_format = "%s"
        self.label_box = True
        self.label_box_color = "black@0.5"

        # Title settings
        self.show_title = True
        self.title_padding = 80
        self.custom_title = None

        # User-provided videos and captions
        self.user_videos = None
        self.user_captions = None
        self.input_directory = None
        self.file_pattern = "*.mp4"  # Glob pattern for finding videos

        # Verbosity
        self.verbose = os.environ.get('FFMPEG_VERBOSE', 'false').lower() == 'true'

    def get_video_dimensions(self, video_path):
        """Get dimensions of a video using ffprobe."""
        try:
            width_cmd = [
                'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=width',
                '-of', 'default=noprint_wrappers=1:nokey=1', video_path
            ]
            width = int(subprocess.check_output(width_cmd).decode().strip())

            height_cmd = [
                'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=height',
                '-of', 'default=noprint_wrappers=1:nokey=1', video_path
            ]
            height = int(subprocess.check_output(height_cmd).decode().strip())

            return width, height
        except Exception as e:
            print(f"Error getting dimensions for {video_path}: {e}", file=sys.stderr)
            return None, None

    def find_videos(self, directory=None):
        """Find all MP4 files in directory and extract video numbers."""
        search_dir = directory or "."
        pattern = os.path.join(search_dir, self.file_pattern)
        videos = sorted(glob.glob(pattern))

        if not videos:
            print(f"No files matching '{self.file_pattern}' found in {search_dir}")
            return None, None, None

        common_name = ""
        video_numbers = []

        # Pattern: <name>_<number>.mp4
        name_pattern = re.compile(r'^(.+)_(\d+)\.mp4$')

        for video in videos:
            basename = os.path.basename(video)
            match = name_pattern.match(basename)
            if match:
                base_name = match.group(1)
                num = match.group(2)

                if not common_name:
                    common_name = base_name
                elif common_name != base_name:
                    print(f"Warning: Mixed video name patterns detected ('{common_name}' vs '{base_name}')")

                video_numbers.append(num)
            else:
                # Fallback: use filename without extension
                video_numbers.append(Path(video).stem)

        return videos, video_numbers, common_name

    def extract_frame(self, video_path, frame_num, output_path, width, label_text=None):
        """Extract a specific frame from a video and optionally add label."""
        loglevel = "info" if self.verbose else "error"

        # Build filter chain
        filters = [f"select=eq(n\\,{frame_num})", f"scale={width}:-1"]

        # Add label if enabled
        if self.show_labels and label_text:
            label_y = "40" if self.label_position == "top" else "h-40"
            box_params = ""
            if self.label_box:
                box_params = f":box=1:boxcolor={self.label_box_color}"

            label_text_escaped = label_text.replace("'", r"'\''")
            filters.append(
                f"drawtext=text='{label_text_escaped}':x=(w-tw)/2:y={label_y}:"
                f"fontcolor={self.label_color}:fontsize={self.label_size}{box_params}"
            )

        filter_str = ",".join(filters)

        cmd = [
            'ffmpeg', '-loglevel', loglevel, '-y',
            '-i', video_path,
            '-vf', filter_str,
            '-vframes', '1',
            output_path
        ]

        if self.verbose:
            print(f"Extracting frame {frame_num} from {video_path}")

        try:
            result = subprocess.run(cmd, check=False, capture_output=not self.verbose)
            return result.returncode == 0
        except Exception as e:
            print(f"Error extracting frame from {video_path}: {e}", file=sys.stderr)
            return False

    def add_title_to_image(self, input_path, output_path, title, width):
        """Add a title bar to the top of an image."""
        loglevel = "info" if self.verbose else "error"

        title_escaped = title.replace("'", r"'\''")

        # Pad the image at the top and add title text
        filter_str = (
            f"pad=iw:ih+{self.title_padding}:0:{self.title_padding}:black,"
            f"drawtext=text='{title_escaped}':x=(w-tw)/2:"
            f"y=({self.title_padding}-th)/2:fontcolor=white:fontsize=36:"
            f"box=1:boxcolor=black@0.7"
        )

        cmd = [
            'ffmpeg', '-loglevel', loglevel, '-y',
            '-i', input_path,
            '-vf', filter_str,
            output_path
        ]

        try:
            result = subprocess.run(cmd, check=False, capture_output=not self.verbose)
            return result.returncode == 0
        except Exception as e:
            print(f"Error adding title: {e}", file=sys.stderr)
            return False

    def create_gif_from_frames(self, frame_paths, output_path):
        """Create a GIF from a list of frame images."""
        loglevel = "info" if self.verbose else "error"

        # Create a concat demuxer file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            concat_file = f.name
            for frame_path in frame_paths:
                f.write(f"file '{frame_path}'\n")
                f.write(f"duration {self.frame_duration}\n")
            # Add last frame again (required for concat demuxer to show last frame correctly)
            if frame_paths:
                f.write(f"file '{frame_paths[-1]}'\n")

        try:
            # Generate palette for better GIF quality
            palette_path = os.path.join(tempfile.gettempdir(), 'palette.png')

            # First pass: generate palette
            palette_cmd = [
                'ffmpeg', '-loglevel', loglevel, '-y',
                '-f', 'concat', '-safe', '0', '-i', concat_file,
                '-vf', 'palettegen=stats_mode=diff',
                palette_path
            ]

            if self.verbose:
                print("Generating color palette...")

            result = subprocess.run(palette_cmd, check=False, capture_output=not self.verbose)
            if result.returncode != 0:
                print("Warning: Palette generation failed, using default palette")
                # Fallback: create GIF without palette
                cmd = [
                    'ffmpeg', '-loglevel', loglevel, '-y',
                    '-f', 'concat', '-safe', '0', '-i', concat_file,
                    '-loop', '0',
                    output_path
                ]
                result = subprocess.run(cmd, check=False, capture_output=not self.verbose)
                return result.returncode == 0

            # Second pass: create GIF using palette
            gif_cmd = [
                'ffmpeg', '-loglevel', loglevel, '-y',
                '-f', 'concat', '-safe', '0', '-i', concat_file,
                '-i', palette_path,
                '-lavfi', 'paletteuse=dither=bayer:bayer_scale=5',
                '-loop', '0',
                output_path
            ]

            if self.verbose:
                print("Creating GIF...")

            result = subprocess.run(gif_cmd, check=False, capture_output=not self.verbose)

            # Cleanup palette
            if os.path.exists(palette_path):
                os.remove(palette_path)

            return result.returncode == 0

        finally:
            # Cleanup concat file
            if os.path.exists(concat_file):
                os.remove(concat_file)

    def make_gif(self):
        """Main function to create the GIF from video frames."""
        # Use user-provided videos or auto-detect
        if self.user_videos:
            videos = self.user_videos
            for video in videos:
                if not os.path.exists(video):
                    print(f"Error: Video file not found: {video}", file=sys.stderr)
                    return 1

            if self.user_captions:
                if len(self.user_captions) != len(videos):
                    print(f"Error: Number of captions ({len(self.user_captions)}) "
                          f"must match number of videos ({len(videos)})", file=sys.stderr)
                    return 1
                video_labels = self.user_captions
            else:
                video_labels = [Path(v).stem for v in videos]

            common_name = self.custom_title
            print(f"Using {len(videos)} user-provided videos")
        else:
            videos, video_labels, common_name = self.find_videos(self.input_directory)
            if videos is None:
                return 1
            print(f"Found {len(videos)} videos")

        if self.custom_title:
            common_name = self.custom_title

        n = len(videos)
        print(f"Extracting frame {self.frame_number} from each video...")

        # Get dimensions from first video
        orig_width, orig_height = self.get_video_dimensions(videos[0])
        if orig_width is None:
            return 1
        print(f"Original video size: {orig_width}x{orig_height}")

        # Calculate scaled width
        cell_width = min(self.max_width, orig_width)
        print(f"Output frame width: {cell_width}")

        # Create temporary directory for frames
        with tempfile.TemporaryDirectory() as temp_dir:
            frame_paths = []

            for i, (video, label) in enumerate(zip(videos, video_labels)):
                # Build label text with format
                label_text = self.label_format % label

                # Extract frame
                frame_path = os.path.join(temp_dir, f"frame_{i:04d}.png")
                success = self.extract_frame(
                    video, self.frame_number, frame_path, cell_width, label_text
                )

                if not success:
                    print(f"Failed to extract frame from {video}")
                    return 1

                # Add title if enabled
                if self.show_title and common_name:
                    titled_path = os.path.join(temp_dir, f"titled_{i:04d}.png")
                    if self.add_title_to_image(frame_path, titled_path, common_name, cell_width):
                        frame_paths.append(titled_path)
                    else:
                        frame_paths.append(frame_path)
                else:
                    frame_paths.append(frame_path)

                print(f"  [{i+1}/{n}] Extracted from {os.path.basename(video)}")

            # Determine output filename
            if not self.output_file:
                base_name = common_name or "output"
                self.output_file = f"{base_name}_frame{self.frame_number}.gif"

            print(f"\nCreating GIF: {self.output_file}")
            print(f"  - {n} frames at {self.frame_duration}s each = {n * self.frame_duration:.1f}s total")

            # Create the GIF
            success = self.create_gif_from_frames(frame_paths, self.output_file)

            if success:
                print(f"✓ GIF created successfully: {self.output_file}")
                return 0
            else:
                print("✗ Failed to create GIF")
                return 1


def main():
    """Parse arguments and create GIF from video frames."""
    parser = argparse.ArgumentParser(
        description='Create a GIF from the Nth frame of videos matching pattern <video_name>_<number>.mp4',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python make_gif_of_frames.py                              # Extract frame 0, 0.2s per frame
  python make_gif_of_frames.py --frame 30                   # Extract frame 30 from each video
  python make_gif_of_frames.py --frame 60 --duration 0.5    # Frame 60, 0.5s per frame
  python make_gif_of_frames.py --directory /path/to/videos  # Use videos from specific folder
  python make_gif_of_frames.py --pattern "*_viewport.mp4"   # Only videos ending in _viewport.mp4
  python make_gif_of_frames.py --no-title                   # GIF without title
  python make_gif_of_frames.py --no-labels                  # GIF without frame labels
  python make_gif_of_frames.py --label-format "Run %s"      # Custom label format

  # Explicit videos with captions:
  python make_gif_of_frames.py --videos a.mp4 b.mp4 --captions "First" "Second"
  python make_gif_of_frames.py --videos *.mp4 --title "My Experiment"

Expected input: MP4 files named like experiment_0.mp4, experiment_1.mp4, etc.
Or use --videos to explicitly specify video files, or --pattern to filter by glob pattern.
        """
    )

    # Frame selection options
    frame_group = parser.add_argument_group('Frame Options')
    frame_group.add_argument('--frame', '-f', type=int, default=0,
                            help='Frame number to extract from each video (0-indexed, default: 0)')
    frame_group.add_argument('--duration', '-d', type=float, default=0.2,
                            help='Duration to display each frame in seconds (default: 0.2)')

    # Input options
    input_group = parser.add_argument_group('Input Options')
    input_group.add_argument('--directory', '-D', type=str, default=None,
                            help='Directory containing video files (default: current directory)')
    input_group.add_argument('--pattern', '-p', type=str, default='*.mp4',
                            help='Glob pattern for matching video files (default: "*.mp4")')
    input_group.add_argument('--videos', nargs='+', metavar='VIDEO',
                            help='Explicit list of video files (instead of auto-detecting)')
    input_group.add_argument('--captions', nargs='+', metavar='CAPTION',
                            help='Captions for each video (must match number of videos)')

    # Title options
    title_group = parser.add_argument_group('Title Options')
    title_group.add_argument('--title', type=str, default=None,
                            help='Custom title for the GIF')
    title_group.add_argument('--no-title', action='store_true',
                            help='Hide the title at the top of each frame')
    title_group.add_argument('--title-padding', type=int, default=80,
                            help='Padding height for title area in pixels (default: 80)')

    # Label options
    label_group = parser.add_argument_group('Label Options')
    label_group.add_argument('--no-labels', action='store_true',
                            help='Hide the labels on each frame')
    label_group.add_argument('--label-size', type=int, default=24,
                            help='Font size for labels (default: 24)')
    label_group.add_argument('--label-color', default='white',
                            help='Color for labels (default: white)')
    label_group.add_argument('--label-position', choices=['bottom', 'top'], default='bottom',
                            help='Position of labels (default: bottom)')
    label_group.add_argument('--label-format', default='%s',
                            help='Format string for labels (default: "%%s")')
    label_group.add_argument('--no-label-box', action='store_true',
                            help='Hide the background box behind labels')
    label_group.add_argument('--label-box-color', default='black@0.5',
                            help='Box color with transparency (default: black@0.5)')

    # Output options
    output_group = parser.add_argument_group('Output Options')
    output_group.add_argument('--output', '-o', type=str, default='',
                             help='Output filename (default: <video_name>_frameN.gif)')
    output_group.add_argument('--width', type=int, default=640,
                             help='Maximum width for frames (default: 640)')

    args = parser.parse_args()

    # Create FrameGifMaker and set options
    maker = FrameGifMaker()

    # Frame options
    maker.frame_number = args.frame
    maker.frame_duration = args.duration

    # Input options
    maker.input_directory = args.directory
    maker.file_pattern = args.pattern
    maker.user_videos = args.videos
    maker.user_captions = args.captions

    # Title options
    maker.custom_title = args.title
    maker.show_title = not args.no_title
    maker.title_padding = args.title_padding

    # Label options
    maker.show_labels = not args.no_labels
    maker.label_size = args.label_size
    maker.label_color = args.label_color
    maker.label_position = args.label_position
    maker.label_format = args.label_format
    maker.label_box = not args.no_label_box
    maker.label_box_color = args.label_box_color

    # Output options
    maker.output_file = args.output
    maker.max_width = args.width

    # Create the GIF
    return maker.make_gif()


if __name__ == '__main__':
    sys.exit(main())
