# STOCKORA 2.0
### Smart Inventory & Order Management System

A full-stack inventory and order management solution built using **Flutter, Node.js, Express.js, and MongoDB**.

STOCKORA provides a centralized workspace for managing products, inventory, customers, orders, and business reports across web and Android platforms.

## Key Features

### Authentication & Role-Based Access
- Secure login using JWT authentication
- Password hashing with bcrypt
- Three user roles: Admin, Manager, and Staff
- Backend-enforced role-based permissions
- User account management for administrators

### Dashboard
- Product and order summaries
- Sales overview for authorized users
- Low-stock alerts
- Recent orders
- Responsive dashboard with animated UI elements

### Product Management
- Add, edit, delete, and search products
- SKU-based product identification
- Product pricing and stock tracking
- Low-stock threshold monitoring

### Inventory Management
- Stock In and Stock Out operations
- Inventory movement history
- Low-stock detection
- Staff restock requests
- Manager/Admin restock notifications and request resolution

### Customer Management
- Add and update customer details
- Search customer records
- Role-based customer deletion

### Order Management
- Create customer orders
- Add multiple products to orders
- Automatic stock deduction
- Order history and sales tracking

### Reports & Analytics
- Sales reports
- Inventory reports
- Stock valuation and inventory health
- Data visualization
- CSV export support

## Technology Stack

| Layer | Technology |
|---|---|
| Web Application | Flutter Web |
| Android Application | Flutter |
| Backend | Node.js, Express.js |
| Database | MongoDB Atlas |
| Authentication | JWT, bcrypt |
| API | REST |
| Version Control | Git, GitHub |

## Role-Based Permissions

| Feature | Admin | Manager | Staff |
|---|---|---|---|
| View Dashboard | Yes | Yes | Yes |
| View Products | Yes | Yes | Yes |
| Add/Edit Products | Yes | Yes | No |
| Delete Products | Yes | No | No |
| Stock In/Out | Yes | Yes | No |
| Request Restock | No | No | Yes |
| View Restock Requests | Yes | Yes | No |
| Manage Customers | Yes | Yes | Limited |
| Create Orders | Yes | Yes | Yes |
| View Financial Reports | Yes | Yes | No |
| Manage Users | Yes | No | No |

## Project Structure

```text
Smart-Inventory-System/
├── backend/
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   ├── server.js
│   └── package.json
├── inventory_app/
│   ├── android/
│   ├── lib/
│   │   ├── screens/
│   │   └── main.dart
│   └── pubspec.yaml
└── README.md
```

## Installation and Setup

### Prerequisites

- Flutter SDK
- Node.js and npm
- MongoDB Atlas database
- Git
- Android SDK (for Android development)

### Backend Setup

```bash
cd backend
npm install
```

Create a `.env` file inside the `backend` directory:

```env
PORT=5000
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=your_secure_jwt_secret
```

Start the backend:

```bash
node server.js
```

### Flutter Setup

Open another terminal:

```bash
cd inventory_app
flutter pub get
flutter run -d chrome
```

For Android, connect a configured device and run:

```bash
flutter devices
flutter run -d <device-id>
```

**Important:** The current development API URL uses `http://localhost:5000`. Configure the appropriate backend address or port forwarding when running on a physical Android device. A deployed version requires a reachable HTTPS API endpoint.

## REST API Overview

| Module | Base Endpoint |
|---|---|
| Authentication | `/api/auth` |
| Products | `/api/products` |
| Inventory | `/api/inventory` |
| Customers | `/api/customers` |
| Orders | `/api/orders` |
| Dashboard | `/api/dashboard` |
| Reports | `/api/reports` |
| User Management | `/api/users` |

Protected endpoints require a JWT bearer token and enforce role-based authorization.

## Security

- JWT-protected API routes
- Hashed passwords
- Role-based backend authorization
- Input validation
- Environment-based configuration
- Sensitive credentials excluded from version control

## Project Status

**Development and testing**

The web and Android applications share a common backend and MongoDB database. Core modules and role-based workflows have been implemented and tested locally.

Production deployment is not yet documented.

## Repository

https://github.com/nihalmt-dev/STOCKORA

## Developer

**Mohammed Nihal MT**

Full Stack & Mobile Application Developer

Developed as part of the Codebxo Full Stack Developer Internship technical assessment.