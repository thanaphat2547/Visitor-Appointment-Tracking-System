const express = require('express');
const router = express.Router();
const location_beacon = require('./location_beacon');
const authMiddleware = require('../Auth/authMiddleware');

router.get('/show_location_beacon', location_beacon.getLocationBeacons);
router.put('/add_location_beacon', location_beacon.putLocationBeacon);
router.put('/put', location_beacon.putLocationBeacon);
router.post('/Calculate', location_beacon.Calculate);

module.exports = router;
