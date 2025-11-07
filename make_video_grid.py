#!/usr/bin/env python3
"""
Python equivalent of the make_video_grid bash function.
Creates a grid video from MP4 files matching pattern <video_name>_<number>.mp4
"""

import argparse
import glob
import math
import os
import re
import subprocess
import sys
from pathlib import Path


class VideoGridMaker:
    """Create a grid video from multiple MP4 files."""
    
    def __init__(self):
        # Default settings
        self.show_title = True
        self.title_padding = 80
        self.max_width = 640
        self.padding_percent = 2
        self.output_file = ""
        self.freeze_frame_offset = 3
        
        # Label settings
        self.show_labels = True
        self.label_size = 24
        self.label_color = "white"
        self.label_position = "bottom"
        self.label_format = "%s"
        self.label_box = True
        self.label_box_color = "black@0.5"
        
        # Verbosity
        self.verbose = os.environ.get('FFMPEG_VERBOSE', 'false').lower() == 'true'
    
    def get_video_metadata(self, video_path):
        """Get duration, framerate, and dimensions of a video using ffprobe."""
        try:
            # Get duration
            duration_cmd = [
                'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                '-of', 'default=noprint_wrappers=1:nokey=1', video_path
            ]
            duration = float(subprocess.check_output(duration_cmd).decode().strip())
            
            # Get framerate
            fps_cmd = [
                'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=r_frame_rate',
                '-of', 'default=noprint_wrappers=1:nokey=1', video_path
            ]
            fps_str = subprocess.check_output(fps_cmd).decode().strip()
            # Convert fraction to decimal
            if '/' in fps_str:
                num, den = map(float, fps_str.split('/'))
                fps = num / den
            else:
                fps = float(fps_str)
            
            # Get width
            width_cmd = [
                'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=width',
                '-of', 'default=noprint_wrappers=1:nokey=1', video_path
            ]
            width = int(subprocess.check_output(width_cmd).decode().strip())
            
            # Get height
            height_cmd = [
                'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=height',
                '-of', 'default=noprint_wrappers=1:nokey=1', video_path
            ]
            height = int(subprocess.check_output(height_cmd).decode().strip())
            
            return {
                'duration': duration,
                'fps': fps,
                'width': width,
                'height': height
            }
        except Exception as e:
            print(f"Error getting metadata for {video_path}: {e}", file=sys.stderr)
            return None
    
    def find_videos(self):
        """Find all MP4 files in current directory and extract video numbers."""
        videos = sorted(glob.glob("*.mp4"))
        
        if not videos:
            print("No MP4 files found.")
            return None, None, None
        
        common_name = ""
        video_numbers = []
        
        # Pattern: <name>_<number>.mp4
        pattern = re.compile(r'^(.+)_(\d+)\.mp4$')
        
        for video in videos:
            match = pattern.match(video)
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
    
    def build_filter_chain(self, videos, video_numbers, metadata_list, max_duration,
                          cell_width, cell_height, padding):
        """Build the ffmpeg filter_complex chain."""
        filters = []
        
        for i, (video, label, metadata) in enumerate(zip(videos, video_numbers, metadata_list)):
            duration = metadata['duration']
            fps = metadata['fps']
            
            # Calculate how much to pad (freeze last frame)
            pad_duration = max_duration - duration
            
            # Calculate frame duration and trim to Nth-to-last frame
            frame_duration = 1.0 / fps
            frames_to_trim = self.freeze_frame_offset - 1
            trim_duration = frames_to_trim * frame_duration
            trim_end = duration - trim_duration
            
            # Build label text with format
            label_text = self.label_format % label
            
            # Add checkmark if video finishes early (needs freezing)
            if pad_duration > 0.01:
                label_text = f"{label_text} ✓"
            
            # Build drawtext filter for label (if enabled)
            drawtext_filter = ""
            if self.show_labels:
                # Determine Y position based on label_position
                label_y = "40" if self.label_position == "top" else "h-40"
                
                # Build box parameters
                box_params = ""
                if self.label_box:
                    box_params = f":box=1:boxcolor={self.label_box_color}"
                
                # Escape single quotes in label text for ffmpeg
                label_text_escaped = label_text.replace("'", r"'\''")
                drawtext_filter = (
                    f",drawtext=text='{label_text_escaped}':x=(w-tw)/2:y={label_y}:"
                    f"fontcolor={self.label_color}:fontsize={self.label_size}{box_params}"
                )
            
            # Build filter chain: scale, add black bars, trim frames, freeze, add text
            if pad_duration > 0.01:
                # Trim off last N-1 frames, then freeze on Nth-to-last frame
                freeze_duration = pad_duration + trim_duration
                filter_chain = (
                    f"[{i}:v]fps={fps},scale={cell_width}:-1,"
                    f"pad={cell_width}:{cell_height}:0:{padding}:black,"
                    f"trim=0:{trim_end:.6f},setpts=PTS-STARTPTS,"
                    f"tpad=stop_mode=clone:stop_duration={freeze_duration:.3f},"
                    f"setpts=PTS-STARTPTS{drawtext_filter}[v{i}]"
                )
            else:
                # Just trim off last N-1 frames and freeze on Nth-to-last frame
                filter_chain = (
                    f"[{i}:v]fps={fps},scale={cell_width}:-1,"
                    f"pad={cell_width}:{cell_height}:0:{padding}:black,"
                    f"trim=0:{trim_end:.6f},setpts=PTS-STARTPTS,"
                    f"tpad=stop_mode=clone:stop_duration={trim_duration:.6f},"
                    f"setpts=PTS-STARTPTS{drawtext_filter}[v{i}]"
                )
            
            filters.append(filter_chain)
        
        return "; ".join(filters)
    
    def build_xstack_layout(self, n, rows, cols, cell_width, cell_height):
        """Build the xstack layout string."""
        layout_parts = []
        
        for r in range(rows):
            for c in range(cols):
                idx = r * cols + c
                if idx < n:
                    x = c * cell_width
                    y = r * cell_height
                    layout_parts.append(f"{x}_{y}")
        
        return "|".join(layout_parts)
    
    def make_grid(self):
        """Main function to create the video grid."""
        # Find videos
        videos, video_numbers, common_name = self.find_videos()
        if videos is None:
            return 1
        
        n = len(videos)
        print(f"Found {n} videos")
        
        # Get metadata for all videos
        print("Detecting video durations and framerates...")
        metadata_list = []
        max_duration = 0
        
        for video in videos:
            metadata = self.get_video_metadata(video)
            if metadata is None:
                return 1
            metadata_list.append(metadata)
            max_duration = max(max_duration, metadata['duration'])
        
        print(f"Longest video duration: {max_duration}s")
        
        # Get dimensions from first video
        print("Detecting video dimensions...")
        orig_width = metadata_list[0]['width']
        orig_height = metadata_list[0]['height']
        print(f"Original video size: {orig_width}x{orig_height}")
        
        # Calculate cell dimensions
        cell_width = self.max_width
        scaled_height = int(orig_height * (cell_width / orig_width))
        print(f"Scaled video size: {cell_width}x{scaled_height}")
        
        padding = int(scaled_height * (self.padding_percent / 100.0))
        cell_height = scaled_height + 2 * padding
        print(f"Cell size with padding: {cell_width}x{cell_height} "
              f"(padding: {padding}px = {self.padding_percent}% top/bottom)")
        
        # Calculate grid size
        cols = math.ceil(math.sqrt(n))
        rows = math.ceil(n / cols)
        
        # Build filter chain
        filters = self.build_filter_chain(
            videos, video_numbers, metadata_list, max_duration,
            cell_width, cell_height, padding
        )
        
        # Gather label references
        refs = "".join([f"[v{i}]" for i in range(n)])
        
        # Build xstack layout
        layout = self.build_xstack_layout(n, rows, cols, cell_width, cell_height)
        
        # Calculate grid dimensions
        grid_width = cols * cell_width
        grid_height = rows * cell_height
        
        # Add xstack and optional title
        if self.show_title and common_name:
            padded_height = grid_height + self.title_padding
            # Escape single quotes in common_name
            common_name_escaped = common_name.replace("'", r"'\''")
            filters += (
                f"; {refs}xstack=layout={layout}:inputs={n}[outv];"
                f"[outv]scale='2*trunc(iw/2)':'2*trunc(ih/2)'[scaled];"
                f"[scaled]pad={grid_width}:{padded_height}:0:{self.title_padding}:black[padded];"
                f"[padded]drawtext=text='{common_name_escaped}':x=(w-tw)/2:"
                f"y=({self.title_padding}-th)/2:font=Arial:fontcolor=white:fontsize=36:"
                f"box=1:boxcolor=black@0.7[final]"
            )
        else:
            filters += (
                f"; {refs}xstack=layout={layout}:inputs={n}[outv];"
                f"[outv]scale='2*trunc(iw/2)':'2*trunc(ih/2)'[final]"
            )
        
        # Determine output filename
        if not self.output_file:
            self.output_file = f"{common_name or 'output'}_GRID.mp4"
        
        # Build ffmpeg command
        loglevel = "info" if self.verbose else "error"
        
        ffmpeg_cmd = ['ffmpeg', '-loglevel', loglevel, '-y', '-vsync', 'cfr']
        
        # Add input files
        for video in videos:
            ffmpeg_cmd.extend(['-i', video])
        
        # Add filter and output options
        ffmpeg_cmd.extend([
            '-filter_complex', filters,
            '-map', '[final]',
            '-c:v', 'libx264',
            '-crf', '23',
            '-pix_fmt', 'yuv420p',
            self.output_file
        ])
        
        print(f"\nCreating grid video: {self.output_file}")
        print(f"Processing {len(videos)} input videos")
        print(f"Command built with {len(ffmpeg_cmd)} arguments")
        
        if self.verbose:
            print(f"Command: {' '.join(ffmpeg_cmd[:15])} ...")
        
        # Execute ffmpeg
        print("Executing ffmpeg...")
        try:
            result = subprocess.run(ffmpeg_cmd, check=False)
            
            if result.returncode == 0:
                print("✓ Grid video created successfully")
                return 0
            else:
                print(f"✗ ffmpeg exited with code {result.returncode}")
                return result.returncode
        except Exception as e:
            print(f"✗ Error executing ffmpeg: {e}", file=sys.stderr)
            return 1


def main():
    """Parse arguments and create video grid."""
    parser = argparse.ArgumentParser(
        description='Create a grid video from MP4 files matching pattern <video_name>_<number>.mp4',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python make_video_grid.py                                      # Use all defaults
  python make_video_grid.py --no-title                           # Grid without title
  python make_video_grid.py --width 800 --padding 3              # Custom width and padding
  python make_video_grid.py --output my_grid.mp4                 # Custom output filename
  python make_video_grid.py --no-labels                          # Hide video numbers
  python make_video_grid.py --label-size 36 --label-color yellow # Bigger yellow labels
  python make_video_grid.py --label-format "Camera %s"           # Custom label format

Expected input: MP4 files named like experiment_0.mp4, experiment_1.mp4, etc.
Note: Videos that finish early and are frozen will show a checkmark (✓) next to their label.
        """
    )
    
    # Title options
    title_group = parser.add_argument_group('Title Options')
    title_group.add_argument('--no-title', action='store_true',
                            help='Hide the title at the top of the grid')
    title_group.add_argument('--title-padding', type=int, default=80,
                            help='Padding height for title area in pixels (default: 80)')
    
    # Grid options
    grid_group = parser.add_argument_group('Grid Options')
    grid_group.add_argument('--width', type=int, default=640,
                           help='Maximum width for each video cell (default: 640)')
    grid_group.add_argument('--padding', type=float, default=2,
                           help='Black bar padding percentage for top/bottom (default: 2)')
    grid_group.add_argument('--freeze-offset', type=int, default=3,
                           help='Freeze on Nth-to-last frame (default: 3)')
    
    # Label options
    label_group = parser.add_argument_group('Label Options')
    label_group.add_argument('--no-labels', action='store_true',
                            help='Hide the numbers/labels on each video')
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
    output_group.add_argument('--output', type=str, default='',
                             help='Output filename (default: <video_name>_GRID.mp4)')
    
    args = parser.parse_args()
    
    # Create VideoGridMaker and set options
    maker = VideoGridMaker()
    maker.show_title = not args.no_title
    maker.title_padding = args.title_padding
    maker.max_width = args.width
    maker.padding_percent = args.padding
    maker.freeze_frame_offset = args.freeze_offset
    maker.show_labels = not args.no_labels
    maker.label_size = args.label_size
    maker.label_color = args.label_color
    maker.label_position = args.label_position
    maker.label_format = args.label_format
    maker.label_box = not args.no_label_box
    maker.label_box_color = args.label_box_color
    maker.output_file = args.output
    
    # Create the grid
    return maker.make_grid()


if __name__ == '__main__':
    sys.exit(main())

