<template>
  <a-dropdown
    placement="bottomRight"
    trigger="click"
    @open-change="handleDropdownVisible"
  >
    <template #overlay>
      <a-card style="width: 420px; padding: 12px;" class="notification-dropdown">
        <div class="header-row">
          <span style="font-weight: bold; font-size: 16px;">📬 แจ้งเตือน</span>
          <a-button type="link" danger size="small" @click.stop="clearNotifications">
            🗑️ ล้างทั้งหมด
          </a-button>
        </div>

        <a-list
          :data-source="notifications"
          :loading="loading"
          item-layout="horizontal"
          :locale="{ emptyText: 'ไม่มีแจ้งเตือน' }"
          class="notification-list"
          size="small"
        >
          <template #renderItem="{ item }">
            <a-list-item :class="{ unread: isUnread(item.log_id) }">
              <a-list-item-meta>
                <template #avatar>
                  <a-avatar
                    :style="{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }"
                  >
                    {{ item.eventtype === 'IN' ? '🟢' : '🔴' }}
                  </a-avatar>
                </template>

                <template #title>
                  <div class="title-row">
                    <span class="title-text">{{ item.title }}</span>
                    <a-tag color="blue" v-if="isUnread(item.log_id)" style="margin-left: 6px;">ยังไม่อ่าน</a-tag>
                  </div>
                </template>

                <template #description>
                  <div class="description">{{ item.body }}</div>
                  <small class="date">🕒 {{ formatDate(item.created_at) }}</small>
                </template>
              </a-list-item-meta>
            </a-list-item>
          </template>
        </a-list>
      </a-card>
    </template>

    <a-badge :count="unreadCount" :offset="[0, 6]">
      <a-button shape="circle" type="text" class="notification-bell">
        <BellOutlined />
      </a-button>
    </a-badge>
  </a-dropdown>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { BellOutlined } from '@ant-design/icons-vue';
import dayjs from 'dayjs';
import axios from '@/axios';
import { useNotification } from '@/components/UseNotification';
import emitter from '@/eventBus';
import { onMessage } from "firebase/messaging";
import { messaging } from "@/firebase";

const notifications = ref([]);
const loading = ref(false);
const { showNotification } = useNotification();

// เก็บ log_id ที่อ่านแล้วใน localStorage
const STORAGE_KEY = 'read_notifications';

// ฟังก์ชันจัดการ read status
const getReadNotifications = () => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch (error) {
    console.error('Error reading localStorage:', error);
    return [];
  }
};

const saveReadNotifications = (readIds) => {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(readIds));
  } catch (error) {
    console.error('Error saving to localStorage:', error);
  }
};

const readNotificationIds = ref(getReadNotifications());
const unreadCount = ref(0);

// เช็คว่า notification อ่านแล้วหรือยัง
const isUnread = (log_id) => {
  return !readNotificationIds.value.includes(log_id);
};

// ฟังก์ชันอัปเดต unread count
const updateUnreadCount = () => {
  unreadCount.value = notifications.value.filter(n => isUnread(n.log_id)).length;
  console.log('📊 Updated unread count:', unreadCount.value);
};

const formatDate = (date) => dayjs(date).format('DD/MM/YYYY HH:mm:ss');

const fetchNotifications = async () => {
  loading.value = true;
  try {
    const user_id = localStorage.getItem('user_id');
    const response = await axios.get('/notification/history', { params: { user_id } });

    const allNotifications = response.data.notifications || [];
    notifications.value = allNotifications;
    
    updateUnreadCount();
    console.log('📥 Fetched notifications:', notifications.value.length);
    console.log('🔔 Unread count:', unreadCount.value);
  } catch (error) {
    console.error('Error fetching notifications:', error);
  } finally {
    loading.value = false;
  }
};

const markNotificationsAsRead = () => {
  // เพิ่ม log_id ทั้งหมดที่ยังไม่อ่านเข้าไปใน readNotificationIds
  const unreadIds = notifications.value
    .filter(n => isUnread(n.log_id))
    .map(n => n.log_id);

  if (unreadIds.length === 0) {
    console.log('✅ No unread notifications');
    return;
  }

  // อัปเดต state
  readNotificationIds.value = [...new Set([...readNotificationIds.value, ...unreadIds])];
  
  // บันทึกลง localStorage
  saveReadNotifications(readNotificationIds.value);
  
  // อัปเดต badge
  updateUnreadCount();
  
  console.log('✅ Marked as read:', unreadIds.length, 'notifications');
  console.log('🔔 New unread count:', unreadCount.value);
};

const clearNotifications = async () => {
  try {
    const user_id = localStorage.getItem('user_id');
    await axios.post('/notification/clear', { user_id });
    
    // ล้างข้อมูล
    notifications.value = [];
    readNotificationIds.value = [];
    saveReadNotifications([]);
    updateUnreadCount();
    
    console.log('🗑️ All notifications cleared');
  } catch (error) {
    console.error('Error clearing notifications:', error);
  }
};

const handleDropdownVisible = (visible) => {
  if (visible) {
    console.log('👁️ Dropdown opened, marking all as read...');
    markNotificationsAsRead();
  }
};

const handleNewNotification = (data) => {
  console.log("🟡 handleNewNotification triggered:", data);
  console.log("🔍 Data keys:", Object.keys(data));
  console.log("🔍 log_id:", data.log_id);
  console.log("🔍 user_id:", data.user_id);
  
  const currentUserId = localStorage.getItem('user_id');
  
  // เช็ค user_id
  if (!data || !data.log_id) {
    console.log('⚠️ No data received');
    return;
  }
  
  if (data.user_id && data.user_id !== currentUserId) {
    console.log('⚠️ User ID mismatch:', data.user_id, 'vs', currentUserId);
    return;
  }

  console.log('📩 New notification received:', data);

  const log_id = data.log_id || `temp-${Date.now()}`;
  
  if (log_id.startsWith('temp-')) {
    console.warn('⚠️ Using temporary log_id:', log_id);
  }

  const newItem = {
    title: data.title || 'ไม่มีหัวข้อ',
    body: data.body || 'ไม่มีเนื้อหา',
    eventtype: data.eventtype,
    bc_id: data.bc_id,
    b_id: data.b_id,
    created_at: data.timestamp || data.created_at || new Date().toISOString(),
    log_id: log_id
  };

  console.log('📦 New item to add:', newItem);

  // เพิ่ม notification ใหม่ด้านบนสุด
  notifications.value.unshift(newItem);
  
  // อัปเดต unread count ทันที
  updateUnreadCount();
  
  console.log('🔔 New unread count:', unreadCount.value);
  console.log('📋 Total notifications:', notifications.value.length);
  console.log('📋 Notifications array:', notifications.value.map(n => n.log_id));

  showNotification(newItem.title, newItem.body, newItem.eventtype);
};

onMounted(() => {
  const role = Number(localStorage.getItem('role_id')); 
  if (role === 1) { 
    fetchNotifications();
    onMessage(messaging, (payload) => {
      console.log("🔥 Firebase Message Received (Foreground):", payload);
      
      const dataForBus = {
        log_id: payload.data?.log_id,
        title: payload.notification?.title,
        body: payload.notification?.body,
        eventtype: payload.data?.eventtype || 'IN',
        user_id: payload.data?.user_id,
        created_at: new Date().toISOString()
      };

      handleNewNotification(dataForBus);
    });
    
    emitter.on('new-notification', handleNewNotification);
    console.log('✅ NotificationDropdown mounted');
  }
});

onUnmounted(() => {
  emitter.off('new-notification', handleNewNotification);
  console.log('👋 NotificationDropdown unmounted');
});

</script>

<style scoped>
.notification-dropdown {
  max-height: 440px;
  overflow-y: auto;
  border-radius: 14px;
  scrollbar-width: thin;
}

.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
  padding-bottom: 8px;
  border-bottom: 1.5px solid #e8f5f1;
}

.notification-bell {
  font-size: 20px;
  color: #0a2540;
  border-radius: 50%;
  padding: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.25s ease;
  background: rgba(0,200,150,0.08);
  border: 1.5px solid rgba(0,200,150,0.2);
}

.notification-bell:hover {
  background: rgba(0,200,150,0.15);
  color: #00a877;
  transform: scale(1.08) rotate(-10deg);
}

:deep(.ant-badge-count) {
  background: #ef4444 !important;
  box-shadow: 0 0 0 2px white !important;
  animation: badge-pulse 2s infinite;
}

@keyframes badge-pulse {
  0%, 100% { box-shadow: 0 0 0 2px white; }
  50% { box-shadow: 0 0 0 3px rgba(239,68,68,0.2); }
}

.unread {
  background: linear-gradient(90deg, rgba(0,200,150,0.04), transparent);
  border-left: 3px solid #00C896 !important;
}

.title-row {
  display: flex;
  align-items: center;
  gap: 6px;
}

.title-text {
  font-weight: 600;
  font-size: 13.5px;
  color: #0a2540;
}

.description {
  font-size: 12.5px;
  color: #64748b;
  margin-top: 2px;
}

.date {
  font-size: 11px;
  color: #94a3b8;
  margin-top: 4px;
  display: flex;
  align-items: center;
  gap: 3px;
}

:deep(.ant-list-item) {
  padding: 10px 12px !important;
  border-radius: 10px !important;
  margin-bottom: 4px !important;
  border-bottom: 1px solid #f0f4f2 !important;
  transition: background 0.2s;
}

:deep(.ant-list-item:hover) {
  background: rgba(0,200,150,0.04) !important;
}

:deep(.ant-avatar) {
  background: transparent !important;
  border: none !important;
  font-size: 18px;
}
</style>