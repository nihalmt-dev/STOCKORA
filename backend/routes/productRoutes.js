
const express = require("express");
const mongoose = require("mongoose");
const Product = require("../models/product");
const { protect, authorize } = require("../middleware/authMiddleware");

const router = express.Router();

// All product routes require authentication
router.use(protect);

// GET all products + search
// Admin, Manager and Staff
router.get("/", authorize("admin", "manager", "staff"), async (req, res) => {
  try {
    const search = String(req.query.search || "").trim();

    // Escape regex special characters in search input
    const safeSearch = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    const filter = safeSearch
      ? {
          $or: [
            { name: { $regex: safeSearch, $options: "i" } },
            { sku: { $regex: safeSearch, $options: "i" } },
            { category: { $regex: safeSearch, $options: "i" } },
          ],
        }
      : {};

    const products = await Product.find(filter).sort({
      createdAt: -1,
    });

    res.json(products);
  } catch (error) {
    console.error("Fetch products error:", error.message);
    res.status(500).json({
      message: "Failed to fetch products",
    });
  }
});

// GET single product
// Admin, Manager and Staff
router.get("/:id", authorize("admin", "manager", "staff"), async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "Invalid product ID",
      });
    }

    const product = await Product.findById(req.params.id);

    if (!product) {
      return res.status(404).json({
        message: "Product not found",
      });
    }

    res.json(product);
  } catch (error) {
    console.error("Fetch product error:", error.message);
    res.status(500).json({
      message: "Failed to fetch product",
    });
  }
});

// POST add product
// Admin and Manager
router.post("/", authorize("admin", "manager"), async (req, res) => {
  try {
    const {
      name,
      sku,
      category,
      price,
      stock,
      lowStockThreshold,
      description,
    } = req.body;

    const product = await Product.create({
      name,
      sku,
      category,
      price,
      stock,
      lowStockThreshold,
      description,
    });

    res.status(201).json({
      message: "Product added successfully",
      product,
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        message: "SKU already exists",
      });
    }

    if (error.name === "ValidationError") {
      return res.status(400).json({
        message: error.message,
      });
    }

    console.error("Add product error:", error.message);
    res.status(500).json({
      message: "Failed to add product",
    });
  }
});

// PUT update product
// Admin and Manager
router.put("/:id", authorize("admin", "manager"), async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "Invalid product ID",
      });
    }

    const allowedFields = [
      "name",
      "sku",
      "category",
      "price",
      "lowStockThreshold",
      "description",
    ];

    // Stock changes must use the inventory API.
    const updates = {};

    for (const field of allowedFields) {
      if (Object.prototype.hasOwnProperty.call(req.body, field)) {
        updates[field] = req.body[field];
      }
    }

    const product = await Product.findByIdAndUpdate(
      req.params.id,
      updates,
      {
        new: true,
        runValidators: true,
      }
    );

    if (!product) {
      return res.status(404).json({
        message: "Product not found",
      });
    }

    res.json({
      message: "Product updated successfully",
      product,
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        message: "SKU already exists",
      });
    }

    if (error.name === "ValidationError") {
      return res.status(400).json({
        message: error.message,
      });
    }

    console.error("Update product error:", error.message);
    res.status(500).json({
      message: "Failed to update product",
    });
  }
});

// DELETE product
// Admin only
router.delete("/:id", authorize("admin"), async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "Invalid product ID",
      });
    }

    const product = await Product.findByIdAndDelete(req.params.id);

    if (!product) {
      return res.status(404).json({
        message: "Product not found",
      });
    }

    res.json({
      message: "Product deleted successfully",
    });
  } catch (error) {
    console.error("Delete product error:", error.message);
    res.status(500).json({
      message: "Failed to delete product",
    });
  }
});

module.exports = router;
