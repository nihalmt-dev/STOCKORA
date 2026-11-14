
const express = require("express");

const Product = require("../models/product");
const Customer = require("../models/Customer");
const Order = require("../models/Order");

const {
  protect,
  authorize,
} = require("../middleware/authMiddleware");

const router = express.Router();

// Authentication required
router.use(protect);

// GET DASHBOARD STATISTICS
// Admin, Manager and Staff
router.get(
  "/stats",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      const isStaff = req.user.role === "staff";

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

        // Financial aggregation is not run for Staff
        isStaff
          ? Promise.resolve([])
          : Order.aggregate([
              {
                $match: {
                  status: "Completed",
                },
              },
              {
                $group: {
                  _id: null,
                  total: {
                    $sum: "$totalAmount",
                  },
                },
              },
            ]),

        Product.find({
          $expr: {
            $lte: [
              "$stock",
              "$lowStockThreshold",
            ],
          },
        }).select(
          "name sku stock lowStockThreshold"
        ),

        Order.find()
          .populate("customer", "name")
          .sort({
            createdAt: -1,
          })
          .limit(5)
          .lean(),
      ]);

      // Common statistics for all roles
      const dashboardData = {
        totalProducts,
        totalCustomers,
        totalOrders,
        lowStockCount: lowStockProducts.length,
        lowStockProducts,
      };

      if (isStaff) {
        // Staff can see operational order details,
        // but not financial information.
        dashboardData.recentOrders = recentOrders.map(
          (order) => ({
            _id: order._id,
            customer: order.customer,
            status: order.status,
            createdAt: order.createdAt,
            items: (order.items || []).map(
              (item) => ({
                product: item.product,
                quantity: item.quantity,
              })
            ),
          })
        );
      } else {
        // Admin and Manager can see full financial data
        dashboardData.totalSales =
          salesResult[0]?.total || 0;

        dashboardData.recentOrders = recentOrders;
      }

      return res.json(dashboardData);
    } catch (error) {
      console.error(
        "Dashboard statistics error:",
        error.message
      );

      return res.status(500).json({
        message:
          "Failed to fetch dashboard statistics",
      });
    }
  }
);

module.exports = router;
