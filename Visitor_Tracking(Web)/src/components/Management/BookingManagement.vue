<template>
  <a-spin :spinning="isLoading" tip="กำลังโหลดข้อมูล...">
  <div class="container-fluid my-4">
    <!-- Toolbar -->
    <div class="toolbar">
      <!-- Search -->
      <a-input
        class="search-input"
        v-model:value="searchValue"
        placeholder="ค้นหาการนัดหมาย..."
        enter-button="ค้นหา"
        size="large"
      />

      <div class="filter-section p-3 mb-3" style="border: none;"> 
  <a-row :gutter="[16, 16]" align="middle">
    <a-col :xs="24" :sm="10" :md="8" style="margin-top: -10px;">
      <span class="filter-label">ช่วงวันที่นัดหมาย:</span>
      <a-range-picker
        v-model:value="filterDateRange"
        style="width: 100%"
        format="DD/MM/YYYY"
        :placeholder="['เริ่ม', 'สิ้นสุด']"
      />
    </a-col>

    <a-col :xs="24" :sm="8" :md="6" style="margin-top: -10px;">
      <span class="filter-label">สถานะ:</span>
      <a-select
        v-model:value="filterStatus"
        placeholder="เลือกสถานะ"
        style="width: 100%"
      >
        <a-select-option value="all">แสดงทั้งหมด</a-select-option>
        <a-select-option value="0">รอดำเนินการ</a-select-option>
        <a-select-option value="1">มาถึงแล้ว</a-select-option>
        <a-select-option value="2">เสร็จสิ้น</a-select-option>
        <a-select-option value="3">เกินกำหนดนัด</a-select-option>
        <a-select-option value="4">ยกเลิก</a-select-option>
      </a-select>
    </a-col>

    <a-col :xs="24" :sm="6" :md="6">
      <div style="margin-top: 7px; display: flex; gap: 8px;">
        <a-button type="primary" block @click="fetchBookings">
          <search-outlined /> ค้นหา
        </a-button>
        <a-button type="primary" danger @click="resetFilters" block>
          ล้างตัวกรอง
        </a-button>
      </div>
    </a-col>
  </a-row>
</div>

      <!-- Add button -->
      <a-button v-if="userRole === 1" type="primary" class="btn-Add" @click="addBooking">
        <i class="bi bi-plus-circle me-1"></i> เพิ่มการนัดหมาย
      </a-button>
    </div>

    <!-- ตาราง -->
    <div class="card-table p-3 rounded shadow-sm">
      <a-table
        bordered
        :data-source="filteredData"
        :columns="columns"
        rowKey="bk_id"
        :pagination="pagination"
        :scroll="{ x: 600 }"
        @change="handleTableChange"
        class="styled-table"
      >
<template #bodyCell="{ column, record }">
  <template v-if="column.key === 'bk_status'">
    <a-tag :color="getStatusColor(record.bk_status)">
      {{ getStatusText(record.bk_status) }}
    </a-tag>
  </template>

  <template v-else-if="column.key === 'appointment_range'">
    <div style="font-size: 13px;">
      <b>{{ dayjs(record.appointment_start).format("DD/MM/YYYY") }}</b><br/>
      <span style="color: #1890ff;">
        {{ dayjs(record.appointment_start).format("HH:mm") }} - {{ dayjs(record.appointment_end).format("HH:mm") }} น.
      </span>
    </div>
  </template>

<template v-else-if="column.key === 'action'">
  <a-space>
    <!-- ปุ่มรายละเอียด -->
    <info-circle-outlined class="editable-cell-icon" style="color: #1890ff;" @click="showDetail(record)" />
    
    <!-- ปุ่มแก้ไข -->
    <template v-if="['0', '1', '3'].includes(record.bk_status)">
      <a-divider type="vertical" />
      <edit-outlined class="editable-cell-icon" @click="editBooking(record)" />
    </template>

    <!-- ปุ่มยกเลิก -->
    <template v-if="!['1','2', '3', '4'].includes(record.bk_status)">
      <a-divider type="vertical" />
      <a-popconfirm 
        title="ยืนยันการยกเลิกการนัดหมาย?" 
        @confirm="cancelBooking(record.bk_id)"
      >
        <close-circle-outlined class="editable-cell-icon-close" title="ยกเลิกนัดหมาย" />
      </a-popconfirm>
    </template>
  </a-space>
</template>

  <template v-else>
    {{ record[column.dataIndex] }}
  </template>
</template>
</a-table>
    </div>

    <!-- Modal Add/Edit -->
    <a-modal
      :title="isEditing ? 'แก้ไขการนัดหมาย' : 'เพิ่มการนัดหมายใหม่'"
      v-model:open="isModalVisible"
        @ok="isEditing ? saveEdit() : saveAdd()"
        @cancel="closeModal"
        ok-text="บันทึก"
        cancel-text="ยกเลิก"
      :style="{ top: '10px' }"
      width="600px"
    >
  <a-form :model="formData" :rules="rules" ref="formRef" layout="vertical">
    
    <a-form-item v-if="userRole === 1 || !isEditing" label="ผู้มาติดต่อ" name="vis_id">
      <a-select
        v-model:value="formData.vis_id"
        placeholder="เลือกผู้มาติดต่อ"
        :options="visitorOptions"
      />
    </a-form-item>

    <template v-if="userRole === 1 || !isEditing">
        <a-form-item label="พนักงานผู้รับนัด" name="emp_id">
          <a-input :value="formData.emp_name" disabled style="color: #000;" />
        </a-form-item>

        <a-row :gutter="16">
          <a-col :span="8">
            <a-form-item label="แผนก">
              <a-input :value="formData.emp_department" disabled style="color: #000;" />
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item label="ฝ่าย">
              <a-input :value="formData.emp_section" disabled style="color: #000;"  />
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item label="ตำแหน่ง">
              <a-input :value="formData.emp_position" disabled style="color: #000;"  />
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="วัตถุประสงค์" name="purpose">
          <a-input v-model:value="formData.purpose" :maxlength="100" placeholder="กรอกวัตถุประสงค์" />
        </a-form-item>
    </template>

    <a-form-item label="อาคาร" name="b_id">
      <a-select
        v-model:value="formData.b_id"
        placeholder="เลือกอาคาร (ไม่บังคับ)"
        :options="buildingOptions"
        allow-clear
      />
    </a-form-item>

    <a-form-item label="ทะเบียนรถ" name="car_registration">
      <a-input v-model:value="formData.car_registration" :maxlength="20" placeholder="กรอกทะเบียนรถ" />
    </a-form-item>

    <a-form-item label="วันเวลานัดหมาย (เริ่ม - สิ้นสุด)" name="appointment_range">
      <a-range-picker
        :show-time="{ format: 'HH:mm' }"
        format="YYYY-MM-DD HH:mm"
        :placeholder="['เวลาเริ่มนัด', 'เวลาสิ้นสุด']"
        style="width: 100%"
        :disabled-date="disabledDate"
        
        @change="(dates) => {
          formData.appointment_range = dates;
          formData.appointment_start = dates ? dates[0] : null;
          formData.appointment_end = dates ? dates[1] : null;
        }"
        :value="formData.appointment_range" 
      />
    </a-form-item>

  </a-form>
</a-modal>

<a-modal
  v-model:open="isDetailModalVisible"
  title="รายละเอียดการนัดหมาย"
  :footer="null"
  :style="{ top: '50px' }" width="700px"
>
  <div v-if="selectedDetail" class="detail-container">
    <a-divider orientation="left"><user-outlined /> ข้อมูลผู้มาติดต่อ</a-divider>
    <a-descriptions bordered :column="2" size="small">
      <a-descriptions-item label="ชื่อ-นามสกุล">{{ selectedDetail.visitor_name }}</a-descriptions-item>
      <a-descriptions-item label="อีเมล">{{ selectedDetail.vis_email || '-' }}</a-descriptions-item>
      <a-descriptions-item label="เบอร์โทรศัพท์">{{ selectedDetail.vis_phone || '-' }}</a-descriptions-item>
      <a-descriptions-item label="ทะเบียนรถ">{{ selectedDetail.car_registration || '-' }}</a-descriptions-item>
      <a-descriptions-item label="Booking ID" :span="2">
        <a-tag color="blue" style="font-size: 14px; font-weight: bold; padding: 4px 10px;">
          {{ selectedDetail.bk_id }}
        </a-tag>
        <small style="color: red; margin-left: 8px;">*ใช้สำหรับลงชื่อเข้าใช้</small>
      </a-descriptions-item>
    </a-descriptions>

    <a-divider orientation="left"><team-outlined /> ข้อมูลพนักงานผู้รับนัด</a-divider>
<a-descriptions bordered :column="2" size="small">
  <a-descriptions-item label="ชื่อ-นามสกุล">{{ selectedDetail.employee_name }}</a-descriptions-item>
  <a-descriptions-item label="อีเมล">{{ selectedDetail.emp_email || '-' }}</a-descriptions-item>
  <a-descriptions-item label="เบอร์โทรศัพท์">{{ selectedDetail.emp_phone || '-' }}</a-descriptions-item>
  <a-descriptions-item label="ตำแหน่ง">{{ selectedDetail.emp_position || '-' }}</a-descriptions-item>
  <a-descriptions-item label="ฝ่าย">{{ selectedDetail.emp_department || '-' }}</a-descriptions-item>
  <a-descriptions-item label="แผนก">{{ selectedDetail.emp_section || '-' }}</a-descriptions-item>
</a-descriptions>

    <a-divider orientation="left"><calendar-outlined /> ข้อมูลนัดหมาย</a-divider>
    <a-descriptions bordered :column="1" size="small">
      <a-descriptions-item label="วันเวลานัดหมาย">
        {{ dayjs(selectedDetail.appointment_start).format("DD/MM/YYYY HH:mm") }} - {{ dayjs(selectedDetail.appointment_end).format("HH:mm") }} น.
      </a-descriptions-item>
      <a-descriptions-item label="สถานที่/อาคาร">{{ selectedDetail.building_name || '-' }}</a-descriptions-item>
      <a-descriptions-item label="วัตถุประสงค์">{{ selectedDetail.purpose || '-' }}</a-descriptions-item>
      <a-descriptions-item label="สถานะ">
        <a-tag :color="getStatusColor(selectedDetail.bk_status)">
          {{ getStatusText(selectedDetail.bk_status) }}
        </a-tag>
      </a-descriptions-item>
    </a-descriptions>
  </div>
</a-modal>

  </div>
  </a-spin>
</template>

<script setup>
import { ref, reactive, computed, onMounted, nextTick } from "vue"
import axios from '@/axios';
import { message } from "ant-design-vue"
import { EditOutlined, CloseCircleOutlined, SearchOutlined, InfoCircleOutlined, UserOutlined, TeamOutlined, CalendarOutlined } from "@ant-design/icons-vue"
import dayjs from 'dayjs'

// state
const data = ref([])
const visitorList = ref([])
const employeeList = ref([])
const buildingList = ref([])
const searchValue = ref("")
const isModalVisible = ref(false)
const isEditing = ref(false)
const formRef = ref(null);
const formKey = ref(0)
const isLoading = ref(true)
const filterDateRange = ref([])
const filterStatus = ref("all")

const isDetailModalVisible = ref(false);
const selectedDetail = ref(null);

const auth = localStorage.getItem("auth");
const userRole = Number(localStorage.getItem("role_id"));

const showDetail = (record) => {
  selectedDetail.value = record;
  isDetailModalVisible.value = true;
};

const resetFilters = () => {
  searchValue.value = "";
  filterDateRange.value = [];
  filterStatus.value = "all";
  fetchBookings();
};

const rules = {
  vis_id: [
    { required: true, message: "กรุณาเลือกผู้มาติดต่อ" }
  ],
  emp_id: [
    { required: true, message: "กรุณาเลือกพนักงาน" }
  ],
  appointment_range: [
    { required: true, message: "กรุณาเลือกวันเวลานัดหมาย" }
  ],
  b_id: [
    { required: true, message: "กรุณาเลือกอาคาร" }
  ],
  purpose: [
    { required: true, message: "กรุณากรอกวัตถุประสงค์" }
  ],
  car_registration: [
    { required: false }
  ]
};

const formData = reactive({
  bk_id: "",
  vis_id: "",
  emp_id: "",
  emp_name: "",    
  emp_department: "", 
  emp_section: "",     
  emp_position: "",
  b_id: "",
  purpose: "",
  car_registration: "",
  appointment_range: [], 
  appointment_start: null, 
  appointment_end: null
})

const formatThaiDate = (date) => {
  if (!date) return "-";
  return dayjs(date).format("DD/MM/YYYY HH:mm น."); 
};

// columns
const columns = [
  { title: "รหัสนัดหมาย", dataIndex: "bk_id", key: "bk_id", width: 120 },
  { title: "ผู้มาติดต่อ", dataIndex: "visitor_name", key: "visitor_name", width: 150 },
  { title: "พนักงาน", dataIndex: "employee_name", key: "employee_name", width: 150 },
  { title: "อาคาร", dataIndex: "building_name", key: "building_name", width: 120 },
  { title: "วัตถุประสงค์", dataIndex: "purpose", key: "purpose", width: 130 },
  { title: "ทะเบียนรถ", dataIndex: "car_registration", key: "car_registration", width: 130 },
  { title: "ช่วงเวลานัดหมาย", key: "appointment_range", width: 200 },
  { title: "สถานะ", dataIndex: "bk_status", key: "bk_status", width: 110 },
  { title: "การจัดการ", key: "action", width: 100 }
]

// pagination
const pagination = ref({
  current: 1,
  pageSize: 5,
  showSizeChanger: true,
  pageSizeOptions: ["5", "10", "20"]
})

// status colors and text
const getStatusColor = (status) => {
  const colors = {
    '0': 'blue',      // pending
    '1': 'green',     // arrived
    '2': 'cyan',      // finished
    '3': 'orange',    // late
    '4': 'red'        // cancelled
  }
  return colors[status] || 'default'
}

const getStatusText = (status) => {
  const texts = {
    '0': 'รอดำเนินการ',
    '1': 'มาถึงแล้ว',
    '2': 'เสร็จสิ้น',
    '3': 'เกินกำหนดนัด',
    '4': 'ยกเลิก'
  }
  return texts[status] || 'ไม่ทราบ'
}

const visitorOptions = computed(() =>
  visitorList.value.map(v => ({
    label: `${v.vis_firstname} ${v.vis_lastname}`,
    value: v.vis_id
  }))
)

const employeeOptions = computed(() =>
  employeeList.value.map(e => ({
    label: `${e.emp_firstname} ${e.emp_lastname}`,
    value: e.emp_id
  }))
)

const disabledDate = (current) => {
  return current && current < dayjs().startOf('day');
};

const buildingOptions = computed(() =>
  buildingList.value.map(b => ({
    label: b.b_name,
    value: b.b_id
  }))
)

// filter Search
const filteredData = computed(() => {
  if (!searchValue.value) return data.value;
  const searchParts = searchValue.value.toLowerCase().split(/\s+/);
  return data.value.filter((item) => {
    const itemText = Object.values(item).join(" ").toLowerCase();
    return searchParts.every(part => itemText.includes(part));
  });
});

// handle pagination change
const handleTableChange = (pag) => {
  pagination.value = { ...pagination.value, ...pag }
}

// โหลดข้อมูล bookings
const fetchBookings = async () => {
  try {
    isLoading.value = true;
    
    const savedProfile = JSON.parse(localStorage.getItem('profile') || '{}');
    const emp_id = savedProfile.emp_id;
    const role_id = localStorage.getItem('role_id');

    const params = {
      status: filterStatus.value,
      emp_id: emp_id,
      role_id: role_id
    };

    // การกรองวันที่
    if (filterDateRange.value && filterDateRange.value.length === 2) {
      params.startDate = filterDateRange.value[0].format('YYYY-MM-DD');
      params.endDate = filterDateRange.value[1].format('YYYY-MM-DD');
    }

    const res = await axios.get("/booking/show_booking", {
      headers: { Authorization: `Basic ${auth}` },
      params: params 
    });

    if (Array.isArray(res.data.data)) {
      data.value = res.data.data;
    } else {
      data.value = [];
    }
  } catch (error) {
    message.error("โหลดข้อมูลการนัดหมายไม่สำเร็จ");
    data.value = [];
  } finally {
    isLoading.value = false;
  }
}

// โหลดข้อมูลที่เกี่ยวข้อง
const fetchRelatedData = async () => {
  try {
    const [visitorRes, employeeRes, buildingRes] = await Promise.all([
      axios.get("/visitor/show_visitor", { headers: { Authorization: `Basic ${auth}` } }),
      axios.get("/employee/show_employee", { headers: { Authorization: `Basic ${auth}` } }),
      axios.get("/building/show_building", { headers: { Authorization: `Basic ${auth}` } })
    ])

    visitorList.value = Array.isArray(visitorRes.data) ? visitorRes.data : visitorRes.data.data || []
    employeeList.value = Array.isArray(employeeRes.data) ? employeeRes.data : employeeRes.data.data || []
    buildingList.value = Array.isArray(buildingRes.data) ? buildingRes.data : buildingRes.data.data || []
  } catch (error) {
    console.error("โหลดข้อมูลที่เกี่ยวข้องไม่สำเร็จ", error)
  }
}

// modal control
const addBooking = async () => {
  if (userRole !== 1) {
    message.warning("คุณไม่มีสิทธิ์ในการเพิ่มข้อมูลนัดหมาย");
    return;
  }
  
  formKey.value++

  const savedProfile = JSON.parse(localStorage.getItem('profile') || '{}');

  Object.assign(formData, {
    bk_id: "",
    vis_id: "",
    // ใส่ค่าอัตโนมัติจากโปรไฟล์ผู้ใช้ที่ Login อยู่
    emp_id: savedProfile.emp_id || "", 
    emp_name: `${savedProfile.emp_firstname} ${savedProfile.emp_lastname}`,
    emp_department: savedProfile.emp_department || "-",
    emp_section: savedProfile.emp_section || "-",
    emp_position: savedProfile.emp_position || "-",
    
    b_id: "",
    purpose: "",
    car_registration: "",
    appointment_date: null
  })
  isEditing.value = false
  isModalVisible.value = true
}

const editBooking = async (record) => {
  formKey.value++

  const savedProfile = JSON.parse(localStorage.getItem('profile') || '{}');

  Object.assign(formData, {
    bk_id: record.bk_id,
    vis_id: record.vis_id,
    emp_id: record.emp_id,

    emp_name: `${savedProfile.emp_firstname} ${savedProfile.emp_lastname}`,
    emp_department: savedProfile.emp_department || "-",
    emp_section: savedProfile.emp_section || "-",
    emp_position: savedProfile.emp_position || "-",

    b_id: record.b_id,
    purpose: record.purpose,
    car_registration: record.car_registration,
    appointment_range: record.appointment_start && record.appointment_end ? [dayjs(record.appointment_start), dayjs(record.appointment_end)] : [],
    appointment_start: record.appointment_start ? dayjs(record.appointment_start) : null,
    appointment_end: record.appointment_end ? dayjs(record.appointment_end) : null
  })
  isEditing.value = true
  isModalVisible.value = true
}

const closeModal = async () => {
  isModalVisible.value = false
  await nextTick()
  formRef.value?.resetFields()
  formRef.value?.clearValidate()
}

// save add
const saveAdd = async () => {
  try {
    await formRef.value.validate();
    
    const payload = {
      vis_id: formData.vis_id,
      emp_id: formData.emp_id,
      b_id: formData.b_id || null,
      purpose: formData.purpose,
      car_registration: formData.car_registration,
      appointment_start: formData.appointment_start.format('YYYY-MM-DD HH:mm:ss'),
      appointment_end: formData.appointment_end.format('YYYY-MM-DD HH:mm:ss'),
      emp_department: formData.emp_department,
      emp_section: formData.emp_section,
      emp_position: formData.emp_position
    }

    const res = await axios.put("/booking/add_booking", payload, {
      headers: { Authorization: `Basic ${auth}` }
    })
    message.success(res.data.message || "บันทึกสำเร็จ")
    await fetchBookings()
    closeModal()
  } catch (error) {
    message.error(error.response?.data?.message || "บันทึกไม่สำเร็จ")
  }
}

// save edit
const saveEdit = async () => {
  try {
    await formRef.value.validate();
    
    const payload = {
      bk_id: formData.bk_id,
      vis_id: formData.vis_id,
      emp_id: formData.emp_id,
      b_id: formData.b_id || null,
      purpose: formData.purpose,
      car_registration: formData.car_registration,
      appointment_start: formData.appointment_start ? formData.appointment_start.format('YYYY-MM-DD HH:mm:ss') : null,
      appointment_end: formData.appointment_end ? formData.appointment_end.format('YYYY-MM-DD HH:mm:ss') : null
    }

    const res = await axios.patch("/booking/edit_booking", payload, {
      headers: { Authorization: `Basic ${auth}` }
    })
    
    message.success(res.data.message || "แก้ไขสำเร็จ")
    await fetchBookings()
    closeModal()
  } catch (error) {
    console.error("Edit Error:", error);
    message.error(error.response?.data?.message || error.response?.data?.error || "อัปเดตไม่สำเร็จ")
  }
}

// cancel booking
const cancelBooking = async (bk_id) => {
  try {
    const res = await axios.patch("/booking/cancel_booking", { bk_id }, {
      headers: { Authorization: `Basic ${auth}` }
    })
    message.success(res.data.message || "ยกเลิกสำเร็จ")
    await fetchBookings()
  } catch (error) {
    message.error(error.response?.data?.message || error.response?.data?.error || "ยกเลิกไม่สำเร็จ")
  }
}

// โหลดข้อมูลตอนเข้า
onMounted(async () => {
  isLoading.value = true
  await Promise.all([
    fetchBookings(),
    fetchRelatedData()
  ])
  isLoading.value = false;
});

</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Prompt:wght@400;500;600;700&display=swap');

.container-fluid { font-family: 'Prompt', sans-serif; }

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 16px;
  gap: 12px;
  flex-wrap: wrap;
}

.search-input { width: 300px; }

.filter-section { border: none !important; }

.filter-label {
  display: block;
  font-weight: 600;
  margin-bottom: 4px;
  color: #64748b;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
}

.btn-Add {
  background: linear-gradient(135deg, #00C896, #00a877) !important;
  border-color: transparent !important;
  color: white !important;
  height: 38px !important;
  padding: 0 18px !important;
  border-radius: 10px !important;
  font-weight: 600 !important;
  display: flex;
  align-items: center;
  gap: 6px;
  box-shadow: 0 3px 10px rgba(0,200,150,0.3) !important;
  transition: all 0.2s ease !important;
}

.btn-Add:hover {
  transform: translateY(-1px) !important;
  box-shadow: 0 5px 16px rgba(0,200,150,0.4) !important;
}

.card-table {
  background-color: white;
  border-radius: 14px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.05);
  border: 1px solid #f0f4f2;
  overflow: hidden;
}

/* Table heading */
:deep(.ant-table-thead > tr > th) {
  background: #f8fbf9 !important;
  color: #64748b !important;
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  border-bottom: 1.5px solid #e8f5f1 !important;
}

:deep(.ant-table-tbody > tr > td) {
  border-bottom: 1px solid #f4f7f6 !important;
  font-size: 13.5px;
}

:deep(.ant-table-tbody > tr:hover > td) {
  background: rgba(0,200,150,0.04) !important;
}

:deep(.ant-table-container) { border-radius: 14px !important; overflow: hidden !important; }

:deep(.ant-pagination-item-active) {
  background: #00C896 !important;
  border-color: #00C896 !important;
}
:deep(.ant-pagination-item-active a) { color: white !important; }

.editable-cell-icon {
  color: #3b82f6;
  cursor: pointer;
  font-size: 16px;
  transition: all 0.2s;
}
.editable-cell-icon:hover { color: #2563eb; transform: scale(1.15); }

.editable-cell-icon-close {
  color: #ef4444;
  cursor: pointer;
  font-size: 16px;
  transition: all 0.2s;
}
.editable-cell-icon-close:hover { color: #dc2626; transform: scale(1.15); }

/* Status tags */
:deep(.ant-tag) {
  border-radius: 20px !important;
  font-weight: 600 !important;
  font-size: 11.5px !important;
  padding: 1px 10px !important;
  border: none !important;
}

@media screen and (max-width: 1024px) {
  .toolbar { flex-wrap: wrap; gap: 10px; }
  .btn-Add { font-size: 14px; }
}
</style>