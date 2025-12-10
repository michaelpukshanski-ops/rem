# Privacy Policy for REM Memory Assistant

**Last Updated:** December 10, 2024

---

## Overview

This ChatGPT Custom GPT ("REM Memory Assistant") connects to a personal REM (Recording & Memory) system hosted on private AWS infrastructure. This system is for personal use only and processes only the owner's audio recordings and transcriptions.

---

## Data Source

- **Type:** Personal audio recordings and their transcriptions
- **Owner:** All data belongs to the system owner
- **Third-Party Data:** None - only personal recordings are processed

---

## Data Storage

All data is stored in the owner's private AWS account:

- **Audio Recordings:** Amazon S3 buckets (private, encrypted)
- **Transcriptions:** Amazon DynamoDB tables (private, encrypted)
- **Metadata:** Amazon DynamoDB tables (private, encrypted)
- **API Logs:** Amazon CloudWatch Logs (private)

---

## Data Usage

- **Purpose:** Search and retrieve personal audio transcriptions via ChatGPT
- **API Access:** Protected by API key authentication
- **Data Transmission:** All communication uses HTTPS encryption
- **Third-Party Sharing:** No data is shared with third parties
- **Data Retention:** Controlled by the owner via AWS lifecycle policies

---

## Security

- **Authentication:** API key-based authentication
- **Encryption:** All data encrypted in transit (HTTPS) and at rest (AWS encryption)
- **Access Control:** Restricted to owner's AWS account only
- **Infrastructure:** Managed via Terraform with security best practices

---

## User Rights

As this is a personal system:
- The owner has full control over all data
- Data can be deleted at any time via AWS console or API
- No data is collected from other users

---

## Contact

This is a personal system for individual use. For questions about this privacy policy, contact the system owner directly.

---

## Changes to This Policy

This privacy policy may be updated as the system evolves. The "Last Updated" date at the top indicates the most recent revision.

