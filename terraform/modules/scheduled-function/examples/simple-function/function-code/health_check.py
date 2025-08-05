"""
Simple health check function example for the scheduled function module.
This function demonstrates how to structure your code for the module.
"""

import os
import json
import logging
import functions_framework
from google.cloud import logging as cloud_logging

# Set up logging
cloud_logging.Client().setup_logging()
logger = logging.getLogger(__name__)

@functions_framework.cloud_event
def main(cloud_event):
    """
    Main function entry point for the scheduled health check.
    
    Args:
        cloud_event: Cloud Functions event object
        
    Returns:
        dict: Status information
    """
    logger.info("Health check function started")
    
    try:
        # Get environment variables
        env = os.environ.get('ENV', 'unknown')
        log_level = os.environ.get('LOG_LEVEL', 'INFO')
        api_token = os.environ.get('API_TOKEN', 'not-configured')
        
        # Log configuration (don't log secrets!)
        logger.info(f"Environment: {env}")
        logger.info(f"Log level: {log_level}")
        logger.info(f"API token configured: {'Yes' if api_token != 'not-configured' else 'No'}")
        
        # Perform health checks
        checks = {
            'environment_configured': env != 'unknown',
            'secrets_available': api_token != 'not-configured',
            'function_responsive': True,
        }
        
        # Determine overall health
        all_healthy = all(checks.values())
        
        result = {
            'status': 'healthy' if all_healthy else 'unhealthy',
            'timestamp': cloud_event['time'] if cloud_event else 'unknown',
            'checks': checks,
            'environment': env
        }
        
        if all_healthy:
            logger.info("All health checks passed")
        else:
            logger.warning(f"Some health checks failed: {checks}")
        
        return result
        
    except Exception as e:
        logger.error(f"Health check failed with error: {str(e)}")
        return {
            'status': 'error',
            'error': str(e),
            'timestamp': cloud_event['time'] if cloud_event else 'unknown'
        }

if __name__ == "__main__":
    # For local testing
    print("Testing health check function locally...")
    result = main(None)
    print(json.dumps(result, indent=2)) 