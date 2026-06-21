<template>
  <a-layout style="min-height: 100vh; background: #f4f7f6">
    <!-- Header -->
    <a-layout-header class="top-header">
      <div class="header-left">
        <div class="brand-logo">
          <img src="@/assets/โลโก้.png" alt="Logo" class="brand-logo-img" />
          <div class="brand-info">
            <span class="brand-text">ระบบติดตามการนัดหมาย</span>
            <span class="brand-sub">Visitor Tracking System</span>
          </div>
        </div>
      </div>
      <div class="header-right">
        <Noti v-if="userRole === 1" />
        <div class="user-info-wrapper">
          <div class="user-name-text">{{ user.firstName }} {{ user.lastName }}</div>
          <div class="user-role-badge-container">
            <span :class="['role-pill', userRole === 0 ? 'role-admin' : 'role-officer']">
              {{ userRole === 0 ? 'ADMIN' : 'OFFICER' }}
            </span>
          </div>
        </div>
        <Profile />
      </div>
    </a-layout-header>

    <!-- Layout ด้านล่าง -->
    <a-layout style="background: #f4f7f6">
      <!-- Sidebar -->
      <a-layout-sider
        :collapsed="false"
        :collapsible="false"
        :width="220"
        :collapsedWidth="80"
        class="custom-sidebar"
      >
        <a-menu
          v-model:selectedKeys="selectedKeys"
          mode="inline"
          class="custom-menu"
        >
          <a-menu-item
            v-for="item in filteredMenu"
            :key="item.key"
            @click="goTo(item.path)"
            class="custom-menu-item"
          >
            <template #icon>
              <div class="menu-icon-wrap">
                <component :is="getIcon(item.icon)" class="menu-icon" />
              </div>
            </template>
            <span class="menu-label">{{ item.key }}</span>
          </a-menu-item>
        </a-menu>
      </a-layout-sider>

      <!-- Content -->
      <a-layout-content :class="['main-content', { 'map-content': isMapPage }]">
        <div class="page-title-bar" v-if="!isMapPage">
          <div class="page-title-icon-wrap">
            <component :is="getIcon(route.meta.icon)" style="color:white; font-size:16px;" />
          </div>
          <span class="page-title-text">{{ currentPageTitle }}</span>
        </div>

        <router-view v-slot="{ Component }">
          <component
            v-if="Component"
            :is="Component"
            v-model:isSiderCollapsed="isSiderCollapsed"
          />
        </router-view>
      </a-layout-content>
    </a-layout>
  </a-layout>
</template>

<script setup>
import { PieChartOutlined, EnvironmentOutlined, UserOutlined, IdcardOutlined, BankOutlined, DeploymentUnitOutlined, FileTextOutlined } from '@ant-design/icons-vue'
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from "@/axios"
import Profile from "@/components/ProfilePage.vue";
import Noti from "@/components/NotificationPage.vue";

const selectedKeys = ref(['dashboard'])
const headerKeys = ref(['dashboard'])
const route = useRoute()
const router = useRouter()
const isSiderCollapsed = ref(false)
const userData = JSON.parse(localStorage.getItem('user') || '{}')
const userRole = Number(userData.role_id)

const goTo = (path) => { router.push(path) }

const getIcon = (name) => {
  const icons = {
    dash: PieChartOutlined,
    map: EnvironmentOutlined,
    beacon: DeploymentUnitOutlined,
    employee: UserOutlined,
    visitor: IdcardOutlined,
    building: BankOutlined,
    mapmanagement: BankOutlined,
    history: FileTextOutlined
  }
  return icons[name] || null
}

watch(route, () => { isSiderCollapsed.value = false })

const getMenuKeyFromRoute = (path) => {
  if (path.includes('/admin/dashboard')) return 'แดชบอร์ด'
  if (path.includes('/admin/mapmanagement')) return 'จัดการแผนที่อาคาร'
  if (path.includes('/map')) return 'ติดตามผู้มาติดต่อ'
  if (path.includes('/admin/beacon')) return 'จัดการบีคอน'
  if (path.includes('/admin/employee')) return 'จัดการพนักงาน'
  if (path.includes('/admin/building')) return 'จัดการอาคาร'
  if (path.includes('/visitor')) return 'จัดการผู้มาติดต่อ'
  if (path.includes('/booking')) return 'จัดการการนัดหมาย'
  return path.split('/').pop()
}

const menuItems = [
  { key: 'แดชบอร์ด', path: '/admin/dashboard', icon: 'dash', roles: [0] },
  { key: 'ติดตามผู้มาติดต่อ', path: '/map', icon: 'map', roles: [0, 1] },
  { key: 'จัดการบีคอน', path: '/admin/beacon', icon: 'beacon', roles: [0] },
  { key: 'จัดการพนักงาน', path: '/admin/employee', icon: 'employee', roles: [0] },
  { key: 'จัดการอาคาร', path: '/admin/building', icon: 'building', roles: [0] },
  { key: 'จัดการผู้มาติดต่อ', path: '/visitor', icon: 'visitor', roles: [0, 1] },
  { key: 'จัดการการนัดหมาย', path: '/booking', icon: 'history', roles: [0, 1] },
]

const filteredMenu = computed(() => menuItems.filter(item => item.roles.includes(userRole)))
const currentPageTitle = computed(() => route.meta.title || '')
const isMapPage = computed(() => !!route.meta.isMapPage)

const user = ref({ firstName: '', lastName: '' })

const syncMenu = () => {
  const key = route.meta.menuKey || getMenuKeyFromRoute(route.path)
  selectedKeys.value = [key]
  headerKeys.value = [key]
}

watch(() => route.path, () => { syncMenu() }, { immediate: true })

onMounted(async () => {
  const savedProfile = localStorage.getItem('profile')
  if (savedProfile) {
    const parsed = JSON.parse(savedProfile)
    user.value = {
      firstName: parsed.emp_firstname || '',
      lastName: parsed.emp_lastname || '',
    }
  }

  const auth = localStorage.getItem('auth')
  if (!auth) return

  const userString = localStorage.getItem('user')
  const userData = userString ? JSON.parse(userString) : {}
  const emp_id = userData.emp_id
  const emp_username = userData.emp_username
  if (!emp_id && !emp_username) return

  try {
    const res = await axios.post('/employee/profile',
      emp_id ? { emp_id } : { emp_username }
    )
    const p = res.data.data
    user.value = {
      firstName: p.emp_firstname || '',
      lastName: p.emp_lastname || '',
    }
    localStorage.setItem('profile', JSON.stringify(p))
  } catch (err) {
    console.error('โหลดโปรไฟล์ไม่สำเร็จ', err)
  }
})

syncMenu()
</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Prompt:wght@300;400;500;600;700&display=swap');

.top-header {
  height: 64px;
  background: #ffffff !important;
  padding: 0 28px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: #1a2f4a;
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  z-index: 1000;
  box-shadow: 0 1px 0 #e8f5f1, 0 2px 16px rgba(0, 200, 150, 0.06);
  border-bottom: 2.5px solid #00C896;
}

.header-left { flex: 1; display: flex; align-items: center; }

.brand-logo { display: flex; align-items: center; gap: 10px; }

.brand-logo-img {
  height: 60px;
  width: auto;
  object-fit: contain;
  filter: drop-shadow(0 2px 4px rgba(0,200,150,0.2)); 
}

.brand-logo {
  display: flex;
  align-items: center;
  gap: 12px; 
}

.brand-info { display: flex; flex-direction: column; line-height: 1.15; }

.brand-text {
  font-family: 'Prompt', sans-serif;
  font-size: 16px;
  font-weight: 700;
  color: #0a2540;
  letter-spacing: -0.2px;
}

.brand-sub {
  font-family: 'Inter', sans-serif;
  font-size: 9.5px;
  font-weight: 600;
  color: #00C896;
  letter-spacing: 0.8px;
  text-transform: uppercase;
}

.header-right { display: flex; align-items: center; justify-content: flex-end; gap: 14px; }

.user-info-wrapper { display: flex; flex-direction: column; align-items: flex-end; line-height: 1.2; }

.user-name-text {
  font-family: 'Prompt', sans-serif;
  font-size: 13.5px;
  font-weight: 600;
  color: #0a2540;
}

.user-role-badge-container { display: flex; justify-content: flex-end; margin-top: 2px; }

.role-pill {
  font-family: 'Inter', sans-serif;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.8px;
  padding: 1px 8px;
  border-radius: 20px;
}

.role-admin {
  background: rgba(255, 80, 80, 0.1);
  color: #d63031;
  border: 1px solid rgba(255, 80, 80, 0.25);
}

.role-officer {
  background: rgba(0, 200, 150, 0.12);
  color: #00a877;
  border: 1px solid rgba(0, 200, 150, 0.3);
}

.custom-sidebar {
  position: fixed !important;
  top: 64px;
  left: 0;
  height: calc(100vh - 64px);
  overflow-y: auto;
  overflow-x: hidden;
  background: #ffffff !important;
  z-index: 999;
  border-right: 1px solid #e8f5f1;
  box-shadow: 2px 0 12px rgba(0,200,150,0.06);
}

:deep(.ant-layout-sider) {
  position: fixed !important;
  top: 64px !important;
  background: #ffffff !important;
}

.custom-menu {
  background: transparent !important;
  border-inline-end: none !important;
  padding: 8px 10px;
  margin-top: 30px;
}

.custom-menu-item {
  border-radius: 10px !important;
  margin-bottom: 4px !important;
  height: auto !important;
  padding: 0 !important;
  line-height: normal !important;
  transition: all 0.2s ease !important;
}

.menu-icon-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  min-width: 36px;
}

.menu-icon {
  font-size: 17px;
  transition: all 0.2s ease;
}

.menu-label {
  font-family: 'Prompt', sans-serif;
  font-size: 13px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

:deep(.ant-menu-item) {
  display: flex;
  align-items: center;
  height: 46px !important;
  color: #64748b !important;
  border-radius: 10px !important;
  margin: 2px 0 !important;
  transition: all 0.2s ease !important;
}

:deep(.ant-menu-item-selected:hover) {
  background: linear-gradient(135deg, #00b386 0%, #00966b 100%) !important;
  color: #ffffff !important;
  box-shadow: 0 4px 14px rgba(0, 200, 150, 0.4) !important;
}

:deep(.ant-menu-item-selected) {
  background: linear-gradient(135deg, #00C896 0%, #00a877 100%) !important;
  color: #ffffff !important;
  box-shadow: 0 4px 14px rgba(0, 200, 150, 0.3) !important;
}

:deep(.ant-menu-item-selected .menu-icon) {
  color: #ffffff !important;
}

:deep(.ant-menu-item-selected .menu-label) {
  color: #ffffff !important;
  font-weight: 600 !important;
}

:deep(.ant-menu-title-content) {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 5px 0 0;
}

.main-content {
  position: relative;
  flex: 1;
  margin-top: 64px;
  margin-left: 220px; 
  padding: 24px;
  min-height: calc(100vh - 64px);
  background-color: #f4f7f6;
  transition: all 0.3s ease; 
  z-index: 1;
}

.map-content {
  padding: 0 !important;
  margin-left: 220px;
}

.page-title-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 20px;
  padding-bottom: 14px;
  border-bottom: 1.5px solid #e0f0ea;
}

.page-title-icon-wrap {
  width: 34px;
  height: 34px;
  background: linear-gradient(135deg, #00C896, #00a877);
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 3px 8px rgba(0,200,150,0.28);
  flex-shrink: 0;
}

.page-title-text {
  font-family: 'Prompt', sans-serif;
  font-size: 20px;
  font-weight: 700;
  color: #0a2540;
  letter-spacing: -0.2px;
}

@media screen and (max-width: 834px) {
  .top-header { padding: 0 14px; height: 56px; }
  .brand-sub { display: none; }
  .brand-text { font-size: 13px; }
  .main-content { margin-top: 56px; margin-left: 80px; padding: 14px; }
  .custom-sidebar { top: 56px !important; }
  :deep(.ant-layout-sider) { top: 56px !important; width: 80px !important; min-width: 80px !important; max-width: 80px !important; }
  .menu-label { display: none; }
  .page-title-text { font-size: 16px; }
  .user-info-wrapper { display: none; }
}

@media screen and (min-width: 835px) and (max-width: 1180px) {
  .top-header { padding: 0 20px; height: 60px; }
  .main-content { margin-top: 60px; margin-left: 220px; padding: 18px; }
  .custom-sidebar { top: 60px !important; }
  :deep(.ant-layout-sider) { top: 60px !important; }
}

@media screen and (max-width: 576px) {
  .user-info-wrapper { display: none; }
}
</style>