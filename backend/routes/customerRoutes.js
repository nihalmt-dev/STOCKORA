
const express = require("express");
const mongoose = require("mongoose");

const Customer = require("../models/Customer");
const {
  protect,
  authorize,
} = require("../middleware/authMiddleware");

const router = express.Router();

// Login required for all customer routes
router.use(protect);

// GET all customers + search
// Admin, Manager, Staff
router.get(
  "/",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      const search = String(req.query.search || "").trim();

      // Escape special regex characters
      const escapedSearch = search.replace(
        /[.*+?^${}()|[\]\\]/g,
        "\\$&"
      );

      const filter = search
        ? {
            $or: [
              {
                name: {
                  $regex: escapedSearch,
                  $options: "i",
                },
              },
              {
                email: {
                  $regex: escapedSearch,
                  $options: "i",
                },
              },
              {
                phone: {
                  $regex: escapedSearch,
                  $options: "i",
                },
              },
            ],
          }
        : {};

      const customers = await Customer.find(filter).sort({
        createdAt: -1,
      });

      return res.json(customers);
    } catch (error) {
      console.error("Fetch customers:", error.message);

      return res.status(500).json({
        message: "Failed to fetch customers",
      });
    }
  }
);

// GET single customer
// Admin, Manager, Staff
router.get(
  "/:id",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      if (!mongoose.isValidObjectId(req.params.id)) {
        return res.status(400).json({
          message: "Invalid customer ID",
        });
      }

      const customer = await Customer.findById(
        req.params.id
      );

      if (!customer) {
        return res.status(404).json({
          message: "Customer not found",
        });
      }

      return res.json(customer);
    } catch (error) {
      console.error("Fetch customer:", error.message);

      return res.status(500).json({
        message: "Failed to fetch customer",
      });
    }
  }
);

// POST add customer
// Admin, Manager, Staff
router.post(
  "/",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      const { name, email, phone, address } = req.body;

      const customer = await Customer.create({
        name,
        email,
        phone,
        address,
      });

      return res.status(201).json({
        message: "Customer added successfully",
        customer,
      });
    } catch (error) {
      if (error.name === "ValidationError") {
        return res.status(400).json({
          message: error.message,
        });
      }

      if (error.code === 11000) {
        return res.status(409).json({
          message: "Customer already exists",
        });
      }

      console.error("Add customer:", error.message);

      return res.status(500).json({
        message: "Failed to add customer",
      });
    }
  }
);

// PUT update customer
// Admin, Manager, Staff
router.put(
  "/:id",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      if (!mongoose.isValidObjectId(req.params.id)) {
        return res.status(400).json({
          message: "Invalid customer ID",
        });
      }

      const allowedFields = [
        "name",
        "email",
        "phone",
        "address",
      ];

      const updates = {};

      for (const field of allowedFields) {
        if (
          Object.prototype.hasOwnProperty.call(
            req.body,
            field
          )
        ) {
          updates[field] = req.body[field];
        }
      }

      if (Object.keys(updates).length === 0) {
        return res.status(400).json({
          message: "No valid fields to update",
        });
      }

      const customer = await Customer.findByIdAndUpdate(
        req.params.id,
        updates,
        {
          new: true,
          runValidators: true,
        }
      );

      if (!customer) {
        return res.status(404).json({
          message: "Customer not found",
        });
      }

      return res.json({
        message: "Customer updated successfully",
        customer,
      });
    } catch (error) {
      if (error.name === "ValidationError") {
        return res.status(400).json({
          message: error.message,
        });
      }

      if (error.code === 11000) {
        return res.status(409).json({
          message: "Customer already exists",
        });
      }

      console.error("Update customer:", error.message);

      return res.status(500).json({
        message: "Failed to update customer",
      });
    }
  }
);

// DELETE customer
// Admin only
router.delete(
  "/:id",
  authorize("admin"),
  async (req, res) => {
    try {
      if (!mongoose.isValidObjectId(req.params.id)) {
        return res.status(400).json({
          message: "Invalid customer ID",
        });
      }

      const customer = await Customer.findByIdAndDelete(
        req.params.id
      );

      if (!customer) {
        return res.status(404).json({
          message: "Customer not found",
        });
      }

      return res.json({
        message: "Customer deleted successfully",
      });
    } catch (error) {
      console.error("Delete customer:", error.message);

      return res.status(500).json({
        message: "Failed to delete customer",
      });
    }
  }
);

module.exports = router;
