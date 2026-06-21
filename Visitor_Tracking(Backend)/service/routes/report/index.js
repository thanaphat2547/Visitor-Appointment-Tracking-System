const express = require("express");
const router = express.Router();
const report = require("./report");
const { authMiddleware, isAdmin, isOfficer } = require('../Auth/authMiddleware');

router.post("/beacon",authMiddleware(),isAdmin, report.postCountBeaconForPlace);


module.exports = router;
