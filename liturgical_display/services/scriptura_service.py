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
    
    def __init__(self, api_key: Optional[str] = None, base_url: str = "https://www.scriptura-api.com", config: Optional[Dict[str, Any]] = None):
        """Initialize the Scriptura service."""
        # Scriptura API is free and doesn't require an API key
        self.api_key = None  # Not needed for this API
        self.base_url = base_url.rstrip('/')
        
        log(f"[scriptura_service.py] Initialized with base URL: {self.base_url}")
    
    def get_reading_contents(self, readings: list) -> list:
        """
        Get the actual text contents of readings from Scriptura API.
        
        Args:
            readings: List of reading reference strings
            
        Returns:
            List of dictionaries with reading references and their text contents
        """
        try:
            enriched_readings = []
            
            for reading_ref in readings:
                if isinstance(reading_ref, str):
                    # Get text for this reading
                    text = self._get_reading_text(reading_ref)
                    enriched_readings.append({
                        'reference': reading_ref,
                        'text': text
                    })
                else:
                    # Keep as-is if not a string
                    enriched_readings.append(reading_ref)
            
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
            
            # Parse reference to get book, chapter, verse range
            book, chapter, verse_range = self._parse_reference(clean_reference)
            
            # Handle verse ranges by making multiple API calls
            if '-' in verse_range:
                start_verse, end_verse = verse_range.split('-', 1)
                start_verse = int(start_verse.strip())
                
                # Handle "end" as a special case - try verses until we get an error
                if end_verse.strip().lower() == 'end':
                    verses = []
                    verse_num = start_verse
                    max_attempts = 50  # Reasonable limit to prevent infinite loops
                    
                    while verse_num <= start_verse + max_attempts:
                        verse_data = self._get_single_verse_data(book, chapter, str(verse_num))
                        if verse_data and not verse_data.get('text', '').startswith("[Reading:"):
                            verses.append(self._format_verse_html(verse_data))
                            verse_num += 1
                        else:
                            # No more verses found, stop here
                            break
                    
                    if verses:
                        return " ".join(verses)
                    else:
                        return f"[Reading: {reference}]"
                else:
                    # Regular range
                    end_verse = int(end_verse.strip())
                verses = []
                for verse_num in range(start_verse, end_verse + 1):
                    verse_data = self._get_single_verse_data(book, chapter, str(verse_num))
                    if verse_data and not verse_data.get('text', '').startswith("[Reading:"):
                        verses.append(self._format_verse_html(verse_data))
                
                if verses:
                    return " ".join(verses)
                else:
                    return f"[Reading: {reference}]"
            else:
                # Single verse
                verse_data = self._get_single_verse_data(book, chapter, verse_range)
                if verse_data and not verse_data.get('text', '').startswith("[Reading:"):
                    return self._format_verse_html(verse_data)
                else:
                    return f"[Reading: {reference}]"
                
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting text for {reference}: {e}")
            return f"[Reading: {reference}]"
    
    def _get_single_verse_data(self, book: str, chapter: str, verse: str) -> dict:
        """
        Get a single verse from the Scriptura API and return the full data.
        
        Args:
            book: Book name
            chapter: Chapter number
            verse: Verse number
            
        Returns:
            Dictionary with verse data or None if error
        """
        try:
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
            
            # Return the full data structure
            return data
                
        except requests.exceptions.RequestException as e:
            log(f"[scriptura_service.py] API request failed for {book} {chapter}:{verse}: {e}")
            return None
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting verse {book} {chapter}:{verse}: {e}")
            return None

    def _format_verse_html(self, verse_data: dict) -> str:
        """
        Format verse data into structured HTML.
        
        Args:
            verse_data: Dictionary with verse data from API
            
        Returns:
            Formatted HTML string
        """
        if not verse_data:
            return ""
        
        verse_number = verse_data.get('verse', '')
        verse_text = verse_data.get('text', '')
        
        if not verse_text:
            return ""
        
        # Clean up the text (remove verse number if it's already there)
        clean_text = verse_text.strip()
        
        # Wrap in structured HTML
        return f'<span class="verse"><span class="verse-number">{verse_number}</span> {clean_text}</span>'

    def _get_single_verse(self, book: str, chapter: str, verse: str) -> str:
        """
        Get a single verse from the Scriptura API.
        
        Args:
            book: Book name
            chapter: Chapter number
            verse: Verse number
            
        Returns:
            Text content of the verse
        """
        try:
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
                log(f"[scriptura_service.py] Unexpected API response format for {book} {chapter}:{verse}")
                return f"[Reading: {book} {chapter}:{verse}]"
                
        except requests.exceptions.RequestException as e:
            log(f"[scriptura_service.py] API request failed for {book} {chapter}:{verse}: {e}")
            return f"[Reading: {book} {chapter}:{verse}]"
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting verse {book} {chapter}:{verse}: {e}")
            return f"[Reading: {book} {chapter}:{verse}]"
    
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
                    
                    # Handle verse ranges (keep the full range)
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
