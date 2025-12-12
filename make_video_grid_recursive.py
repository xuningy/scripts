#!/usr/bin/env python3
"""
Recursively process all subdirectories and create video grids in each one.
Python equivalent of the make_video_grid_recursive bash function.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def find_subdirectories(start_dir):
    """Find all subdirectories recursively."""
    subdirs = []
    for root, dirs, files in os.walk(start_dir):
        # Skip hidden directories
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for d in dirs:
            subdirs.append(os.path.join(root, d))
    return sorted(subdirs)


def has_mp4_files(directory):
    """Check if directory contains any MP4 files."""
    mp4_files = list(Path(directory).glob("*.mp4"))
    return len(mp4_files) > 0


def process_directory(directory, grid_options):
    """Process a single directory by calling make_video_grid.py."""
    original_dir = os.getcwd()

    try:
        # Change to subdirectory
        os.chdir(directory)

        # Check for MP4 files
        if not has_mp4_files('.'):
            print(f"Skipping (no MP4 files found): {directory}")
            return None

        print(f"\nProcessing directory: {directory}")
        print("---")

        # Get the path to make_video_grid.py (same directory as this script)
        script_dir = Path(__file__).parent
        make_video_grid_script = script_dir / "make_video_grid.py"

        # Build command
        cmd = ['python3', str(make_video_grid_script)] + grid_options

        # Execute make_video_grid
        result = subprocess.run(cmd, check=False)

        if result.returncode == 0:
            print(f"✓ Successfully created grid in: {directory}")
            return True
        else:
            print(f"✗ Failed to create grid in: {directory}")
            return False

    except Exception as e:
        print(f"✗ Error processing directory {directory}: {e}", file=sys.stderr)
        return False
    finally:
        # Always return to original directory
        os.chdir(original_dir)


def main():
    """Main function to recursively process directories."""
    parser = argparse.ArgumentParser(
        description='Recursively process all subdirectories and create video grids in each one.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python make_video_grid_recursive.py                             # Process all subdirs with defaults
  python make_video_grid_recursive.py --no-title                   # Process with no title
  python make_video_grid_recursive.py --start-dir ./experiments    # Start from specific directory
  python make_video_grid_recursive.py --width 800 --no-labels      # Custom settings for all grids

All options except --start-dir are passed through to make_video_grid.py.
See 'python make_video_grid.py --help' for details on available options.
        """
    )

    parser.add_argument('--start-dir', type=str, default='.',
                       help='Starting directory (default: current directory)')

    # Parse known arguments and collect the rest to pass to make_video_grid
    args, grid_options = parser.parse_known_args()

    start_dir = args.start_dir

    # Check if start directory exists
    if not os.path.isdir(start_dir):
        print(f"Error: Directory '{start_dir}' does not exist", file=sys.stderr)
        return 1

    # Find all subdirectories
    print(f"Searching for subdirectories in: {start_dir}")
    print("=" * 40)

    subdirs = find_subdirectories(start_dir)

    if not subdirs:
        print("No subdirectories found.")
        return 0

    processed_count = 0
    failed_count = 0
    skipped_count = 0

    # Process each subdirectory
    for subdir in subdirs:
        result = process_directory(subdir, grid_options)

        if result is True:
            processed_count += 1
        elif result is False:
            failed_count += 1
        else:  # None means skipped
            skipped_count += 1

    # Print summary
    print("\n" + "=" * 40)
    print("Summary:")
    print(f"  Successfully processed: {processed_count}")
    print(f"  Failed: {failed_count}")
    print(f"  Skipped (no MP4s): {skipped_count}")
    print("=" * 40)

    return 0 if failed_count == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
