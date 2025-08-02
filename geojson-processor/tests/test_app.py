import pytest
import json
from unittest.mock import patch, MagicMock
import sys
import os

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app, validate_geojson

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Test the health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'

def test_validate_geojson_valid():
    """Test GeoJSON validation with valid data"""
    valid_geojson = {
        "type": "Feature",
        "properties": {"name": "test"},
        "geometry": {
            "type": "Point",
            "coordinates": [0, 0]
        }
    }
    
    is_valid, message = validate_geojson(valid_geojson)
    assert is_valid == True

def test_validate_geojson_invalid():
    """Test GeoJSON validation with invalid data"""
    invalid_geojson = {
        "type": "InvalidType",
        "properties": {},
        "geometry": {}
    }
    
    is_valid, message = validate_geojson(invalid_geojson)
    assert is_valid == False

@patch('app.get_db_connection')
def test_stats_endpoint(mock_db, client):
    """Test the stats endpoint"""
    # Mock database connection and cursor
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_cursor.fetchone.return_value = (5,)  # Mock count
    mock_conn.cursor.return_value = mock_cursor
    mock_db.return_value = mock_conn
    
    response = client.get('/stats')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'total_features' in data