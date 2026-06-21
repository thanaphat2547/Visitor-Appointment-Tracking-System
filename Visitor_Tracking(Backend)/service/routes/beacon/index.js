const express = require('express');
const router = express.Router();
const beacon = require('./beacon'); 
const { authMiddleware, isAdmin } = require('../Auth/authMiddleware');

router.get('/show_beacon', authMiddleware(), beacon.getBeacons); 
router.put('/add_beacon', authMiddleware(), isAdmin, beacon.putBeacon); 
router.patch('/edit_beacon', authMiddleware(), isAdmin, beacon.editBeacon); 
router.patch('/delete_beacon', authMiddleware(), isAdmin, beacon.deleteBeacon);
router.post('/report_beacon', authMiddleware(), beacon.reportBeacon);

module.exports = router;
