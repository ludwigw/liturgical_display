#!/usr/bin/env python3
"""
Web server module for liturgical display.

Provides HTTP endpoints for accessing liturgical information and images.
"""

import os
import logging
from datetime import datetime, date
from flask import Flask, jsonify, render_template, send_file, abort
from pathlib import Path

from .services.data_service import DataService
from .services.wikipedia_service import WikipediaService
from .utils import log

# Initialize Flask app
app = Flask(__name__, static_folder='static')

# Initialize services
data_service = DataService()
wikipedia_service = WikipediaService()

# Configure logging
logger = logging.getLogger(__name__)

def create_app(config=None):
    """Create and configure the Flask application."""
    if config is None:
        # Load default config
        from .calendar import load_config
        config = load_config()
    
    # Configure Flask app
    web_config = config.get('web_server', {})
    app.config['HOST'] = web_config.get('host', '0.0.0.0')
    app.config['PORT'] = web_config.get('port', 8080)
    app.config['DEBUG'] = web_config.get('debug', True)  # Enable debug mode for auto-reload
    
    # Add context processor for current time and data service
    @app.context_processor
    def inject_current_time():
        from datetime import datetime
        return {
            'current_time': datetime.now(),
            'data_service': data_service
        }
    
    return app

@app.route('/')
def index():
    """Home page with navigation."""
    from datetime import date
    from flask import request, redirect
    
    # Check if a date was submitted via the form
    date_param = request.args.get('date')
    if date_param:
        try:
            # Validate the date format
            parsed_date = datetime.strptime(date_param, '%Y-%m-%d').date()
            # Redirect to the date-specific page
            return redirect(f'/{date_param}')
        except ValueError:
            # If invalid date, just render the index page
            pass
    
    return render_template('index.html', today=date.today().strftime('%Y-%m-%d'))

@app.route('/today')
def today():
    """Today's liturgical information page."""
    try:
        today_date = date.today()
        liturgical_data = data_service.get_liturgical_data(today_date)
        wikipedia_summary = None
        
        if liturgical_data.get('url'):
            wikipedia_summary = wikipedia_service.get_summary(liturgical_data['url'])
        
        # Get next artwork info if no artwork for today
        next_artwork_info = None
        if not data_service.get_artwork_path(today_date):
            next_artwork_info = data_service.get_next_artwork_info(today_date)
        
        return render_template('today.html', 
                             data=liturgical_data, 
                             wikipedia_summary=wikipedia_summary,
                             date=today_date,
                             next_artwork=next_artwork_info)
    except Exception as e:
        logger.error(f"Error rendering today page: {e}")
        abort(500)

@app.route('/<date_str>')
def date_page(date_str):
    """Liturgical information page for a specific date."""
    try:
        # Parse date string (format: YYYY-MM-DD)
        parsed_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        liturgical_data = data_service.get_liturgical_data(parsed_date)
        wikipedia_summary = None
        
        if liturgical_data.get('url'):
            wikipedia_summary = wikipedia_service.get_summary(liturgical_data['url'])
        
        # Get next artwork info if no artwork for this date
        next_artwork_info = None
        if not data_service.get_artwork_path(parsed_date):
            next_artwork_info = data_service.get_next_artwork_info(parsed_date)
        
        return render_template('date.html', 
                             data=liturgical_data, 
                             wikipedia_summary=wikipedia_summary,
                             date=parsed_date,
                             next_artwork=next_artwork_info)
    except ValueError:
        abort(400, description="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        logger.error(f"Error rendering date page for {date_str}: {e}")
        abort(500)

@app.route('/api/today')
def api_today():
    """API endpoint for today's liturgical data."""
    try:
        today_date = date.today()
        liturgical_data = data_service.get_liturgical_data(today_date)
        return jsonify(liturgical_data)
    except Exception as e:
        logger.error(f"Error getting today's data: {e}")
        abort(500)

@app.route('/api/info/<date_str>')
def api_date_info(date_str):
    """API endpoint for liturgical data for a specific date."""
    try:
        parsed_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        liturgical_data = data_service.get_liturgical_data(parsed_date)
        return jsonify(liturgical_data)
    except ValueError:
        abort(400, description="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        logger.error(f"Error getting data for {date_str}: {e}")
        abort(500)

@app.route('/api/image/today/png')
def api_today_png():
    """API endpoint for today's liturgical image in PNG format."""
    try:
        today_date = date.today()
        image_path = data_service.generate_image(today_date, 'png')
        return send_file(image_path, mimetype='image/png')
    except Exception as e:
        logger.error(f"Error generating today's PNG: {e}")
        abort(500)

@app.route('/api/image/today/bmp')
def api_today_bmp():
    """API endpoint for today's liturgical image in BMP format."""
    try:
        today_date = date.today()
        image_path = data_service.generate_image(today_date, 'bmp')
        return send_file(image_path, mimetype='image/bmp')
    except Exception as e:
        logger.error(f"Error generating today's BMP: {e}")
        abort(500)

@app.route('/api/image/<date_str>/png')
def api_date_png(date_str):
    """API endpoint for liturgical image in PNG format for a specific date."""
    try:
        parsed_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        image_path = data_service.generate_image(parsed_date, 'png')
        return send_file(image_path, mimetype='image/png')
    except ValueError:
        abort(400, description="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        logger.error(f"Error generating PNG for {date_str}: {e}")
        abort(500)

@app.route('/api/image/<date_str>/bmp')
def api_date_bmp(date_str):
    """API endpoint for liturgical image in BMP format for a specific date."""
    try:
        parsed_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        image_path = data_service.generate_image(parsed_date, 'bmp')
        return send_file(image_path, mimetype='image/bmp')
    except ValueError:
        abort(400, description="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        logger.error(f"Error generating BMP for {date_str}: {e}")
        abort(500)

@app.route('/api/artwork/today')
def api_today_artwork():
    """API endpoint for today's liturgical artwork."""
    try:
        today_date = date.today()
        artwork_path = data_service.get_artwork_path(today_date)
        if artwork_path:
            return send_file(artwork_path, mimetype='image/jpeg')
        else:
            abort(404, description="No artwork available for today")
    except Exception as e:
        logger.error(f"Error serving today's artwork: {e}")
        abort(500)

@app.route('/api/artwork/<date_str>')
def api_date_artwork(date_str):
    """API endpoint for liturgical artwork for a specific date."""
    try:
        parsed_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        artwork_path = data_service.get_artwork_path(parsed_date)
        if artwork_path:
            return send_file(artwork_path, mimetype='image/jpeg')
        else:
            abort(404, description=f"No artwork available for {date_str}")
    except ValueError:
        abort(400, description="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        logger.error(f"Error serving artwork for {date_str}: {e}")
        abort(500)

@app.route('/api/next-artwork/today')
def api_today_next_artwork():
    """API endpoint for next artwork when no artwork is available for today."""
    try:
        today_date = date.today()
        next_artwork_info = data_service.get_next_artwork_info(today_date)
        if next_artwork_info and next_artwork_info.get('cached_file'):
            return send_file(next_artwork_info['cached_file'], mimetype='image/jpeg')
        else:
            abort(404, description="No next artwork available")
    except Exception as e:
        logger.error(f"Error serving next artwork for today: {e}")
        abort(500)

@app.route('/api/next-artwork/<date_str>')
def api_date_next_artwork(date_str):
    """API endpoint for next artwork when no artwork is available for a specific date."""
    try:
        parsed_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        next_artwork_info = data_service.get_next_artwork_info(parsed_date)
        if next_artwork_info and next_artwork_info.get('cached_file'):
            return send_file(next_artwork_info['cached_file'], mimetype='image/jpeg')
        else:
            abort(404, description=f"No next artwork available for {date_str}")
    except ValueError:
        abort(400, description="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        logger.error(f"Error serving next artwork for {date_str}: {e}")
        abort(500)

@app.errorhandler(400)
def bad_request(error):
    """Handle 400 errors."""
    return jsonify({'error': error.description}), 400

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    return jsonify({'error': 'Internal server error'}), 500

def run_web_server(config=None):
    """Run the web server."""
    app = create_app(config)
    
    host = app.config['HOST']
    port = app.config['PORT']
    debug = app.config['DEBUG']
    
    log(f"[web_server.py] Starting web server on {host}:{port} (debug={debug})")
    print(f"Flask debug mode: {debug}")
    print(f"Auto-reloader enabled: True")
    print(f"Watching for changes in: {os.path.dirname(os.path.abspath(__file__))}")
    
    # Force debug mode for development
    app.run(host=host, port=port, debug=True, use_reloader=True, extra_files=[
        os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates'),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')
    ])

if __name__ == "__main__":
    run_web_server() 