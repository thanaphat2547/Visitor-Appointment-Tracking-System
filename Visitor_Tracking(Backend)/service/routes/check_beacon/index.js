const express = require('express');
const router = express.Router();
const checkbeacon = require('./checkbeacon');
const { authMiddleware, isAdmin, isUser } = require('../Auth/authMiddleware');

router.post('/',checkbeacon.postcheckbeacon);

module.exports = router;