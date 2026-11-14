
const express = require("express");
const mongoose = require("mongoose");

const Order = require("../models/Order");
const Customer = require("../models/Customer");
const Product = require("../models/product");
const StockMovement = require("../models/StockMovement");

const {
  protect,
  authorize,
} = require("../middleware/authMiddleware");

const router = express.Router();

// Authentication required for all order routes
router.use(protect);

// CREATE ORDER
// Admin, Manager and Staff
router.post(
  "/",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    const { customerId, items } = req.body || {};

    if (!mongoose.isValidObjectId(customerId)) {
      return res.status(400).json({
        message: "Invalid customer ID",
      });
    }

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        message: "Order must contain at least one product",
      });
    }

    // Validate items before starting transaction
    const seenProducts = new Set();

    for (const item of items) {
      if (
        !item ||
        !mongoose.isValidObjectId(item.productId) ||
        !Number.isInteger(item.quantity) ||
        item.quantity <= 0
      ) {
        return res.status(400).json({
          message: "Invalid product or quantity",
        });
      }

      const productKey = String(item.productId).toLowerCase();

      if (seenProducts.has(productKey)) {
        return res.status(400).json({
          message: "Duplicate product in order",
        });
      }

      seenProducts.add(productKey);
    }

    let session;

    try {
      session = await mongoose.startSession();
      let createdOrder;

      await session.withTransaction(async () => {
        const customer = await Customer.findById(
          customerId
        ).session(session);

        if (!customer) {
          const error = new Error("Customer not found");
          error.status = 404;
          throw error;
        }

        const orderItems = [];
        let totalAmount = 0;

        for (const item of items) {
          const { productId, quantity } = item;

          // Prevent stock from becoming negative
          const product = await Product.findOneAndUpdate(
            {
              _id: productId,
              stock: { $gte: quantity },
            },
            {
              $inc: { stock: -quantity },
            },
            {
              new: true,
              session,
            }
          );

          if (!product) {
            const error = new Error(
              "Product not found or insufficient stock"
            );
            error.status = 400;
            throw error;
          }

          const subtotal = product.price * quantity;

          orderItems.push({
            product: product._id,
            quantity,
            price: product.price,
            subtotal,
          });

          totalAmount += subtotal;

          // Record inventory movement
          await StockMovement.create(
            [
              {
                product: product._id,
                type: "OUT",
                quantity,
                note: "Order created",
                performedBy: req.user.id,
              },
            ],
            { session }
          );
        }

        const orders = await Order.create(
          [
            {
              customer: customerId,
              items: orderItems,
              totalAmount,
              status: "Completed",
              createdBy: req.user.id,
            },
          ],
          { session }
        );

        createdOrder = orders[0];
      });

      return res.status(201).json({
        message: "Order created successfully",
        order: createdOrder,
      });
    } catch (error) {
      console.error(
        "Create order error:",
        error.message
      );

      return res.status(error.status || 500).json({
        message: error.status
          ? error.message
          : "Failed to create order",
      });
    } finally {
      if (session) {
        await session.endSession();
      }
    }
  }
);

// GET ALL ORDERS
// Admin, Manager and Staff
router.get(
  "/",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      const orders = await Order.find()
        .populate("customer", "name email phone")
        .populate("items.product", "name sku")
        .populate("createdBy", "name email")
        .sort({ createdAt: -1 });

      return res.json(orders);
    } catch (error) {
      console.error(
        "Fetch orders error:",
        error.message
      );

      return res.status(500).json({
        message: "Failed to fetch orders",
      });
    }
  }
);

// GET SINGLE ORDER
// Admin, Manager and Staff
router.get(
  "/:id",
  authorize("admin", "manager", "staff"),
  async (req, res) => {
    try {
      if (!mongoose.isValidObjectId(req.params.id)) {
        return res.status(400).json({
          message: "Invalid order ID",
        });
      }

      const order = await Order.findById(req.params.id)
        .populate("customer", "name email phone")
        .populate("items.product", "name sku")
        .populate("createdBy", "name email");

      if (!order) {
        return res.status(404).json({
          message: "Order not found",
        });
      }

      return res.json(order);
    } catch (error) {
      console.error(
        "Fetch order error:",
        error.message
      );

      return res.status(500).json({
        message: "Failed to fetch order",
      });
    }
  }
);

module.exports = router;
