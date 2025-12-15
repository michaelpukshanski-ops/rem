# DynamoDB Table for Recording Metadata

resource "aws_dynamodb_table" "recordings" {
  name           = "${var.project_name}-recordings-${var.environment}"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity

  hash_key  = "PK"   # userId
  range_key = "SK"   # recordingId

  # Primary key attributes
  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # GSI for querying by device and time
  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  # Global Secondary Index for device + time queries
  global_secondary_index {
    name            = "DeviceTimeIndex"
    hash_key        = "GSI1PK"  # deviceId
    range_key       = "GSI1SK"  # startedAt
    projection_type = "ALL"
    read_capacity   = var.dynamodb_read_capacity
    write_capacity  = var.dynamodb_write_capacity
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  # TTL for automatic cleanup (optional)
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = {
    Name = "REM Recordings Metadata"
  }
}

# ============================================================================
# DynamoDB Table for Users
# ============================================================================

resource "aws_dynamodb_table" "users" {
  name           = "${var.project_name}-users-${var.environment}"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity

  hash_key = "userId"  # Internal UUID

  attribute {
    name = "userId"
    type = "S"
  }

  # For looking up by Clerk user ID
  attribute {
    name = "clerkUserId"
    type = "S"
  }

  # For looking up by email
  attribute {
    name = "email"
    type = "S"
  }

  # GSI to query by clerkUserId
  global_secondary_index {
    name            = "ClerkUserIdIndex"
    hash_key        = "clerkUserId"
    projection_type = "ALL"
    read_capacity   = var.dynamodb_read_capacity
    write_capacity  = var.dynamodb_write_capacity
  }

  # GSI to query by email
  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
    read_capacity   = var.dynamodb_read_capacity
    write_capacity  = var.dynamodb_write_capacity
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "REM Users"
  }
}

# Auto-scaling for read capacity
resource "aws_appautoscaling_target" "dynamodb_read" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_read_capacity
  resource_id        = "table/${aws_dynamodb_table.recordings.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_read" {
  name               = "${var.project_name}-read-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_read.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_read.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_read.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

# Auto-scaling for write capacity
resource "aws_appautoscaling_target" "dynamodb_write" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_write_capacity
  resource_id        = "table/${aws_dynamodb_table.recordings.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_write" {
  name               = "${var.project_name}-write-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_write.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_write.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_write.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}

# ============================================================================
# Auto-scaling for Users table
# ============================================================================

resource "aws_appautoscaling_target" "users_read" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_read_capacity
  resource_id        = "table/${aws_dynamodb_table.users.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "users_read" {
  name               = "${var.project_name}-users-read-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.users_read.resource_id
  scalable_dimension = aws_appautoscaling_target.users_read.scalable_dimension
  service_namespace  = aws_appautoscaling_target.users_read.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_target" "users_write" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_write_capacity
  resource_id        = "table/${aws_dynamodb_table.users.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "users_write" {
  name               = "${var.project_name}-users-write-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.users_write.resource_id
  scalable_dimension = aws_appautoscaling_target.users_write.scalable_dimension
  service_namespace  = aws_appautoscaling_target.users_write.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}
