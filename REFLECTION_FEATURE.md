# Liturgical Reflection Generator

This feature adds AI-generated daily reflections to the liturgical display web interface.

## Overview

The reflection generator creates personalized devotional content based on:
- Liturgical season
- Daily readings (with full text from Scriptura API)
- Feast/saint information (with Wikipedia context)
- Historical context

## Features

- **AI-Powered Reflections**: Uses OpenAI's GPT-4o-mini for cost-effective generation
- **Smart Caching**: Reflections are generated once per day and cached
- **Reading Integration**: Fetches full reading texts from Scriptura API
- **Fallback Handling**: Graceful degradation when APIs are unavailable
- **Cost Tracking**: Monitors token usage and estimated costs
- **Web Integration**: Seamlessly integrated into existing web interface

## Setup

### 1. Environment Variables

Set the required API keys:

```bash
# Required for reflection generation
export OPENAI_API_KEY="your-openai-api-key"

# Optional for reading content enrichment
export SCRIPTURA_API_KEY="your-scriptura-api-key"
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Test the Feature

```bash
python test_reflection.py
```

## API Endpoints

### Get Today's Reflection
```
GET /api/reflection/today
```

### Get Reflection for Specific Date
```
GET /api/reflection/2025-01-15
```

### Get Token Usage Statistics
```
GET /api/tokens
```

## Response Format

```json
{
  "date": "2025-01-15",
  "season": "Ordinary Time",
  "title": "St. Paul the Hermit",
  "reflection": "Today we honor St. Paul the Hermit...",
  "generated_at": "2025-01-15T10:30:00",
  "tokens_used": 150,
  "fallback": false
}
```

## Caching

Reflections are cached in `cache/reflections/` as JSON files:
- One file per date: `YYYY-MM-DD.json`
- Cached reflections are reused until manually cleared
- Cache directory is created automatically

## Cost Management

- Uses GPT-4o-mini for cost efficiency
- Limited to 300 tokens per reflection
- Token usage is tracked and displayed
- Estimated cost: ~$0.00015 per 1000 tokens

## Error Handling

- **OpenAI API failure**: Falls back to simple reflection
- **Scriptura API failure**: Uses reading references only
- **Cache issues**: Regenerates reflection
- **Network issues**: Shows error message in UI

## Configuration

The reflection service can be configured by modifying the `ReflectionService` class:

```python
# In reflection_service.py
self.client = openai.OpenAI(api_key=api_key)
# Change model, max_tokens, temperature as needed
```

## Web Interface

The reflection appears on the date pages with:
- Loading state while generating
- Error handling for failures
- Metadata display (season, tokens, generation time)
- Responsive design matching existing UI

## Testing

Run the test script to verify functionality:

```bash
python test_reflection.py
```

This will:
1. Check for required environment variables
2. Generate a reflection for today
3. Display the results
4. Show token usage and cost

## Troubleshooting

### Common Issues

1. **"OpenAI API key not provided"**
   - Set the `OPENAI_API_KEY` environment variable

2. **"Reading contents not available"**
   - Set the `SCRIPTURA_API_KEY` environment variable (optional)

3. **Reflections not appearing in web interface**
   - Check browser console for JavaScript errors
   - Verify the reflection API endpoints are working

4. **High costs**
   - Check token usage with `/api/tokens`
   - Consider reducing `max_tokens` in the service

### Debug Mode

Enable debug logging to see detailed information:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Future Enhancements

- [ ] Multiple reflection styles (contemplative, practical, etc.)
- [ ] User preferences for reflection length
- [ ] Integration with liturgical calendar updates
- [ ] Batch generation for multiple dates
- [ ] Reflection sharing and export features
