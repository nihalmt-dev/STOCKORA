
const express = require("express");
const Order = require("../models/Order");
const Product = require("../models/product");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(protect);

// SALES REPORT
router.get("/sales", async (req, res) => {
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
          totalSales: { $sum: "$totalAmount" },
          totalOrders: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    res.json(sales);
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch sales report",
    });
  }
});

// INVENTORY REPORT
router.get("/inventory", async (req, res) => {
  try {
    const products = await Product.find()
      .select("name sku category price stock lowStockThreshold")
      .sort({ name: 1 });

    const inventory = products.map((product) => ({
      name: product.name,
      sku: product.sku,
      category: product.category,
      price: product.price,
      stock: product.stock,
      stockValue: product.price * product.stock,
      lowStock: product.stock <= product.lowStockThreshold,
    }));

    const totalStockValue = inventory.reduce(
      (sum, item) => sum + item.stockValue,
      0
    );

    res.json({
      totalProducts: inventory.length,
      totalStockValue,
      products: inventory,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch inventory report",
    });
  }
});

module.exports = router;
