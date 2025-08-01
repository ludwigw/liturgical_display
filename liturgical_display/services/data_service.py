#!/usr/bin/env python3
"""
Data service for liturgical display web server.

Handles liturgical data access and image generation.
"""

import os
import sys
import subprocess
import logging
from datetime import date
from pathlib import Path
from typing import Dict, Any, Optional

from liturgical_calendar.liturgical import liturgical_calendar
from ..utils import log

logger = logging.getLogger(__name__)

class DataService:
    """Service for accessing liturgical data and generating images."""
    
    def __init__(self, cache_dir: Optional[str] = None):
        """Initialize the data service."""
        # Use liturgical-calendar's cache directory structure
        if cache_dir:
            self.cache_dir = cache_dir
        else:
            # Get the project root directory (parent of liturgical_display package)
            import os
            current_dir = Path(__file__).parent  # liturgical_display/services/
            project_root = current_dir.parent.parent  # project root
            self.cache_dir = str(project_root / "cache")
        
        self.images_cache_dir = Path(self.cache_dir) / "images"
        self.images_cache_dir.mkdir(parents=True, exist_ok=True)
        
        log(f"[data_service.py] Initialized with cache dir: {self.cache_dir}")
    
    def get_liturgical_data(self, target_date: date) -> Dict[str, Any]:
        """
        Get liturgical data for a specific date.
        
        Args:
            target_date: The date to get data for
            
        Returns:
            Dictionary containing liturgical information
        """
        try:
            date_str = target_date.strftime("%Y-%m-%d")
            log(f"[data_service.py] Getting liturgical data for {date_str}")
            
            # Get data from liturgical-calendar package
            data = liturgical_calendar(date_str)
            
            # Ensure we have a dictionary
            if not isinstance(data, dict):
                data = {"name": str(data) if data else ""}
            
            # Add date information
            data['date'] = date_str
            data['date_obj'] = target_date
            
            # Extract wikipedia URL if present
            if 'url' in data:
                data['wikipedia_url'] = data['url']
            
            log(f"[data_service.py] Retrieved data: {data.get('name', 'Unknown')}")
            return data
            
        except Exception as e:
            log(f"[data_service.py] ERROR getting liturgical data: {e}")
            logger.error(f"Error getting liturgical data for {target_date}: {e}")
            # Return minimal data on error
            return {
                "name": "Error retrieving data",
                "date": target_date.strftime("%Y-%m-%d"),
                "date_obj": target_date,
                "season": "Unknown",
                "colour": "Unknown"
            }
    
    def generate_image(self, target_date: date, format: str = 'png') -> str:
        """
        Generate liturgical image for a specific date.
        
        Args:
            target_date: The date to generate image for
            format: Image format ('png' or 'bmp')
            
        Returns:
            Path to the generated image file
        """
        try:
            date_str = target_date.strftime("%Y-%m-%d")
            
            # Use liturgical-calendar's cache directory structure
            image_filename = f"{date_str}.{format}"
            image_path = self.images_cache_dir / image_filename
            
            # Check if image already exists in cache
            if image_path.exists():
                log(f"[data_service.py] Using cached image: {image_path}")
                return str(image_path)
            
            log(f"[data_service.py] Generating {format} image for {date_str}")
            
            # Generate image using liturgical-calendar CLI
            result = subprocess.run([
                sys.executable, '-m', 'liturgical_calendar.cli', 'generate',
                date_str, '--output', str(image_path)
            ], capture_output=True, text=True, check=True)
            
            if image_path.exists():
                log(f"[data_service.py] Generated image: {image_path}")
                return str(image_path)
            else:
                raise Exception(f"Image generation failed - file not created: {image_path}")
                
        except subprocess.CalledProcessError as e:
            log(f"[data_service.py] ERROR in image generation subprocess: {e}")
            logger.error(f"Subprocess error generating image for {target_date}: {e.stderr}")
            raise Exception(f"Image generation failed: {e.stderr}")
        except Exception as e:
            log(f"[data_service.py] ERROR generating image: {e}")
            logger.error(f"Error generating image for {target_date}: {e}")
            raise
    
    def get_artwork_path(self, target_date: date) -> Optional[str]:
        """
        Get the path to the original artwork for a specific date.
        
        Args:
            target_date: The date to get artwork for
            
        Returns:
            Path to artwork file, or None if not found
        """
        try:
            # Use the liturgical-calendar ArtworkManager to get artwork info
            from liturgical_calendar.core.artwork_manager import ArtworkManager
            
            date_str = target_date.strftime("%Y-%m-%d")
            artwork_manager = ArtworkManager()
            artwork_info = artwork_manager.get_artwork_for_date(date_str, auto_cache=True)
            
            if artwork_info and artwork_info.get('cached_file'):
                artwork_path = artwork_info['cached_file']
                # Make sure the path is absolute
                if not Path(artwork_path).is_absolute():
                    artwork_path = str(Path(self.cache_dir).parent / artwork_path)
                log(f"[data_service.py] Found artwork: {artwork_path}")
                return artwork_path
            else:
                log(f"[data_service.py] No artwork found for {target_date}")
                return None
                
        except Exception as e:
            log(f"[data_service.py] ERROR getting artwork path: {e}")
            return None

    def get_next_artwork_info(self, target_date: date) -> Optional[dict]:
        """
        Get information about the next available artwork when no artwork exists for the current date.
        
        Args:
            target_date: The date to find next artwork from
            
        Returns:
            Dictionary with next artwork info, or None if not found
        """
        try:
            from liturgical_calendar.core.artwork_manager import ArtworkManager
            
            date_str = target_date.strftime("%Y-%m-%d")
            artwork_manager = ArtworkManager()
            next_artwork = artwork_manager.find_next_artwork(date_str)
            
            if next_artwork and next_artwork.get('cached_file'):
                # Make sure the path is absolute
                artwork_path = next_artwork['cached_file']
                if not Path(artwork_path).is_absolute():
                    artwork_path = str(Path(self.cache_dir).parent / artwork_path)
                
                # Return the next artwork info with absolute path
                next_artwork_info = next_artwork.copy()
                next_artwork_info['cached_file'] = artwork_path
                log(f"[data_service.py] Found next artwork: {artwork_path}")
                return next_artwork_info
            else:
                log(f"[data_service.py] No next artwork found from {target_date}")
                return None
                
        except Exception as e:
            log(f"[data_service.py] ERROR getting next artwork info: {e}")
            return None
    
    def get_cached_image_path(self, target_date: date, format: str = 'png') -> Optional[str]:
        """
        Get path to cached image if it exists.
        
        Args:
            target_date: The date to check
            format: Image format ('png' or 'bmp')
            
        Returns:
            Path to cached image, or None if not found
        """
        date_str = target_date.strftime("%Y-%m-%d")
        image_filename = f"{date_str}.{format}"
        image_path = self.images_cache_dir / image_filename
        
        if image_path.exists():
            return str(image_path)
        return None
    
    def clear_cache(self, format: Optional[str] = None):
        """
        Clear the image cache.
        
        Args:
            format: Specific format to clear ('png', 'bmp'), or None for all
        """
        try:
            if format:
                pattern = f"*.{format}"
                files = list(self.images_cache_dir.glob(pattern))
            else:
                files = list(self.images_cache_dir.glob("*"))
            
            for file in files:
                file.unlink()
            
            log(f"[data_service.py] Cleared {len(files)} cached files")
        except Exception as e:
            log(f"[data_service.py] ERROR clearing cache: {e}")
            logger.error(f"Error clearing cache: {e}") 