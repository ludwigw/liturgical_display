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
    
    def __init__(self, api_key: Optional[str] = None, base_url: str = "https://www.scriptura-api.com", config: Optional[Dict[str, Any]] = None, version: str = "asv"):
        """Initialize the Scriptura service."""
        # Scriptura API is free and doesn't require an API key
        self.api_key = None  # Not needed for this API
        self.base_url = base_url.rstrip('/')
        self.version = version
        
        log(f"[scriptura_service.py] Initialized with base URL: {self.base_url}, version: {self.version}")
    
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
            Text content of the reading with proper paragraph structure
        """
        try:
            # Clean up the reference for the API
            clean_reference = self._clean_reference(reference)
            
            # Parse reference to get book, chapter, verse range
            parsed = self._parse_reference(clean_reference)
            
            if parsed is None:
                # Complex reference - handle with special logic
                return self._handle_complex_reference(clean_reference)
            
            book, chapter, verse_range = parsed
            
            # Get the entire chapter in one API call
            chapter_data = self._get_chapter_data(book, chapter)
            if not chapter_data:
                return f"[Reading: {reference}]"
            
            # Extract the specific verses we need
            verses_data = []
            
            if '-' in verse_range:
                start_verse, end_verse = verse_range.split('-', 1)
                start_verse = int(start_verse.strip())
                
                if end_verse.strip().lower() == 'end':
                    # Find the last verse in the chapter
                    verse_numbers = [int(v) for v in chapter_data['verses'].keys() if v.isdigit()]
                    if verse_numbers:
                        end_verse = max(verse_numbers)
                    else:
                        end_verse = start_verse
                else:
                    end_verse = int(end_verse.strip())
                
                # Extract verses from the chapter data
                for verse_num in range(start_verse, end_verse + 1):
                    verse_text = chapter_data['verses'].get(str(verse_num))
                    if verse_text:
                        verses_data.append({
                            'verse': str(verse_num),
                            'text': verse_text
                        })
            else:
                # Single verse
                verse_text = chapter_data['verses'].get(verse_range)
                if verse_text:
                    verses_data.append({
                        'verse': verse_range,
                        'text': verse_text
                    })
            
            # Format all verses into proper paragraph structure
            if verses_data:
                return self._format_reading_paragraph(verses_data)
            else:
                return f"[Reading: {reference}]"
                
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting text for {reference}: {e}")
            return f"[Reading: {reference}]"
    
    def _handle_complex_reference(self, reference: str) -> str:
        """
        Handle complex references like "Psalm 139:1-5, 12-17" or "John 3:16-4:1".
        
        Args:
            reference: Complex Bible reference
            
        Returns:
            Formatted HTML text
        """
        try:
            # Handle discontinuous ranges like "Psalm 139:1-5, 12-17"
            if ',' in reference:
                return self._handle_discontinuous_range(reference)
            
            # Handle cross-chapter references like "John 3:16-4:1"
            if '-' in reference and ':' in reference:
                colon_count = reference.count(':')
                if colon_count >= 2:
                    return self._handle_cross_chapter_reference(reference)
            
            # If we get here, it's an unexpected complex reference
            log(f"[scriptura_service.py] Unexpected complex reference: {reference}")
            return f"[Reading: {reference}]"
            
        except Exception as e:
            log(f"[scriptura_service.py] Error handling complex reference '{reference}': {e}")
            return f"[Reading: {reference}]"
    
    def _handle_discontinuous_range(self, reference: str) -> str:
        """
        Handle discontinuous ranges like "Psalm 139:1-5, 12-17".
        
        Args:
            reference: Reference with commas
            
        Returns:
            Formatted HTML text
        """
        try:
            # Split by comma to get individual ranges
            parts = reference.split(',')
            all_verses = []
            
            # Parse the first part to get book and chapter
            first_part = parts[0].strip()
            if ':' not in first_part:
                return f"[Reading: {reference}]"
            
            book_chapter, verse_part = first_part.split(':', 1)
            book_chapter_parts = book_chapter.rsplit(' ', 1)
            
            if len(book_chapter_parts) == 2:
                book = book_chapter_parts[0].strip()
                chapter = book_chapter_parts[1].strip()
            else:
                book = book_chapter
                chapter = "1"
            
            # Normalize book name for API
            book = self._normalize_book_name(book)
            
            # Process all parts (first and subsequent)
            for part in parts:
                part = part.strip()
                
                if ':' in part:
                    # Parse each part as a separate reference
                    book_chapter, verse_part = part.split(':', 1)
                    book_chapter_parts = book_chapter.rsplit(' ', 1)
                    
                    if len(book_chapter_parts) == 2:
                        part_book = book_chapter_parts[0].strip()
                        part_chapter = book_chapter_parts[1].strip()
                    else:
                        part_book = book_chapter
                        part_chapter = "1"
                    
                    # Normalize book name for API
                    part_book = self._normalize_book_name(part_book)
                else:
                    # Reuse book and chapter from first part
                    part_book = book
                    part_chapter = chapter
                    verse_part = part
                
                # Get chapter data
                chapter_data = self._get_chapter_data(part_book, part_chapter)
                if not chapter_data:
                    continue
                
                # Parse verse range
                verse_part = self._clean_verse_suffix(verse_part)
                if '-' in verse_part:
                    start_verse, end_verse = verse_part.split('-', 1)
                    start_verse = int(start_verse.strip())
                    end_verse = int(end_verse.strip())
                    
                    for verse_num in range(start_verse, end_verse + 1):
                        verse_text = chapter_data['verses'].get(str(verse_num))
                        if verse_text:
                            all_verses.append({
                                'verse': str(verse_num),
                                'text': verse_text
                            })
                else:
                    # Single verse
                    verse_text = chapter_data['verses'].get(verse_part)
                    if verse_text:
                        all_verses.append({
                            'verse': verse_part,
                            'text': verse_text
                        })
            
            if all_verses:
                return self._format_reading_paragraph(all_verses)
            else:
                return f"[Reading: {reference}]"
                
        except Exception as e:
            log(f"[scriptura_service.py] Error handling discontinuous range '{reference}': {e}")
            return f"[Reading: {reference}]"
    
    def _handle_cross_chapter_reference(self, reference: str) -> str:
        """
        Handle cross-chapter references like "John 3:16-4:1".
        
        Args:
            reference: Cross-chapter reference
            
        Returns:
            Formatted HTML text
        """
        try:
            # Parse cross-chapter reference like "John 3:16-4:1"
            # This means: from John chapter 3 verse 16 to John chapter 4 verse 1
            
            # Find the pattern: Book Chapter:Verse-Chapter:Verse
            import re
            pattern = r'^(.+?)\s+(\d+):(\d+)-(\d+):(\d+)$'
            match = re.match(pattern, reference.strip())
            
            if not match:
                return f"[Reading: {reference}]"
            
            book = match.group(1).strip()
            start_chapter = int(match.group(2))
            start_verse = int(match.group(3))
            end_chapter = int(match.group(4))
            end_verse = int(match.group(5))
            
            all_verses = []
            
            # Handle verses from start chapter
            if start_chapter == end_chapter:
                # Same chapter - just get the range
                chapter_data = self._get_chapter_data(book, str(start_chapter))
                if chapter_data:
                    for verse_num in range(start_verse, end_verse + 1):
                        verse_text = chapter_data['verses'].get(str(verse_num))
                        if verse_text:
                            all_verses.append({
                                'verse': str(verse_num),
                                'text': verse_text
                            })
            else:
                # Cross-chapter - get verses from start chapter to end
                # First, get remaining verses from start chapter
                chapter_data = self._get_chapter_data(book, str(start_chapter))
                if chapter_data:
                    # Get all verses from start_verse to end of chapter
                    verse_numbers = [int(v) for v in chapter_data['verses'].keys() if v.isdigit()]
                    if verse_numbers:
                        max_verse = max(verse_numbers)
                        for verse_num in range(start_verse, max_verse + 1):
                            verse_text = chapter_data['verses'].get(str(verse_num))
                            if verse_text:
                                all_verses.append({
                                    'verse': str(verse_num),
                                    'text': verse_text
                                })
                
                # Then get verses from end chapter
                chapter_data = self._get_chapter_data(book, str(end_chapter))
                if chapter_data:
                    for verse_num in range(1, end_verse + 1):
                        verse_text = chapter_data['verses'].get(str(verse_num))
                        if verse_text:
                            all_verses.append({
                                'verse': str(verse_num),
                                'text': verse_text
                            })
            
            if all_verses:
                return self._format_reading_paragraph(all_verses)
            else:
                return f"[Reading: {reference}]"
            
        except Exception as e:
            log(f"[scriptura_service.py] Error handling cross-chapter reference '{reference}': {e}")
            return f"[Reading: {reference}]"
    
    def _get_chapter_data(self, book: str, chapter: str) -> dict:
        """
        Get an entire chapter from the Scriptura API.
        
        Args:
            book: Book name (e.g., "John")
            chapter: Chapter number (e.g., "3")
            
        Returns:
            Dictionary with chapter data including all verses
        """
        try:
            url = f"{self.base_url}/api/chapter"
            params = {
                'book': book,
                'chapter': chapter,
                'version': self.version
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            return response.json()
            
        except Exception as e:
            logger.error(f"Error fetching chapter {book} {chapter} (version {self.version}): {e}")
            return {}
    
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
                'version': self.version
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

    def _format_reading_paragraph(self, verses: list) -> str:
        """
        Format a list of verses into a single paragraph with proper structure.
        
        Args:
            verses: List of verse data dictionaries
            
        Returns:
            Formatted HTML string with one paragraph containing all verses
        """
        if not verses:
            return ""
        
        # Start with opening paragraph tag
        html_parts = ['<p class="reading-paragraph">']
        
        for verse_data in verses:
            if not verse_data:
                continue
                
            verse_number = verse_data.get('verse', '')
            verse_text = verse_data.get('text', '')
            
            if not verse_text:
                continue
            
            # Clean up the text
            clean_text = verse_text.strip()
            
            # Handle paragraph markers (pilcrows) - only KJV has them
            if '¶' in clean_text:
                # Split by ¶ and process each part
                parts = clean_text.split('¶')
                
                # Filter out empty parts
                non_empty_parts = [part.strip() for part in parts if part.strip()]
                
                for i, part in enumerate(non_empty_parts):
                    if i == 0:
                        # First part - add verse number and content with nowrap
                        wrapped_text = self._wrap_verse_with_nowrap(verse_number, part)
                        html_parts.append(f'<span class="verse">{wrapped_text}</span>')
                    else:
                        # Subsequent parts - close paragraph and start new one
                        html_parts.append('</p><p class="reading-paragraph">')
                        wrapped_text = self._wrap_verse_with_nowrap(verse_number, part)
                        html_parts.append(f'<span class="verse">{wrapped_text}</span>')
            else:
                # No paragraph markers, just add verse span with nowrap
                wrapped_text = self._wrap_verse_with_nowrap(verse_number, clean_text)
                html_parts.append(f'<span class="verse">{wrapped_text}</span>')
        
        # Close the final paragraph
        html_parts.append('</p>')
        
        return ''.join(html_parts)
    
    def _wrap_verse_with_nowrap(self, verse_number: str, text: str) -> str:
        """
        Wrap verse number and first two words in a nowrap span.
        
        Args:
            verse_number: The verse number
            text: The verse text
            
        Returns:
            HTML with nowrap span around verse number and first two words
        """
        # Split text into words
        words = text.split()
        
        if len(words) >= 2:
            # Take first two words for nowrap
            first_two_words = ' '.join(words[:2])
            remaining_words = ' '.join(words[2:])
            
            return f'<span class="nowrap"><span class="verse-number">{verse_number}</span> {first_two_words}</span> {remaining_words}'
        else:
            # If less than 2 words, wrap everything
            return f'<span class="nowrap"><span class="verse-number">{verse_number}</span> {text}</span>'
    
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
        
        # Clean up the text
        clean_text = verse_text.strip()
        
        # Handle paragraph markers (pilcrows) - only KJV has them
        if '¶' in clean_text:
            # Split by ¶ and process each part
            parts = clean_text.split('¶')
            
            # Filter out empty parts
            non_empty_parts = [part.strip() for part in parts if part.strip()]
            
            if not non_empty_parts:
                return f'<span class="verse"><span class="verse-number">{verse_number}</span> {clean_text}</span>'
            
            # Start with opening <p> tag
            html_parts = ['<p class="verse">']
            
            for i, part in enumerate(non_empty_parts):
                if i == 0:
                    # First non-empty part - add verse number and content
                    html_parts.append(f'<span class="verse-number">{verse_number}</span> {part}')
                else:
                    # Subsequent parts - close previous paragraph and start new one
                    html_parts.append('</p><p class="verse-paragraph">')
                    html_parts.append(part)
            
            # Close the final paragraph
            html_parts.append('</p>')
            
            return ''.join(html_parts)
        else:
            # No paragraph markers, just wrap in verse span
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
                'version': self.version
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
    
    def _normalize_book_name(self, book: str) -> str:
        """
        Normalize book names to match Scriptura API expectations.
        
        Args:
            book: Book name from liturgical calendar
            
        Returns:
            Normalized book name for API
        """
        # Common book name mappings
        book_mappings = {
            'Psalm': 'Psalms',
            'Ps': 'Psalms',
            'PSALM': 'Psalms',
            'PSALMS': 'Psalms',
            # Add more mappings as needed
        }
        
        return book_mappings.get(book, book)
    
    def _parse_reference(self, reference: str) -> tuple[str, str, str]:
        """
        Parse a Bible reference into book, chapter, verse.
        
        Args:
            reference: Bible reference (e.g., "John 3:16", "Psalm 23:1-6")
            
        Returns:
            Tuple of (book, chapter, verse)
        """
        try:
            # Handle complex references with commas (discontinuous ranges)
            if ',' in reference:
                # This is a complex reference - handle in _get_reading_text
                return None
            
            # Handle cross-chapter references like "John 3:16-4:1"
            if '-' in reference and ':' in reference:
                # Check if it's cross-chapter (has two colons)
                colon_count = reference.count(':')
                if colon_count >= 2:
                    # This is a cross-chapter reference - handle in _get_reading_text
                    return None
            
            # Handle single chapter references
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
                    
                    # Normalize book name for API
                    book = self._normalize_book_name(book)
                    
                    # Clean up verse part - remove suffixes like "a", "b", etc.
                    verse = self._clean_verse_suffix(verse_part)
                    
                    return book, chapter, verse
            
            # If no colon, assume it's just a book name
            book = reference.strip()
            book = self._normalize_book_name(book)
            return book, "1", "1"
            
        except Exception as e:
            log(f"[scriptura_service.py] Error parsing reference '{reference}': {e}")
            return "Genesis", "1", "1"  # Fallback
    
    def _clean_verse_suffix(self, verse_part: str) -> str:
        """
        Clean up verse suffixes like 'a', 'b', etc.
        
        Args:
            verse_part: Verse part like "2-19a" or "16"
            
        Returns:
            Cleaned verse part like "2-19" or "16"
        """
        if '-' in verse_part:
            # Handle ranges like "2-19a"
            start, end = verse_part.split('-', 1)
            # Remove suffix from end part
            end_clean = ''.join(c for c in end if c.isdigit())
            return f"{start}-{end_clean}"
        else:
            # Handle single verses like "16a"
            return ''.join(c for c in verse_part if c.isdigit())
    
    def get_available_versions(self) -> list:
        """
        Get list of available Bible versions from Scriptura API.
        
        Returns:
            List of version dictionaries
        """
        try:
            url = f"{self.base_url}/api/versions"
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error fetching available versions: {e}")
            return []
    
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
