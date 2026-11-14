
const express = require("express");

const Order = require("../models/Order");
const Product = require("../models/product");

const {
  protect,
  authorize,
} = require("../middleware/authMiddleware");

const router = express.Router();

// Authentication required for all report routes
router.use(protect);

// SALES REPORT
// Admin and Manager only
router.get(
  "/sales",
  authorize("admin", "manager"),
  async (req, res) => {
    try {
      const sales = await Order.aggregate([
        {
          $match: {
            status: "Completed",
          },
        },
        {
          $group: {
            _id: {
              $dateToString: {
                format: "%Y-%m-%d",
                date: "$createdAt",
                timezone: "Asia/Kolkata",
              },
            },
            totalSales: {
              $sum: "$totalAmount",
            },
            totalOrders: {
              $sum: 1,
            },
          },
        },
        {
          $sort: {
            _id: 1,
          },
        },
      ]);

      return res.json(sales);
    } catch (error) {
      console.error(
        "Sales report error:",
        error.message
      );

      return res.status(500).json({
        message: "Failed to fetch sales report",
      });
    }
  }
);

// INVENTORY REPORT
// Admin and Manager only
router.get(
  "/inventory",
  authorize("admin", "manager"),
  async (req, res) => {
    try {
      const products = await Product.find()
        .select(
          "name sku category price stock lowStockThreshold"
        )
        .sort({
          name: 1,
        });

      const inventory = products.map((product) => ({
        name: product.name,
        sku: product.sku,
        category: product.category,
        price: product.price,
        stock: product.stock,
        stockValue: product.price * product.stock,
        lowStock:
          product.stock <= product.lowStockThreshold,
      }));

      const totalStockValue = inventory.reduce(
        (sum, item) => sum + item.stockValue,
        0
      );

      return res.json({
        totalProducts: inventory.length,
        totalStockValue,
        products: inventory,
      });
    } catch (error) {
      console.error(
        "Inventory report error:",
        error.message
      );

      return res.status(500).json({
        message: "Failed to fetch inventory report",
      });
    }
  }
);

module.exports = router;
