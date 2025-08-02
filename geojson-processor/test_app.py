import json
import requests
import time

def test_health_endpoint():
    """Test the health check endpoint"""
    try:
        response = requests.get('http://localhost:5000/health')
        print(f"Health check status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return False

def test_manual_process():
    """Test manual processing endpoint"""
    test_data = {
        "bucket": "your-test-bucket",
        "key": "test-file.geojson"
    }
    
    try:
        response = requests.post(
            'http://localhost:5000/process',
            json=test_data,
            headers={'Content-Type': 'application/json'}
        )
        print(f"Manual process status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Manual process test failed: {e}")
        return False

def test_stats_endpoint():
    """Test stats endpoint"""
    try:
        response = requests.get('http://localhost:5000/stats')
        print(f"Stats status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Stats test failed: {e}")
        return False

if __name__ == '__main__':
    print("Testing GeoJSON Processor endpoints...")
    
    # Wait a bit for the server to start
    time.sleep(2)
    
    # Run tests
    health_ok = test_health_endpoint()
    stats_ok = test_stats_endpoint()
    
    print(f"\nTest Results:")
    print(f"Health endpoint: {'PASS' if health_ok else 'FAIL'}")
    print(f"Stats endpoint: {'PASS' if stats_ok else 'FAIL'}")