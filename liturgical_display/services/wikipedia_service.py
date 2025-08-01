#!/usr/bin/env python3
"""
Wikipedia service for liturgical display web server.

Handles fetching and caching Wikipedia summaries.
"""

import os
import json
import logging
import requests
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Any, Optional
from urllib.parse import urlparse

from ..utils import log

logger = logging.getLogger(__name__)

class WikipediaService:
    """Service for fetching and caching Wikipedia summaries."""
    
    def __init__(self, cache_dir: Optional[str] = None, cache_duration_hours: int = 24):
        """Initialize the Wikipedia service."""
        self.cache_dir = cache_dir or "cache"
        self.wikipedia_cache_dir = Path(self.cache_dir) / "wikipedia"
        self.wikipedia_cache_dir.mkdir(parents=True, exist_ok=True)
        self.cache_duration = timedelta(hours=cache_duration_hours)
        
        # Wikipedia API base URL
        self.api_base_url = "https://en.wikipedia.org/api/rest_v1/page/summary"
        
        # Request headers to identify our application
        self.headers = {
            'User-Agent': 'LiturgicalDisplay/1.0 (https://github.com/ludwigw/liturgical_display)'
        }
        
        log(f"[wikipedia_service.py] Initialized with cache dir: {self.cache_dir}")
    
    def extract_article_title(self, wikipedia_url: str) -> Optional[str]:
        """
        Extract article title from Wikipedia URL.
        
        Args:
            wikipedia_url: Full Wikipedia URL
            
        Returns:
            Article title, or None if URL is invalid
        """
        try:
            parsed = urlparse(wikipedia_url)
            if 'wikipedia.org' not in parsed.netloc:
                return None
            
            # Extract title from path
            path_parts = parsed.path.strip('/').split('/')
            if len(path_parts) >= 2 and path_parts[0] == 'wiki':
                title = path_parts[1]
                # URL decode the title
                import urllib.parse
                title = urllib.parse.unquote(title)
                return title
            
            return None
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR extracting title from URL: {e}")
            return None
    
    def get_cache_path(self, article_title: str) -> Path:
        """
        Get cache file path for an article title.
        
        Args:
            article_title: Wikipedia article title
            
        Returns:
            Path to cache file
        """
        # Sanitize filename
        safe_title = "".join(c for c in article_title if c.isalnum() or c in (' ', '-', '_')).rstrip()
        safe_title = safe_title.replace(' ', '_')
        return self.wikipedia_cache_dir / f"{safe_title}.json"
    
    def is_cache_valid(self, cache_path: Path) -> bool:
        """
        Check if cached data is still valid.
        
        Args:
            cache_path: Path to cache file
            
        Returns:
            True if cache is valid, False otherwise
        """
        if not cache_path.exists():
            return False
        
        try:
            # Check file modification time
            mtime = datetime.fromtimestamp(cache_path.stat().st_mtime)
            age = datetime.now() - mtime
            return age < self.cache_duration
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR checking cache validity: {e}")
            return False
    
    def load_from_cache(self, cache_path: Path) -> Optional[Dict[str, Any]]:
        """
        Load data from cache file.
        
        Args:
            cache_path: Path to cache file
            
        Returns:
            Cached data, or None if loading failed
        """
        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            log(f"[wikipedia_service.py] Loaded from cache: {cache_path}")
            return data
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR loading from cache: {e}")
            return None
    
    def save_to_cache(self, cache_path: Path, data: Dict[str, Any]):
        """
        Save data to cache file.
        
        Args:
            cache_path: Path to cache file
            data: Data to cache
        """
        try:
            with open(cache_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            log(f"[wikipedia_service.py] Saved to cache: {cache_path}")
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR saving to cache: {e}")
    
    def fetch_from_wikipedia(self, article_title: str) -> Optional[Dict[str, Any]]:
        """
        Fetch summary from Wikipedia API.
        
        Args:
            article_title: Wikipedia article title
            
        Returns:
            Wikipedia summary data, or None if fetch failed
        """
        try:
            url = f"{self.api_base_url}/{article_title}"
            log(f"[wikipedia_service.py] Fetching from Wikipedia API: {url}")
            
            response = requests.get(url, headers=self.headers, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            # Extract relevant information
            summary_data = {
                'title': data.get('title', ''),
                'extract': data.get('extract', ''),
                'content_url': data.get('content_urls', {}).get('desktop', {}).get('page', ''),
                'thumbnail': data.get('thumbnail', {}).get('source', '') if data.get('thumbnail') else '',
                'timestamp': datetime.now().isoformat()
            }
            
            log(f"[wikipedia_service.py] Successfully fetched summary for: {summary_data['title']}")
            return summary_data
            
        except requests.exceptions.RequestException as e:
            log(f"[wikipedia_service.py] ERROR fetching from Wikipedia API: {e}")
            logger.error(f"Wikipedia API request failed for {article_title}: {e}")
            return None
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR processing Wikipedia response: {e}")
            logger.error(f"Error processing Wikipedia response for {article_title}: {e}")
            return None
    
    def get_summary(self, wikipedia_url: str) -> Optional[Dict[str, Any]]:
        """
        Get Wikipedia summary for a URL, using cache if available.
        
        Args:
            wikipedia_url: Full Wikipedia URL
            
        Returns:
            Wikipedia summary data, or None if not available
        """
        try:
            # Extract article title from URL
            article_title = self.extract_article_title(wikipedia_url)
            if not article_title:
                log(f"[wikipedia_service.py] Could not extract title from URL: {wikipedia_url}")
                return None
            
            # Check cache first
            cache_path = self.get_cache_path(article_title)
            if self.is_cache_valid(cache_path):
                cached_data = self.load_from_cache(cache_path)
                if cached_data:
                    return cached_data
            
            # Fetch from Wikipedia API
            summary_data = self.fetch_from_wikipedia(article_title)
            if summary_data:
                # Save to cache
                self.save_to_cache(cache_path, summary_data)
                return summary_data
            
            return None
            
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR getting summary: {e}")
            logger.error(f"Error getting Wikipedia summary for {wikipedia_url}: {e}")
            return None
    
    def clear_cache(self):
        """Clear the Wikipedia cache."""
        try:
            files = list(self.wikipedia_cache_dir.glob("*.json"))
            for file in files:
                file.unlink()
            log(f"[wikipedia_service.py] Cleared {len(files)} cached Wikipedia summaries")
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR clearing cache: {e}")
            logger.error(f"Error clearing Wikipedia cache: {e}")
    
    def get_cache_stats(self) -> Dict[str, Any]:
        """
        Get cache statistics.
        
        Returns:
            Dictionary with cache statistics
        """
        try:
            files = list(self.wikipedia_cache_dir.glob("*.json"))
            total_size = sum(f.stat().st_size for f in files)
            
            return {
                'total_files': len(files),
                'total_size_bytes': total_size,
                'cache_dir': str(self.wikipedia_cache_dir)
            }
        except Exception as e:
            log(f"[wikipedia_service.py] ERROR getting cache stats: {e}")
            return {'error': str(e)} 