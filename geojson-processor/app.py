import json
import os
import boto3
import psycopg2
import logging
from flask import Flask, request, jsonify
from geojson import loads
from psycopg2.extras import RealDictCursor

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')
DB_NAME = os.environ.get('DB_NAME')
AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')
S3_BUCKET = os.environ.get('S3_BUCKET')
S3_KEY = os.environ.get('S3_KEY')

s3_client = boto3.client('s3', region_name=AWS_REGION)

def get_db_connection():
    """Create database connection"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            cursor_factory=RealDictCursor
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {str(e)}")
        raise

def create_geojson_table():
    """Create table for storing GeoJSON data if it doesn't exist"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # First enable PostGIS extension
        cursor.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        
        create_table_query = """
        CREATE TABLE IF NOT EXISTS geojson_data (
            id SERIAL PRIMARY KEY,
            filename VARCHAR(255) NOT NULL,
            feature_type VARCHAR(100),
            properties JSONB,
            geometry GEOMETRY,
            processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        cursor.execute(create_table_query)
        conn.commit()
        cursor.close()
        conn.close()
        logger.info("GeoJSON table created/verified successfully")
        
    except Exception as e:
        logger.error(f"Failed to create table: {str(e)}")
        raise

def validate_geojson(geojson_data):
    """
    Simple GeoJSON validation
    """
    try:
        if not isinstance(geojson_data, dict):
            return False
        
        # Check if it has required GeoJSON properties
        if 'type' not in geojson_data:
            return False
            
        valid_types = ['Feature', 'FeatureCollection', 'Point', 'LineString', 'Polygon', 'MultiPoint', 'MultiLineString', 'MultiPolygon', 'GeometryCollection']
        if geojson_data['type'] not in valid_types:
            return False
            
        return True
    except Exception as e:
        logger.error(f"Error validating GeoJSON: {e}")
        return False

def insert_geojson_to_db(filename, geojson_obj):
    """Insert GeoJSON features into database"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        features = geojson_obj.get('features', [])
        if not features and geojson_obj.get('type') == 'Feature':
            features = [geojson_obj]
        
        inserted_count = 0
        for feature in features:
            feature_type = feature.get('type', 'Feature')
            properties = json.dumps(feature.get('properties', {}))
            geometry = json.dumps(feature.get('geometry', {}))
            
            insert_query = """
            INSERT INTO geojson_data (filename, feature_type, properties, geometry)
            VALUES (%s, %s, %s, ST_GeomFromGeoJSON(%s))
            """
            
            cursor.execute(insert_query, (filename, feature_type, properties, geometry))
            inserted_count += 1
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Successfully inserted {inserted_count} features from {filename}")
        return inserted_count
        
    except Exception as e:
        logger.error(f"Database insertion failed: {str(e)}")
        raise

def process_s3_file():
    """Process GeoJSON file from S3 (triggered by Lambda)"""
    if not S3_BUCKET or not S3_KEY:
        logger.error("S3_BUCKET or S3_KEY environment variables not set")
        return

    try:
        logger.info(f"Processing file: s3://{S3_BUCKET}/{S3_KEY}")
        
        # Download file from S3
        response = s3_client.get_object(Bucket=S3_BUCKET, Key=S3_KEY)
        geojson_content = response['Body'].read().decode('utf-8')
        
        logger.info(f"Downloaded file size: {len(geojson_content)} bytes")
        
        # Validate GeoJSON
        geojson_obj = loads(geojson_content)
        is_valid_geojson = validate_geojson(geojson_obj)
        
        if not is_valid_geojson:
            logger.error(f"Invalid GeoJSON file: {S3_KEY}")
            return
        
        # Create table if it doesn't exist
        create_geojson_table()
        
        # Insert data into database
        inserted_count = insert_geojson_to_db(S3_KEY, geojson_obj)
        
        logger.info(f"Successfully processed {S3_KEY}: {inserted_count} features inserted")
        
    except Exception as e:
        logger.error(f"Failed to process S3 file {S3_KEY}: {str(e)}")
        raise

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'geojson-processor'
    }), 200

@app.route('/process', methods=['POST'])
def manual_process():
    """Manual processing endpoint for testing"""
    try:
        data = request.get_json()
        bucket = data.get('bucket')
        key = data.get('key')
        
        if not bucket or not key:
            return jsonify({'error': 'bucket and key are required'}), 400
        
        # Set environment variables for processing
        os.environ['S3_BUCKET'] = bucket
        os.environ['S3_KEY'] = key
        
        # Process the file
        process_s3_file()
        
        return jsonify({
            'message': f'Successfully processed {key} from {bucket}'
        }), 200
        
    except Exception as e:
        logger.error(f"Manual processing failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/stats', methods=['GET'])
def get_stats():
    """Get processing statistics"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get total features count
        cursor.execute("SELECT COUNT(*) as total_features FROM geojson_data")
        total_features = cursor.fetchone()['total_features']
        
        # Get files processed
        cursor.execute("SELECT COUNT(DISTINCT filename) as total_files FROM geojson_data")
        total_files = cursor.fetchone()['total_files']
        
        # Get recent files
        cursor.execute("""
            SELECT filename, COUNT(*) as feature_count, MAX(processed_at) as last_processed
            FROM geojson_data 
            GROUP BY filename 
            ORDER BY last_processed DESC 
            LIMIT 10
        """)
        recent_files = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'total_features': total_features,
            'total_files': total_files,
            'recent_files': recent_files
        }), 200
        
    except Exception as e:
        logger.error(f"Failed to get stats: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting GeoJSON Processor application")
    
    # If running as ECS task (triggered by Lambda), process the S3 file and exit
    if S3_BUCKET and S3_KEY:
        logger.info("Running in ECS task mode - processing S3 file")
        try:
            process_s3_file()
            logger.info("Processing completed successfully")
        except Exception as e:
            logger.error(f"Processing failed: {str(e)}")
            exit(1)
    else:
        # Run as Flask web server for manual testing
        logger.info("Running in web server mode")
        app.run(host='0.0.0.0', port=5000, debug=False)