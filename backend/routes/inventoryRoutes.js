
const express = require("express");
const mongoose = require("mongoose");

const Product = require("../models/product");
const StockMovement = require("../models/StockMovement");

const {
  protect,
  authorize,
} = require("../middleware/authMiddleware");

const router = express.Router();

// All inventory endpoints require login
router.use(protect);

// STOCK IN / STOCK OUT
// Only Admin and Manager can update stock
router.post(
  "/movement",
  authorize("admin", "manager"),
  async (req, res) => {
    try {
      const { productId, type, quantity, note } = req.body;

      if (!mongoose.isValidObjectId(productId)) {
        return res.status(400).json({
          message: "Invalid product ID",
        });
      }

      if (
        !["IN", "OUT"].includes(type) ||
        !Number.isInteger(quantity) ||
        quantity <= 0
      ) {
        return res.status(400).json({
          message:
            "Valid type and positive integer quantity required",
        });
      }

      if (
        note !== undefined &&
        typeof note !== "string"
      ) {
        return res.status(400).json({
          message: "Note must be a string",
        });
      }

      const change = type === "IN" ? quantity : -quantity;

      // Atomic stock update to prevent negative stock
      const product = await Product.findOneAndUpdate(
        {
          _id: productId,
          stock: {
            $gte: type === "OUT" ? quantity : 0,
          },
        },
        {
          $inc: { stock: change },
        },
        {
          new: true,
          runValidators: true,
        }
      );

      if (!product) {
        return res.status(400).json({
          message:
            "Product not found or insufficient stock",
        });
      }

      try {
        const movement = await StockMovement.create({
          product: productId,
          type,
          quantity,
          note: note?.trim() || "",
          performedBy: req.user.id,
        });

        return res.status(201).json({
          message: "Stock updated successfully",
          product,
          movement,
          lowStockAlert:
            product.stock <= product.lowStockThreshold,
        });
      } catch (error) {
        // Restore stock if movement history creation fails
        await Product.findByIdAndUpdate(productId, {
          $inc: { stock: -change },
        });

        throw error;
      }
    } catch (error) {
      console.error(
        "Stock movement error:",
        error.message
      );

      return res.status(500).json({
        message: "Failed to update stock",
      });
    }
  }
);

// GET STOCK MOVEMENT HISTORY
// Admin, Manager and Staff can view
router.get(
  "/movements",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      const movements = await StockMovement.find()
        .populate("product", "name sku")
        .populate("performedBy", "name email")
        .sort({ createdAt: -1 });

      return res.json(movements);
    } catch (error) {
      console.error(
        "Fetch movements error:",
        error.message
      );

      return res.status(500).json({
        message: "Failed to fetch stock movements",
      });
    }
  }
);

// GET LOW STOCK PRODUCTS
// Admin, Manager and Staff can view
router.get(
  "/low-stock",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      const products = await Product.find({
        $expr: {
          $lte: ["$stock", "$lowStockThreshold"],
        },
      });

      return res.json(products);
    } catch (error) {
      console.error(
        "Fetch low stock error:",
        error.message
      );

      return res.status(500).json({
        message: "Failed to fetch low stock products",
      });
    }
  }
);

const RestockRequest = require("../models/RestockRequest");

// STAFF: Send a restock request
router.post(
  "/restock-requests",
  authorize("staff"),
  async (req, res) => {
    try {
      const { productId, note } = req.body;

      if (!mongoose.isValidObjectId(productId)) {
        return res.status(400).json({
          message: "Invalid product ID",
        });
      }

      if (note !== undefined &&
          (typeof note !== "string" || note.length > 300)) {
        return res.status(400).json({
          message: "Note must be 300 characters or fewer",
        });
      }

      const product = await Product.findById(productId);

      if (!product) {
        return res.status(404).json({
          message: "Product not found",
        });
      }

      if (product.stock > product.lowStockThreshold) {
        return res.status(400).json({
          message: "This product is not low on stock",
        });
      }

      const request = await RestockRequest.create({
        product: productId,
        requestedBy: req.user.id,
        note: note?.trim() || "",
      });

      return res.status(201).json({
        message: "Restock request sent to management",
        request,
      });
    } catch (error) {
      if (error.code === 11000) {
        return res.status(409).json({
          message: "A pending request already exists for this product",
        });
      }

      console.error("Restock request error:", error.message);

      return res.status(500).json({
        message: "Failed to send restock request",
      });
    }
  }
);

// MANAGER / ADMIN: View restock requests
router.get(
  "/restock-requests",
  authorize("admin", "manager"),
  async (req, res) => {
    try {
      const requests = await RestockRequest.find()
        .populate("product", "name sku stock lowStockThreshold")
        .populate("requestedBy", "name email")
        .populate("resolvedBy", "name")
        .sort({ createdAt: -1 });

      return res.json(requests);
    } catch (error) {
      console.error("Fetch restock requests error:", error.message);

      return res.status(500).json({
        message: "Failed to fetch restock requests",
      });
    }
  }
);

// MANAGER / ADMIN: Resolve a restock request
router.patch(
  "/restock-requests/:id/resolve",
  authorize("admin", "manager"),
  async (req, res) => {
    try {
      if (!mongoose.isValidObjectId(req.params.id)) {
        return res.status(400).json({
          message: "Invalid request ID",
        });
      }

      const request = await RestockRequest.findOneAndUpdate(
        {
          _id: req.params.id,
          status: "pending",
        },
        {
          $set: {
            status: "resolved",
            resolvedBy: req.user.id,
            resolvedAt: new Date(),
          },
        },
        { new: true }
      );

      if (!request) {
        return res.status(404).json({
          message: "Pending request not found",
        });
      }

      return res.json({
        message: "Restock request resolved",
        request,
      });
    } catch (error) {
      console.error("Resolve restock request error:", error.message);

      return res.status(500).json({
        message: "Failed to resolve restock request",
      });
    }
  }
);

module.exports = router;
