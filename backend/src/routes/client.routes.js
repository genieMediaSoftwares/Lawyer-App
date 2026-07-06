const express = require("express");
const clientController = require("../controllers/client/clientController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.get("/", clientController.getClients);
router.get("/:id", clientController.getClientById);
router.post("/:id/notes", clientController.addNote);
router.get("/:id/notes", clientController.getNotes);

module.exports = router;
