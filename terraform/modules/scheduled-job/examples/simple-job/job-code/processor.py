#!/usr/bin/env python3
"""
Sample Cloud Run Job for data processing.
This script demonstrates a basic job that can be scheduled to run periodically.
"""

import os
import sys
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    """Main function for the Cloud Run Job."""
    logger.info("Starting data processing job")
    
    # Get environment variables
    env = os.getenv('ENV', 'development')
    log_level = os.getenv('LOG_LEVEL', 'INFO')
    database_url = os.getenv('DATABASE_URL')
    
    logger.info(f"Environment: {env}")
    logger.info(f"Log level: {log_level}")
    logger.info(f"Database URL configured: {database_url is not None}")
    
    # Simulate data processing work
    logger.info("Processing data...")
    
    # Simulate some work
    for i in range(5):
        logger.info(f"Processing batch {i + 1}/5")
        # In a real job, you would do actual data processing here
        # For example: database queries, API calls, file processing, etc.
    
    logger.info("Data processing completed successfully")
    
    # Return exit code 0 for success
    return 0

if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except Exception as e:
        logger.error(f"Job failed with error: {e}")
        sys.exit(1)
