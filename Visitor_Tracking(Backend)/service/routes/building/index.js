const express = require('express');
const router = express.Router();
const building = require('./building');

const { authMiddleware, isAdmin} = require('../Auth/authMiddleware');

router.get('/show_building',authMiddleware(),building.getbuilding)
router.put('/add_building',authMiddleware(),isAdmin,building.putbuilding)
router.patch('/edit_building',authMiddleware(),isAdmin,building.editbuilding)
router.patch('/delete_building',authMiddleware(),isAdmin,building.deletebuilding)
router.post('/report_building', authMiddleware(), isAdmin,building.reportBuilding);

module.exports = router;
