
const express = require("express");
const Product = require("../models/product");
const Customer = require("../models/Customer");
const Order = require("../models/Order");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(protect);

// GET DASHBOARD STATISTICS
router.get("/stats", async (req, res) => {
  try {
    const [
      totalProducts,
      totalCustomers,
      totalOrders,
      salesResult,
      lowStockProducts,
      recentOrders,
    ] = await Promise.all([
      Product.countDocuments(),

      Customer.countDocuments(),

      Order.countDocuments({
        status: "Completed",
      }),

      Order.aggregate([
        {
          $match: { status: "Completed" },
        },
        {
          $group: {
            _id: null,
            total: { $sum: "$totalAmount" },
          },
        },
      ]),

      Product.find({
        $expr: {
          $lte: ["$stock", "$lowStockThreshold"],
        },
      }).select("name sku stock lowStockThreshold"),

      Order.find()
        .populate("customer", "name")
        .sort({ createdAt: -1 })
        .limit(5),
    ]);

    res.json({
      totalProducts,
      totalCustomers,
      totalOrders,
      totalSales: salesResult[0]?.total || 0,
      lowStockCount: lowStockProducts.length,
      lowStockProducts,
      recentOrders,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch dashboard statistics",
    });
  }
});

module.exports = router;
