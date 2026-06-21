const express = require('express');
const router = express.Router();
const employee = require('./employee');
const { authMiddleware, isAdmin } = require('../Auth/authMiddleware');

router.get('/show_employee', authMiddleware(), employee.getEmployees);
router.put('/add_employee', authMiddleware(), isAdmin, employee.putEmployee);
router.patch('/edit_employee', authMiddleware(), isAdmin,employee.editEmployee);
router.patch('/delete_employee', authMiddleware(), isAdmin, employee.deleteEmployee);
router.post('/report_employee', authMiddleware(), isAdmin, employee.reportEmployee);
router.post('/profile', authMiddleware(), employee.getEmployeeProfile);

router.post('/login', authMiddleware(), (req, res) => {
  const user = req.user;
  const userRole = parseInt(user.role_id);


  res.json({
    success: true,
    message: 'เข้าสู่ระบบสำเร็จ',
    emp_id: user.emp_id || user.vis_id, 
    firstname: user.firstname,
    lastname: user.lastname,
    role_id: userRole,
    bk_id: user.bk_id || null
  });
});
module.exports = router;