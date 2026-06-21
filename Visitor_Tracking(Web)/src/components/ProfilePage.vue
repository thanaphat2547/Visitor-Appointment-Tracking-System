<template>
  <a-dropdown placement="bottomRight" trigger="click">
    <template #overlay>
      <a-card style="width: 280px; padding: 10px;">
        <div style="font-weight: bold; font-size: 16px; margin-bottom: 8px; text-align: center;">
          {{ user.emp_firstname }} {{ user.emp_lastname }}
        </div>
        <div style="font-size: 13px; color: #000; margin-bottom: 4px; text-align: left;">
          <UserOutlined style="margin-right: 6px;" /> {{ user.emp_username }}
        </div>
        <div style="font-size: 13px; color: #000; margin-bottom: 4px; text-align: left;">
          <MailOutlined style="margin-right: 6px;" /> {{ user.emp_email }}
        </div>
        <div style="font-size: 13px; color: #000; margin-bottom: 12px; text-align: left;">
          <PhoneOutlined style="margin-right: 6px;" /> {{ user.emp_phone }}
        </div>
        <hr style="border: 0; border-top: 1px solid #eee; margin: 8px 0;" /> <div style="font-size: 13px; color: #555; margin-bottom: 4px; text-align: left;">
          <strong style="color: #003c70;">ฝ่าย:</strong> {{ user.emp_department || '-' }}
        </div>
        <div style="font-size: 13px; color: #555; margin-bottom: 4px; text-align: left;">
          <strong style="color: #003c70;">แผนก:</strong> {{ user.emp_section || '-' }}
        </div>
        <div style="font-size: 13px; color: #555; margin-bottom: 12px; text-align: left;">
          <strong style="color: #003c70;">ตำแหน่ง:</strong> {{ user.emp_position || '-' }}
        </div>

        <template v-if="!showConfirmLogout">
          <a-button type="primary" block danger @click.stop="handleLogoutClick">
            ลงชื่อออก
          </a-button>
        </template>

        <template v-else>
          <div style="margin-bottom: 8px; font-weight: bold; text-align: center;">
            คุณแน่ใจหรือไม่?
          </div>
          <a-space direction="vertical" style="width: 100%;">
            <a-button type="primary" block danger @click.stop="confirmLogout">
              ลงชื่อออก
            </a-button>
            <a-button block @click.stop="cancelLogout">
              ยกเลิก
            </a-button>
          </a-space>
        </template>
      </a-card>
    </template>

    <div class="profile-avatar">
      {{ user.emp_firstname ? user.emp_firstname.charAt(0) : '?' }}
    </div>
  </a-dropdown>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { UserOutlined, MailOutlined, PhoneOutlined } from '@ant-design/icons-vue'
import axios from "@/axios";
import { useRouter } from "vue-router";

const router = useRouter();
const showConfirmLogout = ref(false);
const user = ref({
  emp_firstname: '',
  emp_lastname: '',
  emp_username: '',
  emp_email: '',
  emp_phone: '',
  emp_department: '',
  emp_section: '',
  emp_position: ''
});

const handleLogoutClick = () => showConfirmLogout.value = true;
const cancelLogout = () => showConfirmLogout.value = false;

const confirmLogout = async () => {
  try {
    const user_id = localStorage.getItem('user_id');
    if (user_id) {
      await axios.post('/notification/clear', { user_id });

      // เครียร์แจ้งเตือน
      if (typeof notifications !== 'undefined') notifications.value = [];
      if (typeof unreadCount !== 'undefined') unreadCount.value = 0;
    }
  } catch (error) {
    console.error('ล้างแจ้งเตือนไม่สำเร็จ:', error);
  }

  localStorage.removeItem('auth');
  localStorage.removeItem('user');
  localStorage.removeItem('profile');
  localStorage.removeItem('user_id');
  localStorage.removeItem('username');
  localStorage.removeItem('role');      
  localStorage.removeItem('password');  
  sessionStorage.clear(); 
                 
  router.push('/');
};

onMounted(async () => {
  const savedProfile = localStorage.getItem('profile');
  if (savedProfile) {
    const parsed = JSON.parse(savedProfile);
    user.value = {
      emp_firstname: parsed.emp_firstname || '',
      emp_lastname: parsed.emp_lastname || '',
      emp_username: parsed.emp_username || '',
      emp_email: parsed.emp_email || '',
      emp_phone: parsed.emp_phone || '',
      emp_department: parsed.emp_department || '',
      emp_section: parsed.emp_section || '',
      emp_position: parsed.emp_position || ''
    }
  }

  const auth = localStorage.getItem('auth');
  const userString = localStorage.getItem('user');
  const userData = userString ? JSON.parse(userString) : {};
  const emp_id = userData.emp_id;
  const emp_username = userData.emp_username;
  if (!auth || (!emp_id && !emp_username)) return;

  try {
    const res = await axios.post('/employee/profile',
      emp_id ? { emp_id } : { emp_username }
    );
    const p = res.data.data;
    user.value = {
      emp_firstname: p.emp_firstname || '',
      emp_lastname: p.emp_lastname || '',
      emp_username: p.emp_username || '',
      emp_email: p.emp_email || '',
      emp_phone: p.emp_phone || '',
      emp_department: p.emp_department || '', 
      emp_section: p.emp_section || '',
      emp_position: p.emp_position || ''
    }
    localStorage.setItem('profile', JSON.stringify(p));
  } catch (err) {
    console.error('โหลดโปรไฟล์ไม่สำเร็จ', err);
  }
});
</script>

<style scoped>
.profile-avatar {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  color: white;
  font-weight: 700;
  font-size: 17px;
  overflow: hidden;
  cursor: pointer;
  background: linear-gradient(135deg, #00C896, #00a877);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 3px 10px rgba(0,200,150,0.35);
  border: 2.5px solid #fff;
  transition: all 0.25s ease;
}

.profile-avatar:hover {
  transform: scale(1.08);
  box-shadow: 0 5px 16px rgba(0,200,150,0.45);
}

:deep(.ant-card) {
  border-radius: 14px !important;
  box-shadow: 0 8px 32px rgba(0,0,0,0.10) !important;
  border: 1px solid #e8f5f1 !important;
  overflow: hidden;
}

:deep(.ant-card-body) {
  padding: 14px !important;
}
</style>
