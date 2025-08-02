#!/bin/bash
cd lambda
zip -r ../s3_trigger.zip lambda_function.py
cd ..
echo "Lambda function packaged as s3_trigger.zip"