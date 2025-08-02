# GeoJSON Processor

A containerized Python application that processes GeoJSON files from Amazon S3 and stores spatial data in PostgreSQL with PostGIS support.

## 🚀 Features

- **GeoJSON Validation**: Validates incoming GeoJSON files for correctness
- **Spatial Data Storage**: Stores geometric data in PostgreSQL with PostGIS extension
- **S3 Integration**: Automatically triggered by S3 events via AWS Lambda
- **Dual Mode Operation**: 
  - ECS Task mode for production (triggered by Lambda)
  - Web server mode for development and testing
- **Comprehensive Logging**: All operations logged to CloudWatch
- **Health Monitoring**: Built-in health check and statistics endpoints

## 🏗️ Architecture