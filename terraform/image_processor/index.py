"""
Image Processor Lambda Function
Triggers on S3 upload, creates thumbnail, sends metadata to SQS
"""

import json
import os
import boto3
import uuid
from datetime import datetime
from PIL import Image
from io import BytesIO
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')

# Environment variables
THUMBNAIL_BUCKET = os.environ['THUMBNAIL_BUCKET']
METADATA_QUEUE = os.environ['METADATA_QUEUE']
THUMBNAIL_SIZE = int(os.environ.get('THUMBNAIL_SIZE', 200))


def handler(event, context):
    """
    Main Lambda handler function

    Args:
        event: S3 event notification
        context: Lambda context object
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Process each S3 record in the event
        for record in event['Records']:
            process_image(record)

        return {
            'statusCode': 200,
            'body': json.dumps('Images processed successfully')
        }

    except Exception as e:
        logger.error(f"Error processing images: {str(e)}", exc_info=True)
        # Re-raise to trigger Lambda retry
        raise


def process_image(record):
    """
    Process a single image: create thumbnail and send metadata to SQS

    Args:
        record: S3 event record
    """
    # Extract S3 information
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']
    size = record['s3']['object']['size']

    logger.info(f"Processing image: s3://{bucket}/{key}")

    # Generate unique ID for this image
    image_id = str(uuid.uuid4())

    # Download image from S3
    logger.info("Downloading original image...")
    response = s3_client.get_object(Bucket=bucket, Key=key)
    image_data = response['Body'].read()

    # Create thumbnail
    logger.info("Creating thumbnail...")
    thumbnail_key = create_thumbnail(image_data, key, image_id)

    # Extract metadata
    metadata = extract_metadata(image_data, key, size, image_id, thumbnail_key)

    # Send metadata to SQS
    logger.info("Sending metadata to SQS...")
    send_to_queue(metadata)

    logger.info(f"Successfully processed image: {image_id}")


def create_thumbnail(image_data, original_key, image_id):
    """
    Create and upload thumbnail to S3

    Args:
        image_data: Original image binary data
        original_key: S3 key of original image
        image_id: Unique identifier for this image

    Returns:
        S3 key of the uploaded thumbnail
    """
    try:
        # Open image with PIL
        img = Image.open(BytesIO(image_data))

        # Convert RGBA to RGB if necessary (for JPEG compatibility)
        if img.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
            img = background

        # Create thumbnail maintaining aspect ratio
        img.thumbnail((THUMBNAIL_SIZE, THUMBNAIL_SIZE), Image.Resampling.LANCZOS)

        # Save thumbnail to BytesIO
        thumbnail_buffer = BytesIO()
        img.save(thumbnail_buffer, format='JPEG', quality=85, optimize=True)
        thumbnail_buffer.seek(0)

        # Generate thumbnail key
        file_extension = original_key.split('.')[-1]
        thumbnail_key = f"thumbnails/{image_id}.jpg"

        # Upload thumbnail to S3
        s3_client.put_object(
            Bucket=THUMBNAIL_BUCKET,
            Key=thumbnail_key,
            Body=thumbnail_buffer.getvalue(),
            ContentType='image/jpeg',
            Metadata={
                'original-key': original_key,
                'image-id': image_id
            }
        )

        logger.info(f"Thumbnail uploaded: s3://{THUMBNAIL_BUCKET}/{thumbnail_key}")
        return thumbnail_key

    except Exception as e:
        logger.error(f"Error creating thumbnail: {str(e)}", exc_info=True)
        raise


def extract_metadata(image_data, key, size, image_id, thumbnail_key):
    """
    Extract metadata from the image

    Args:
        image_data: Original image binary data
        key: S3 key of original image
        size: File size in bytes
        image_id: Unique identifier
        thumbnail_key: S3 key of thumbnail

    Returns:
        Dictionary containing image metadata
    """
    try:
        img = Image.open(BytesIO(image_data))

        metadata = {
            'imageId': image_id,
            'originalKey': key,
            'thumbnailKey': thumbnail_key,
            'fileName': key.split('/')[-1],
            'fileSize': size,
            'fileSizeKB': round(size / 1024, 2),
            'width': img.width,
            'height': img.height,
            'format': img.format,
            'mode': img.mode,
            'uploadDate': datetime.utcnow().isoformat(),
            'processingDate': datetime.utcnow().isoformat(),
            'thumbnailSize': THUMBNAIL_SIZE
        }

        # Add EXIF data if available
        if hasattr(img, '_getexif') and img._getexif():
            exif_data = img._getexif()
            if exif_data:
                # Store a few key EXIF fields
                metadata['exif'] = {
                    'available': True,
                    'fields': len(exif_data)
                }

        logger.info(f"Extracted metadata: {json.dumps(metadata, default=str)}")
        return metadata

    except Exception as e:
        logger.error(f"Error extracting metadata: {str(e)}", exc_info=True)
        # Return basic metadata even if extraction fails
        return {
            'imageId': image_id,
            'originalKey': key,
            'thumbnailKey': thumbnail_key,
            'fileName': key.split('/')[-1],
            'fileSize': size,
            'uploadDate': datetime.utcnow().isoformat(),
            'error': str(e)
        }


def send_to_queue(metadata):
    """
    Send metadata to SQS queue

    Args:
        metadata: Dictionary containing image metadata
    """
    try:
        response = sqs_client.send_message(
            QueueUrl=METADATA_QUEUE,
            MessageBody=json.dumps(metadata, default=str),
            MessageAttributes={
                'ImageId': {
                    'StringValue': metadata['imageId'],
                    'DataType': 'String'
                },
                'ProcessingDate': {
                    'StringValue': metadata.get('processingDate', ''),
                    'DataType': 'String'
                }
            }
        )

        logger.info(f"Message sent to SQS. MessageId: {response['MessageId']}")

    except Exception as e:
        logger.error(f"Error sending to SQS: {str(e)}", exc_info=True)
        raise
