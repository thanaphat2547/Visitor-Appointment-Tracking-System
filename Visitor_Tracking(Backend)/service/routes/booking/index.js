const express = require('express');
const router = express.Router();
const bookingController = require('./booking'); 

const { authMiddleware, isAdmin } = require('../Auth/authMiddleware');

router.get('/show_booking', authMiddleware(), bookingController.getBookings);
router.put('/add_booking', authMiddleware(), bookingController.putBooking);
router.patch('/edit_booking', authMiddleware(), bookingController.editBooking);
router.patch('/cancel_booking', authMiddleware(), bookingController.cancelBooking);
router.post('/report_booking', authMiddleware(), bookingController.reportBooking);

module.exports = router;
