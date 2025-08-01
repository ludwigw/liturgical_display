# Web Server Implementation Plan for Liturgical Display

## 📋 Analysis of Current Codebase vs. GitHub Issue #6

### ✅ What the Ticket Got Right
- The liturgical-calendar package does provide feast information
- There are wikipedia URLs available in the data
- The project structure supports adding web server functionality

### ❌ What the Ticket Got Wrong
1. **Data Storage**: The ticket assumes JSON data storage, but the liturgical-calendar package returns Python dictionaries, not JSON files
2. **Wikipedia Field**: The ticket mentions a `wikipedia` field, but the actual field is called `url` in the feast data
3. **Image Source**: The ticket assumes Wikipedia thumbnails, but the user wants to display the **artwork for the day** (from the liturgical-calendar package's artwork cache)
4. **Data Access**: The ticket doesn't account for how the liturgical-calendar package actually works - it's a Python library, not a JSON API

## 🎯 Additional Requirements (User Notes)
- Display the **artwork for the day**, not Wikipedia thumbnails
- Provide endpoints for PNG and BMP image formats
- Support date-specific endpoints (e.g., `/2025/08/25`) that render information for that specific day
- Implement `/today` endpoints that leverage the date-specific functionality

## 🏗 Implementation Plan

### Phase 1: Core Web Server Infrastructure

#### 1.1 Add Web Server Dependencies
- Add Flask to `requirements.txt`
- Add Jinja2 for HTML templating

#### 1.2 Create Web Server Module
- Create `liturgical_display/web_server.py`
- Implement Flask app with basic routing
- Add configuration for web server settings (port, host, etc.)

#### 1.3 Update Configuration
- Add web server settings to `config.yaml`:
  ```yaml
  web_server:
    host: "0.0.0.0"
    port: 8080
    debug: false
  ```

### Phase 2: Data Access Layer

#### 2.1 Create Data Service
- Create `liturgical_display/services/data_service.py`
- Implement functions to:
  - Get liturgical data for a specific date
  - Extract wikipedia URL from feast data
  - Get artwork path for a specific date
  - Generate images for specific dates

#### 2.2 Integrate with liturgical-calendar Package
- Use `liturgical_calendar.liturgical_calendar()` function to get feast data
- Parse the returned dictionary to extract:
  - Feast name
  - Season
  - Color
  - Wikipedia URL (from `url` field)
  - Readings
  - Date information

### Phase 3: Image Generation Endpoints

#### 3.1 Date-Specific Image Endpoints
- `/api/image/<date>/png` - Returns PNG image for specific date
- `/api/image/<date>/bmp` - Returns BMP image for specific date
- Date format: `YYYY-MM-DD` (e.g., `/api/image/2025-08-25/png`)

#### 3.2 Today Image Endpoints
- `/api/image/today/png` - Returns PNG image for today
- `/api/image/today/bmp` - Returns BMP image for today

#### 3.3 Image Generation Logic
- Use `liturgical_calendar.cli.generate` command for image generation
- Support both PNG and BMP output formats
- Cache generated images to avoid regeneration

### Phase 4: Information Endpoints

#### 4.1 Date-Specific Information Endpoint
- `/api/info/<date>` - Returns JSON with liturgical information for specific date
- Include:
  - Feast name and details
  - Season and week information
  - Color
  - Wikipedia URL
  - Readings
  - Artwork information

#### 4.2 Today Information Endpoint
- `/api/today` - Returns JSON with liturgical information for today

### Phase 5: Web Page Endpoints

#### 5.1 Date-Specific Web Page
- `/<date>` - Renders HTML page for specific date (e.g., `/2025-08-25`)
- Display:
  - Feast title and date
  - Season information
  - Wikipedia summary (fetched from Wikipedia API)
  - Artwork image (from liturgical-calendar package)
  - Link to full Wikipedia article

#### 5.2 Today Web Page
- `/today` - Renders HTML page for today's liturgical information

### Phase 6: Wikipedia Integration

#### 6.1 Wikipedia API Service
- Create `liturgical_display/services/wikipedia_service.py`
- Implement functions to:
  - Extract article title from Wikipedia URL
  - Fetch summary from Wikipedia REST API
  - Cache Wikipedia responses to avoid rate limiting

#### 6.2 Wikipedia API Endpoint
- `https://en.wikipedia.org/api/rest_v1/page/summary/{title}`
- Parse response for:
  - `extract` (plain-text summary)
  - `content_urls.desktop.page` (URL to full article)

### Phase 7: Caching and Performance

#### 7.1 Image Caching
- Cache generated images in `cache/images/` directory
- Use date-based filenames
- Implement cache invalidation for updated artwork

#### 7.2 Wikipedia Caching
- Cache Wikipedia summaries in `cache/wikipedia/` directory
- Use article title as filename
- Implement cache expiration (e.g., 24 hours)

#### 7.3 Data Caching
- Cache liturgical data responses
- Implement cache invalidation for date changes

### Phase 8: Error Handling and Fallbacks

#### 8.1 Offline Support
- Use cached data when Wikipedia API is unavailable
- Fallback to showing title and date only if needed
- Graceful degradation for missing artwork

#### 8.2 Error Handling
- Handle invalid dates gracefully
- Handle missing feast data
- Handle Wikipedia API failures
- Handle image generation failures

### Phase 9: Integration and Testing

#### 9.1 Update Main Application
- Add web server startup to `main.py`
- Make web server optional (controlled by config)
- Ensure web server doesn't interfere with eInk display functionality

#### 9.2 Update Setup Script
- Add web server dependencies to `setup.sh`
- Add web server configuration options

#### 9.3 Testing
- Add web server tests to test suite
- Test all endpoints with various dates
- Test error conditions and fallbacks
- Test caching behavior

## 🔧 Technical Implementation Details

### Web Server Architecture
```
liturgical_display/
├── web_server.py          # Flask app and routing
├── services/
│   ├── data_service.py    # Liturgical data access
│   └── wikipedia_service.py # Wikipedia API integration
├── templates/
│   ├── today.html         # Today's page template
│   └── date.html          # Date-specific page template
└── static/
    └── css/
        └── style.css      # Basic styling
```

### API Endpoints Summary
```
GET /api/info/<date>       # JSON liturgical data
GET /api/info/today        # JSON today's data
GET /api/image/<date>/png  # PNG image for date
GET /api/image/<date>/bmp  # BMP image for date
GET /api/image/today/png   # PNG image for today
GET /api/image/today/bmp   # BMP image for today
GET /<date>                # HTML page for date
GET /today                 # HTML page for today
```

### Data Flow
1. **Date Input** → Parse date string
2. **Liturgical Data** → Call `liturgical_calendar()` function
3. **Wikipedia Data** → Extract URL, fetch summary via API
4. **Artwork** → Get artwork path from liturgical-calendar package
5. **Image Generation** → Call `liturgical_calendar.cli.generate`
6. **Response** → Return JSON/HTML/image as appropriate

## 🚀 Deployment Considerations

### Tailscale Funnel Integration
- Web server runs on port 8080 (configurable)
- Tailscale Funnel can expose this port publicly
- NFC tags can point to `https://your-pi-name.ts.net/today`

### Security
- No authentication required (public liturgical information)
- Rate limiting for Wikipedia API calls
- Input validation for date parameters

### Performance
- Image caching to avoid regeneration
- Wikipedia response caching
- Lightweight Flask app suitable for Raspberry Pi

## 📝 Implementation Order

1. **Start with data service** - Core liturgical data access
2. **Add image generation endpoints** - PNG/BMP for specific dates
3. **Implement Wikipedia integration** - Summary fetching and caching
4. **Create web pages** - HTML templates and rendering
5. **Add today endpoints** - Leverage date-specific functionality
6. **Integrate with main app** - Web server startup and configuration
7. **Add caching and error handling** - Performance and reliability
8. **Testing and documentation** - Ensure everything works correctly

This plan addresses all the user's requirements while correcting the misconceptions in the original ticket and building on the actual codebase structure. 