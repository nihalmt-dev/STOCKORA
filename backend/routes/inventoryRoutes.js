
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

module.exports = router;
