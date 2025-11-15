"""
Database Writer Lambda Function
Polls SQS queue and writes image metadata to DynamoDB
"""

import json
import logging
import os
from datetime import datetime
from decimal import Decimal

import boto3

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")

# Environment variables
TABLE_NAME = os.environ["DYNAMODB_TABLE"]
table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    """
    Main Lambda handler function
    Processes SQS messages in batch

    Args:
        event: SQS event with batch of messages
        context: Lambda context object

    Returns:
        Batch item failures for SQS partial batch responses
    """
    logger.info(f"Processing {len(event['Records'])} messages")

    failed_items = []

    # Process each message in the batch
    for record in event["Records"]:
        try:
            process_message(record)
            logger.info(f"Successfully processed message: {record['messageId']}")

        except Exception as e:
            logger.error(
                f"Error processing message {record['messageId']}: {str(e)}",
                exc_info=True,
            )
            # Add to failed items for retry
            failed_items.append({"itemIdentifier": record["messageId"]})

    # Return failed message IDs for SQS to retry
    # Successfully processed messages will be deleted from queue
    return {"batchItemFailures": failed_items}


def process_message(record):
    """
    Process a single SQS message and write to DynamoDB

    Args:
        record: SQS message record
    """
    # Parse message body
    message_body = json.loads(record["body"])
    logger.info(f"Processing metadata for image: {message_body.get('imageId')}")

    # Prepare item for DynamoDB
    item = prepare_dynamodb_item(message_body)

    # Write to DynamoDB
    write_to_dynamodb(item)


def prepare_dynamodb_item(metadata):
    """
    Prepare metadata for DynamoDB insertion
    Converts floats to Decimals (required by DynamoDB)

    Args:
        metadata: Dictionary containing image metadata

    Returns:
        Dictionary formatted for DynamoDB
    """

    # Convert float values to Decimal for DynamoDB
    def convert_floats(obj):
        if isinstance(obj, float):
            return Decimal(str(obj))
        elif isinstance(obj, dict):
            return {k: convert_floats(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_floats(i) for i in obj]
        return obj

    item = convert_floats(metadata)

    # Add timestamps if not present
    current_time = datetime.utcnow().isoformat()
    if "createdAt" not in item:
        item["createdAt"] = current_time
    item["updatedAt"] = current_time

    # Add TTL (optional - auto-delete after 1 year)
    # Uncomment if you want automatic data expiration
    # from datetime import timedelta
    # ttl = datetime.utcnow() + timedelta(days=365)
    # item['ttl'] = int(ttl.timestamp())

    logger.info(f"Prepared DynamoDB item: {json.dumps(item, default=str)}")
    return item


def write_to_dynamodb(item):
    """
    Write item to DynamoDB with error handling

    Args:
        item: Dictionary containing item data
    """
    try:
        # Validate required fields
        if "imageId" not in item:
            raise ValueError("Missing required field: imageId")

        if "uploadDate" not in item:
            raise ValueError("Missing required field: uploadDate")

        # Write to DynamoDB
        response = table.put_item(
            Item=item,
            # Optional: Prevent overwriting existing items
            ConditionExpression="attribute_not_exists(imageId)",
        )

        logger.info(
            f"Successfully wrote to DynamoDB. "
            f"ImageId: {item['imageId']}, "
            f"ConsumedCapacity: {response.get('ConsumedCapacity', 'N/A')}"
        )

    except table.meta.client.exceptions.ConditionalCheckFailedException:
        logger.warning(f"Item already exists: {item['imageId']}")
        # Item already exists (duplicate processing)
        # This is OK - idempotency in action
        # Message will be deleted from queue

    except Exception as e:
        logger.error(f"Error writing to DynamoDB: {str(e)}", exc_info=True)
        # Re-raise to trigger retry
        raise


def update_existing_item(image_id, updates):
    """
    Helper function to update an existing item
    (Optional - use if you need to update instead of create)

    Args:
        image_id: Primary key of item to update
        updates: Dictionary of fields to update
    """
    try:
        # Build update expression
        update_expr = "SET "
        expr_attr_values = {}

        for i, (key, value) in enumerate(updates.items()):
            update_expr += f"{key} = :val{i}, "
            expr_attr_values[f":val{i}"] = value

        # Add updatedAt
        update_expr += "updatedAt = :updated"
        expr_attr_values[":updated"] = datetime.utcnow().isoformat()

        response = table.update_item(
            Key={"imageId": image_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_attr_values,
            ReturnValues="UPDATED_NEW",
        )

        logger.info(f"Updated item: {image_id}")
        return response

    except Exception as e:
        logger.error(f"Error updating item: {str(e)}", exc_info=True)
        raise
