
const express = require("express");
const mongoose = require("mongoose");
const Order = require("../models/Order");
const Customer = require("../models/Customer");
const Product = require("../models/product");
const StockMovement = require("../models/StockMovement");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(protect);

// CREATE ORDER
router.post("/", async (req, res) => {
  const { customerId, items } = req.body;

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

  const session = await mongoose.startSession();

  try {
    let createdOrder;

    await session.withTransaction(async () => {
      const customer = await Customer.findById(customerId).session(session);

      if (!customer) {
        const error = new Error("Customer not found");
        error.status = 404;
        throw error;
      }

      const orderItems = [];
      let totalAmount = 0;
      const seenProducts = new Set();

      for (const item of items) {
        const { productId, quantity } = item;

        if (
          !mongoose.isValidObjectId(productId) ||
          !Number.isInteger(quantity) ||
          quantity <= 0
        ) {
          const error = new Error("Invalid product or quantity");
          error.status = 400;
          throw error;
        }

        if (seenProducts.has(productId)) {
          const error = new Error("Duplicate product in order");
          error.status = 400;
          throw error;
        }

        seenProducts.add(productId);

        const product = await Product.findOneAndUpdate(
          {
            _id: productId,
            stock: { $gte: quantity },
          },
          { $inc: { stock: -quantity } },
          { new: true, session }
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

    res.status(201).json({
      message: "Order created successfully",
      order: createdOrder,
    });
  } catch (error) {
    res.status(error.status || 500).json({
      message: error.status
        ? error.message
        : "Failed to create order",
    });
  } finally {
    await session.endSession();
  }
});

// GET ALL ORDERS
router.get("/", async (req, res) => {
  try {
    const orders = await Order.find()
      .populate("customer", "name email phone")
      .populate("items.product", "name sku")
      .populate("createdBy", "name email")
      .sort({ createdAt: -1 });

    res.json(orders);
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch orders",
    });
  }
});

// GET SINGLE ORDER
router.get("/:id", async (req, res) => {
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

    res.json(order);
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch order",
    });
  }
});

module.exports = router;
