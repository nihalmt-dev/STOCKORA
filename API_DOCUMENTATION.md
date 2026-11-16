
# STOCKORA 2.0 — REST API Documentation

## Smart Inventory & Order Management System

STOCKORA provides a REST API built with Node.js, Express.js, and MongoDB Atlas.

The API serves both the Flutter Web and Android applications.

## API Base URLs

**Production**

https://stockora-backend-l8i3.onrender.com

**Local Development**

http://localhost:5000

## Authentication

STOCKORA uses JWT bearer token authentication.

Protected requests must include:

```http
Authorization: Bearer YOUR_JWT_TOKEN
```

For requests containing JSON data:

```http
Content-Type: application/json
```

### Authentication Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/register` | Register a user |
| POST | `/api/auth/login` | Authenticate a user |

**Login request example:**

```json
{
  "email": "user@example.com",
  "password": "YOUR_PASSWORD"
}
```

Registration accepts `name`, `email`, and `password`.

## Role-Based Access

Three user roles are supported:

- **Admin:** System administration and user management
- **Manager:** Inventory operations and reporting
- **Staff:** Permitted daily operations and restock requests

Access permissions are enforced by backend middleware.

## Product Management

Base path: `/api/products`

| Method | Endpoint | Access |
|---|---|---|
| GET | `/api/products` | Admin, Manager, Staff |
| GET | `/api/products/:id` | Admin, Manager, Staff |
| POST | `/api/products` | Admin, Manager |
| PUT | `/api/products/:id` | Admin, Manager |
| DELETE | `/api/products/:id` | Admin |

Products support searching, SKU identification, pricing, stock quantities, and low-stock thresholds.

## Inventory Management

Base path: `/api/inventory`

| Method | Endpoint | Access |
|---|---|---|
| POST | `/api/inventory/movement` | Admin, Manager |
| GET | `/api/inventory/movements` | Admin, Manager, Staff |
| GET | `/api/inventory/low-stock` | Admin, Manager, Staff |
| POST | `/api/inventory/restock-requests` | Staff |
| GET | `/api/inventory/restock-requests` | Admin, Manager |
| PATCH | `/api/inventory/restock-requests/:id/resolve` | Admin, Manager |

### Stock Movement

**POST `/api/inventory/movement`**

```json
{
  "productId": "507f1f77bcf86cd799439012",
  "type": "IN",
  "quantity": 10,
  "note": "New stock received"
}
```

**Fields:**

- `productId`: Required MongoDB product ID
- `type`: `IN` or `OUT`
- `quantity`: Required positive integer
- `note`: Optional string

The backend prevents stock quantities from becoming negative.

### Staff Restock Request

**POST `/api/inventory/restock-requests`**

```json
{
  "productId": "507f1f77bcf86cd799439012",
  "note": "Stock is running low. Please restock."
}
```

**Validation:**

- Product must exist.
- Product stock must be at or below its low-stock threshold.
- Note must not exceed 300 characters.
- A duplicate pending request for the same product is rejected.

**Successful response:** HTTP 201 Created.

### View Restock Requests

**GET `/api/inventory/restock-requests`**

Admin and Manager can view requests, including product information, requesting staff, status, and resolution details.

### Resolve Restock Request

**PATCH `/api/inventory/restock-requests/:id/resolve`**

Replace `:id` with the restock request ID.

No request body is required.

Successful response:

```json
{
  "message": "Restock request resolved",
  "request": {}
}
```

The API marks a pending request as resolved and records the resolving user and timestamp.

**Note:** Resolving a request does not automatically add stock. Inventory quantities must be updated through the Stock In operation.

## Customer Management

Base path: `/api/customers`

| Method | Endpoint | Access |
|---|---|---|
| GET | `/api/customers` | Admin, Manager, Staff |
| GET | `/api/customers/:id` | Admin, Manager, Staff |
| POST | `/api/customers` | Admin, Manager, Staff |
| PUT | `/api/customers/:id` | Admin, Manager, Staff |
| DELETE | `/api/customers/:id` | Admin |

## Order Management

Base path: `/api/orders`

| Method | Endpoint | Access |
|---|---|---|
| POST | `/api/orders` | Admin, Manager, Staff |
| GET | `/api/orders` | Admin, Manager, Staff |
| GET | `/api/orders/:id` | Admin, Manager, Staff |

### Create Order

**POST `/api/orders`**

```json
{
  "customerId": "507f1f77bcf86cd799439011",
  "items": [
    {
      "productId": "507f1f77bcf86cd799439012",
      "quantity": 2
    },
    {
      "productId": "507f1f77bcf86cd799439013",
      "quantity": 1
    }
  ]
}
```

**Validation:**

- A valid customer ID is required.
- An order must contain at least one product.
- Product IDs must be valid.
- Quantities must be positive integers.
- Duplicate products in the same order are rejected.

Order creation uses a MongoDB transaction to coordinate order processing and stock updates.

## Dashboard

| Method | Endpoint | Access |
|---|---|---|
| GET | `/api/dashboard/stats` | Admin, Manager, Staff |

The dashboard provides product, inventory, and order summaries.

Financial information is restricted according to user role.

## Reports

| Method | Endpoint | Access |
|---|---|---|
| GET | `/api/reports/sales` | Admin, Manager |
| GET | `/api/reports/inventory` | Admin, Manager |

These endpoints provide sales and inventory reporting data.

## User Management

Base path: `/api/users`

**Access: Admin only**

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/users` | List users |
| POST | `/api/users` | Create user |
| PATCH | `/api/users/:id/role` | Update user role |
| PATCH | `/api/users/:id/status` | Update account status |
| DELETE | `/api/users/:id` | Delete user |

All user management endpoints require authentication and Admin authorization.

## Health Check

**GET `/`**

Expected response:

```json
{
  "success": true,
  "message": "STOCKORA API is running successfully"
}
```

## Common HTTP Status Codes

| Code | Meaning |
|---|---|
| 200 | Request successful |
| 201 | Resource created |
| 400 | Invalid request |
| 401 | Authentication required or invalid |
| 403 | Insufficient permissions |
| 404 | Resource not found |
| 409 | Conflict, such as duplicate pending request |
| 500 | Internal server error |

Actual status codes depend on the endpoint and validation result.

## Security

- JWT authentication
- Role-based authorization
- bcrypt password hashing
- Request validation
- MongoDB ObjectId validation where applicable
- Environment-based configuration
- Protected administrative endpoints

Never expose database credentials, JWT secrets, or production passwords in documentation.

## Project Links

**Web Application:**  
https://stockora-inventory.netlify.app

**Android APK:**  
https://github.com/nihalmt-dev/STOCKORA/releases/download/v2.0.0/app-release.apk

**GitHub Repository:**  
https://github.com/nihalmt-dev/STOCKORA

## Developer

**Mohammed Nihal MT**

Full Stack & Mobile Application Developer

Codebxo Full Stack Developer Internship Technical Assessment.
