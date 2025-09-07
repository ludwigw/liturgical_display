#!/usr/bin/env python3
"""
Scriptura API service for liturgical display.

Fetches reading contents from Scriptura API for reflection generation.
Uses the enhanced local Scriptura API with built-in parsing capabilities.
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
        
        # Check if we should use local Scriptura instance
        if config and config.get('scriptura', {}).get('use_local', False):
            scriptura_config = config.get('scriptura', {})
            local_port = scriptura_config.get('local_port', 8081)
            self.base_url = f"http://localhost:{local_port}"
            log(f"[scriptura_service.py] Using LOCAL Scriptura API at: {self.base_url}")
        else:
            # No remote fallback - fail clearly if local is not configured
            raise ValueError("Scriptura API not configured for local use. Set scriptura.use_local: true in config.yml")
        
        # Use version from config if available, otherwise use parameter
        if config and config.get('scriptura', {}).get('version'):
            self.version = config['scriptura']['version']
        else:
            self.version = version
        
        self.config = config or {}
    
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
                    # Check if this reading contains "or" (alternative readings)
                    if ' or ' in reading_ref:
                        # Split by "or" and handle each alternative separately
                        alternatives = [alt.strip() for alt in reading_ref.split(' or ')]
                        
                        # Create a special structure for alternative readings
                        alternative_readings = []
                        for alt_ref in alternatives:
                            text, parsed = self._get_reading_text_with_status(alt_ref)
                            alternative_readings.append({
                                'reference': alt_ref,
                                'text': text,
                                'parsed': parsed
                            })
                        
                        # Return the alternatives as a special structure
                        enriched_readings.append({
                            'reference': reading_ref,
                            'text': None,  # No combined text
                            'alternatives': alternative_readings,
                            'is_alternative': True
                        })
                    else:
                        # Regular single reading
                        text, parsed = self._get_reading_text_with_status(reading_ref)
                        enriched_readings.append({
                            'reference': reading_ref,
                            'text': text,
                            'parsed': parsed
                        })
                else:
                    # Keep as-is if not a string
                    enriched_readings.append(reading_ref)
            
            return enriched_readings
            
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting reading contents: {e}")
            logger.error(f"Error getting reading contents: {e}")
            return readings  # Return original on error
    
    def _get_reading_text_with_status(self, reference: str) -> tuple[str, bool]:
        """
        Get the text content and parsing status for a specific reading reference.
        
        Args:
            reference: Bible reference (e.g., "John 3:16", "Psalm 23:1-6", "Psalm 104:26-36,37")
            
        Returns:
            Tuple of (text_content, was_parsed_successfully)
        """
        try:
            # Use the enhanced parsing API to handle complex references
            parse_result = self._parse_reference_with_api(reference)
            
            if parse_result and parse_result.get('parsed', False):
                # Get the formatted text from the parsing API and add HTML formatting
                plain_text = parse_result.get('formatted_text', f"[Reading: {reference}]")
                formatted_text = self._format_reading_html(plain_text)
                return formatted_text, True
            else:
                # Fallback for parsing errors
                error_msg = parse_result.get('error', 'Unknown parsing error') if parse_result else 'No response from API'
                log(f"[scriptura_service.py] Parsing failed for '{reference}': {error_msg}")
                return f"[Reading: {reference}]", False
                
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting reading text for '{reference}': {e}")
            logger.error(f"Error getting reading text for '{reference}': {e}")
            return f"[Reading: {reference}]", False

    def _get_reading_text(self, reference: str) -> str:
        """
        Get the text content for a specific reading reference using enhanced parsing.
        
        Args:
            reference: Bible reference (e.g., "John 3:16", "Psalm 23:1-6", "Psalm 104:26-36,37")
            
        Returns:
            Text content of the reading with proper paragraph structure
        """
        try:
            # Use the enhanced parsing API to handle complex references
            parse_result = self._parse_reference_with_api(reference)
            
            if parse_result and parse_result.get('parsed', False):
                # Use the formatted text from the parsing API
                return parse_result.get('formatted_text', f"[Reading: {reference}]")
            else:
                # Fallback for parsing errors
                error_msg = parse_result.get('error', 'Unknown parsing error') if parse_result else 'No response from API'
                log(f"[scriptura_service.py] Parsing failed for '{reference}': {error_msg}")
                return f"[Reading: {reference}]"
                
        except Exception as e:
            log(f"[scriptura_service.py] ERROR getting reading text for '{reference}': {e}")
            logger.error(f"Error getting reading text for '{reference}': {e}")
            return f"[Reading: {reference}]"
    
    def _parse_reference_with_api(self, reference: str) -> Optional[Dict[str, Any]]:
        """
        Parse a Bible reference using the enhanced local Scriptura API.
        
        Args:
            reference: Bible reference string
            
        Returns:
            Parsing result dictionary or None on error
        """
        try:
            # Use the enhanced parsing endpoint
            url = f"{self.base_url}/api/parse/reference/{reference}"
            params = {'version': self.version}
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            return response.json()
            
        except Exception as e:
            log(f"[scriptura_service.py] ERROR parsing reference '{reference}': {e}")
            logger.error(f"Error parsing reference '{reference}': {e}")
            return None
    
    def _format_reading_html(self, plain_text: str) -> str:
        """
        Format plain text reading with HTML structure.
        
        Args:
            plain_text: Plain text from parsing API (e.g., "1 Verse text 2 More text")
            
        Returns:
            HTML formatted text with proper verse structure
        """
        if not plain_text or plain_text.startswith('[Reading:'):
            return plain_text
        
        # Split by verse numbers (digits followed by space)
        import re
        parts = re.split(r'(\d+ )', plain_text)
        
        if len(parts) < 2:
            return plain_text
        
        formatted_parts = []
        i = 0
        while i < len(parts):
            if i + 1 < len(parts) and re.match(r'^\d+ $', parts[i]):
                # This is a verse number
                verse_num = parts[i].strip()
                verse_text = parts[i + 1] if i + 1 < len(parts) else ""
                
                # Wrap verse number and first two words in nowrap span
                words = verse_text.split()
                if len(words) >= 2:
                    first_two_words = f"{words[0]} {words[1]}"
                    remaining_text = " ".join(words[2:]) if len(words) > 2 else ""
                    if remaining_text:
                        formatted_verse = f'<span class="verse"><span class="nowrap"><span class="verse-number">{verse_num}</span> {first_two_words}</span> {remaining_text}</span>'
                    else:
                        formatted_verse = f'<span class="verse"><span class="nowrap"><span class="verse-number">{verse_num}</span> {first_two_words}</span></span>'
                else:
                    formatted_verse = f'<span class="verse"><span class="nowrap"><span class="verse-number">{verse_num}</span> {verse_text}</span></span>'
                
                formatted_parts.append(formatted_verse)
                i += 2
            else:
                # Regular text
                if parts[i].strip():
                    formatted_parts.append(parts[i])
                i += 1
        
        # Join with spaces and wrap in paragraph
        formatted_text = " ".join(formatted_parts)
        return f'<p>{formatted_text}</p>'