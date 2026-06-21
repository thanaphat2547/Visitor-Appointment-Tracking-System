<template>
  <a-spin :spinning="isLoading" tip="กำลังโหลดข้อมูล...">
  <div class="dashboard-wrapper">

    <!-- Top bar: update info -->
    <div class="top-bar">
      <div class="update-info">
        <span class="update-dot"></span>
        <span>อัปเดต: <b>{{ lastUpdateTime || '-' }}</b></span>
        <span class="sep">|</span>
        <span>รีเฟรชใน <b class="countdown-num">{{ countdown }}</b> วิ</span>
      </div>
      <button class="refresh-btn" @click="manualRefresh" :class="{ spinning: isRefreshing }" title="รีเฟรชข้อมูล">
        <SyncOutlined />
      </button>
    </div>

    <!-- Summary Cards -->
    <div class="cards-grid">

      <div class="summary-card card-appointments">
        <div class="card-icon-wrap" style="background: rgba(99,102,241,0.12)">
          <img src="@/assets/จำนวนนัดหมายวันนี้.png" alt="นัดหมาย" class="card-img" />
        </div>
        <div class="card-body">
          <div class="card-label">นัดหมายวันนี้</div>
          <div class="card-value">{{ totalBooking }}</div>
          <div class="card-unit">รายการ</div>
        </div>
        <div class="card-accent" style="background: #6366f1"></div>
      </div>

      <div class="summary-card card-beacon">
        <div class="card-icon-wrap" style="background: rgba(0,200,150,0.12)">
          <img src="@/assets/ผู้ติดต่อที่มาถึงแล้ว.png" alt="บีคอน" class="card-img" />
        </div>
        <div class="card-body">
          <div class="card-label">อุปกรณ์บีคอน</div>
          <div class="card-value">{{ totalBeacons }}</div>
          <div class="card-unit">ตัว</div>
        </div>
        <div class="card-accent" style="background: #00C896"></div>
      </div>

      <div class="summary-card card-building">
        <div class="card-icon-wrap" style="background: rgba(59,130,246,0.12)">
          <img src="@/assets/Icon_Building_Dash.png" alt="อาคาร" class="card-img" />
        </div>
        <div class="card-body">
          <div class="card-label">จำนวนอาคาร</div>
          <div class="card-value">{{ totalBuilding }}</div>
          <div class="card-unit">อาคาร</div>
        </div>
        <div class="card-accent" style="background: #3b82f6"></div>
      </div>

      <div class="summary-card card-employee">
        <div class="card-icon-wrap" style="background: rgba(245,158,11,0.12)">
          <img src="@/assets/Icon_Employee.png" alt="พนักงาน" class="card-img" />
        </div>
        <div class="card-body">
          <div class="card-label">จำนวนพนักงาน</div>
          <div class="card-value">{{ totalEmployee }}</div>
          <div class="card-unit">คน</div>
        </div>
        <div class="card-accent" style="background: #f59e0b"></div>
      </div>

    </div>

    <!-- Table Card -->
    <div class="table-card">
      <div class="table-header">
        <div class="table-title-group">
          <ClockCircleOutlined class="table-icon" />
          <span class="table-title">รายการนัดหมายวันนี้</span>
          <span class="table-badge">{{ recentLogs.length }} รายการ</span>
        </div>
      </div>

      <a-table
        :data-source="recentLogs"
        :columns="logColumns"
        :pagination="{ pageSize: 5, showSizeChanger: false }"
        row-key="bk_id"
        size="middle"
        class="premium-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'appointment_range'">
            <div class="time-cell">
              <span class="time-date">{{ dayjs(record.appointment_start).format("DD/MM/YYYY") }}</span>
              <span class="time-range">{{ dayjs(record.appointment_start).format("HH:mm") }} - {{ dayjs(record.appointment_end).format("HH:mm") }} น.</span>
            </div>
          </template>

          <template v-else-if="column.dataIndex === 'bk_status'">
            <span :class="['status-pill', `status-${record.bk_status}`]">
              {{ getStatusText(record.bk_status) }}
            </span>
          </template>
        </template>
      </a-table>
    </div>

  </div>
  </a-spin>
</template>

<script setup>
import { ClockCircleOutlined, SyncOutlined } from '@ant-design/icons-vue'
import { ref, onMounted, onUnmounted } from 'vue'
import axios from "@/axios";
import dayjs from "dayjs";
import "dayjs/locale/th";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore";

dayjs.extend(isSameOrAfter);
dayjs.extend(isSameOrBefore);
dayjs.locale("th");

const totalBooking = ref(0)
const totalBeacons = ref(0)
const totalBuilding = ref(0)
const totalEmployee = ref(0)
const recentLogs = ref([])
const isLoading = ref(true)

const countdown = ref(15);
const lastUpdateTime = ref(null);
let countdownTimer = null;

const isRefreshing = ref(false);

const manualRefresh = async () => {
  try {
    isRefreshing.value = true;
    isLoading.value = true;
    await Promise.all([fetchDashboardData(true), fetchTodayBookings()]);
    countdown.value = 15;
  } catch (err) {
    console.error("Manual refresh failed:", err);
  } finally {
    isLoading.value = false;
    isRefreshing.value = false;
  }
};

const fetchDashboardData = async (updateTime = false) => {
  try {
    const auth = localStorage.getItem("auth");
    if (!auth) return;
    const headers = { Authorization: `Basic ${auth}` };
    const [bookingRes, beaconRes, buildingRes, employeeRes] = await Promise.all([
      axios.post("/booking/report_booking", {}, { headers }),
      axios.post("/beacon/report_beacon", {}, { headers }),
      axios.post("/building/report_building", {}, { headers }),
      axios.post("/employee/report_employee", {}, { headers }),
    ]);
    totalBooking.value = bookingRes.data?.data?.[0]?.total_all || 0;
    totalBeacons.value = beaconRes.data?.data?.[0]?.total_beacons || 0;
    totalBuilding.value = buildingRes.data?.data?.[0]?.total_buildings || 0;
    totalEmployee.value = employeeRes.data?.data?.[0]?.total_employees || 0;
    if (updateTime) {
      lastUpdateTime.value = dayjs().format("DD/MM/YYYY HH:mm:ss");
      localStorage.setItem('dashboardLastUpdateTime', lastUpdateTime.value);
    }
  } catch (err) {
    console.error("Fetch dashboard data error:", err);
  }
}

const fetchTodayBookings = async () => {
  try {
    const auth = localStorage.getItem("auth");
    const headers = { Authorization: `Basic ${auth}` };
    const todayStr = dayjs().format('YYYY-MM-DD');
    const res = await axios.get("/booking/show_booking", {
      headers,
      params: { startDate: todayStr, endDate: todayStr }
    });
    if (res.data && res.data.data) {
      const filtered = res.data.data.filter(item =>
        dayjs(item.appointment_start).format('YYYY-MM-DD') === todayStr
      );
      recentLogs.value = filtered;
      localStorage.setItem('cachedTodayBookings', JSON.stringify(filtered));
    }
  } catch (err) {
    console.error("Fetch bookings error:", err);
  }
};

const logColumns = [
  { title: 'ชื่อผู้มาติดต่อ', dataIndex: 'visitor_name' },
  { title: 'ชื่อพนักงาน', dataIndex: 'employee_name' },
  { title: 'อาคาร', dataIndex: 'building_name' },
  { title: 'หัวข้อการติดต่อ', dataIndex: 'purpose' },
  { title: 'ช่วงเวลา', key: 'appointment_range', width: 170 },
  { title: 'สถานะ', dataIndex: 'bk_status', width: 130 },
]

const getStatusText = (status) => {
  const texts = { '0': 'รอดำเนินการ', '1': 'มาถึงแล้ว', '2': 'เสร็จสิ้น', '3': 'เกินกำหนดนัด', '4': 'ยกเลิก' }
  return texts[status] || 'ไม่ทราบ'
}

onMounted(async () => {
  const savedLastUpdate = localStorage.getItem('dashboardLastUpdateTime');
  const cachedBookings = localStorage.getItem('cachedTodayBookings');
  lastUpdateTime.value = savedLastUpdate ?? lastUpdateTime.value;
  if (cachedBookings) recentLogs.value = JSON.parse(cachedBookings);

  isLoading.value = true;
  try {
    await Promise.all([fetchDashboardData(true), fetchTodayBookings()]);
  } catch (error) {
    console.error("Initial fetch error:", error);
  } finally {
    isLoading.value = false;
  }

  const savedCountdown = parseInt(localStorage.getItem('dashboardCountdown'));
  countdown.value = !isNaN(savedCountdown) ? savedCountdown : 15;

  clearInterval(countdownTimer);
  countdownTimer = setInterval(async () => {
    countdown.value--;
    if (countdown.value <= 0) {
      try {
        await Promise.all([fetchDashboardData(true), fetchTodayBookings()]);
      } catch (err) { console.error("Auto refresh error:", err); }
      countdown.value = 15;
    }
    localStorage.setItem('dashboardCountdown', countdown.value);
  }, 1000);
});

onUnmounted(() => { clearInterval(countdownTimer); });
</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Prompt:wght@400;500;600;700&display=swap');

.dashboard-wrapper {
  display: flex;
  flex-direction: column;
  gap: 20px;
  font-family: 'Prompt', 'Inter', sans-serif;
}

.top-bar {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 12px;
}

.update-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  background: #00C896;
  border-radius: 50%;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}

.update-info {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  color: #64748b;
  background: white;
  padding: 6px 14px;
  border-radius: 20px;
  border: 1px solid #e8f5f1;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}

.update-info b { color: #0a2540; font-weight: 600; }
.sep { color: #d1d5db; }
.countdown-num { color: #00C896; font-weight: 700; font-size: 14px; }

.refresh-btn {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 1.5px solid #e8f5f1;
  background: white;
  color: #64748b;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  transition: all 0.25s ease;
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}

.refresh-btn:hover { color: #00C896; border-color: #00C896; background: rgba(0,200,150,0.06); transform: rotate(15deg); }
.refresh-btn.spinning { animation: spin 0.8s linear infinite; }
@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 16px;
}

.summary-card {
  background: white;
  border-radius: 16px;
  padding: 20px;
  display: flex;
  align-items: center;
  gap: 16px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.05);
  border: 1px solid #f0f4f2;
  position: relative;
  overflow: hidden;
  transition: transform 0.25s ease, box-shadow 0.25s ease;
}

.summary-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.09);
}

.card-accent {
  position: absolute;
  left: 0;
  top: 0;
  width: 4px;
  height: 100%;
  border-radius: 4px 0 0 4px;
}

.card-icon-wrap {
  width: 58px;
  height: 58px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.card-img {
  width: 36px;
  height: 36px;
  object-fit: contain;
}

.card-body { flex: 1; }

.card-label {
  font-size: 12.5px;
  color: #64748b;
  font-weight: 500;
  margin-bottom: 4px;
}

.card-value {
  font-size: 32px;
  font-weight: 700;
  color: #0a2540;
  line-height: 1;
  margin-bottom: 2px;
}

.card-unit {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 500;
}

.table-card {
  background: white;
  border-radius: 16px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.05);
  border: 1px solid #f0f4f2;
  overflow: hidden;
}

.table-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 18px 24px 14px;
  border-bottom: 1.5px solid #f0f4f2;
}

.table-title-group { display: flex; align-items: center; gap: 10px; }

.table-icon { font-size: 18px; color: #00C896; }

.table-title {
  font-size: 15px;
  font-weight: 700;
  color: #0a2540;
}

.table-badge {
  background: rgba(0,200,150,0.1);
  color: #00a877;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 10px;
  border-radius: 20px;
  border: 1px solid rgba(0,200,150,0.2);
}

:deep(.premium-table .ant-table) {
  font-family: 'Prompt', sans-serif;
  font-size: 13.5px;
}

:deep(.premium-table .ant-table-thead > tr > th) {
  background: #f8fbf9 !important;
  color: #64748b !important;
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  border-bottom: 1.5px solid #e8f5f1 !important;
}

:deep(.premium-table .ant-table-tbody > tr:hover > td) {
  background: rgba(0,200,150,0.04) !important;
}

:deep(.premium-table .ant-table-tbody > tr > td) {
  border-bottom: 1px solid #f4f7f6 !important;
  padding: 10px 16px !important;
}

.time-cell { display: flex; flex-direction: column; gap: 2px; }
.time-date { font-size: 13px; font-weight: 600; color: #0a2540; }
.time-range { font-size: 12px; color: #00a877; font-weight: 500; }

.status-pill {
  display: inline-flex;
  align-items: center;
  padding: 3px 12px;
  border-radius: 20px;
  font-size: 11.5px;
  font-weight: 600;
  letter-spacing: 0.2px;
}

.status-0 { background: #eff6ff; color: #3b82f6; border: 1px solid #bfdbfe; }
.status-1 { background: #f0fdf9; color: #00a877; border: 1px solid #a7f3d0; }
.status-2 { background: #ecfeff; color: #0891b2; border: 1px solid #a5f3fc; }
.status-3 { background: #fff7ed; color: #d97706; border: 1px solid #fed7aa; }
.status-4 { background: #fef2f2; color: #ef4444; border: 1px solid #fecaca; }

:deep(.ant-pagination-item-active) {
  background: #00C896 !important;
  border-color: #00C896 !important;
}
:deep(.ant-pagination-item-active a) { color: white !important; }
</style>