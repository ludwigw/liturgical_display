#!/usr/bin/env python3
"""
Test script for the liturgical reflection generator.

This script tests the reflection functionality without requiring a full web server.
"""

import os
import sys
from datetime import date

# Add the project root to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from liturgical_display.services.data_service import DataService

def test_reflection():
    """Test the reflection generation functionality."""
    print("Testing Liturgical Reflection Generator")
    print("=" * 50)
    
    # Load config if available
    config = None
    config_path = 'config.yml'
    if os.path.exists(config_path):
        try:
            import yaml
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            print(f"✅ Loaded config from {config_path}")
        except Exception as e:
            print(f"⚠️  Could not load config: {e}")
    
    # Check for API keys in config or environment
    openai_key = None
    scriptura_key = None
    
    if config:
        openai_key = config.get('openai_api_key')
        scriptura_key = config.get('scriptura_api_key')
    
    if not openai_key:
        openai_key = os.getenv('OPENAI_API_KEY')
    
    if not scriptura_key:
        scriptura_key = os.getenv('SCRIPTURA_API_KEY')
    
    if not openai_key:
        print("❌ OpenAI API key not found")
        print("   Set it in config.yml or as environment variable OPENAI_API_KEY")
        return False
    
    if not scriptura_key:
        print("⚠️  Scriptura API key not found")
        print("   Reading contents will not be available, but reflections will still work")
    
    try:
        # Initialize data service with config
        print("Initializing data service...")
        data_service = DataService(config=config)
        
        # Test with today's date
        today = date.today()
        print(f"Testing reflection for {today}")
        
        # Get reflection
        print("Generating reflection...")
        reflection = data_service.get_reflection(today)
        
        # Display results
        print("\n" + "=" * 50)
        print("REFLECTION RESULTS")
        print("=" * 50)
        print(f"Date: {reflection['date']}")
        print(f"Season: {reflection['season']}")
        print(f"Title: {reflection['title']}")
        print(f"Tokens Used: {reflection.get('tokens_used', 'N/A')}")
        print(f"Generated At: {reflection.get('generated_at', 'N/A')}")
        print(f"Fallback: {reflection.get('fallback', False)}")
        print("\nReflection Text:")
        print("-" * 30)
        print(reflection['reflection'])
        print("-" * 30)
        
        # Check token usage
        total_tokens = data_service.get_token_usage()
        print(f"\nTotal tokens used in session: {total_tokens}")
        print(f"Estimated cost: ${total_tokens * 0.00015 / 1000:.4f}")
        
        print("\n✅ Reflection generation test completed successfully!")
        return True
        
    except Exception as e:
        print(f"\n❌ Error during testing: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_reflection()
    sys.exit(0 if success else 1)
