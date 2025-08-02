# Create a temporary directory for Lambda packaging
$tempDir = "lambda_temp"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir

# Copy Lambda function
Copy-Item "lambda\lambda_function.py" "$tempDir\"

# Create the zip file
Compress-Archive -Path "$tempDir\*" -DestinationPath "s3_trigger.zip" -Force

# Clean up
Remove-Item $tempDir -Recurse -Force

Write-Host "Lambda package created: s3_trigger.zip"