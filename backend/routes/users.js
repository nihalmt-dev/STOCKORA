
const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const User = require("../models/User");
const {
  protect,
  authorize,
} = require("../middleware/authMiddleware");

const router = express.Router();

// All routes: Admin only
router.use(protect);
router.use(authorize("admin"));

const normalizeEmail = (email) =>
  typeof email === "string"
    ? email.trim().toLowerCase()
    : "";

const validRole = (role) =>
  ["admin", "manager", "staff"].includes(role);

const safeUser = (user) => ({
  id: user._id,
  name: user.name,
  email: user.email,
  role: user.role,
  isActive: user.isActive !== false,
  createdAt: user.createdAt,
});

// GET /api/users
// List all users
router.get("/", async (req, res) => {
  try {
    const users = await User.find()
      .select("-password")
      .sort({ createdAt: -1 });

    res.json(users.map(safeUser));
  } catch (error) {
    console.error("List users error:", error.message);
    res.status(500).json({
      message: "Unable to load users",
    });
  }
});

// POST /api/users
// Create Manager or Staff
router.post("/", async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    const normalizedEmail = normalizeEmail(email);

    if (
      typeof name !== "string" ||
      !name.trim() ||
      !normalizedEmail ||
      typeof password !== "string" ||
      password.length < 8 ||
      !["manager", "staff"].includes(role)
    ) {
      return res.status(400).json({
        message:
          "Valid name, email, password (minimum 8 characters) and Manager/Staff role are required",
      });
    }

    const exists = await User.findOne({
      email: normalizedEmail,
    });

    if (exists) {
      return res.status(409).json({
        message: "Email already registered",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 12);

    const user = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      password: hashedPassword,
      role,
      isActive: true,
    });

    return res.status(201).json({
      message: "User created successfully",
      user: safeUser(user),
    });
  } catch (error) {
    console.error("Create user error:", error.message);

    if (error.code === 11000) {
      return res.status(409).json({
        message: "Email already registered",
      });
    }

    return res.status(500).json({
      message: "Unable to create user",
    });
  }
});

// PATCH /api/users/:id/role
// Change role
router.patch("/:id/role", async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;

    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({
        message: "Invalid user ID",
      });
    }

    if (!validRole(role)) {
      return res.status(400).json({
        message: "Invalid role",
      });
    }

    const user = await User.findById(id);

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    // Prevent Admin from demoting their own account
    if (
      user._id.toString() === req.user.id.toString() &&
      role !== "admin"
    ) {
      return res.status(403).json({
        message: "You cannot change your own Admin role",
      });
    }

    // Preserve at least one active Admin
    if (user.role === "admin" && role !== "admin" &&
        user.isActive !== false) {
      const activeAdmins = await User.countDocuments({
        role: "admin",
        isActive: { $ne: false },
      });

      if (activeAdmins <= 1) {
        return res.status(403).json({
          message: "At least one active Admin is required",
        });
      }
    }

    user.role = role;
    await user.save();

    return res.json({
      message: "User role updated successfully",
      user: safeUser(user),
    });
  } catch (error) {
    console.error("Update role error:", error.message);
    return res.status(500).json({
      message: "Unable to update role",
    });
  }
});

// PATCH /api/users/:id/status
// Activate or deactivate a user
router.patch("/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { isActive } = req.body;

    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({
        message: "Invalid user ID",
      });
    }

    if (typeof isActive !== "boolean") {
      return res.status(400).json({
        message: "isActive must be true or false",
      });
    }

    const user = await User.findById(id);

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    // Prevent Admin from deactivating themselves
    if (
      user._id.toString() === req.user.id.toString() &&
      isActive === false
    ) {
      return res.status(403).json({
        message: "You cannot deactivate your own account",
      });
    }

    // Preserve at least one active Admin
    if (
      user.role === "admin" &&
      user.isActive !== false &&
      isActive === false
    ) {
      const activeAdmins = await User.countDocuments({
        role: "admin",
        isActive: { $ne: false },
      });

      if (activeAdmins <= 1) {
        return res.status(403).json({
          message: "At least one active Admin is required",
        });
      }
    }

    user.isActive = isActive;
    await user.save();

    return res.json({
      message: isActive
        ? "User activated successfully"
        : "User deactivated successfully",
      user: safeUser(user),
    });
  } catch (error) {
    console.error("Update status error:", error.message);
    return res.status(500).json({
      message: "Unable to update user status",
    });
  }
});

module.exports = router;
