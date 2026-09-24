const express = require("express");
const router = express.Router();
const categoryController = require("../controllers/category/categoryController");
const authMiddleware = require("../middleware/authMiddleware");

router.use(authMiddleware);

router.get("/", categoryController.list);
router.get("/:id", categoryController.getById);
router.post("/", categoryController.create);
router.put("/:id", categoryController.update);
router.delete("/:id", categoryController.remove);

module.exports = router;
