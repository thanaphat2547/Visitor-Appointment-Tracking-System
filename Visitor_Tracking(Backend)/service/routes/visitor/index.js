const express = require('express');
const router = express.Router();
const visitor = require('./visitor');
const { authMiddleware,} = require('../Auth/authMiddleware');

router.get('/show_visitor', authMiddleware(), visitor.getVisitors);
router.put('/add_visitor', authMiddleware(), visitor.putVisitor);
router.patch('/edit_visitor', authMiddleware(), visitor.patchVisitor);
router.patch('/delete_visitor', authMiddleware(), visitor.deleteVisitor);
router.post('/report_visitor', authMiddleware(), visitor.reportVisitor);

module.exports = router;