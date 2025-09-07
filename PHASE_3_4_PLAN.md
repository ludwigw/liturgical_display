# 🚀 Phase 3 & 4: Enhanced Scriptura API Integration

## Overview

This document outlines the detailed plan for Phase 3 (Fork & Enhance Scriptura API) and Phase 4 (Simplify Integration) of the liturgical display project.

## Phase 3: Fork & Enhance Scriptura API

### Goal
Move complex reading reference parsing logic from `liturgical_display` into a forked version of the Scriptura API, creating a more maintainable and reusable solution.

### 3.1 Fork Scriptura Repository

#### 3.1.1 GitHub Fork
- **Source**: `https://github.com/AlexLamper/ScripturaAPI`
- **Target**: `https://github.com/ludwigw/ScripturaAPI`
- **Method**: Use GitHub CLI (`gh fork`)
- **Branch**: Create `feature/enhanced-parsing` branch

#### 3.1.2 Local Setup
```bash
# Fork on GitHub
gh fork AlexLamper/ScripturaAPI

# Update local clone to point to fork
cd scriptura-api
git remote set-url origin https://github.com/ludwigw/ScripturaAPI.git
git remote add upstream https://github.com/AlexLamper/ScripturaAPI.git

# Create enhancement branch
git checkout -b feature/enhanced-parsing
git push -u origin feature/enhanced-parsing
```

### 3.2 Analyze Current Parsing Logic

#### 3.2.1 Extract Parsing Requirements
From `liturgical_display/services/scriptura_service.py`:

**Complex Reference Types:**
- **Discontinuous ranges**: `Psalm 139:1-5, 12-17`
- **Cross-chapter references**: `John 3:16-4:1`
- **Complex ranges**: `Mark 2:4, (6-10), 11-end`
- **Verse suffixes**: `Habakkuk 3:2-19a`
- **Book name normalization**: `Psalm` → `Psalms`

**Parsing Methods to Extract:**
- `_parse_reference()` - Main parsing entry point
- `_handle_discontinuous_range()` - Comma-separated ranges
- `_handle_cross_chapter_range()` - Cross-chapter references
- `_handle_complex_range()` - Parentheses and complex syntax
- `_normalize_book_name()` - Book name standardization
- `_extract_verse_suffix()` - Handle verse suffixes (a, b, etc.)

#### 3.2.2 Document API Requirements
**New Endpoints Needed:**
- `POST /api/parse-reference` - Parse complex references
- `GET /api/parse-reference/{reference}` - Parse single reference
- `POST /api/parse-references` - Parse multiple references

**Request/Response Format:**
```json
// Request
{
  "reference": "Psalm 139:1-5, 12-17",
  "version": "asv"
}

// Response
{
  "reference": "Psalm 139:1-5, 12-17",
  "parsed": true,
  "chapters": [
    {
      "book": "Psalms",
      "chapter": 139,
      "verses": [
        {"start": 1, "end": 5},
        {"start": 12, "end": 17}
      ]
    }
  ],
  "formatted_text": "<p><span class=\"verse\">...</span></p>"
}
```

### 3.3 Enhance Scriptura API

#### 3.3.1 Add Parsing Module
**File**: `scriptura-api/parsing/`
- `reference_parser.py` - Main parsing logic
- `book_normalizer.py` - Book name handling
- `verse_formatter.py` - HTML formatting
- `range_parser.py` - Range parsing utilities

#### 3.3.2 Add API Endpoints
**File**: `scriptura-api/api/parsing.py`
```python
from fastapi import APIRouter, HTTPException
from parsing.reference_parser import ReferenceParser

router = APIRouter(prefix="/api/parse", tags=["parsing"])

@router.post("/reference")
async def parse_reference(request: ParseRequest):
    parser = ReferenceParser()
    result = parser.parse(request.reference, request.version)
    return result

@router.get("/reference/{reference}")
async def parse_single_reference(reference: str, version: str = "asv"):
    parser = ReferenceParser()
    result = parser.parse(reference, version)
    return result
```

#### 3.3.3 Add Comprehensive Tests
**File**: `scriptura-api/tests/test_parsing.py`
```python
import pytest
from parsing.reference_parser import ReferenceParser

def test_discontinuous_ranges():
    parser = ReferenceParser()
    result = parser.parse("Psalm 139:1-5, 12-17", "asv")
    assert result["parsed"] == True
    assert len(result["chapters"]) == 1
    assert result["chapters"][0]["verses"] == [
        {"start": 1, "end": 5},
        {"start": 12, "end": 17}
    ]

def test_cross_chapter_references():
    parser = ReferenceParser()
    result = parser.parse("John 3:16-4:1", "asv")
    assert result["parsed"] == True
    assert len(result["chapters"]) == 2

# ... more test cases
```

#### 3.3.4 Update Documentation
**File**: `scriptura-api/README.md`
- Add parsing API documentation
- Include usage examples
- Document all supported reference formats

### 3.4 Test Enhanced API

#### 3.4.1 Unit Tests
```bash
cd scriptura-api
python -m pytest tests/test_parsing.py -v
```

#### 3.4.2 Integration Tests
```bash
# Test with liturgical_display
cd ../liturgical_display
# Update config to use local enhanced API
# Test all reading scenarios
```

#### 3.4.3 Performance Tests
- Benchmark parsing performance
- Test with large reference sets
- Verify memory usage

## Phase 4: Simplify Integration

### Goal
Update `liturgical_display` to use the enhanced Scriptura API with built-in parsing, removing complex parsing logic from the client.

### 4.1 Update ScripturaService

#### 4.1.1 Simplify Service
**File**: `liturgical_display/services/scriptura_service.py`

**Remove:**
- All parsing methods (`_parse_reference`, `_handle_discontinuous_range`, etc.)
- Complex reference handling logic
- Book name normalization
- HTML formatting

**Add:**
- Simple API calls to enhanced Scriptura
- Error handling for parsing failures
- Caching for parsed references

#### 4.1.2 New Implementation
```python
class ScripturaService:
    def __init__(self, config=None):
        # ... existing init code ...
        self.parsing_enabled = config.get('scriptura', {}).get('parsing_enabled', True)
    
    def get_reading_contents(self, references):
        if self.parsing_enabled:
            return self._get_parsed_readings(references)
        else:
            return self._get_simple_readings(references)
    
    def _get_parsed_readings(self, references):
        # Call enhanced Scriptura API parsing endpoint
        response = requests.post(f"{self.base_url}/api/parse/references", {
            "references": references,
            "version": self.version
        })
        return response.json()
    
    def _get_simple_readings(self, references):
        # Fallback to simple verse-by-verse fetching
        # ... existing simple logic ...
```

### 4.2 Update Configuration

#### 4.2.1 Add Parsing Configuration
**File**: `config.yml`
```yaml
scriptura:
  use_local: true
  local_port: 8081
  version: "asv"
  parsing_enabled: true  # New option
  parsing_timeout: 30    # New option
```

#### 4.2.2 Update Setup Script
**File**: `setup.sh`
- Point to forked Scriptura repository
- Install enhanced API with parsing
- Configure parsing options

### 4.3 Update Setup Script

#### 4.3.1 Point to Fork
**File**: `setup_scriptura_local.sh`
```bash
# Clone from fork instead of original
git clone https://github.com/ludwigw/ScripturaAPI.git scriptura-api
```

#### 4.3.2 Install Enhanced Features
```bash
# Install additional dependencies for parsing
pip install -r requirements.txt
pip install -r requirements-parsing.txt  # New parsing dependencies
```

### 4.4 Test Final Integration

#### 4.4.1 End-to-End Testing
```bash
# Test complete workflow
./setup.sh
# Verify all reading scenarios work
# Test performance improvements
# Verify error handling
```

#### 4.4.2 Performance Validation
- Compare parsing speed (client vs server)
- Measure memory usage
- Test with complex reference sets

#### 4.4.3 Regression Testing
- Ensure all existing functionality works
- Test fallback scenarios
- Verify error handling

## Success Criteria

### Phase 3 Complete When:
- [ ] Scriptura API forked and enhanced
- [ ] All parsing logic moved to Scriptura
- [ ] New parsing endpoints working
- [ ] Comprehensive tests passing
- [ ] Documentation updated

### Phase 4 Complete When:
- [ ] ScripturaService simplified
- [ ] All parsing logic removed from liturgical_display
- [ ] Enhanced API integrated
- [ ] Performance improved
- [ ] All tests passing

## Benefits

### Technical Benefits:
- **Separation of Concerns**: Parsing logic belongs in API
- **Reusability**: Other projects can use enhanced parsing
- **Maintainability**: Single source of truth for parsing
- **Performance**: Server-side parsing is faster
- **Testing**: Easier to test parsing in isolation

### User Benefits:
- **Faster**: No client-side parsing overhead
- **More Reliable**: Server-side parsing is more robust
- **Better Error Handling**: Centralized error management
- **Easier Updates**: Parsing improvements in one place

## Timeline

### Phase 3: 2-3 days
- Day 1: Fork and analyze parsing logic
- Day 2: Implement enhanced API
- Day 3: Test and document

### Phase 4: 1-2 days
- Day 1: Simplify ScripturaService
- Day 2: Test integration and deploy

## Risk Mitigation

### Potential Issues:
1. **API Compatibility**: Ensure enhanced API is backward compatible
2. **Performance**: Monitor parsing performance impact
3. **Error Handling**: Ensure graceful fallbacks
4. **Testing**: Comprehensive test coverage

### Mitigation Strategies:
1. **Versioning**: Use API versioning for compatibility
2. **Benchmarking**: Performance testing before deployment
3. **Fallbacks**: Keep simple parsing as fallback
4. **CI/CD**: Automated testing pipeline

## Next Steps

1. **Start Phase 3**: Fork Scriptura repository
2. **Analyze**: Extract current parsing logic
3. **Implement**: Add parsing to Scriptura API
4. **Test**: Verify enhanced API works
5. **Integrate**: Update liturgical_display
6. **Deploy**: Test in production

---

*This document will be updated as we progress through the phases.*
