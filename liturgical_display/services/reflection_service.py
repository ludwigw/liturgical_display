#!/usr/bin/env python3
"""
Reflection service for liturgical display.

Generates daily devotional reflections using LLM integration with liturgical data.
"""

import os
import json
import logging
from datetime import date, datetime
from pathlib import Path
from typing import Dict, Any, Optional
import openai
import smartypants
from ..utils import log

logger = logging.getLogger(__name__)

class ReflectionService:
    """Service for generating liturgical reflections using LLM."""
    
    def __init__(self, cache_dir: Optional[str] = None, openai_api_key: Optional[str] = None, config: Optional[Dict[str, Any]] = None):
        """Initialize the reflection service."""
        if cache_dir:
            self.cache_dir = Path(cache_dir)
        else:
            # Get the project root directory
            current_dir = Path(__file__).parent  # liturgical_display/services/
            project_root = current_dir.parent.parent  # project root
            self.cache_dir = project_root / "cache"
        
        self.reflections_cache_dir = self.cache_dir / "reflections"
        self.reflections_cache_dir.mkdir(parents=True, exist_ok=True)
        
        # Get API key from config, environment, or parameter
        api_key = None
        if config and 'openai_api_key' in config:
            api_key = config['openai_api_key']
        elif openai_api_key:
            api_key = openai_api_key
        else:
            api_key = os.getenv('OPENAI_API_KEY')
        
        if not api_key:
            raise ValueError("OpenAI API key not provided. Set in config file, environment variable, or parameter.")
        
        self.client = openai.OpenAI(api_key=api_key)
        
        # Cost tracking
        self.tokens_used = 0
        
        log(f"[reflection_service.py] Initialized with cache dir: {self.reflections_cache_dir}")
    
    def get_reflection(self, target_date: date, liturgical_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Get or generate a reflection for a specific date.
        
        Args:
            target_date: The date to get reflection for
            liturgical_data: Liturgical data including season, readings, feast info
            
        Returns:
            Dictionary containing reflection data
        """
        try:
            date_str = target_date.strftime("%Y-%m-%d")
            
            # Check cache first
            cached_reflection = self._get_cached_reflection(date_str)
            if cached_reflection:
                log(f"[reflection_service.py] Using cached reflection for {date_str}")
                return cached_reflection
            
            # Generate new reflection
            log(f"[reflection_service.py] Generating new reflection for {date_str}")
            reflection = self._generate_reflection(target_date, liturgical_data)
            
            # Cache the reflection
            self._cache_reflection(date_str, reflection)
            
            return reflection
            
        except Exception as e:
            log(f"[reflection_service.py] ERROR getting reflection: {e}")
            logger.error(f"Error getting reflection for {target_date}: {e}")
            return self._get_fallback_reflection(target_date, liturgical_data)
    
    def _get_cached_reflection(self, date_str: str) -> Optional[Dict[str, Any]]:
        """Get cached reflection if it exists."""
        cache_file = self.reflections_cache_dir / f"{date_str}.json"
        
        if cache_file.exists():
            try:
                with open(cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                log(f"[reflection_service.py] ERROR reading cached reflection: {e}")
                return None
        
        return None
    
    def _cache_reflection(self, date_str: str, reflection: Dict[str, Any]) -> None:
        """Cache a reflection to disk."""
        cache_file = self.reflections_cache_dir / f"{date_str}.json"
        
        try:
            with open(cache_file, 'w', encoding='utf-8') as f:
                json.dump(reflection, f, indent=2, ensure_ascii=False)
            log(f"[reflection_service.py] Cached reflection: {cache_file}")
        except Exception as e:
            log(f"[reflection_service.py] ERROR caching reflection: {e}")
    
    def _generate_reflection(self, target_date: date, liturgical_data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate a new reflection using LLM."""
        try:
            # Prepare inputs for LLM
            inputs = self._prepare_llm_inputs(target_date, liturgical_data)
            
            # Call OpenAI API
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",  # Cost-effective model
                messages=[
                    {
                        "role": "system",
                        "content": self._get_system_prompt()
                    },
                    {
                        "role": "user",
                        "content": self._format_user_message(inputs)
                    }
                ],
                max_tokens=300,  # Limit to keep costs low
                temperature=0.7
            )
            
            # Track token usage
            self.tokens_used += response.usage.total_tokens
            log(f"[reflection_service.py] Used {response.usage.total_tokens} tokens (total: {self.tokens_used})")
            
            # Extract and parse JSON response
            response_content = response.choices[0].message.content.strip()
            
            try:
                # Try to parse as JSON first
                response_data = json.loads(response_content)
                reflection_text = response_data.get('reflection', response_content)
                prayer_text = response_data.get('prayer', '')
            except json.JSONDecodeError:
                # Fallback to treating as plain text
                reflection_text = response_content
                prayer_text = ''
            
            # Apply typography improvements
            reflection_text = smartypants.smartypants(reflection_text)
            if prayer_text:
                prayer_text = smartypants.smartypants(prayer_text)
            
            # Build response
            reflection = {
                "date": target_date.strftime("%Y-%m-%d"),
                "season": liturgical_data.get('season', 'Unknown'),
                "title": liturgical_data.get('name', ''),
                "reflection": reflection_text,
                "prayer": prayer_text,
                "generated_at": datetime.now().isoformat(),
                "tokens_used": response.usage.total_tokens
            }
            
            return reflection
            
        except Exception as e:
            log(f"[reflection_service.py] ERROR generating reflection: {e}")
            logger.error(f"Error generating reflection: {e}")
            raise
    
    def _prepare_llm_inputs(self, target_date: date, liturgical_data: Dict[str, Any]) -> Dict[str, Any]:
        """Prepare inputs for LLM from liturgical data."""
        inputs = {
            "season": liturgical_data.get('season', 'Unknown'),
            "readings": liturgical_data.get('readings', {}),
            "feast": liturgical_data.get('name', ''),
            "wikipedia_summary": liturgical_data.get('wikipedia_summary', ''),
            "wikipedia_url": liturgical_data.get('wikipedia_url', '')
        }
        
        return inputs
    
    def _get_system_prompt(self) -> str:
        """Get the system prompt for the LLM."""
        return """You are a liturgical reflection generator. 
Always produce a short devotional reflection (2–10 sentences) and a 2-line prayer.

- If a feast/saint is present: name them and describe what they are remembered for, connecting to the readings. 
- If no feast: mention the season and connect the readings to the season's themes. 
Always end with a practical takeaway for Christian life today.

The prayer should be 2 lines that resonate with the reflection, written in a traditional prayer style.

Tone: warm, devotional, concise.

Output format: Return a JSON object with:
- "reflection": the devotional reflection (1-2 paragraphs)
- "prayer": the 2-line prayer

Example:
{
  "reflection": "Today we honor...",
  "prayer": "Heavenly Father, grant us the courage to follow your will.\nMay we find strength in your word and peace in your presence. Amen."
}"""
    
    def _format_user_message(self, inputs: Dict[str, Any]) -> str:
        """Format the user message for the LLM."""
        message_parts = []
        
        # Season
        message_parts.append(f"Season: {inputs['season']}")
        
        # Feast info
        if inputs['feast']:
            message_parts.append(f"Feast: {inputs['feast']}")
            if inputs['wikipedia_summary']:
                message_parts.append(f"Historical context: {inputs['wikipedia_summary']}")
        
        # Readings
        if inputs['readings']:
            message_parts.append("Readings:")
            for i, reading_data in enumerate(inputs['readings'], 1):
                if isinstance(reading_data, dict) and 'text' in reading_data:
                    message_parts.append(f"- Reading {i}: {reading_data['text']}")
                elif isinstance(reading_data, str):
                    message_parts.append(f"- Reading {i}: {reading_data}")
        
        return "\n".join(message_parts)
    
    def _get_fallback_reflection(self, target_date: date, liturgical_data: Dict[str, Any]) -> Dict[str, Any]:
        """Get a fallback reflection when LLM generation fails."""
        season = liturgical_data.get('season', 'this season')
        feast = liturgical_data.get('name', '')
        
        if feast:
            reflection_text = f"Today we remember {feast} in {season}. May their example inspire us in our daily walk of faith."
            prayer_text = "Heavenly Father, help us follow the example of your saints.\nGrant us the grace to serve you faithfully in all we do. Amen."
        else:
            reflection_text = f"In {season}, we continue our journey of faith. May God's grace guide us through this day."
            prayer_text = "Lord, guide us through this season of faith.\nMay your grace be our strength and your love our guide. Amen."
        
        # Apply typography improvements
        reflection_text = smartypants.smartypants(reflection_text)
        prayer_text = smartypants.smartypants(prayer_text)
        
        return {
            "date": target_date.strftime("%Y-%m-%d"),
            "season": liturgical_data.get('season', 'Unknown'),
            "title": feast,
            "reflection": reflection_text,
            "prayer": prayer_text,
            "generated_at": datetime.now().isoformat(),
            "tokens_used": 0,
            "fallback": True
        }
    
    def get_token_usage(self) -> int:
        """Get total tokens used in this session."""
        return self.tokens_used
