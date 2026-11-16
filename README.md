
# STOCKORA 2.0
### Smart Inventory & Order Management System

A full-stack, cross-platform inventory and order management solution built with **Flutter, Node.js, Express.js, and MongoDB Atlas**.

STOCKORA provides a centralized workspace for managing products, stock movements, customers, orders, and business reports across web and Android platforms.

Developed as part of the **Codebxo Full Stack Developer Internship Technical Assessment**.

---

## Live Application

| Platform | Link |
|---|---|
| Web Application | https://stockora-inventory.netlify.app |
| Backend API | https://stockora-backend-l8i3.onrender.com |
| Android APK | https://github.com/nihalmt-dev/STOCKORA/releases/download/v2.0.0/app-release.apk |
| GitHub Repository | https://github.com/nihalmt-dev/STOCKORA |
| GitHub Releases | https://github.com/nihalmt-dev/STOCKORA/releases/tag/v2.0.0 |

**Note:** The backend uses Render's free hosting tier. The first request may take additional time when the service resumes after inactivity.

---

## Key Features

### Authentication & Role-Based Access

- Secure JWT-based authentication
- Password hashing using bcrypt
- Three user roles: Admin, Manager, and Staff
- Backend-enforced role-based authorization
- Administrator-controlled user management
- Persistent login sessions and logout functionality

### Dashboard

- Product and order summaries
- Sales overview for authorized users
- Inventory and low-stock statistics
- Recent order activity
- Responsive layout with animated UI elements
- Role-specific dashboard information

### Product Management

- Add, edit, delete, and search products
- Unique SKU-based product identification
- Product categories and pricing
- Stock quantity tracking
- Configurable low-stock thresholds

### Inventory Management

- Stock In and Stock Out operations
- Inventory movement history
- Low-stock detection and alerts
- Staff restock request functionality
- Manager/Admin restock notifications
- Restock request review and resolution

### Customer Management

- Add and update customer records
- Search customers by available details
- Role-based customer management permissions

### Order Management

- Create customer orders
- Add multiple products to a single order
- Automatic stock deduction
- Stock availability validation
- Order history and sales tracking

### Reports & Analytics

- Sales reports
- Inventory reports
- Stock valuation
- Inventory health monitoring
- Data visualization
- CSV export support

---

## Technology Stack

| Layer | Technology |
|---|---|
| Web Frontend | Flutter Web |
| Android Application | Flutter |
| Programming Language | Dart, JavaScript |
| Backend | Node.js, Express.js |
| Database | MongoDB Atlas |
| Authentication | JWT, bcrypt |
| API Architecture | REST |
| Web Hosting | Netlify |
| Backend Hosting | Render |
| Version Control | Git, GitHub |
| Android Distribution | GitHub Releases |

---

## Role-Based Permissions

STOCKORA implements three roles with different responsibilities.

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

### Admin

Full system administration, including user management, product management, inventory operations, reports, and operational oversight.

### Manager

Handles day-to-day inventory operations, product updates, restock requests, customer management, and financial reporting without administrator-level user management access.

### Staff

Handles permitted daily operations, including viewing products, creating orders, and submitting restock requests. Restricted financial and administrative information is not accessible.

---

## System Architecture

STOCKORA uses a shared backend architecture.

```text
       Flutter Web Application
                |
                |
       Flutter Android App
                |
                v
       REST API (Express.js)
                |
                v
        JWT Authentication
                |
                v
          MongoDB Atlas
```

Both Flutter applications communicate with the same REST API and share the same database.

The backend handles authentication, authorization, data validation, inventory updates, and business logic.

---

## Project Structure

```text
Smart-Inventory-System/
|
|-- backend/
|   |-- middleware/
|   |-- models/
|   |-- routes/
|   |-- server.js
|   |-- package.json
|
|-- inventory_app/
|   |-- android/
|   |-- web/
|   |-- lib/
|   |   |-- config/
|   |   |-- screens/
|   |   |-- main.dart
|   |-- pubspec.yaml
|
|-- README.md
```

---

## Installation and Setup

### Prerequisites

- Flutter SDK
- Dart SDK
- Node.js and npm
- MongoDB Atlas database
- Git
- Android SDK (for Android development)

### 1. Clone the Repository

```bash
git clone https://github.com/nihalmt-dev/STOCKORA.git
cd STOCKORA
```

### 2. Backend Setup

Navigate to the backend directory:

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

Replace the placeholders with your own secure configuration values.

Start the backend:

```bash
node server.js
```

The backend runs locally at:

```text
http://localhost:5000
```

### 3. Flutter Setup

Open another terminal and navigate to the Flutter application:

```bash
cd inventory_app
flutter pub get
```

Run the web application using the deployed backend:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://stockora-backend-l8i3.onrender.com
```

For local development, you can use:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```

### 4. Run on Android

Connect an Android device with USB debugging enabled.

List available devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=https://stockora-backend-l8i3.onrender.com
```

Replace `YOUR_DEVICE_ID` with the connected Android device ID.

---

## Production Builds

### Flutter Web Build

```bash
cd inventory_app
flutter build web --release --dart-define=API_BASE_URL=https://stockora-backend-l8i3.onrender.com
```

Build output:

```text
inventory_app/build/web/
```

The web application is deployed using Netlify.

### Android Release APK

```bash
cd inventory_app
flutter build apk --release --dart-define=API_BASE_URL=https://stockora-backend-l8i3.onrender.com
```

APK output:

```text
inventory_app/build/app/outputs/flutter-apk/app-release.apk
```

The Android release is distributed through GitHub Releases.

---

## REST API Overview
For complete API endpoints, authentication, role permissions, and request examples, see [API Documentation](API_DOCUMENTATION.md).

The backend provides RESTful endpoints for the main application modules.

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

### Authentication

Protected endpoints use JWT bearer token authentication.

Example request header:

```http
Authorization: Bearer YOUR_JWT_TOKEN
```

The backend validates authentication tokens and enforces permissions based on the authenticated user's role.

### API Base URL

Production:

```text
https://stockora-backend-l8i3.onrender.com
```

Local development:

```text
http://localhost:5000
```

---

## Security

STOCKORA implements the following security practices:

- JWT-based authentication
- Password hashing with bcrypt
- Backend-enforced role-based authorization
- Protected API endpoints
- Request input validation
- Environment-based configuration
- Restricted access to administrative operations
- Sensitive credentials excluded from version control

**Important:** Never commit `.env` files, database credentials, or JWT secrets to the repository.

---

## Deployment

### Frontend — Netlify

The Flutter Web application is hosted on Netlify.

https://stockora-inventory.netlify.app

### Backend — Render

The Node.js and Express.js REST API is hosted on Render.

https://stockora-backend-l8i3.onrender.com

### Database — MongoDB Atlas

MongoDB Atlas provides the cloud database used by the backend.

### Android — GitHub Releases

The Android application is distributed as a release APK.

https://github.com/nihalmt-dev/STOCKORA/releases/tag/v2.0.0

---

## Testing

The application has been tested across web and Android environments.

Testing includes:

- Login and logout functionality
- Persistent login sessions
- Admin, Manager, and Staff access
- Role-based permissions
- Product management
- Inventory stock movements
- Low-stock alerts and restock requests
- Customer management
- Multi-product order creation
- Automatic stock deduction
- Dashboard and reports
- Android release APK connectivity
- Production backend integration

---

## Project Status

**Deployed and tested**

- Flutter Web application deployed on Netlify
- Node.js and Express.js backend deployed on Render
- MongoDB Atlas cloud database connected
- Android release APK published through GitHub Releases
- Core inventory and order management modules implemented
- Role-based access and restock workflows implemented
- Web and Android applications connected to a shared backend

---

## Future Enhancements

Potential future improvements include:

- Push notifications for inventory alerts
- Barcode and QR code scanning
- Advanced sales analytics
- PDF invoice generation
- Automated inventory forecasting
- Additional reporting and export options

---

## Repository

https://github.com/nihalmt-dev/STOCKORA

## Developer

**Mohammed Nihal MT**

Full Stack & Mobile Application Developer

Developed as part of the **Codebxo Full Stack Developer Internship Technical Assessment**.

---

**STOCKORA 2.0 — Smart Inventory. Better Management.**
