Write-Host "Starting GeoJSON Processor locally..." -ForegroundColor Green

# Set environment variables for local testing
$env:DB_HOST = "localhost"
$env:DB_USER = "postgres"
$env:DB_PASSWORD = "Hello123"
$env:DB_NAME = "mydb"
$env:AWS_REGION = "eu-central-1"

# Unset S3 variables to run in web server mode
Remove-Item Env:S3_BUCKET -ErrorAction SilentlyContinue
Remove-Item Env:S3_KEY -ErrorAction SilentlyContinue

Write-Host "Environment variables set:" -ForegroundColor Yellow
Write-Host "  DB_HOST: $env:DB_HOST"
Write-Host "  DB_USER: $env:DB_USER"
Write-Host "  DB_NAME: $env:DB_NAME"
Write-Host "  AWS_REGION: $env:AWS_REGION"
Write-Host ""

# Check if requirements are installed
Write-Host "Checking Python dependencies..." -ForegroundColor Yellow
try {
    python -c "import flask, boto3, psycopg2, geojson" 2>$null
    Write-Host "✓ All dependencies are installed" -ForegroundColor Green
} catch {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
}

Write-Host ""
Write-Host "Starting application on http://localhost:5000" -ForegroundColor Green
Write-Host "Available endpoints:" -ForegroundColor Cyan
Write-Host "  GET  /health  - Health check"
Write-Host "  POST /process - Manual file processing"
Write-Host "  GET  /stats   - Processing statistics"
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

# Run the application
python app.py