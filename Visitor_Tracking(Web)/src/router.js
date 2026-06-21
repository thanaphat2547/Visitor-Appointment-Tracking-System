import { createRouter, createWebHistory } from 'vue-router';

// Login
import Login from "@/components/LoginPage.vue";

// Layout
import Layout from '@/components/Layout.vue';

// Pages
import Dashboard from "@/components/DashboardPage.vue";
import Map from "@/components/MapPage.vue";
import Beacon from "@/components/Management/BeaconManagement.vue";
import Employee from "@/components/Management/EmployeeManagement.vue";
import Building from "@/components/Management/BuildingManagement.vue";
import Visitor from "@/components/Management/VisitorManagement.vue";
import Booking from "@/components/Management/BookingManagement.vue";

import MapManagement from './components/Management/MapManagement.vue';

const routes = [
  {   
    path: '/',
    name: 'Login',
    component: Login
  },
  {
    path: '/',
    component: Layout,
    children: [
      // Admin เห็นเท่านั้น
      {
        path: 'admin/dashboard', 
        name: 'Dashboard', 
        component: Dashboard,
        meta: { role: 0, title: 'แดชบอร์ด', icon: 'dash', menuKey: 'แดชบอร์ด' }
      },
      {
        path: 'admin/beacon',
        name: 'Beacon',
        component: Beacon,
        meta: { role: 0, title: 'จัดการข้อมูลอุปกรณ์บีคอน', icon: 'beacon', menuKey: 'จัดการบีคอน' }
      },
      {
        path: 'admin/employee',
        name: 'Employee',
        component: Employee,
        meta: { role: 0, title: 'จัดการข้อมูลพนักงาน', icon: 'employee', menuKey: 'จัดการพนักงาน' }
      },
      {
        path: 'admin/building',
        name: 'Building',
        component: Building,
        meta: { role: 0, title: 'จัดการข้อมูลอาคาร', icon: 'building', menuKey: 'จัดการอาคาร' }
      },
      {
        path: 'admin/mapmanagement',
        name: 'MapManagement',
        component: MapManagement,
        meta: { role: 0, title: 'แผนที่จัดการอาคาร', icon: 'mapmanagement', menuKey: 'จัดการอาคาร', isMapPage: true }
      },

      // Admin และ Officer ใช้ร่วมกัน
      {
        path: '/map',
        name: 'MapPage', 
        component: Map,
        meta: { role: [0, 1] , title: 'สถานะผู้มาติดต่อ', icon: 'map', menuKey: 'ติดตามผู้มาติดต่อ', isMapPage: true }
      },
      {
        path: '/visitor',
        name: 'Visitor',
        component: Visitor,
        meta: { role: [0, 1], title: 'จัดการข้อมูลผู้มาติดต่อ', icon: 'visitor', menuKey: 'จัดการผู้มาติดต่อ' }
      },
      {
        path: '/booking',
        name: 'Booking', 
        component: Booking,
        meta: { role: [0, 1] , title: 'จัดการการนัดหมาย', icon: 'history', menuKey: 'จัดการการนัดหมาย' }
      }
    ],
  }
];

// สร้าง router ก่อน
const router = createRouter({
  history: createWebHistory(),
  routes,
});

// navigation guard ตรวจสอบ role
router.beforeEach((to, from, next) => {
  const auth = localStorage.getItem('auth');

  const roleIdFromStore = localStorage.getItem('role_id');
  const role = roleIdFromStore !==null ? Number(roleIdFromStore) : -1;

  // Some routes are nested; check all matched route records for role metadata
  const requiresAuth = to.matched.some(record => record.meta && typeof record.meta.role !== 'undefined');

  // ถ้า route ต้อง login แต่ไม่มี auth
  if (requiresAuth && !auth) return next('/');

  if (requiresAuth) {
    // collect allowed roles from all matched records (flatten)
    const allowedRoles = to.matched.reduce((acc, rec) => {
      if (rec.meta && typeof rec.meta.role !== 'undefined') {
        const r = Array.isArray(rec.meta.role) ? rec.meta.role : [rec.meta.role];
        r.forEach(x => { if (!acc.includes(x)) acc.push(x); });
      }
      return acc;
    }, []);

    if (allowedRoles.length > 0 && !allowedRoles.includes(role)) {
      // redirect non-authorized users to a safe page depending on their role
      if (role === 0) return next('/admin/dashboard');
      if (role === 1) return next('/map');
      return next('/');
    }
  }

  next();
});

export default router;