#!/usr/bin/env python3
"""
Scriptura API service for liturgical display.

Fetches reading contents from Scriptura API for reflection generation.
"""

import os
import requests
import logging
from typing import Dict, Any, Optional
from ..utils import log

logger = logging.getLogger(__name__)

class ScripturaService:
    """Service for fetching reading contents from Scriptura API."""
    
    def __init__(self, api_key: Optional[str] = None, base_url: str = "https://api.scriptura-api.com", config: Optional[Dict[str, Any]] = None):
        """Initialize the Scriptura service."""
        # Scriptura API is free and doesn't require an API key
        self.api_key = None  # Not needed for this API
        self.base_url = base_url.rstrip('/')
        
        log(f"[scriptura_service.py] Initialized with base URL: {self.base_url}")
    
    def get_reading_contents(self, readings: Dict[str, Any]) -> Dict[str, Any]:
        """
        Get the actual text contents of readings from Scriptura API.
        
        Args:
            readings: Dictionary containing reading references
            
        Returns:
            Dictionary with reading references and their text contents
        """
        if not self.api_key:
            log("[scriptura_service.py] No API key available, returning original readings")
            return readings
        
        try:
            enriched_readings = {}
            
            for reading_type, reading_data in readings.items():
                if isinstance(reading_data, dict) and 'reference' in reading_data:
                    # Get text for this reading
                    text = self._get_reading_text(reading_data['reference'])
                    enriched_readings[reading_type] = {
                        'reference': reading_data['reference'],
                        'text': text
                    }
                elif isinstance(reading_data, str):
                    # Direct reference string
                    text = self._get_reading_text(reading_data)
                    enriched_readings[reading_type] = {
                        'reference': reading_data,
                        'text': text
                    }
                else:
                    # Keep as-is if not a reference
                    enriched_readings[reading_type] = reading_data
            
            return enriched_readings
            
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting reading contents: {e}")
            logger.error(f"Error getting reading contents: {e}")
            return readings  # Return original on error
    
    def _get_reading_text(self, reference: str) -> str:
        """
        Get the text content for a specific reading reference.
        
        Args:
            reference: Bible reference (e.g., "John 3:16", "Psalm 23:1-6")
            
        Returns:
            Text content of the reading
        """
        try:
            # Clean up the reference for the API
            clean_reference = self._clean_reference(reference)
            
            # Parse reference to get book, chapter, verse
            book, chapter, verse = self._parse_reference(clean_reference)
            
            # Make API request to Scriptura API
            url = f"{self.base_url}/api/verse"
            params = {
                'book': book,
                'chapter': chapter,
                'verse': verse,
                'version': 'kjv'  # Use KJV as it's available and commonly used
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            # Extract text from response
            if 'text' in data:
                return data['text'].strip()
            elif 'verse' in data:
                return data['verse'].strip()
            else:
                log(f"[scriptura_service.py] Unexpected API response format for {reference}")
                return f"[Reading: {reference}]"
                
        except requests.exceptions.RequestException as e:
            log(f"[scriptura_service.py] API request failed for {reference}: {e}")
            return f"[Reading: {reference}]"
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting text for {reference}: {e}")
            return f"[Reading: {reference}]"
    
    def _clean_reference(self, reference: str) -> str:
        """
        Clean up a Bible reference for the API.
        
        Args:
            reference: Raw reference string
            
        Returns:
            Cleaned reference string
        """
        # Remove common prefixes and clean up
        cleaned = reference.strip()
        
        # Remove "First Reading:", "Second Reading:", etc.
        prefixes_to_remove = [
            "First Reading:",
            "Second Reading:", 
            "Gospel:",
            "Psalm:",
            "Old Testament:",
            "New Testament:",
            "Epistle:"
        ]
        
        for prefix in prefixes_to_remove:
            if cleaned.startswith(prefix):
                cleaned = cleaned[len(prefix):].strip()
        
        return cleaned
    
    def _parse_reference(self, reference: str) -> tuple[str, str, str]:
        """
        Parse a Bible reference into book, chapter, verse.
        
        Args:
            reference: Bible reference (e.g., "John 3:16", "Psalm 23:1-6")
            
        Returns:
            Tuple of (book, chapter, verse)
        """
        try:
            # Handle different reference formats
            if ':' in reference:
                # Format: "Book Chapter:Verse" or "Book Chapter:Start-End"
                parts = reference.split(':')
                if len(parts) == 2:
                    book_chapter = parts[0].strip()
                    verse_part = parts[1].strip()
                    
                    # Split book and chapter
                    book_chapter_parts = book_chapter.rsplit(' ', 1)
                    if len(book_chapter_parts) == 2:
                        book = book_chapter_parts[0].strip()
                        chapter = book_chapter_parts[1].strip()
                    else:
                        book = book_chapter
                        chapter = "1"
                    
                    # Handle verse ranges (take first verse)
                    if '-' in verse_part:
                        verse = verse_part.split('-')[0].strip()
                    else:
                        verse = verse_part
                    
                    return book, chapter, verse
            
            # If no colon, assume it's just a book name
            return reference.strip(), "1", "1"
            
        except Exception as e:
            log(f"[scriptura_service.py] Error parsing reference '{reference}': {e}")
            return "Genesis", "1", "1"  # Fallback
    
    def test_connection(self) -> bool:
        """
        Test the connection to Scriptura API.
        
        Returns:
            True if connection successful, False otherwise
        """
        try:
            # Test with a simple reference
            test_text = self._get_reading_text("John 3:16")
            return not test_text.startswith("[Reading:")
        except Exception as e:
            log(f"[scriptura_service.py] Connection test failed: {e}")
            return False
