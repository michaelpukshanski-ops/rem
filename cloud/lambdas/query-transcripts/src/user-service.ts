/**
 * User management service
 * Handles user lookup and creation in DynamoDB
 */

import { DynamoDBDocumentClient, QueryCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';
import { User } from './types';

/**
 * Get user by Clerk user ID, or create if doesn't exist
 */
export async function getOrCreateUserByClerkId(
  dynamoClient: DynamoDBDocumentClient,
  usersTable: string,
  clerkUserId: string,
  email: string
): Promise<User> {
  // First, try to find existing user by clerkUserId
  const queryResult = await dynamoClient.send(
    new QueryCommand({
      TableName: usersTable,
      IndexName: 'ClerkUserIdIndex',
      KeyConditionExpression: 'clerkUserId = :clerkUserId',
      ExpressionAttributeValues: {
        ':clerkUserId': clerkUserId,
      },
      Limit: 1,
    })
  );

  if (queryResult.Items && queryResult.Items.length > 0) {
    return queryResult.Items[0] as User;
  }

  // User doesn't exist, create new one
  const now = new Date().toISOString();
  const newUser: User = {
    userId: randomUUID(),
    clerkUserId,
    email,
    createdAt: now,
    updatedAt: now,
  };

  await dynamoClient.send(
    new PutCommand({
      TableName: usersTable,
      Item: newUser,
      ConditionExpression: 'attribute_not_exists(userId)',
    })
  );

  console.log(`Created new user: ${newUser.userId} for clerkUserId: ${clerkUserId}`);
  return newUser;
}

/**
 * Get user by email
 */
export async function getUserByEmail(
  dynamoClient: DynamoDBDocumentClient,
  usersTable: string,
  email: string
): Promise<User | null> {
  const queryResult = await dynamoClient.send(
    new QueryCommand({
      TableName: usersTable,
      IndexName: 'EmailIndex',
      KeyConditionExpression: 'email = :email',
      ExpressionAttributeValues: {
        ':email': email,
      },
      Limit: 1,
    })
  );

  if (queryResult.Items && queryResult.Items.length > 0) {
    return queryResult.Items[0] as User;
  }

  return null;
}

