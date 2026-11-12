
const express = require("express");
const mongoose = require("mongoose");
const Product = require("../models/product");
const StockMovement = require("../models/StockMovement");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(protect);

// STOCK IN / STOCK OUT
router.post("/movement", async (req, res) => {
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
        message: "Valid type and positive integer quantity required",
      });
    }

    const change = type === "IN" ? quantity : -quantity;

    const product = await Product.findOneAndUpdate(
      {
        _id: productId,
        stock: { $gte: type === "OUT" ? quantity : 0 },
      },
      { $inc: { stock: change } },
      { new: true, runValidators: true }
    );

    if (!product) {
      return res.status(400).json({
        message: "Product not found or insufficient stock",
      });
    }

    try {
      const movement = await StockMovement.create({
        product: productId,
        type,
        quantity,
        note,
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
      // Reverse stock change if history creation fails
      await Product.findByIdAndUpdate(productId, {
        $inc: { stock: -change },
      });
      throw error;
    }
  } catch (error) {
    res.status(500).json({
      message: "Failed to update stock",
    });
  }
});

// GET STOCK MOVEMENT HISTORY
router.get("/movements", async (req, res) => {
  try {
    const movements = await StockMovement.find()
      .populate("product", "name sku")
      .populate("performedBy", "name email")
      .sort({ createdAt: -1 });

    res.json(movements);
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch stock movements",
    });
  }
});

// GET LOW STOCK PRODUCTS
router.get("/low-stock", async (req, res) => {
  try {
    const products = await Product.find({
      $expr: {
        $lte: ["$stock", "$lowStockThreshold"],
      },
    });

    res.json(products);
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch low stock products",
    });
  }
});

module.exports = router;
