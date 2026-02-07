#!/usr/bin/env python3
"""
Test script to check what's on your USB drive
"""

import sys
from pathlib import Path

USB_MOUNT_BASE = '/Volumes'
AUDIO_EXTENSIONS = {'.wav', '.mp3', '.m4a', '.flac'}

def scan_usb():
    """Scan all USB volumes and show what files are found."""
    volumes_path = Path(USB_MOUNT_BASE)
    
    if not volumes_path.exists():
        print(f"❌ {USB_MOUNT_BASE} doesn't exist")
        return
    
    # Get all volumes
    volumes = []
    for volume in volumes_path.iterdir():
        # Skip system volumes
        if volume.name in ['Macintosh HD', 'Preboot', 'Recovery', 'VM', 'Data']:
            continue
        if volume.is_dir():
            volumes.append(volume)
    
    if not volumes:
        print("❌ No USB drives found")
        print(f"\nAll volumes in {USB_MOUNT_BASE}:")
        for v in volumes_path.iterdir():
            print(f"  - {v.name}")
        return
    
    print(f"✅ Found {len(volumes)} USB drive(s):\n")
    
    for volume in volumes:
        print(f"📁 {volume.name} ({volume})")
        print("=" * 60)
        
        # Count all files
        all_files = list(volume.rglob('*'))
        total_files = sum(1 for f in all_files if f.is_file())
        
        # Find audio files
        audio_files = []
        for file_path in volume.rglob('*'):
            if file_path.is_file():
                ext = file_path.suffix.lower()
                if ext in AUDIO_EXTENSIONS:
                    audio_files.append(file_path)
        
        print(f"  Total files: {total_files}")
        print(f"  Audio files: {len(audio_files)}")
        print()
        
        if audio_files:
            print("  🎵 Audio files found:")
            for audio in audio_files:
                size_mb = audio.stat().st_size / (1024 * 1024)
                marker = audio.parent / f"{audio.name}.rem_processed"
                processed = "✅ PROCESSED" if marker.exists() else "🆕 NEW"
                print(f"    {processed} - {audio.name} ({size_mb:.2f} MB)")
                print(f"      Path: {audio}")
        else:
            print("  ⚠️  No audio files found (.wav, .mp3, .m4a, .flac)")
            print()
            print("  📄 All files on USB:")
            file_list = [f for f in all_files if f.is_file()][:20]  # Show first 20
            for f in file_list:
                print(f"    - {f.name} ({f.suffix})")
            if len(file_list) < total_files:
                print(f"    ... and {total_files - len(file_list)} more files")
        
        print()

if __name__ == '__main__':
    print("🔍 REM USB Scanner")
    print("=" * 60)
    print()
    scan_usb()

